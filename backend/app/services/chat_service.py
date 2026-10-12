"""Saved docent conversations for logged-in users.

Answering is the RAG side's job. Once ``POST /artworks/{id}/chat`` produces a
``ChatResponse``, the route stores it for a logged-in user with::

    if user is not None:
        chat_service.save_exchange(
            db, user_id=user.id, artwork_id=artwork_id,
            question=body.question, response=response,
        )

Timestamps are stored as naive UTC and returned with an explicit UTC offset.
"""

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core import timeutil
from app.models import ChatRole
from app.repositories import chat_repository
from app.schemas.chat import ChatMessageOut, ChatResponse, ChatSummary
from app.services import catalog_service


def save_exchange(
    db: Session,
    *,
    user_id: int,
    artwork_id: int,
    question: str,
    response: ChatResponse,
    now: datetime | None = None,
) -> None:
    """Store one question and its answer in the user's session for this artwork."""

    now = now or timeutil.utcnow()
    session_id = chat_repository.get_or_create_session_id(
        db, user_id=user_id, artwork_id=artwork_id, now=now
    )
    chat_repository.add_message(
        db,
        session_id=session_id,
        role=ChatRole.USER,
        content=question,
        refused=False,
        sources=None,
        now=now,
    )
    chat_repository.add_message(
        db,
        session_id=session_id,
        role=ChatRole.ASSISTANT,
        content=response.answer,
        refused=response.refused,
        sources=[s.model_dump(mode="json") for s in response.sources],
        now=now,
    )
    chat_repository.touch_session(db, session_id=session_id, now=now)
    db.commit()


def list_messages(
    db: Session, *, user_id: int, artwork_id: int
) -> list[ChatMessageOut]:
    """Empty when the user never asked about this artwork."""

    session_id = chat_repository.get_session_id(
        db, user_id=user_id, artwork_id=artwork_id
    )
    if session_id is None:
        return []
    return [
        ChatMessageOut(
            id=m.id,
            role=ChatRole(m.role).value,
            content=m.content,
            refused=m.refused,
            sources=m.sources or [],
            created_at=m.created_at.replace(tzinfo=UTC),
        )
        for m in chat_repository.list_messages(db, session_id=session_id)
    ]


def reset(db: Session, *, user_id: int, artwork_id: int) -> None:
    """Idempotent: resetting a conversation that does not exist is a success."""

    session_id = chat_repository.get_session_id(
        db, user_id=user_id, artwork_id=artwork_id
    )
    if session_id is not None:
        chat_repository.delete_session(db, session_id=session_id)
        db.commit()


def list_chats(db: Session, *, user_id: int) -> list[ChatSummary]:
    return [
        ChatSummary(
            artwork=catalog_service.to_artwork_card(row.artwork, row.artist_name),
            last_message=row.last_message,
            updated_at=row.updated_at.replace(tzinfo=UTC),
        )
        for row in chat_repository.list_summaries(db, user_id=user_id)
    ]
