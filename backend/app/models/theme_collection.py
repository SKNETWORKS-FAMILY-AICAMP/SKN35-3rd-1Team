"""Private, durable AI playlist cache (separate from saved collections)."""

from datetime import datetime

from sqlalchemy import JSON, BigInteger, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import TABLE_OPTIONS, Base


class ThemeCollectionCache(Base):
    __tablename__ = "theme_collection_cache"
    __table_args__ = TABLE_OPTIONS

    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    fingerprint: Mapped[str | None] = mapped_column(String(64))
    themes: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    # Liked/seen artwork IDs the current themes were made from.
    basis: Mapped[dict | None] = mapped_column(JSON)
    generated_at: Mapped[datetime | None] = mapped_column(DateTime)
    attempted_at: Mapped[datetime | None] = mapped_column(DateTime)
