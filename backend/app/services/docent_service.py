"""Grounded artwork answers with explicit style preferences and verified citations."""

import json

from chromadb.errors import ChromaError
from fastapi import HTTPException
from httpx import HTTPError
from langchain_core.exceptions import OutputParserException
from langchain_openai import ChatOpenAI
from openai import APIError
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.rag.classifier import classify_artwork, refusal_message
from app.rag.retriever import retrieve
from app.schemas.chat import ChatResponse
from app.services import catalog_service, mypage_service, recommendation_service
from app.services.docent_grounding import (
    NO_EVIDENCE_MESSAGE,
    GroundedAnswer,
    context,
    retrieval_question,
    validate_response,
)
from app.services.docent_grounding import instructions as grounding_instructions


def instructions(db, user_id, explanation_style=None):
    preference = mypage_service.preference(db, user_id) if user_id else None
    return grounding_instructions(preference, explanation_style)


def generate(schema, instruction, data):
    settings = get_settings()
    if settings.openai_api_key is None:
        raise HTTPException(503, "AI 연결 설정이 필요해요.")
    try:
        llm = ChatOpenAI(
            model=settings.assistant_model,
            api_key=settings.openai_api_key,
            timeout=25,
            max_retries=0,
            temperature=0.3,
        )
        return llm.with_structured_output(schema).invoke(
            [("system", instruction), ("human", json.dumps(data, ensure_ascii=False))]
        )
    except (APIError, OutputParserException, ValidationError, TimeoutError):
        raise HTTPException(503, "AI 응답을 완료하지 못했어요. 다시 시도해 주세요.") from None


def _similar_answer(works) -> str:
    if not works:
        return "현재 이 작품과 유사한 작품 정보가 아직 준비되지 않았어요."
    return "이 작품과 비슷한 결을 가진 작품을 더 둘러보세요. " + _titles(works)


def _titles(works) -> str:
    return " · ".join(f"『{work.title}』" for work in works[:3])


def _personal_answer(works) -> str:
    if not works:
        return "아직 충분한 취향 데이터가 쌓이지 않았어요."
    items = [
        f"『{work.title}』 — {work.reason}" if work.reason else f"『{work.title}』"
        for work in works[:3]
    ]
    return "이런 작품은 어떠신가요? " + " · ".join(items)


def answer(db: Session, artwork_id, body, user_id=None):
    art = catalog_service.get_artwork(db, artwork_id)
    route = classify_artwork(db, artwork_id, body.question)
    if route.kind in ("refuse", "other_artist"):
        return ChatResponse(answer=refusal_message(route), refused=True, sources=[])
    if route.kind in ("recommend_similar", "recommend_personal"):
        if route.kind == "recommend_personal" and user_id is None:
            works = recommendation_service.similar(db, artwork_id=artwork_id)
            login_hint = "로그인 후 감상 기록이 쌓이면 더 정교한 추천을 받아볼 수 있어요."
            return ChatResponse(
                answer=(
                    f"{login_hint} 현재 작품과 비슷한 작품을 먼저 만나보세요. {_titles(works)}"
                    if works
                    else f"{login_hint} {_similar_answer(works)}"
                ),
                refused=False,
                sources=[],
            )
        works = (
            recommendation_service.recommend_artworks(db, user_id=user_id)
            if route.kind == "recommend_personal"
            else recommendation_service.similar(db, artwork_id=artwork_id)
        )
        return ChatResponse(
            answer=(
                _personal_answer(works)
                if route.kind == "recommend_personal"
                else _similar_answer(works)
            ),
            refused=False,
            sources=[],
        )
    try:
        docs = retrieve(db, artwork_id, retrieval_question(body))[:40]
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
            503, "작품 자료를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        ) from None
    if not docs:
        return ChatResponse(
            answer=NO_EVIDENCE_MESSAGE,
            refused=True,
            sources=[],
        )
    draft = generate(
        GroundedAnswer,
        instructions(db, user_id, body.explanation_style),
        context(art, body, docs),
    )
    try:
        return validate_response(draft.model_dump(), docs)
    except (ValueError, AttributeError):
        return ChatResponse(
            answer=NO_EVIDENCE_MESSAGE,
            refused=True,
            sources=[],
        )
