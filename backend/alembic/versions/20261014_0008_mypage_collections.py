"""Account preferences, onboarding and private collections.
Revision ID: 20261014_0008
Revises: 20261013_0007
"""

import sqlalchemy as sa
from alembic import op

revision = "20261014_0008"
down_revision = "20261013_0007"
branch_labels = None
depends_on = None


def upgrade():
    for column in (
        sa.Column("birth_date", sa.Date()),
        sa.Column("explanation_priorities", sa.JSON()),
        sa.Column("conversation_style", sa.String(30)),
        sa.Column(
            "onboarding_completed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("taste_summary", sa.Text()),
        sa.Column("taste_fingerprint", sa.String(64)),
        sa.Column("taste_generated_at", sa.DateTime()),
    ):
        op.add_column("user_preferences", column)
    op.create_table(
        "collections",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            sa.BigInteger(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
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
        sa.UniqueConstraint("user_id", "name", name="uq_collection_owner_name"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_general_ci",
    )
    op.create_index("ix_collections_user_id", "collections", ["user_id"])
    op.create_table(
        "collection_items",
        sa.Column(
            "collection_id",
            sa.BigInteger(),
            sa.ForeignKey("collections.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "artwork_id",
            sa.BigInteger(),
            sa.ForeignKey("artworks.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_general_ci",
    )


def downgrade():
    op.drop_table("collection_items")
    op.drop_table("collections")
    for name in (
        "taste_generated_at",
        "taste_fingerprint",
        "taste_summary",
        "onboarding_completed",
        "conversation_style",
        "explanation_priorities",
        "birth_date",
    ):
        op.drop_column("user_preferences", name)
