"""Art movement, artist, and artwork catalog models."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    SmallInteger,
    String,
    Text,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.activity import ArtistFollow, ArtworkLike, ArtworkView
    from app.models.document import Document, DocumentArtist, DocumentArtwork
    from app.models.embedding import ArtworkEmbedding


class ArtMovement(Base):
    __tablename__ = "art_movements"
    __table_args__ = TABLE_OPTIONS

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    slug: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    name_en: Mapped[str | None] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    artists: Mapped[list[Artist]] = relationship(
        back_populates="movement",
        passive_deletes=True,
    )
    artworks: Mapped[list[Artwork]] = relationship(
        back_populates="movement",
        passive_deletes=True,
    )


class Artist(Base):
    __tablename__ = "artists"
    __table_args__ = (
        Index("idx_artists_movement", "movement_id"),
        Index("idx_artists_name", "name"),
        TABLE_OPTIONS,
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    slug: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    name_en: Mapped[str | None] = mapped_column(String(200))
    movement_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey(
            "art_movements.id",
            name="fk_artists_movement",
            ondelete="SET NULL",
        ),
    )
    birth_year: Mapped[int | None] = mapped_column(SmallInteger)
    death_year: Mapped[int | None] = mapped_column(SmallInteger)
    nationality: Mapped[str | None] = mapped_column(String(100))
    summary: Mapped[str | None] = mapped_column(Text)
    portrait_url: Mapped[str | None] = mapped_column(String(1024))
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

    movement: Mapped[ArtMovement | None] = relationship(back_populates="artists")
    artworks: Mapped[list[Artwork]] = relationship(
        back_populates="artist",
        passive_deletes=True,
    )
    document_links: Mapped[list[DocumentArtist]] = relationship(
        back_populates="artist",
        passive_deletes=True,
    )
    followers: Mapped[list[ArtistFollow]] = relationship(
        back_populates="artist",
        passive_deletes=True,
    )


class Artwork(Base):
    __tablename__ = "artworks"
    __table_args__ = (
        Index("idx_artworks_artist_year", "artist_id", "year_start"),
        Index("idx_artworks_movement_year", "movement_id", "year_start"),
        TABLE_OPTIONS,
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    slug: Mapped[str] = mapped_column(String(160), nullable=False, unique=True)
    artist_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("artists.id", name="fk_artworks_artist", ondelete="RESTRICT"),
        nullable=False,
    )
    movement_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey(
            "art_movements.id",
            name="fk_artworks_movement",
            ondelete="SET NULL",
        ),
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    title_en: Mapped[str | None] = mapped_column(String(255))
    year_label: Mapped[str | None] = mapped_column(String(50))
    year_start: Mapped[int | None] = mapped_column(SmallInteger)
    medium: Mapped[str | None] = mapped_column(String(255))
    dimensions: Mapped[str | None] = mapped_column(String(100))
    collection: Mapped[str | None] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(1024))
    image_source_url: Mapped[str | None] = mapped_column(String(1024))
    image_license: Mapped[str | None] = mapped_column(String(100))
    is_featured: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
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

    artist: Mapped[Artist] = relationship(back_populates="artworks")
    movement: Mapped[ArtMovement | None] = relationship(back_populates="artworks")
    embedding_record: Mapped[ArtworkEmbedding | None] = relationship(
        back_populates="artwork",
        passive_deletes=True,
        uselist=False,
    )
    documents: Mapped[list[Document]] = relationship(
        back_populates="artwork",
        passive_deletes=True,
    )
    related_document_links: Mapped[list[DocumentArtwork]] = relationship(
        back_populates="artwork",
        passive_deletes=True,
    )
    likes: Mapped[list[ArtworkLike]] = relationship(
        back_populates="artwork",
        passive_deletes=True,
    )
    views: Mapped[list[ArtworkView]] = relationship(
        back_populates="artwork",
        passive_deletes=True,
    )
