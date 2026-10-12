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
