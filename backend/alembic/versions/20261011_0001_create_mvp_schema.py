"""Create the MVP database schema.

Revision ID: 20261011_0001
Revises: None
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mysql
from tidb_vector.sqlalchemy import VectorType

from alembic import op

revision: str = "20261011_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TABLE_OPTIONS = {
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_general_ci",
}


def created_at() -> sa.Column[sa.DateTime]:
    return sa.Column(
        "created_at",
        sa.DateTime(),
        nullable=False,
        server_default=sa.text("CURRENT_TIMESTAMP"),
    )


def updated_at() -> sa.Column[sa.DateTime]:
    return sa.Column(
        "updated_at",
        sa.DateTime(),
        nullable=False,
        server_default=sa.text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
    )


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("nickname", sa.String(50), nullable=False),
        created_at(),
        updated_at(),
        sa.PrimaryKeyConstraint("id", name="pk_users"),
        sa.UniqueConstraint("email", name="uq_users_email"),
        **TABLE_OPTIONS,
    )

    op.create_table(
        "art_movements",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("slug", sa.String(100), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("name_en", sa.String(100), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        created_at(),
        sa.PrimaryKeyConstraint("id", name="pk_art_movements"),
        sa.UniqueConstraint("slug", name="uq_art_movements_slug"),
        **TABLE_OPTIONS,
    )

    op.create_table(
        "artists",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("slug", sa.String(120), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("name_en", sa.String(200), nullable=True),
        sa.Column("movement_id", sa.BigInteger(), nullable=True),
        sa.Column("birth_year", sa.SmallInteger(), nullable=True),
        sa.Column("death_year", sa.SmallInteger(), nullable=True),
        sa.Column("nationality", sa.String(100), nullable=True),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("portrait_url", sa.String(1024), nullable=True),
        created_at(),
        updated_at(),
        sa.ForeignKeyConstraint(
            ["movement_id"],
            ["art_movements.id"],
            name="fk_artists_movement",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_artists"),
        sa.UniqueConstraint("slug", name="uq_artists_slug"),
        **TABLE_OPTIONS,
    )
    op.create_index("idx_artists_movement", "artists", ["movement_id"])
    op.create_index("idx_artists_name", "artists", ["name"])

    op.create_table(
        "artworks",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("slug", sa.String(160), nullable=False),
        sa.Column("artist_id", sa.BigInteger(), nullable=False),
        sa.Column("movement_id", sa.BigInteger(), nullable=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("title_en", sa.String(255), nullable=True),
        sa.Column("year_label", sa.String(50), nullable=True),
        sa.Column("year_start", sa.SmallInteger(), nullable=True),
        sa.Column("medium", sa.String(255), nullable=True),
        sa.Column("dimensions", sa.String(100), nullable=True),
        sa.Column("collection", sa.String(255), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("image_url", sa.String(1024), nullable=True),
        sa.Column("image_source_url", sa.String(1024), nullable=True),
        sa.Column("image_license", sa.String(100), nullable=True),
        sa.Column(
            "is_featured",
            mysql.TINYINT(display_width=1),
            server_default="0",
            nullable=False,
        ),
        created_at(),
        updated_at(),
        sa.ForeignKeyConstraint(
            ["artist_id"],
            ["artists.id"],
            name="fk_artworks_artist",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["movement_id"],
            ["art_movements.id"],
            name="fk_artworks_movement",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_artworks"),
        sa.UniqueConstraint("slug", name="uq_artworks_slug"),
        **TABLE_OPTIONS,
    )
    op.create_index("idx_artworks_artist_year", "artworks", ["artist_id", "year_start"])
    op.create_index(
        "idx_artworks_movement_year", "artworks", ["movement_id", "year_start"]
    )

    op.create_table(
        "artwork_embeddings",
        sa.Column("artwork_id", sa.BigInteger(), nullable=False),
        sa.Column("embedding", VectorType(1536), nullable=False),
        sa.Column("embedding_model", sa.String(64), nullable=False),
        updated_at(),
        sa.ForeignKeyConstraint(
            ["artwork_id"],
            ["artworks.id"],
            name="fk_artwork_embeddings_artwork",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("artwork_id", name="pk_artwork_embeddings"),
        **TABLE_OPTIONS,
    )

    op.create_table(
        "documents",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("doc_type", sa.String(30), nullable=False),
        sa.Column("artwork_id", sa.BigInteger(), nullable=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("content", mysql.MEDIUMTEXT(), nullable=False),
        sa.Column("source_url", sa.String(1024), nullable=True),
        sa.Column("source_name", sa.String(255), nullable=True),
        sa.Column("license", sa.String(100), nullable=True),
        created_at(),
        updated_at(),
        sa.ForeignKeyConstraint(
            ["artwork_id"],
            ["artworks.id"],
            name="fk_documents_artwork",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_documents"),
        **TABLE_OPTIONS,
    )
    op.create_index("idx_documents_artwork", "documents", ["artwork_id"])

    op.create_table(
        "document_artists",
        sa.Column("document_id", sa.BigInteger(), nullable=False),
        sa.Column("artist_id", sa.BigInteger(), nullable=False),
        sa.ForeignKeyConstraint(
            ["artist_id"],
            ["artists.id"],
            name="fk_document_artists_artist",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["document_id"],
            ["documents.id"],
            name="fk_document_artists_document",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("document_id", "artist_id", name="pk_document_artists"),
        **TABLE_OPTIONS,
    )
    op.create_index(
        "idx_document_artists_artist",
        "document_artists",
        ["artist_id", "document_id"],
    )

    op.create_table(
        "document_chunks",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("document_id", sa.BigInteger(), nullable=False),
        sa.Column("chunk_index", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("embedding", VectorType(1536), nullable=False),
        sa.Column("embedding_model", sa.String(64), nullable=False),
        created_at(),
        sa.ForeignKeyConstraint(
            ["document_id"],
            ["documents.id"],
            name="fk_document_chunks_document",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_document_chunks"),
        sa.UniqueConstraint(
            "document_id",
            "chunk_index",
            name="uq_document_chunks_doc_idx",
        ),
        **TABLE_OPTIONS,
    )

    op.create_table(
        "artwork_likes",
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("artwork_id", sa.BigInteger(), nullable=False),
        created_at(),
        sa.ForeignKeyConstraint(
            ["artwork_id"],
            ["artworks.id"],
            name="fk_artwork_likes_artwork",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_artwork_likes_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "artwork_id", name="pk_artwork_likes"),
        **TABLE_OPTIONS,
    )
    op.create_index(
        "idx_artwork_likes_user_created",
        "artwork_likes",
        ["user_id", "created_at"],
    )
    op.create_index("idx_artwork_likes_artwork", "artwork_likes", ["artwork_id"])

    op.create_table(
        "artist_follows",
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("artist_id", sa.BigInteger(), nullable=False),
        created_at(),
        sa.ForeignKeyConstraint(
            ["artist_id"],
            ["artists.id"],
            name="fk_artist_follows_artist",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_artist_follows_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "artist_id", name="pk_artist_follows"),
        **TABLE_OPTIONS,
    )
    op.create_index("idx_artist_follows_artist", "artist_follows", ["artist_id"])

    op.create_table(
        "artwork_views",
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("viewed_on", sa.Date(), nullable=False),
        sa.Column("artwork_id", sa.BigInteger(), nullable=False),
        sa.Column("view_count", sa.Integer(), server_default="1", nullable=False),
        sa.Column(
            "first_viewed_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "last_viewed_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["artwork_id"],
            ["artworks.id"],
            name="fk_artwork_views_artwork",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_artwork_views_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "user_id",
            "viewed_on",
            "artwork_id",
            name="pk_artwork_views",
        ),
        **TABLE_OPTIONS,
    )
    op.create_index("idx_artwork_views_artwork", "artwork_views", ["artwork_id"])


def downgrade() -> None:
    op.drop_table("artwork_views")
    op.drop_table("artist_follows")
    op.drop_table("artwork_likes")
    op.drop_table("document_chunks")
    op.drop_table("document_artists")
    op.drop_table("documents")
    op.drop_table("artwork_embeddings")
    op.drop_table("artworks")
    op.drop_table("artists")
    op.drop_table("art_movements")
    op.drop_table("users")
