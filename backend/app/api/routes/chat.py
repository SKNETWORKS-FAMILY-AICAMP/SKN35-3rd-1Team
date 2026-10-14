"""작품 도슨트 채팅과 채팅 기록.

질문은 로그인 없이도 가능하고(`OptionalUser`), 로그인 상태면 질문과 답변을 저장한다.
답변 맥락은 로그인 여부와 관계없이 요청의 `history`로 받는다.
"""

import json
import logging

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse

from app.core.auth import CurrentUser, OptionalUser
from app.db.session import DbSession
from app.schemas.chat import ChatMessageOut, ChatRequest, ChatResponse, ChatSummary
from app.services import chat_service, docent_service, docent_stream

router = APIRouter(tags=["chat"])
logger = logging.getLogger(__name__)


def _frame(event: str, payload: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(payload, ensure_ascii=False)}\n\n"


@router.post("/artworks/{artwork_id}/chat")
def ask(artwork_id: int, body: ChatRequest, user: OptionalUser, db: DbSession) -> ChatResponse:
    """작품 도슨트에게 질문. 근거가 없으면 `refused: true`.

    RAG 답변이 나오면 로그인 사용자는 `chat_service.save_exchange`로 저장한다.
    """
    response = docent_service.answer(db, artwork_id, body, user_id=user.id if user else None)
    if user is not None:
        chat_service.save_exchange(db, user_id=user.id, artwork_id=artwork_id, question=body.question, response=response)
    return response


@router.post("/artworks/{artwork_id}/chat/stream")
async def ask_stream(
    artwork_id: int, body: ChatRequest, user: OptionalUser, db: DbSession
) -> StreamingResponse:
    """Stream provisional LangChain text and one validated final response."""

    async def events():
        try:
            async for event, payload in docent_stream.answer_events(
                db, artwork_id=artwork_id, body=body, user_id=user.id if user else None
            ):
                if event == "done":
                    assert isinstance(payload, ChatResponse)
                    yield _frame(event, payload.model_dump(mode="json"))
                else:
                    assert isinstance(payload, str)
                    yield _frame(event, {"content": payload})
        except HTTPException as exc:
            yield _frame("error", {"message": str(exc.detail)})
        except Exception as exc:  # noqa: BLE001 -- SSE boundary must end with a safe error frame.
            # Provider exceptions may contain request data. Log the type only.
            logger.error("Docent stream failed for artwork_id=%s: %s", artwork_id, type(exc).__name__)
            yield _frame("error", {"message": "AI 응답을 완료하지 못했어요. 다시 시도해 주세요."})

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache, no-transform", "X-Accel-Buffering": "no"},
    )


@router.get("/artworks/{artwork_id}/chat/messages")
def list_messages(
    artwork_id: int, user: CurrentUser, db: DbSession
) -> list[ChatMessageOut]:
    """이 작품과 나눈 내 대화 기록 (오래된 순). 대화가 없으면 빈 배열."""
    return chat_service.list_messages(db, user_id=user.id, artwork_id=artwork_id)


@router.delete("/artworks/{artwork_id}/chat", status_code=status.HTTP_204_NO_CONTENT)
def reset_chat(artwork_id: int, user: CurrentUser, db: DbSession) -> None:
    """이 작품 대화 초기화. 대화가 없어도 204."""
    chat_service.reset(db, user_id=user.id, artwork_id=artwork_id)


@router.get("/me/chats")
def list_my_chats(user: CurrentUser, db: DbSession) -> list[ChatSummary]:
    """내가 대화한 작품 목록 (최근 대화순)."""
    return chat_service.list_chats(db, user_id=user.id)
