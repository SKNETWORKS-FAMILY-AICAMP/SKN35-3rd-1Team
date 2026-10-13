"""Keep provenance for appended document supplements and corrections.

Revision ID: 20261012_0003
Revises: 20261011_0002
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261012_0003"
down_revision: str | None = "20261011_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TABLE_OPTIONS = {
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_general_ci",
}


def upgrade() -> None:
    op.add_column(
        "documents",
        sa.Column("basis_external_sources", sa.JSON(), nullable=True),
    )
    op.execute("UPDATE documents SET basis_external_sources = JSON_ARRAY() WHERE basis_external_sources IS NULL")
    op.alter_column("documents", "basis_external_sources", existing_type=sa.JSON(), nullable=False)
    op.create_table(
        "document_basis_documents",
        sa.Column("document_id", sa.BigInteger(), nullable=False),
        sa.Column("basis_document_id", sa.BigInteger(), nullable=False),
        sa.ForeignKeyConstraint(
            ["document_id"],
            ["documents.id"],
            name="fk_document_basis_document",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["basis_document_id"],
            ["documents.id"],
            name="fk_document_basis_basis",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "document_id",
            "basis_document_id",
            name="pk_document_basis_documents",
        ),
        **TABLE_OPTIONS,
    )
    op.create_index(
        "idx_document_basis_basis",
        "document_basis_documents",
        ["basis_document_id", "document_id"],
    )


def downgrade() -> None:
    op.drop_table("document_basis_documents")
    op.drop_column("documents", "basis_external_sources")
