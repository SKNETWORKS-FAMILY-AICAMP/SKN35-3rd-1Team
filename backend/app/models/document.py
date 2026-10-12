"""RAG source document and chunk models."""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import TYPE_CHECKING

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy import (
    Enum as SAEnum,
)
from sqlalchemy.dialects.mysql import MEDIUMTEXT
from sqlalchemy.orm import Mapped, deferred, mapped_column, relationship
from tidb_vector.sqlalchemy import VectorType

from app.models.base import EMBEDDING_DIMENSION, TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.catalog import Artist, Artwork


class DocumentType(str, Enum):
    ARTIST_BIO = "artist_bio"
    ARTWORK_COMMENTARY = "artwork_commentary"
    ARTIST_COMPARISON = "artist_comparison"


class Document(Base):
    __tablename__ = "documents"
    __table_args__ = (Index("idx_documents_artwork", "artwork_id"), TABLE_OPTIONS)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    # Stable key from data/processed (``<artist slug>/<source file>``) so reloads can upsert.
    doc_key: Mapped[str] = mapped_column(String(191), nullable=False, unique=True)
    doc_type: Mapped[DocumentType] = mapped_column(
        SAEnum(
            DocumentType,
            native_enum=False,
            create_constraint=False,
            values_callable=lambda enum: [member.value for member in enum],
            length=30,
        ),
        nullable=False,
    )
    artwork_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("artworks.id", name="fk_documents_artwork", ondelete="CASCADE"),
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    content: Mapped[str] = mapped_column(MEDIUMTEXT, nullable=False)
    source_url: Mapped[str | None] = mapped_column(String(1024))
    source_name: Mapped[str | None] = mapped_column(String(255))
    license: Mapped[str | None] = mapped_column(String(100))
    lang: Mapped[str] = mapped_column(String(8), nullable=False, server_default=text("'ko'"))
    # Kind of artist_bio material (e.g. 생애 전체, 주변 인물, 연표); see data/processed/README.md.
    topic: Mapped[str | None] = mapped_column(String(30))
    # Human review is pending; retrieval decides at query time whether to include it.
    needs_review: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
    )
    # External sources used only by appended editorial supplements/corrections.
    # Local document provenance is normalized in document_basis_documents.
    basis_external_sources: Mapped[list[dict[str, str]]] = mapped_column(
        JSON,
        nullable=False,
        default=list,
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

    artwork: Mapped[Artwork | None] = relationship(back_populates="documents")
    artist_links: Mapped[list[DocumentArtist]] = relationship(
        back_populates="document",
        passive_deletes=True,
    )
    chunks: Mapped[list[DocumentChunk]] = relationship(
        back_populates="document",
        passive_deletes=True,
        order_by="DocumentChunk.chunk_index",
    )
    related_artwork_links: Mapped[list[DocumentArtwork]] = relationship(
        back_populates="document",
        passive_deletes=True,
    )
    basis_links: Mapped[list[DocumentBasis]] = relationship(
        foreign_keys="DocumentBasis.document_id",
        back_populates="document",
        passive_deletes=True,
    )
    used_as_basis_links: Mapped[list[DocumentBasis]] = relationship(
        foreign_keys="DocumentBasis.basis_document_id",
        back_populates="basis_document",
        passive_deletes=True,
    )


class DocumentArtist(Base):
    __tablename__ = "document_artists"
    __table_args__ = (
        Index("idx_document_artists_artist", "artist_id", "document_id"),
        TABLE_OPTIONS,
    )

    document_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "documents.id",
            name="fk_document_artists_document",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    artist_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "artists.id",
            name="fk_document_artists_artist",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    document: Mapped[Document] = relationship(back_populates="artist_links")
    artist: Mapped[Artist] = relationship(back_populates="document_links")


class DocumentArtwork(Base):
    """Artworks a document talks about without being their commentary (timeline events).

    ``documents.artwork_id`` stays the single artwork a commentary explains; this table
    lets one artist_bio timeline event point at several artworks.
    """

    __tablename__ = "document_artworks"
    __table_args__ = (
        Index("idx_document_artworks_artwork", "artwork_id", "document_id"),
        TABLE_OPTIONS,
    )

    document_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "documents.id",
            name="fk_document_artworks_document",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    artwork_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "artworks.id",
            name="fk_document_artworks_artwork",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    document: Mapped[Document] = relationship(back_populates="related_artwork_links")
    artwork: Mapped[Artwork] = relationship(back_populates="related_document_links")


class DocumentBasis(Base):
    """A collected document used to write an appended supplement or correction."""

    __tablename__ = "document_basis_documents"
    __table_args__ = (
        Index("idx_document_basis_basis", "basis_document_id", "document_id"),
        TABLE_OPTIONS,
    )

    document_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("documents.id", name="fk_document_basis_document", ondelete="CASCADE"),
        primary_key=True,
    )
    basis_document_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("documents.id", name="fk_document_basis_basis", ondelete="CASCADE"),
        primary_key=True,
    )

    document: Mapped[Document] = relationship(
        foreign_keys=[document_id],
        back_populates="basis_links",
    )
    basis_document: Mapped[Document] = relationship(
        foreign_keys=[basis_document_id],
        back_populates="used_as_basis_links",
    )


class DocumentChunk(Base):
    __tablename__ = "document_chunks"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    document_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "documents.id",
            name="fk_document_chunks_document",
            ondelete="CASCADE",
        ),
        nullable=False,
    )
    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    embedding: Mapped[list[float]] = deferred(
        mapped_column(VectorType(EMBEDDING_DIMENSION), nullable=False)
    )
    embedding_model: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    document: Mapped[Document] = relationship(back_populates="chunks")

    __table_args__ = (
        # One deterministic chunk position per document; also supports scope scans.
        # The explicit name matches the reviewed SQL design.
        UniqueConstraint(
            "document_id",
            "chunk_index",
            name="uq_document_chunks_doc_idx",
        ),
        TABLE_OPTIONS,
    )
