"""Add private-by-default daily impressions and indexed public feed.

Revision ID: 20261013_0007
Revises: 20261013_0006
"""

import sqlalchemy as sa
from alembic import op

revision = "20261013_0007"
down_revision = "20261013_0006"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "diary_entries",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("entry_date", sa.Date(), nullable=False),
        sa.Column("artwork_id", sa.BigInteger(), nullable=True),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "is_public", sa.Boolean(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_diary_entries_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["artwork_id"],
            ["artworks.id"],
            name="fk_diary_entries_artwork_id_artworks",
            ondelete="SET NULL",
        ),
        sa.UniqueConstraint("user_id", "entry_date", name="uq_diary_user_date"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_general_ci",
    )
    op.create_index("ix_diary_public_id", "diary_entries", ["is_public", "id"])
    op.create_index(
        "ix_diary_artwork_public_id", "diary_entries", ["artwork_id", "is_public", "id"]
    )


def downgrade():
    op.drop_table("diary_entries")
