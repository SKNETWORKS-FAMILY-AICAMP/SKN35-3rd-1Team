"""User account model."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, DateTime, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.activity import ArtistFollow, ArtworkLike, ArtworkView
    from app.models.chat import ChatSession


class User(Base):
    __tablename__ = "users"
    __table_args__ = TABLE_OPTIONS

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    # Firebase Auth user id. The server takes it only from a verified ID token,
    # never from a client-supplied field.
    firebase_uid: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    nickname: Mapped[str] = mapped_column(String(50), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
    )

    artwork_likes: Mapped[list[ArtworkLike]] = relationship(
        back_populates="user",
        passive_deletes=True,
    )
    artist_follows: Mapped[list[ArtistFollow]] = relationship(
        back_populates="user",
        passive_deletes=True,
    )
    artwork_views: Mapped[list[ArtworkView]] = relationship(
        back_populates="user",
        passive_deletes=True,
    )
    chat_sessions: Mapped[list[ChatSession]] = relationship(
        back_populates="user",
        passive_deletes=True,
    )
