"""Daily impressions. Private until the owner explicitly publishes them."""

from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import TABLE_OPTIONS, Base


class DiaryEntry(Base):
    __tablename__ = "diary_entries"
    __table_args__ = (
        UniqueConstraint("user_id", "entry_date", name="uq_diary_user_date"),
        Index("ix_diary_public_id", "is_public", "id"),
        Index("ix_diary_artwork_public_id", "artwork_id", "is_public", "id"),
        TABLE_OPTIONS,
    )

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    entry_date: Mapped[date] = mapped_column(Date, nullable=False)
    artwork_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("artworks.id", ondelete="SET NULL")
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    is_public: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=text("0")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP")
    )
