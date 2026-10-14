"""External login identities and optional docent preferences."""

from __future__ import annotations

from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.user import User


class SocialAccount(Base):
    """An external identity linked to a service user.

    Authentication still uses ``users.firebase_uid`` for now. This table is
    intentionally provider-neutral so a later login change can link Google,
    Naver, or other accounts without changing the service user id.
    """

    __tablename__ = "social_accounts"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "provider_user_id",
            name="uq_social_accounts_provider_user",
        ),
        TABLE_OPTIONS,
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    provider: Mapped[str] = mapped_column(String(30), nullable=False)
    provider_user_id: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    user: Mapped[User] = relationship(back_populates="social_accounts")


class UserPreference(Base):
    """Optional per-user settings used to personalize docent responses."""

    __tablename__ = "user_preferences"
    __table_args__ = TABLE_OPTIONS

    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    birth_date: Mapped[date | None] = mapped_column(Date)
    # Kept for existing rows; the profile API and docent no longer use topic order.
    explanation_priorities: Mapped[list | None] = mapped_column(JSON)
    conversation_style: Mapped[str | None] = mapped_column(String(30))
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=text("0")
    )
    taste_summary: Mapped[str | None] = mapped_column(Text)
    taste_fingerprint: Mapped[str | None] = mapped_column(String(64))
    taste_generated_at: Mapped[datetime | None] = mapped_column(DateTime)
    birth_year: Mapped[int | None] = mapped_column(SmallInteger)
    gender: Mapped[str | None] = mapped_column(String(30))
    tone: Mapped[str | None] = mapped_column(String(30))
    explanation_level: Mapped[str | None] = mapped_column(String(30))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
    )

    user: Mapped[User] = relationship(back_populates="preferences")
