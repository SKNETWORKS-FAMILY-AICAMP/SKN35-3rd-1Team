"""Sign users in with Firebase Auth instead of local passwords.

Revision ID: 20261012_0005
Revises: 20261012_0004
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20261012_0005"
down_revision: str | None = "20261012_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # users was empty when this ran, so the NOT NULL column needs no backfill.
    op.add_column("users", sa.Column("firebase_uid", sa.String(length=128), nullable=False))
    op.create_unique_constraint("uq_users_firebase_uid", "users", ["firebase_uid"])
    op.drop_column("users", "password_hash")


def downgrade() -> None:
    op.add_column(
        "users",
        sa.Column("password_hash", sa.String(length=255), server_default="", nullable=False),
    )
    op.drop_constraint("uq_users_firebase_uid", "users", type_="unique")
    op.drop_column("users", "firebase_uid")
