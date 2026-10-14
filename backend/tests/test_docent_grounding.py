"""The two chat transports share style, follow-up search, and citation checks."""

from types import SimpleNamespace

import pytest
from langchain_core.documents import Document

from app.schemas.chat import ChatRequest, ChatTurn
from app.services.docent_grounding import (
    NO_EVIDENCE_MESSAGE,
    context,
    instructions,
    retrieval_question,
    validate_response,
)


def _doc(document_id: int = 4) -> Document:
    return Document(
        page_content="승인된 작품 해설",
        metadata={
            "chunk_id": 9,
            "document_id": document_id,
            "title": "작품 해설",
            "doc_type": "artwork_commentary",
            "source_name": "소장 기관",
            "source_url": "https://example.org/artwork",
            "license": "CC BY 4.0",
            "basis_sources": [],
            "annotation": "답변 시 주의",
            "pinned": True,
        },
    )


def test_saved_professional_style_changes_terms_not_default_depth():
    prompt = instructions(SimpleNamespace(conversation_style="professional"))
    assert "전문 용어를 적극 사용" in prompt
    assert "선택한 설명 스타일: 미술 용어를 곁들인 해설" in prompt
    assert "질문에서 요청한 주제와 설명 깊이" in prompt
    assert "선택한 설명 스타일: 근거를 연결하는 심화 해설" not in prompt


def test_follow_up_search_uses_previous_user_question_only():
    body = ChatRequest(
        question="그 사람은 언제 태어났어?",
        history=[
            ChatTurn(role="user", content="이 작품의 작가는 누구야?"),
            ChatTurn(role="assistant", content="근거 없이 말한 1900년"),
        ],
    )
    query = retrieval_question(body)
    assert "이 작품의 작가는 누구야?" in query
    assert "1900년" not in query
    assert retrieval_question(ChatRequest(question="이 작품의 연도는?", history=body.history)) == "이 작품의 연도는?"


def test_context_keeps_identity_and_editorial_metadata_without_profile():
    data = context(
        SimpleNamespace(
            id=3, title="같은 이름의 작품", artist_name="작가", year_label="1889", collection="미술관"
        ),
        ChatRequest(question="어느 판본인가요?"),
        [_doc()],
    )
    assert data["artwork"]["year_label"] == "1889"
    assert data["sources"][0]["document_id"] == 4
    assert data["sources"][0]["annotation"] == "답변 시 주의"
    assert data["sources"][0]["pinned"] is True
    assert "source_url" not in data["sources"][0]


def test_public_source_uses_retrieved_metadata_only():
    result = validate_response(
        {"answer": "자료에 따르면 1889년입니다.", "refused": False, "used_document_ids": [4]},
        [_doc()],
    )
    assert not result.refused
    assert result.sources[0].source_url == "https://example.org/artwork"
    assert result.sources[0].license == "CC BY 4.0"


def test_editorial_basis_survives_multiple_chunks_from_one_document():
    plain = _doc()
    plain.metadata["basis_sources"] = []
    note = _doc()
    note.metadata["chunk_id"] = 10
    note.metadata["basis_sources"] = [
        {"source_name": "기관 원문", "source_url": "https://example.org/original"}
    ]
    result = validate_response(
        {"answer": "팀의 감상 포인트입니다.", "refused": False, "used_document_ids": [4]},
        [note, plain],
    )
    assert result.sources[0].basis_sources[0].source_name == "기관 원문"


def test_model_refusal_uses_server_copy():
    result = validate_response(
        {"answer": "모델이 쓴 임의의 거절 문구", "refused": True, "used_document_ids": []},
        [_doc()],
    )
    assert result.refused and result.answer == NO_EVIDENCE_MESSAGE
    assert result.sources == []


def test_ambiguous_referent_can_be_clarified_without_a_document_claim():
    result = validate_response(
        {"answer": "어떤 사람을 말씀하시는 건가요?", "refused": True, "used_document_ids": []},
        [_doc()],
    )
    assert result.refused
    assert result.answer == "어떤 사람을 말씀하시는 건가요?"
    assert result.sources == []


def test_model_cannot_put_a_url_in_answer():
    with pytest.raises(ValueError):
        validate_response(
            {"answer": "근거는 https://invented.example 입니다.", "refused": False, "used_document_ids": [4]},
            [_doc()],
        )


@pytest.mark.parametrize("ids", [[], [999], [4, 4], [True]])
def test_invalid_document_ids_are_rejected(ids):
    with pytest.raises(ValueError):
        validate_response(
            {"answer": "확인했습니다.", "refused": False, "used_document_ids": ids},
            [_doc()],
        )
