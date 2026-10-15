"""User account model."""

from __future__ import annotations

import secrets
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Boolean, DateTime, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.activity import ArtistFollow, ArtworkLike, ArtworkView
    from app.models.chat import ChatSession
    from app.models.user_profile import SocialAccount, UserPreference


def new_public_id() -> str:
    return secrets.token_urlsafe(9)


class User(Base):
    __tablename__ = "users"
    __table_args__ = TABLE_OPTIONS

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    # Firebase Auth user id. The server takes it only from a verified ID token,
    # never from a client-supplied field.
    firebase_uid: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    nickname: Mapped[str] = mapped_column(String(50), nullable=False)
    # Opaque id for public profile URLs and feed authors. Internal ids, email and
    # Firebase uid are never exposed to other users.
    public_id: Mapped[str] = mapped_column(
        String(22),
        nullable=False,
        unique=True,
        default=new_public_id,
    )
    # Whether other users may see this account's following/follower lists.
    follow_list_public: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=text("1")
    )
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
    social_accounts: Mapped[list[SocialAccount]] = relationship(
        back_populates="user",
        passive_deletes=True,
    )
    preferences: Mapped[UserPreference | None] = relationship(
        back_populates="user",
        passive_deletes=True,
        uselist=False,
    )
