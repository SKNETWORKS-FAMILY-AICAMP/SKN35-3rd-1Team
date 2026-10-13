"""작품 벡터 적재 테스트. DB·임베딩 API 없이 가짜 세션과 가짜 임베딩으로 확인한다."""

import pytest

from app.models import EMBEDDING_DIMENSION
from scripts import build_artwork_embeddings as ba

MODEL = "test-model"


def artwork(i, **kw):
    values = {
        "id": i, "title": "인상, 해돋이", "title_en": "Impression, Sunrise", "artist_name": "클로드 모네",
        "movement_name": "인상주의", "medium": "캔버스에 유채", "description": "르아브르 항구의 해돋이.",
    }
    return ba.ArtworkRow(**(values | kw))


def test_text_has_title_movement_medium_description_without_artist():
    assert ba.artwork_text(artwork(1)) == (
        "제목: 인상, 해돋이 (Impression, Sunrise)\n사조: 인상주의\n재료·기법: 캔버스에 유채\n설명: 르아브르 항구의 해돋이."
    )


def test_text_with_artist_and_missing_values():
    text = ba.artwork_text(artwork(1, title_en=None, medium=None), with_artist=True)
    assert text == "제목: 인상, 해돋이\n작가: 클로드 모네\n사조: 인상주의\n설명: 르아브르 항구의 해돋이."


class FakeSession:
    def __init__(self):
        self.log = []

    def execute(self, stmt):
        self.log.append(f"upsert {len(stmt.compile().params) // 3}")

    def commit(self):
        self.log.append("commit")


def fake_embed(texts):
    return [[0.0] * EMBEDDING_DIMENSION for _ in texts]


def test_write_upserts_in_batches_then_commits_once(monkeypatch):
    monkeypatch.setattr(ba, "ROWS_PER_INSERT", 2)
    session = FakeSession()
    assert ba.write(session, [artwork(i) for i in range(5)], MODEL, fake_embed) == 5
    assert session.log == ["upsert 2", "upsert 2", "upsert 1", "commit"]


def test_upsert_statement_updates_vector_on_duplicate():
    from sqlalchemy.dialects import mysql

    captured = []

    class Capture(FakeSession):
        def execute(self, stmt):
            captured.append(str(stmt.compile(dialect=mysql.dialect())))

    ba.write(Capture(), [artwork(1)], MODEL, fake_embed)
    assert "ON DUPLICATE KEY UPDATE" in captured[0]
    assert "embedding = VALUES(embedding)" in captured[0]


def test_write_leaves_db_untouched_when_embedding_fails():
    def broken(texts):
        raise RuntimeError("API 오류")

    session = FakeSession()
    with pytest.raises(RuntimeError):
        ba.write(session, [artwork(1)], MODEL, broken)
    assert session.log == []
