"""Private, owner-scoped named artwork collections."""

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import TABLE_OPTIONS, Base


class Collection(Base):
    __tablename__ = "collections"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_collection_owner_name"),
        TABLE_OPTIONS,
    )
    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP")
    )


class CollectionItem(Base):
    __tablename__ = "collection_items"
    __table_args__ = TABLE_OPTIONS
    collection_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("collections.id", ondelete="CASCADE"), primary_key=True
    )
    artwork_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("artworks.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP")
    )
