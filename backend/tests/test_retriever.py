"""검색 함수 테스트. 메모리 Chroma 에 청크를 넣고, TiDB 조회(repository)는 가짜 함수로 바꾼다."""

import uuid

import chromadb
import pytest

from app.clients import chroma_client
from app.rag import retriever
from app.repositories import document_repository as repo

# 문서 id → (청크 id, 머리말 포함 본문, 벡터). 질문 벡터는 [1, 0, 0]
CHUNKS = {
    10: [(1, "야경 해설\n\n민병대 그림.", [1.0, 0.0, 0.0]), (2, "야경 해설 > 감상 포인트\n\n빛.", [0.9, 0.1, 0.0])],
    20: [(3, "렘브란트 연표: 1642\n\n사스키아의 죽음.", [0.0, 1.0, 0.0])],  # 질문과 멀다
    30: [(4, "렘브란트 > 답변 시 주의\n\n소장처 정정.", [0.0, 0.0, 1.0])],  # 질문과 멀다
    40: [(5, "다른 작가 해설\n\n범위 밖.", [1.0, 0.0, 0.0])],  # 질문과 가깝지만 범위 밖
}


@pytest.fixture
def collection(monkeypatch):
    monkeypatch.setattr(chroma_client, "model_name", lambda: "test-model")
    col = chroma_client._collection(chromadb.EphemeralClient(), f"test-{uuid.uuid4().hex}")
    rows = [(cid, text, vec, doc_id) for doc_id, chunks in CHUNKS.items() for cid, text, vec in chunks]
    col.add(
        ids=[str(r[0]) for r in rows], documents=[r[1] for r in rows], embeddings=[r[2] for r in rows],
        metadatas=[{"document_id": r[3], "doc_key": f"k/{r[3]}", "doc_type": "artist_bio", "artwork_id": 0,
                    "chunk_index": 0} for r in rows],
    )
    return col


@pytest.fixture
def fake_repo(monkeypatch):
    scope = {7: [10, 20, 30]}  # 작품 7 의 범위 문서
    monkeypatch.setattr(repo, "scope_document_ids", lambda s, a: scope.get(a, []))
    monkeypatch.setattr(repo, "pinned_chunk_ids", lambda s, a, ids: [3, 4])
    monkeypatch.setattr(repo, "document_sources", lambda s, ids: {
        i: repo.DocumentSource(i, f"k/{i}", "artist_bio", f"문서{i}", "위키백과", f"https://x/{i}", "CC BY-SA 4.0",
                               [{"source_name": "Met", "source_url": "https://met"}])
        for i in ids
    })


def search(collection, artwork_id=7, k=2):
    return retriever.retrieve(None, artwork_id, "질문", k, collection=collection, embed=lambda q: [1.0, 0.0, 0.0])


def test_ranked_hits_stay_in_scope_and_pinned_follow(collection, fake_repo):
    docs = search(collection)
    assert [d.metadata["chunk_id"] for d in docs] == [1, 2, 3, 4]  # 범위 밖 청크 5 는 가까워도 빠짐
    assert [d.metadata["pinned"] for d in docs] == [False, False, True, True]
    distances = [d.metadata["distance"] for d in docs]
    assert distances[0] == pytest.approx(0.0, abs=1e-4) and distances[0] <= distances[1]


def test_metadata_matches_contract(collection, fake_repo):
    doc = search(collection)[0]
    assert set(doc.metadata) == {
        "chunk_id", "chunk_index", "document_id", "doc_key", "doc_type", "title", "source_name", "source_url",
        "license", "distance", "pinned", "annotation", "basis_sources",
    }
    assert doc.page_content.startswith("야경 해설\n\n")
    assert (doc.metadata["title"], doc.metadata["license"]) == ("문서10", "CC BY-SA 4.0")


def test_annotation_chunks_carry_basis_sources(collection, fake_repo):
    by_id = {d.metadata["chunk_id"]: d.metadata for d in search(collection)}
    assert by_id[2]["annotation"] == "감상 포인트" and by_id[2]["basis_sources"][0]["source_name"] == "Met"
    assert by_id[4]["annotation"] == "답변 시 주의"
    assert by_id[1]["annotation"] is None and by_id[1]["basis_sources"] == []


def test_pinned_chunk_already_ranked_is_not_duplicated(collection, fake_repo, monkeypatch):
    monkeypatch.setattr(repo, "pinned_chunk_ids", lambda s, a, ids: [1, 3])
    ids = [d.metadata["chunk_id"] for d in search(collection)]
    assert ids == [1, 2, 3]


def test_unknown_artwork_returns_empty_without_embedding(collection, fake_repo):
    def fail(q):
        raise AssertionError("범위가 비면 임베딩 API 를 부르지 않아야 함")

    assert retriever.retrieve(None, 999, "질문", collection=collection, embed=fail) == []


def add(collection, chunk_id, doc_id, vec, *, artwork_id=0, doc_type="artist_bio", text="본문"):
    collection.add(
        ids=[str(chunk_id)], documents=[f"추가 문서\n\n{text}"], embeddings=[vec],
        metadatas=[{"document_id": doc_id, "doc_key": f"k/{doc_id}", "doc_type": doc_type,
                    "artwork_id": artwork_id, "chunk_index": 0}],
    )


def test_own_artwork_commentary_gets_a_seat_even_if_far(collection, fake_repo, monkeypatch):
    """생애 문서가 상위를 다 차지해도 고른 작품 자신의 해설은 들어온다."""
    monkeypatch.setattr(repo, "scope_document_ids", lambda s, a: [10, 20, 30, 50])
    add(collection, 6, 50, [0.0, 0.2, 1.0], artwork_id=7)  # 질문과 멀지만 작품 7 의 해설
    ids = [d.metadata["chunk_id"] for d in search(collection, k=1)]
    assert 6 in ids and ids[0] == 1


def test_comparison_seat_only_for_comparison_questions(collection, fake_repo, monkeypatch):
    monkeypatch.setattr(repo, "scope_document_ids", lambda s, a: [10, 20, 30, 60])
    monkeypatch.setattr(repo, "pinned_chunk_ids", lambda s, a, ids: [])
    add(collection, 7, 60, [0.0, 0.3, 1.0], doc_type="artist_comparison")  # 질문과 먼 비교 문서

    def ask(question):
        docs = retriever.retrieve(None, 7, question, 1, collection=collection, embed=lambda q: [1.0, 0.0, 0.0])
        return [d.metadata["chunk_id"] for d in docs]

    assert 7 not in ask("이 그림은 언제 그렸어?")
    assert 7 in ask("렘브란트와 카라바조의 명암 차이는?")


def test_own_seats_rotate_across_documents(collection, fake_repo, monkeypatch):
    """원문과 번역본처럼 같은 작품의 해설이 둘이면, 더 가까운 문서가 자리를 다 가져가지 않는다."""
    monkeypatch.setattr(repo, "scope_document_ids", lambda s, a: [10, 20, 30, 70, 71])
    monkeypatch.setattr(repo, "pinned_chunk_ids", lambda s, a, ids: [])
    for cid, vec in ((8, [0.5, 0.0, 0.9]), (9, [0.5, 0.0, 0.8]), (10, [0.5, 0.0, 0.7])):
        add(collection, cid, 70, vec, artwork_id=7)  # 번역본: 청크 3개, 모두 원문보다 가까움
    add(collection, 11, 71, [0.0, 0.1, 1.0], artwork_id=7)  # 원문: 청크 1개, 더 멂
    docs = retriever.retrieve(None, 7, "질문", 1, collection=collection, embed=lambda q: [1.0, 0.0, 0.0])
    own = [d.metadata["document_id"] for d in docs if d.metadata["document_id"] in (70, 71)]
    assert 71 in own and own.count(70) == 2  # 문서마다 1개씩 먼저, 남은 자리는 거리순


def test_comparison_seats_cover_two_documents(collection, fake_repo, monkeypatch):
    monkeypatch.setattr(repo, "scope_document_ids", lambda s, a: [10, 60, 61])
    monkeypatch.setattr(repo, "pinned_chunk_ids", lambda s, a, ids: [])
    add(collection, 12, 60, [0.0, 0.3, 1.0], doc_type="artist_comparison")
    add(collection, 13, 60, [0.0, 0.35, 1.0], doc_type="artist_comparison")
    add(collection, 14, 61, [0.0, 0.0, 1.0], doc_type="artist_comparison")  # 가장 먼 비교 문서
    docs = retriever.retrieve(None, 7, "두 화가의 명암 차이는?", 1, collection=collection, embed=lambda q: [1.0, 0.0, 0.0])
    assert {d.metadata["document_id"] for d in docs} >= {60, 61}


def test_pinned_chunks_do_not_depend_on_approximate_search(collection, fake_repo, monkeypatch):
    """Chroma Cloud 의 query(ids=...) 는 근사 검색 후보 밖 id 를 빼 버린다. 항상 넣는 청크는 get() 으로 가져와야 한다."""
    real_query = collection.query

    def query(**kw):
        assert "ids" not in kw, "항상 넣는 청크를 query(ids=...) 로 가져오면 Cloud 에서 빠질 수 있음"
        return real_query(**kw)

    monkeypatch.setattr(collection, "query", query)
    docs = search(collection)
    pinned = {d.metadata["chunk_id"]: d.metadata["distance"] for d in docs if d.metadata["pinned"]}
    assert set(pinned) == {3, 4}
    assert pinned[3] == pytest.approx(1.0, abs=1e-4)  # [0,1,0] 과 질문 [1,0,0] 은 직교 → 코사인 거리 1


def test_translation_pair_counts_as_one_topic_for_comparison_seats(collection, fake_repo, monkeypatch):
    """비교 자리 2개를 같은 주제의 원문·번역본이 나눠 갖지 않는다 (테네브리즘 원문·번역 vs 키아로스쿠로)."""
    monkeypatch.setattr(repo, "scope_document_ids", lambda s, a: [10, 80, 81, 82])
    monkeypatch.setattr(repo, "pinned_chunk_ids", lambda s, a, ids: [])

    def put(cid, doc_id, key, vec):
        collection.add(ids=[str(cid)], documents=["비교\n\n본문"], embeddings=[vec], metadatas=[{
            "document_id": doc_id, "doc_key": key, "doc_type": "artist_comparison", "artwork_id": 0, "chunk_index": 0}])

    put(15, 80, "_comparisons/tenebrism", [0.0, 0.3, 1.0])
    put(16, 81, "_comparisons/tenebrism.en", [0.0, 0.31, 1.0])
    put(17, 82, "_comparisons/chiaroscuro", [0.0, 0.0, 1.0])  # 셋 중 가장 멂
    docs = retriever.retrieve(None, 7, "두 화가의 명암 차이는?", 1, collection=collection, embed=lambda q: [1.0, 0.0, 0.0])
    ids = {d.metadata["document_id"] for d in docs}
    assert {80, 82} <= ids and 81 not in ids  # 테네브리즘 원문 + 키아로스쿠로, 번역본은 자리를 못 받음


def test_same_artwork_document_outside_reviewed_scope_is_excluded(collection, fake_repo):
    add(collection, 99, 99, [1.0, 0.0, 0.0], artwork_id=7)
    assert 99 not in {d.metadata["document_id"] for d in search(collection)}
