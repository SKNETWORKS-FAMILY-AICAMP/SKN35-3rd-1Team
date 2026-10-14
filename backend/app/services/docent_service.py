"""Grounded artwork answers with account preferences, never demographic prompts."""

from chromadb.errors import ChromaError
from fastapi import HTTPException
from httpx import HTTPError
from openai import APIError
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.rag.classifier import classify_artwork, refusal_message
from app.rag.prompts import STYLE_RULES
from app.rag.retriever import retrieve
from app.schemas.chat import ChatResponse, Source
from app.services import catalog_service, mypage_service, recommendation_service
from app.services.collection_assistant import generate

PRIORITIES = {
    "technique": "회화 기법",
    "background": "작품의 배경 이야기",
    "artist_life": "작가 생애와 작품의 관계",
}


class GroundedAnswer(BaseModel):
    answer: str = Field(min_length=1, max_length=4000)
    refused: bool
    used_chunk_ids: list[int] = Field(default_factory=list, max_length=40)


def instructions(db, user_id, explanation_style=None):
    p = mypage_service.preference(db, user_id) if user_id else None
    if explanation_style in STYLE_RULES:
        # The tab selected in the chat overrides the saved account style.
        style = STYLE_RULES[explanation_style].replace("\n", " ")
    elif p and p.conversation_style == "professional":
        style = "회화 전문용어를 적극 사용하고 개념을 정확하게 설명하세요."
    else:
        style = "편안한 일상 언어와 쉬운 예시로 짧게 설명하세요. 필요한 전문용어는 풀어서 설명하세요."
    priorities = (
        p.explanation_priorities
        if p and p.explanation_priorities
        else ["background", "technique", "artist_life"]
    )
    return (
        style
        + " 사용자의 질문에 먼저 답하고, 넓은 작품 설명에서는 이 순서를 우선하세요: "
        + " → ".join(PRIORITIES[k] for k in priorities if k in PRIORITIES)
        + ". 자료가 없는 항목을 채우려고 지어내지 마세요."
    )


def answer(db: Session, artwork_id, body, user_id=None):
    art = catalog_service.get_artwork(db, artwork_id)
    route = classify_artwork(db, artwork_id, body.question)
    if route.kind in ("refuse", "other_artist"):
        return ChatResponse(answer=refusal_message(route), refused=True, sources=[])
    if route.kind in ("recommend_similar", "recommend_personal"):
        if route.kind == "recommend_personal" and user_id is None:
            return ChatResponse(
                answer="로그인하고 좋아하는 그림을 모으면 취향에 맞는 다음 그림을 추천해 드릴게요.",
                refused=False,
                sources=[],
            )
        works = (
            recommendation_service.recommend_artworks(db, user_id=user_id)
            if route.kind == "recommend_personal"
            else recommendation_service.similar(db, artwork_id=artwork_id)
        )
        return ChatResponse(
            answer="함께 감상해 볼 그림이에요: "
            + " · ".join(w.title for w in works[:3])
            if works
            else "아직 추천할 작품이 없어요. 마음에 드는 그림에 좋아요를 눌러 보세요.",
            refused=False,
            sources=[],
        )
    try:
        docs = retrieve(db, artwork_id, body.question)
    except (
        ChromaError,
        APIError,
        HTTPError,
        ConnectionError,
        TimeoutError,
        ValueError,
        RuntimeError,
    ):
        raise HTTPException(
            503, "작품 자료를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요."
        ) from None
    if not docs:
        return ChatResponse(
            answer="현재 이 작품의 자료에는 질문에 답할 근거가 없어요. 다른 감상 질문을 들려주세요.",
            refused=True,
            sources=[],
        )
    docs = docs[:40]
    draft = generate(
        GroundedAnswer,
        "한국어 미술 도슨트입니다. 제공한 자료 안에서만 답하세요. 답할 근거가 없으면 refused=true로 하고 자료에 없다고 말하세요. "
        "이미지를 직접 보지 않으므로 자료에 없는 화면 세부를 지어내지 마세요. 작품 판본·소장처를 혼동하지 마세요. "
        "인물 관계, 정신질환, 미래 사건과의 인과를 추측하지 마세요. 답변 시 주의 보정문은 원문보다 우선하며 감상 포인트는 팀의 편집 보충임을 밝히세요. "
        "이전 대화는 질문 맥락이며 사실 근거가 아닙니다. 사용한 근거의 chunk_id를 used_chunk_ids에 넣으세요. "
        "URL을 만들거나 답변에 직접 쓰지 마세요. 원문을 길게 그대로 옮기지 마세요. "
        + instructions(db, user_id, body.explanation_style),
        {
            "artwork": {"title": art.title, "artist": art.artist_name},
            "question": body.question,
            "history": [t.model_dump() for t in body.history],
            "sources": [
                {
                    "chunk_id": d.metadata["chunk_id"],
                    "text": d.page_content[:5000],
                    "annotation": d.metadata.get("annotation"),
                }
                for d in docs
            ],
        },
    )
    ids = set(draft.used_chunk_ids)
    used = [d for d in docs if d.metadata["chunk_id"] in ids]
    if (
        draft.refused
        or not used
        or not ids.issubset({d.metadata["chunk_id"] for d in docs})
    ):
        return ChatResponse(
            answer="현재 자료에서 확인할 수 있는 근거가 부족해 답을 유보할게요. 작품에 관한 다른 질문을 들려주세요.",
            refused=True,
            sources=[],
        )
    sources = {
        d.metadata["document_id"]: Source.model_validate(d.metadata) for d in used
    }
    return ChatResponse(
        answer=draft.answer, refused=False, sources=list(sources.values())
    )
