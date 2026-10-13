"""Preferences reach grounded answers, and citations can only come from retrieved chunks."""

from types import SimpleNamespace

import pytest
from langchain_core.documents import Document

from app.schemas.chat import ChatRequest
from app.services import docent_service as docent


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


def test_style_priority_and_citations_use_only_retrieved_material(setup, monkeypatch):
    observed = {}

    def generate(schema, prompt, data):
        observed.update(prompt=prompt, data=data)
        return docent.GroundedAnswer(
            answer="자료에 근거한 답변", refused=False, used_chunk_ids=[7]
        )

    monkeypatch.setattr(docent, "generate", generate)
    result = docent.answer(None, 1, ChatRequest(question="설명해 줘"), user_id=1)
    assert not result.refused and result.sources[0].document_id == 2
    assert "전문용어" in observed["prompt"]
    assert (
        "작가 생애와 작품의 관계 → 회화 기법 → 작품의 배경 이야기" in observed["prompt"]
    )
    assert "2001-01-01" not in str(observed)


@pytest.mark.parametrize("ids", [[], [999], [7, 999]])
def test_invented_or_missing_citations_refuse(setup, monkeypatch, ids):
    monkeypatch.setattr(
        docent,
        "generate",
        lambda *a: docent.GroundedAnswer(
            answer="근거 없는 답변", refused=False, used_chunk_ids=ids
        ),
    )
    result = docent.answer(None, 1, ChatRequest(question="설명해 줘"))
    assert result.refused and result.sources == []


def test_no_documents_never_calls_model(setup, monkeypatch):
    monkeypatch.setattr(docent, "retrieve", lambda *a: [])
    monkeypatch.setattr(
        docent, "generate", lambda *a: pytest.fail("근거 없이 LLM 호출")
    )
    assert docent.answer(None, 1, ChatRequest(question="설명해 줘")).refused
