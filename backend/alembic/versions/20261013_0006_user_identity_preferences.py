"""Add external identities and optional docent preferences.

Revision ID: 20261013_0006
Revises: 20261012_0005
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261013_0006"
down_revision: str | None = "20261012_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TABLE_OPTIONS = {
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_general_ci",
}


def upgrade() -> None:
    op.create_table(
        "social_accounts",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("provider", sa.String(length=30), nullable=False),
        sa.Column("provider_user_id", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_social_accounts_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_social_accounts"),
        sa.UniqueConstraint(
            "provider",
            "provider_user_id",
            name="uq_social_accounts_provider_user",
        ),
        **TABLE_OPTIONS,
    )
    op.create_index("ix_social_accounts_user_id", "social_accounts", ["user_id"])

    op.create_table(
        "user_preferences",
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("birth_year", sa.SmallInteger(), nullable=True),
        sa.Column("gender", sa.String(length=30), nullable=True),
        sa.Column("tone", sa.String(length=30), nullable=True),
        sa.Column("explanation_level", sa.String(length=30), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_user_preferences_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", name="pk_user_preferences"),
        **TABLE_OPTIONS,
    )

    # Preserve today's Firebase identities without changing the login flow.
    op.execute(
        sa.text(
            """
            INSERT INTO social_accounts (user_id, provider, provider_user_id)
            SELECT id, 'firebase', firebase_uid
            FROM users
            """
        )
    )


def downgrade() -> None:
    op.drop_table("user_preferences")
    op.drop_table("social_accounts")
