"""Chroma 동기화 테스트. 메모리 Chroma(EphemeralClient)에 실제로 넣어 보고, TiDB 대신 가짜 레코드를 쓴다."""

import uuid

import chromadb
import pytest

from app.clients import chroma_client
from scripts import sync_chroma as sc


@pytest.fixture
def collection(monkeypatch):
    monkeypatch.setattr(chroma_client, "model_name", lambda: "test-model")
    # EphemeralClient 는 프로세스 안에서 상태를 공유하므로 테스트마다 이름을 새로 짓는다
    return chroma_client._collection(chromadb.EphemeralClient(), f"test-{uuid.uuid4().hex}")


def record(i, vec=(1.0, 0.0, 0.0)):
    return sc.Record(
        id=i, embedding=list(vec), document=f"청크 {i}",
        metadata={"document_id": 100 + i, "doc_key": f"a/{i}", "doc_type": "artist_bio", "artwork_id": 0, "chunk_index": 0},
    )


def fetcher(calls):
    def fetch(ids):
        calls.append(list(ids))
        return [record(i) for i in ids]
    return fetch


def test_chunks_added_then_rerun_is_noop(collection):
    calls = []
    assert sc.sync_chunks(collection, {1, 2, 3}, fetcher(calls)) == sc.Result(added=3)
    assert collection.count() == 3
    assert sc.sync_chunks(collection, {1, 2, 3}, fetcher(calls)) == sc.Result()
    assert calls == [[1, 2, 3], []]  # 두 번째 실행은 TiDB 에서 아무것도 읽지 않음
    got = collection.get(ids=["2"], include=["documents", "metadatas"])
    assert got["documents"] == ["청크 2"] and got["metadatas"][0]["document_id"] == 102


def test_chunks_removed_from_tidb_are_deleted(collection):
    sc.sync_chunks(collection, {1, 2, 3}, fetcher([]))
    # build_chunks 가 문서 하나를 다시 만들면 예전 청크 id(2)는 사라지고 새 id(4)가 생긴다
    assert sc.sync_chunks(collection, {1, 3, 4}, fetcher([])) == sc.Result(added=1, deleted=1)
    assert sorted(collection.get(include=[])["ids"]) == ["1", "3", "4"]


def test_dry_run_does_not_write(collection):
    calls = []
    assert sc.sync_chunks(collection, {1, 2}, fetcher(calls), dry_run=True) == sc.Result(added=2)
    assert collection.count() == 0 and calls == []


def test_batches_respect_limit(collection, monkeypatch):
    monkeypatch.setattr(sc, "BATCH", 2)
    sc.sync_chunks(collection, set(range(1, 6)), fetcher([]))
    assert collection.count() == 5


def test_artworks_upsert_replaces_vectors_and_deletes_missing(collection):
    sc.sync_artworks(collection, [record(1), record(2)])
    result = sc.sync_artworks(collection, [record(1, vec=(0.0, 1.0, 0.0))])
    assert result == sc.Result(upserted=1, deleted=1)
    assert collection.get(include=[])["ids"] == ["1"]
    hit = collection.query(query_embeddings=[[0.0, 1.0, 0.0]], n_results=1)
    assert hit["distances"][0][0] == pytest.approx(0.0, abs=1e-6)  # 새 벡터로 바뀌었고 거리는 cosine


def test_scope_filter_with_document_ids(collection):
    """retriever 가 쓸 방식: TiDB 에서 구한 범위 문서 id 로 $in 필터."""
    sc.sync_chunks(collection, {1, 2, 3}, fetcher([]))
    hit = collection.query(query_embeddings=[[1.0, 0.0, 0.0]], n_results=5, where={"document_id": {"$in": [101, 103]}})
    assert sorted(hit["ids"][0]) == ["1", "3"]


def test_collection_made_with_other_model_is_rejected(monkeypatch):
    client = chromadb.EphemeralClient()
    name = f"test-{uuid.uuid4().hex}"
    monkeypatch.setattr(chroma_client, "model_name", lambda: "old-model")
    chroma_client._collection(client, name)
    monkeypatch.setattr(chroma_client, "model_name", lambda: "new-model")
    with pytest.raises(RuntimeError, match="--reset"):
        chroma_client._collection(client, name)


def test_ids_are_read_page_by_page(collection, monkeypatch):
    """Chroma Cloud 는 get() 한 번에 300개까지만 돌려준다. 한 쪽보다 많아도 전부 읽어야 다시 넣지 않는다."""
    monkeypatch.setattr(sc, "BATCH", 2)
    sc.sync_chunks(collection, set(range(1, 8)), fetcher([]))
    assert sc.chroma_ids(collection) == set(range(1, 8))
    assert sc.sync_chunks(collection, set(range(1, 8)), fetcher([])) == sc.Result()
