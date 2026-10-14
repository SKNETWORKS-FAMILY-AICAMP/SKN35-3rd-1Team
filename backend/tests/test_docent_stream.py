"""Exercise incremental answer delivery and final citation validation."""

import asyncio
from types import SimpleNamespace

import pytest

from app.rag.classifier import classify
from app.schemas.chat import ChatRequest
from app.services import docent_stream


@pytest.mark.parametrize("used_ids, refused", [([4], False), ([999], True), ([], True)])
def test_rag_stream_emits_deltas_and_verified_final_answer(monkeypatch, used_ids, refused):
    metadata = {
        "chunk_id": 9,
        "document_id": 4,
        "title": "작품 해설",
        "doc_type": "artwork_commentary",
        "source_name": "미술관",
        "source_url": None,
        "license": None,
    }
    doc = SimpleNamespace(metadata=metadata, page_content="확인된 작품 자료")
    monkeypatch.setattr(
        docent_stream.catalog_service,
        "get_artwork",
        lambda *args: SimpleNamespace(title="작품", artist_name="작가"),
    )
    monkeypatch.setattr(
        docent_stream,
        "classify_artwork",
        lambda *args: SimpleNamespace(kind="rag"),
    )
    monkeypatch.setattr(docent_stream.docent_scope, "is_artwork_request", lambda *args: True)
    monkeypatch.setattr(docent_stream, "retrieve", lambda *args: [doc])
    monkeypatch.setattr(
        docent_stream, "get_settings",
        lambda: SimpleNamespace(openai_api_key="test", assistant_model="mock"),
    )
    styles = []
    monkeypatch.setattr(
        docent_stream.docent_service,
        "instructions",
        lambda *args: styles.append(args) or "",
    )
    saved = []
    monkeypatch.setattr(
        docent_stream.chat_service,
        "save_exchange",
        lambda *args, **kwargs: saved.append(kwargs),
    )

    class FakeParser:
        def __init__(self, **kwargs):
            pass

        def get_format_instructions(self):
            return "Return JSON"

    class FakeModel:
        def __init__(self, **kwargs):
            pass

        def __or__(self, parser):
            return self

        async def astream(self, messages):
            yield {"answer": "근거"}
            yield {"answer": "근거 있는 답변", "refused": False, "used_document_ids": used_ids}

    monkeypatch.setattr(docent_stream, "JsonOutputParser", FakeParser)
    monkeypatch.setattr(docent_stream, "ChatOpenAI", FakeModel)

    async def collect():
        return [
            event
            async for event in docent_stream.answer_events(
                None,
                artwork_id=1,
                body=ChatRequest(question="무엇인가요?", explanation_style="deep"),
                user_id=3,
            )
        ]

    events = asyncio.run(collect())
    assert events[:2] == [("token", "근거"), ("token", " 있는 답변")]
    assert events[-1][0] == "done"
    assert events[-1][1].refused is refused
    if refused:
        assert events[-2][0] == "replace"
        assert events[-1][1].sources == []
    else:
        assert events[-1][1].sources[0].document_id == 4
    assert saved[0]["response"] == events[-1][1]
    assert styles == [(None, 3, "deep")]


@pytest.mark.parametrize("question", [
    "이거 내 컬렉션에 추가해줘",
    "나 오늘 저녁 뭐 먹을까?",
    "욕해봐",
    "나 기분나빠",
    "뭐해? 나 심심해",
])
def test_clear_unrelated_stream_refuses_without_artwork_answer(monkeypatch, question):
    monkeypatch.setattr(
        docent_stream.catalog_service,
        "get_artwork",
        lambda *args: SimpleNamespace(title="루엘에서 본 풍경", artist_name="모네"),
    )
    classify_action = lambda _db, _artwork_id, question: classify(question, "claude-monet")
    monkeypatch.setattr(docent_stream, "classify_artwork", classify_action)
    monkeypatch.setattr(docent_stream.docent_service, "classify_artwork", classify_action)
    monkeypatch.setattr(
        docent_stream.docent_service,
        "retrieve",
        lambda *args: pytest.fail("앱 기능 요청에 자료 검색"),
    )
    monkeypatch.setattr(
        docent_stream.docent_service,
        "generate",
        lambda *args: pytest.fail("앱 기능 요청에 LLM 호출"),
    )

    async def collect():
        return [
            event
            async for event in docent_stream.answer_events(
                None,
                artwork_id=1,
                body=ChatRequest(question=question),
                user_id=None,
            )
        ]

    events = asyncio.run(collect())
    assert events[0] == ("token", "해당 작품과 작가에 대해서만 대화 할 수 있어요.")
    assert events[1][0] == "done"
    assert events[1][1].refused
    assert events[1][1].sources == []


def test_semantic_scope_gate_refuses_stream_before_retrieval(monkeypatch):
    monkeypatch.setattr(
        docent_stream.catalog_service,
        "get_artwork",
        lambda *args: SimpleNamespace(title="대수욕도", artist_name="세잔"),
    )
    monkeypatch.setattr(
        docent_stream,
        "classify_artwork",
        lambda *args: classify("이번 주 운동 루틴 알려줘", "paul-cezanne"),
    )
    monkeypatch.setattr(docent_stream.docent_scope, "is_artwork_request", lambda *args: False)
    monkeypatch.setattr(docent_stream, "retrieve", lambda *args: pytest.fail("범위 밖 질문에 자료 검색"))

    async def collect():
        return [
            event
            async for event in docent_stream.answer_events(
                None,
                artwork_id=1,
                body=ChatRequest(question="이번 주 운동 루틴 알려줘"),
                user_id=None,
            )
        ]

    events = asyncio.run(collect())
    assert events[0] == ("token", "해당 작품과 작가에 대해서만 대화 할 수 있어요.")
    assert events[-1][0] == "done"
    assert events[-1][1].refused and events[-1][1].sources == []
