"""Saved docent conversations for logged-in users (one per user and artwork)."""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import TYPE_CHECKING, Any

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.catalog import Artwork
    from app.models.user import User


class ChatRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"


class ChatSession(Base):
    __tablename__ = "chat_sessions"
    __table_args__ = (
        # Reopening an artwork continues the same conversation.
        UniqueConstraint("user_id", "artwork_id", name="uq_chat_sessions_user_artwork"),
        Index("idx_chat_sessions_user_updated", "user_id", "updated_at"),
        Index("idx_chat_sessions_artwork", "artwork_id"),
        TABLE_OPTIONS,
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", name="fk_chat_sessions_user", ondelete="CASCADE"),
        nullable=False,
    )
    artwork_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("artworks.id", name="fk_chat_sessions_artwork", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    # Time of the latest message; the app sets it when it appends messages.
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
    )

    user: Mapped[User] = relationship(back_populates="chat_sessions")
    artwork: Mapped[Artwork] = relationship(back_populates="chat_sessions")
    messages: Mapped[list[ChatMessage]] = relationship(
        back_populates="session",
        order_by="ChatMessage.id",
        passive_deletes=True,
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    __table_args__ = (
        Index("idx_chat_messages_session", "session_id", "id"),
        TABLE_OPTIONS,
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("chat_sessions.id", name="fk_chat_messages_session", ondelete="CASCADE"),
        nullable=False,
    )
    role: Mapped[ChatRole] = mapped_column(
        SAEnum(
            ChatRole,
            native_enum=False,
            create_constraint=False,
            values_callable=lambda enum: [member.value for member in enum],
            length=20,
        ),
        nullable=False,
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    # Assistant answers only: out-of-scope refusal flag and the cited sources.
    refused: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
    )
    # Snapshot of the API ``sources`` list. Not a FK to chunks: re-chunking changes chunk ids.
    sources: Mapped[list[dict[str, Any]] | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    session: Mapped[ChatSession] = relationship(back_populates="messages")
