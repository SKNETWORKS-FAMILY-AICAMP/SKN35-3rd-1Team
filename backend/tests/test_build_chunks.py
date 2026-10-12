"""청크 적재 계획과 쓰기 순서 테스트. DB·임베딩 API 없이 가짜 세션과 가짜 임베딩으로 확인한다."""

import pytest

from app.clients import embedding_client
from app.models import EMBEDDING_DIMENSION, DocumentChunk
from scripts import build_chunks as bc

MODEL = "test-model"


def doc(doc_id, content="짧은 본문."):
    return {"id": doc_id, "doc_key": f"a/{doc_id}", "title": f"문서{doc_id}", "content": content}


def stored(d, model=MODEL):
    """지금 규칙으로 이미 적재된 상태의 청크."""
    return [(c.chunk_index, c.content, model) for c in bc.chunk_document(d)]


def test_plan_classifies_new_up_to_date_and_stale():
    d1, d2, d3, d4 = doc(1), doc(2), doc(3, "바뀐 본문."), doc(4)
    existing = {
        2: stored(d2),
        3: stored(doc(3, "예전 본문.")),
        4: stored(d4, model="old-model"),
    }
    p = bc.plan([d1, d2, d3, d4], existing, MODEL)
    assert list(p.new) == [1]
    assert p.skip == [2]
    assert sorted(p.stale) == [3, 4]
    assert list(p.todo) == [1, 3, 4]


def test_plan_detects_extra_old_chunks():
    d = doc(1)
    existing = {1: stored(d) + [(1, "남은 예전 청크", MODEL)]}
    assert list(bc.plan([d], existing, MODEL).stale) == [1]


class FakeSession:
    def __init__(self):
        self.log = []
        self.rows = []

    def execute(self, stmt):
        self.log.append("delete")

    def add_all(self, rows):
        rows = list(rows)
        self.rows += rows
        self.log.append(f"add {len(rows)}")

    def commit(self):
        self.log.append("commit")


def fake_embed(texts):
    return [[float(i)] * EMBEDDING_DIMENSION for i in range(len(texts))]


def test_write_embeds_then_replaces_in_batches(monkeypatch):
    monkeypatch.setattr(bc, "DOCS_PER_EMBED_CALL", 2)
    todo = bc.plan([doc(i) for i in (1, 2, 3)], {}, MODEL).todo
    session = FakeSession()
    assert bc.write(session, todo, MODEL, fake_embed) == 3
    assert session.log == ["delete", "add 2", "commit", "delete", "add 1", "commit"]
    row = session.rows[0]
    assert isinstance(row, DocumentChunk)
    assert (row.document_id, row.chunk_index, row.embedding_model) == (1, 0, MODEL)
    assert row.content.startswith("문서1\n\n")


def test_write_leaves_db_untouched_when_embedding_fails():
    def broken(texts):
        raise RuntimeError("API 오류")

    session = FakeSession()
    with pytest.raises(RuntimeError):
        bc.write(session, bc.plan([doc(1)], {}, MODEL).todo, MODEL, broken)
    assert session.log == []


def test_embedding_dimension_mismatch_is_rejected():
    with pytest.raises(ValueError, match="VECTOR"):
        embedding_client._check([[0.0] * (EMBEDDING_DIMENSION - 1)])
    embedding_client._check([[0.0] * EMBEDDING_DIMENSION])
