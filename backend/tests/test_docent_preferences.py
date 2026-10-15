"""Preferences reach grounded answers; citations only use retrieved documents."""

from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from langchain_core.documents import Document

from app.docent import service as docent
from app.rag.classifier import classify
from app.schemas.chat import ChatRequest, ChatTurn


@pytest.fixture
def setup(monkeypatch):
    monkeypatch.setattr(
        docent.catalog_service,
        "get_artwork",
        lambda *a: SimpleNamespace(title="그림", artist_name="작가"),
    )
    monkeypatch.setattr(
        docent, "classify_artwork", lambda *a: SimpleNamespace(kind="rag")
    )
    monkeypatch.setattr(docent.docent_scope, "is_artwork_request", lambda *a: True)
    monkeypatch.setattr(
        docent.mypage_service,
        "preference",
        lambda *a: SimpleNamespace(
            birth_date="2001-01-01",
            conversation_style="professional",
            explanation_priorities=["artist_life", "technique", "background"],
        ),
    )
    doc = Document(
        page_content="검토한 설명",
        metadata={
            "chunk_id": 7,
            "document_id": 2,
            "title": "기관 해설",
            "doc_type": "artwork_commentary",
            "source_name": "미술관",
            "source_url": "https://example.org/source",
            "license": "CC BY 4.0",
            "annotation": None,
        },
    )
    monkeypatch.setattr(docent, "retrieve", lambda *a: [doc])
    return doc


def test_style_uses_question_and_citations_without_saved_priority(setup, monkeypatch):
    observed = {}

    def generate(schema, prompt, data):
        observed.update(prompt=prompt, data=data)
        return docent.GroundedAnswer(
            answer="자료에 근거한 답변", refused=False, used_document_ids=[2]
        )

    monkeypatch.setattr(docent, "generate", generate)
    result = docent.answer(None, 1, ChatRequest(question="설명해 줘"), user_id=1)
    assert not result.refused and result.sources[0].document_id == 2
    assert "전문 용어" in observed["prompt"]
    assert "이번 질문에서 요청한 주제와 설명 깊이" in observed["prompt"]
    assert "답변 시 주의" in observed["prompt"]
    assert "used_document_ids" in observed["prompt"]
    assert observed["data"]["sources"][0]["document_id"] == 2
    assert "작가 생애와 작품의 관계 → 회화 기법" not in observed["prompt"]
    assert "artist_life" not in str(observed)
    assert "2001-01-01" not in str(observed)


def test_easy_style_allows_detailed_answers_without_topic_order(setup, monkeypatch):
    monkeypatch.setattr(
        docent.mypage_service,
        "preference",
        lambda *a: SimpleNamespace(
            conversation_style="easy",
            explanation_priorities=["artist_life", "technique", "background"],
        ),
    )
    instruction = docent.instructions(None, 1)
    assert "자세한 질문의 답을 짧게 줄이지" in instruction
    assert "작가 생애" not in instruction


@pytest.mark.parametrize("ids", [[], [999], [2, 999]])
def test_invented_or_missing_citations_refuse(setup, monkeypatch, ids):
    monkeypatch.setattr(
        docent,
        "generate",
        lambda *a: docent.GroundedAnswer(
            answer="근거 없는 답변", refused=False, used_document_ids=ids
        ),
    )
    result = docent.answer(None, 1, ChatRequest(question="설명해 줘"))
    assert result.refused and result.sources == []


def test_no_documents_never_calls_model(setup, monkeypatch):
    monkeypatch.setattr(docent, "retrieve", lambda *a: [])
    monkeypatch.setattr(
        docent, "generate", lambda *a: pytest.fail("근거 없이 LLM 호출")
    )
    response = docent.answer(None, 1, ChatRequest(question="설명해 줘"))
    assert response.refused
    assert response.answer == (
        "현재 검수된 자료로는 정확한 확인이 어려워요. "
        "다른 궁금하신 내용이 있으신가요?"
    )


@pytest.mark.parametrize(("question", "history", "expected"), [
    ("이 작가의 이름이 뭐야?", [], "이 작품의 작가는 클로드 모네입니다."),
    ("작가 이름 이야기해줘", [], "이 작품의 작가는 클로드 모네입니다."),
    ("이 그림 누가 그렸어?", [], "이 작품의 작가는 클로드 모네입니다."),
    ("클로드 모네라는 작가의 이름을 다시는 답변에 넣지마", [], "알겠습니다."),
    (
        "왜 이름을 말 안해?",
        [ChatTurn(role="user", content="이 작가의 이름이 뭐야?"), ChatTurn(role="assistant", content="작품 설명만 반복했습니다.")],
        "이 작품의 작가는 클로드 모네입니다.",
    ),
])
def test_identity_and_wording_corrections_skip_rag(setup, monkeypatch, question, history, expected):
    monkeypatch.setattr(
        docent.catalog_service,
        "get_artwork",
        lambda *a: SimpleNamespace(title="푸르빌의 절벽 산책로", artist_name="클로드 모네"),
    )
    monkeypatch.setattr(docent.docent_scope, "is_artwork_request", lambda *a: pytest.fail("명확한 질문에 범위 모델 호출"))
    monkeypatch.setattr(docent, "retrieve", lambda *a: pytest.fail("카탈로그 단답에 검색 호출"))
    monkeypatch.setattr(docent, "generate", lambda *a: pytest.fail("카탈로그 단답에 생성 호출"))

    result = docent.answer(None, 1, ChatRequest(question=question, history=history))
    assert not result.refused and result.sources == []
    assert expected in result.answer
    assert len(result.answer) < 120


def test_identity_question_overrides_earlier_no_name_request(setup, monkeypatch):
    monkeypatch.setattr(
        docent.catalog_service,
        "get_artwork",
        lambda *a: SimpleNamespace(title="푸르빌의 절벽 산책로", artist_name="클로드 모네"),
    )
    body = ChatRequest(question="이 작가의 이름이 뭐야?", history=[
        ChatTurn(role="user", content="클로드 모네라는 작가의 이름을 다시는 답변에 넣지마"),
        ChatTurn(role="assistant", content="알겠습니다."),
    ])
    result = docent.answer(None, 1, body)
    assert result.answer == "이 작품의 작가는 클로드 모네입니다."


def test_multiple_artist_identity_question_does_not_take_single_artist_shortcut(setup, monkeypatch):
    monkeypatch.setattr(
        docent,
        "classify_artwork",
        lambda *a: SimpleNamespace(kind="rag", artists=("claude-monet", "paul-cezanne"), names=()),
    )
    monkeypatch.setattr(docent.docent_scope, "is_artwork_request", lambda *a: False)
    monkeypatch.setattr(docent, "retrieve", lambda *a: pytest.fail("범위 밖 질문에 검색 호출"))
    result = docent.answer(None, 1, ChatRequest(question="모네와 세잔 작가 이름 이야기해줘"))
    assert result.refused


def test_collection_action_refuses_before_retrieval(setup, monkeypatch):
    monkeypatch.setattr(
        docent,
        "classify_artwork",
        lambda _db, _artwork_id, question: classify(question, "claude-monet"),
    )
    monkeypatch.setattr(docent, "retrieve", lambda *a: pytest.fail("앱 기능 요청에 자료 검색"))
    monkeypatch.setattr(docent, "generate", lambda *a: pytest.fail("앱 기능 요청에 LLM 호출"))

    response = docent.answer(None, 1, ChatRequest(question="이거 내 컬렉션에 추가해줘"))

    assert response.refused
    assert response.sources == []
    assert response.answer == "해당 작품과 작가에 대해서만 대화 할 수 있어요."


@pytest.mark.parametrize("question", [
    "나 오늘 저녁 뭐 먹을까?",
    "욕해봐",
    "나 기분나빠",
    "뭐해? 나 심심해",
    "너 정해진 답 있지",
    "랜덤 돌려서 답 가져와?",
])
def test_clear_unrelated_chat_refuses_before_retrieval(setup, monkeypatch, question):
    monkeypatch.setattr(
        docent, "classify_artwork",
        lambda _db, _artwork_id, text: classify(text, "paul-cezanne"),
    )
    monkeypatch.setattr(docent.docent_scope, "is_artwork_request", lambda *a: pytest.fail("명백한 범위 밖 질문에 AI 분류 호출"))
    monkeypatch.setattr(docent, "retrieve", lambda *a: pytest.fail("범위 밖 질문에 자료 검색"))
    monkeypatch.setattr(docent, "generate", lambda *a: pytest.fail("범위 밖 질문에 답변 생성"))

    response = docent.answer(None, 1, ChatRequest(question=question))

    assert response.refused
    assert response.sources == []
    assert response.answer == "해당 작품과 작가에 대해서만 대화 할 수 있어요."


def test_semantic_scope_gate_refuses_unlisted_topic_before_retrieval(setup, monkeypatch):
    monkeypatch.setattr(docent.docent_scope, "is_artwork_request", lambda *a: False)
    monkeypatch.setattr(docent, "retrieve", lambda *a: pytest.fail("범위 밖 질문에 자료 검색"))
    monkeypatch.setattr(docent, "generate", lambda *a: pytest.fail("범위 밖 질문에 답변 생성"))

    response = docent.answer(None, 1, ChatRequest(question="이번 주 운동 루틴 알려줘"))

    assert response.refused
    assert response.sources == []
    assert response.answer == "해당 작품과 작가에 대해서만 대화 할 수 있어요."


def test_search_failure_uses_approved_message(setup, monkeypatch):
    def fail(*args):
        raise RuntimeError("Chroma unavailable")

    monkeypatch.setattr(docent, "retrieve", fail)
    with pytest.raises(HTTPException) as exc:
        docent.answer(None, 1, ChatRequest(question="설명해 줘"))
    assert exc.value.status_code == 503
    assert exc.value.detail == "작품 자료를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."


@pytest.mark.parametrize(
    ("style", "expected"),
    [
        ("easy", "쉬운 말로 핵심만"),
        ("standard", "미술 용어를 곁들인 해설"),
        ("deep", "근거를 연결하는 심화 해설"),
    ],
)
def test_chat_tab_style_overrides_saved_style(setup, monkeypatch, style, expected):
    observed = {}

    def generate(schema, prompt, data):
        observed["prompt"] = prompt
        return docent.GroundedAnswer(
            answer="자료에 근거한 답변", refused=False, used_document_ids=[2]
        )

    monkeypatch.setattr(docent, "generate", generate)
    docent.answer(
        None,
        1,
        ChatRequest(question="설명해 줘", explanation_style=style),
        user_id=1,
    )
    assert expected in observed["prompt"]
    assert "전문 용어를 적극 사용하되" not in observed["prompt"]


def test_unknown_chat_style_is_rejected():
    with pytest.raises(ValueError):
        ChatRequest(question="설명해 줘", explanation_style="invented")
