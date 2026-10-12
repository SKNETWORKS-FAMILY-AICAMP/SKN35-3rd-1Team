"""작품 도슨트 채팅과 채팅 기록.

질문은 로그인 없이도 가능하고(`OptionalUser`), 로그인 상태면 질문과 답변을 저장한다.
답변 맥락은 로그인 여부와 관계없이 요청의 `history`로 받는다.
"""

from fastapi import APIRouter, status

from app.api.stub import not_implemented
from app.core.auth import CurrentUser, OptionalUser
from app.db.session import DbSession
from app.schemas.chat import ChatMessageOut, ChatRequest, ChatResponse, ChatSummary
from app.services import chat_service

router = APIRouter(tags=["chat"])


@router.post("/artworks/{artwork_id}/chat")
def ask(artwork_id: int, body: ChatRequest, user: OptionalUser) -> ChatResponse:
    """작품 도슨트에게 질문. 근거가 없으면 `refused: true`.

    RAG 답변이 나오면 로그인 사용자는 `chat_service.save_exchange`로 저장한다.
    """
    not_implemented()


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
