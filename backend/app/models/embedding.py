"""Artwork-level vector used for recommendations."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, DateTime, ForeignKey, String, text
from sqlalchemy.orm import Mapped, deferred, mapped_column, relationship
from tidb_vector.sqlalchemy import VectorType

from app.models.base import EMBEDDING_DIMENSION, TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.catalog import Artwork


class ArtworkEmbedding(Base):
    __tablename__ = "artwork_embeddings"
    __table_args__ = TABLE_OPTIONS

    artwork_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "artworks.id",
            name="fk_artwork_embeddings_artwork",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    embedding: Mapped[list[float]] = deferred(
        mapped_column(VectorType(EMBEDDING_DIMENSION), nullable=False)
    )
    embedding_model: Mapped[str] = mapped_column(String(64), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
    )

    artwork: Mapped[Artwork] = relationship(back_populates="embedding_record")
