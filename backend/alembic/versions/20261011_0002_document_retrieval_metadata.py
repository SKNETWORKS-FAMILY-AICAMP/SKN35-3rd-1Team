"""Keep retrieval metadata from data/processed on documents.

Adds the stable document key, language, topic and review state to ``documents``,
and ``document_artworks`` for timeline events that mention artworks.

Revision ID: 20261011_0002
Revises: 20261011_0001
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mysql

from alembic import op

revision: str = "20261011_0002"
down_revision: str | None = "20261011_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TABLE_OPTIONS = {
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_general_ci",
}


def upgrade() -> None:
    # documents is empty when this runs (no loader yet), so NOT NULL + UNIQUE is safe.
    op.add_column("documents", sa.Column("doc_key", sa.String(191), nullable=False))
    op.add_column(
        "documents",
        sa.Column("lang", sa.String(8), server_default=sa.text("'ko'"), nullable=False),
    )
    op.add_column("documents", sa.Column("topic", sa.String(30), nullable=True))
    op.add_column(
        "documents",
        sa.Column(
            "needs_review",
            mysql.TINYINT(display_width=1),
            server_default="0",
            nullable=False,
        ),
    )
    op.create_unique_constraint("uq_documents_doc_key", "documents", ["doc_key"])

    op.create_table(
        "document_artworks",
        sa.Column("document_id", sa.BigInteger(), nullable=False),
        sa.Column("artwork_id", sa.BigInteger(), nullable=False),
        sa.ForeignKeyConstraint(
            ["artwork_id"],
            ["artworks.id"],
            name="fk_document_artworks_artwork",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["document_id"],
            ["documents.id"],
            name="fk_document_artworks_document",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("document_id", "artwork_id", name="pk_document_artworks"),
        **TABLE_OPTIONS,
    )
    op.create_index(
        "idx_document_artworks_artwork",
        "document_artworks",
        ["artwork_id", "document_id"],
    )


def downgrade() -> None:
    op.drop_table("document_artworks")
    op.drop_constraint("uq_documents_doc_key", "documents", type_="unique")
    op.drop_column("documents", "needs_review")
    op.drop_column("documents", "topic")
    op.drop_column("documents", "lang")
    op.drop_column("documents", "doc_key")
