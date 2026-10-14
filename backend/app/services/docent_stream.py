"""SSE delivery of the same grounded docent answer contract as the JSON route."""

import json
from collections.abc import AsyncIterator
from typing import Literal

from chromadb.errors import ChromaError
from fastapi import HTTPException
from httpx import HTTPError
from langchain_core.output_parsers import JsonOutputParser
from langchain_openai import ChatOpenAI
from openai import APIError
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.core.config import get_settings
from app.rag.classifier import classify_artwork
from app.rag.retriever import retrieve
from app.schemas.chat import ChatRequest, ChatResponse
from app.services import catalog_service, chat_service, docent_service
from app.services.docent_grounding import (
    NO_EVIDENCE_MESSAGE,
    context,
    retrieval_question,
    validate_response,
)

EventName = Literal["token", "replace", "done"]
ChatEvent = tuple[EventName, str | ChatResponse]


async def answer_events(
    db: Session, *, artwork_id: int, body: ChatRequest, user_id: int | None
) -> AsyncIterator[ChatEvent]:
    """Stream provisional text, then replace it with a validated final answer."""

    # Synchronous DB and retrieval calls share one session outside the event loop.
    art = await run_in_threadpool(catalog_service.get_artwork, db, artwork_id)
    route = await run_in_threadpool(classify_artwork, db, artwork_id, body.question)
    if route.kind != "rag":
        response = await run_in_threadpool(
            docent_service.answer, db, artwork_id, body, user_id=user_id
        )
        yield "token", response.answer
    else:
        try:
            docs = (
                await run_in_threadpool(
                    retrieve, db, artwork_id, retrieval_question(body)
                )
            )[:40]
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
            response = ChatResponse(
                answer=NO_EVIDENCE_MESSAGE,
                refused=True,
                sources=[],
            )
            yield "token", response.answer
        else:
            settings = get_settings()
            if settings.openai_api_key is None:
                raise HTTPException(503, "AI 연결 설정이 필요해요.")

            parser = JsonOutputParser(pydantic_object=docent_service.GroundedAnswer)
            preferences = await run_in_threadpool(
                docent_service.instructions, db, user_id, body.explanation_style
            )
            instruction = preferences + "\n\n" + parser.get_format_instructions()
            model = ChatOpenAI(
                model=settings.assistant_model,
                api_key=settings.openai_api_key,
                timeout=25,
                max_retries=0,
                temperature=0.3,
            )
            latest: dict | None = None
            shown = ""
            async for partial in (model | parser).astream(
                [
                    ("system", instruction),
                    ("human", json.dumps(context(art, body, docs), ensure_ascii=False)),
                ]
            ):
                if not isinstance(partial, dict):
                    continue
                latest = partial
                text = partial.get("answer")
                if not isinstance(text, str) or text == shown:
                    continue
                if text.startswith(shown):
                    yield "token", text[len(shown):]
                else:
                    yield "replace", text
                shown = text

            try:
                response = validate_response(latest, docs)
            except (ValueError, AttributeError, TypeError):
                response = ChatResponse(
                    answer=NO_EVIDENCE_MESSAGE,
                    refused=True,
                    sources=[],
                )
            if response.answer != shown:
                yield "replace", response.answer

    if user_id is not None:
        await run_in_threadpool(
            chat_service.save_exchange,
            db,
            user_id=user_id,
            artwork_id=artwork_id,
            question=body.question,
            response=response,
        )
    yield "done", response
