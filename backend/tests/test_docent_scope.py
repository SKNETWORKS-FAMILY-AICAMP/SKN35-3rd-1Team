"""The separate scope check sees the latest request without retrieved artwork text."""

import json
from types import SimpleNamespace

import pytest

from app.docent import scope as docent_scope
from app.schemas.chat import ChatRequest, ChatTurn


@pytest.mark.parametrize("kind,expected", [
    ("off_topic", False),
    ("artwork", True),
])
def test_scope_decision_uses_current_question_and_only_reference_history(monkeypatch, kind, expected):
    calls = {}
    monkeypatch.setattr(
        docent_scope,
        "get_settings",
        lambda: SimpleNamespace(openai_api_key="test", assistant_model="test-model"),
    )

    class FakeModel:
        def __init__(self, **kwargs):
            calls["settings"] = kwargs

        def with_structured_output(self, schema):
            assert schema is docent_scope.ScopeDecision
            return self

        def invoke(self, messages):
            calls["messages"] = messages
            return docent_scope.ScopeDecision(kind=kind)

    monkeypatch.setattr(docent_scope, "ChatOpenAI", FakeModel)
    body = ChatRequest(
        question="나 기분나빠",
        history=[
            ChatTurn(role="user", content="이 그림은 언제 그렸나요?"),
            ChatTurn(role="assistant", content="1906년입니다."),
        ],
    )
    art = SimpleNamespace(title="대수욕도", artist_name="세잔")

    assert docent_scope.is_artwork_request(art, body) is expected
    assert calls["settings"]["temperature"] == 0
    system, user = calls["messages"]
    assert "나 기분나빠" in system[1]
    assert "이 그림에 대해 비난해봐" in system[1]
    data = json.loads(user[1])
    assert data["question"] == "나 기분나빠"
    assert data["selected_artwork"] == {"title": "대수욕도", "artist_name": "세잔"}
    assert len(data["history"]) == 2
    assert "sources" not in data
