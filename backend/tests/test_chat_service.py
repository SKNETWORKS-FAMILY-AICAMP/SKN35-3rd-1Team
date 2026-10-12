"""Saved chat history with a fake repository (no TiDB)."""

# ruff: noqa: DTZ001  (naive UTC is what the DATETIME columns store)

from datetime import UTC, datetime
from types import SimpleNamespace

import pytest

from app.models import ChatRole
from app.repositories import chat_repository
from app.schemas.chat import ChatResponse, Source
from app.services import chat_service

NOW = datetime(2026, 10, 12, 3, 0)


class FakeDb:
    def __init__(self) -> None:
        self.commits = 0

    def commit(self) -> None:
        self.commits += 1


@pytest.fixture
def repo(monkeypatch):
    state = SimpleNamespace(session_id=None, messages=[], calls=[])

    def get_or_create(db, *, user_id, artwork_id, now):
        state.calls.append(("session", user_id, artwork_id))
        state.session_id = state.session_id or 42
        return state.session_id

    def add_message(db, **kwargs):
        state.calls.append(("message", kwargs["role"], kwargs["content"]))
        state.messages.append(kwargs)

    cr = chat_repository
    monkeypatch.setattr(cr, "get_session_id", lambda db, **k: state.session_id)
    monkeypatch.setattr(cr, "get_or_create_session_id", get_or_create)
    monkeypatch.setattr(cr, "add_message", add_message)
    monkeypatch.setattr(
        cr, "touch_session", lambda db, **k: state.calls.append(("touch", k["now"]))
    )
    monkeypatch.setattr(
        cr,
        "delete_session",
        lambda db, **k: state.calls.append(("delete", k["session_id"])),
    )
    return state


def test_save_exchange_stores_question_then_answer(repo) -> None:
    db = FakeDb()
    source = Source(
        document_id=1,
        title="야경 해설",
        doc_type="artwork_commentary",
        source_name="국립중앙박물관",
        source_url=None,
        license="공공누리 제1유형",
    )
    response = ChatResponse(
        answer="1642년에 그렸습니다.", refused=False, sources=[source]
    )
    chat_service.save_exchange(
        db,
        user_id=1,
        artwork_id=7,
        question="언제 그렸나요?",
        response=response,
        now=NOW,
    )
    assert repo.calls == [
        ("session", 1, 7),
        ("message", ChatRole.USER, "언제 그렸나요?"),
        ("message", ChatRole.ASSISTANT, "1642년에 그렸습니다."),
        ("touch", NOW),
    ]
    question, answer = repo.messages
    assert question["sources"] is None
    assert answer["sources"] == [source.model_dump(mode="json")]
    assert db.commits == 1


def test_no_session_means_no_messages(repo) -> None:
    assert chat_service.list_messages(FakeDb(), user_id=1, artwork_id=7) == []


def test_messages_restore_sources_and_utc(monkeypatch, repo) -> None:
    repo.session_id = 42
    stored = [
        SimpleNamespace(
            id=1,
            role=ChatRole.USER,
            content="질문",
            refused=False,
            sources=None,
            created_at=NOW,
        ),
        SimpleNamespace(
            id=2,
            role=ChatRole.ASSISTANT,
            content="자료에 없습니다.",
            refused=True,
            sources=[],
            created_at=NOW,
        ),
    ]
    monkeypatch.setattr(chat_repository, "list_messages", lambda db, session_id: stored)
    out = chat_service.list_messages(FakeDb(), user_id=1, artwork_id=7)
    assert [(m.role, m.refused, m.sources) for m in out] == [
        ("user", False, []),
        ("assistant", True, []),
    ]
    assert out[0].created_at == NOW.replace(tzinfo=UTC)


def test_reset_is_idempotent(repo) -> None:
    db = FakeDb()
    chat_service.reset(db, user_id=1, artwork_id=7)
    assert repo.calls == [] and db.commits == 0
    repo.session_id = 42
    chat_service.reset(db, user_id=1, artwork_id=7)
    assert repo.calls == [("delete", 42)] and db.commits == 1
