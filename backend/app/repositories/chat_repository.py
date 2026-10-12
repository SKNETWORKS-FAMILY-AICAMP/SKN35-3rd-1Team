"""Saved docent conversations: one session per user and artwork.

The caller commits.
"""

from datetime import datetime
from typing import Any, NamedTuple

from sqlalchemy import delete, func, select, update
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.orm import Session

from app.models import Artist, Artwork, ChatMessage, ChatRole, ChatSession


class ChatSummaryRow(NamedTuple):
    artwork: Artwork
    artist_name: str
    last_message: str
    updated_at: datetime


def get_session_id(db: Session, *, user_id: int, artwork_id: int) -> int | None:
    return db.scalar(
        select(ChatSession.id).where(
            ChatSession.user_id == user_id, ChatSession.artwork_id == artwork_id
        )
    )


def get_or_create_session_id(
    db: Session, *, user_id: int, artwork_id: int, now: datetime
) -> int:
    """``INSERT IGNORE`` so two first questions at once still share one session."""

    db.execute(
        insert(ChatSession)
        .values(user_id=user_id, artwork_id=artwork_id, created_at=now, updated_at=now)
        .prefix_with("IGNORE")
    )
    session_id = get_session_id(db, user_id=user_id, artwork_id=artwork_id)
    assert session_id is not None
    return session_id


def add_message(
    db: Session,
    *,
    session_id: int,
    role: ChatRole,
    content: str,
    refused: bool,
    sources: list[dict[str, Any]] | None,
    now: datetime,
) -> None:
    db.add(
        ChatMessage(
            session_id=session_id,
            role=role,
            content=content,
            refused=refused,
            sources=sources,
            created_at=now,
        )
    )
    db.flush()


def touch_session(db: Session, *, session_id: int, now: datetime) -> None:
    db.execute(
        update(ChatSession).where(ChatSession.id == session_id).values(updated_at=now)
    )


def list_messages(db: Session, *, session_id: int) -> list[ChatMessage]:
    """Oldest first; ids grow with insertion order."""

    stmt = (
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.id)
    )
    return list(db.scalars(stmt))


def delete_session(db: Session, *, session_id: int) -> None:
    # Messages first instead of relying on the FK cascade.
    db.execute(delete(ChatMessage).where(ChatMessage.session_id == session_id))
    db.execute(delete(ChatSession).where(ChatSession.id == session_id))


def list_summaries(db: Session, *, user_id: int) -> list[ChatSummaryRow]:
    """Sessions that have messages, most recently updated first."""

    latest = (
        select(ChatMessage.session_id, func.max(ChatMessage.id).label("last_id"))
        .group_by(ChatMessage.session_id)
        .subquery()
    )
    stmt = (
        select(Artwork, Artist.name, ChatMessage.content, ChatSession.updated_at)
        .select_from(ChatSession)
        .join(latest, latest.c.session_id == ChatSession.id)
        .join(ChatMessage, ChatMessage.id == latest.c.last_id)
        .join(Artwork, Artwork.id == ChatSession.artwork_id)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(ChatSession.user_id == user_id)
        .order_by(ChatSession.updated_at.desc(), ChatSession.id.desc())
    )
    return [ChatSummaryRow(*row) for row in db.execute(stmt)]
