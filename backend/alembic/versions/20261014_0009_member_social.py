"""Public member ids, member follows and follow-list visibility.
Revision ID: 20261014_0009
Revises: 20261014_0008
"""

import secrets

import sqlalchemy as sa
from alembic import op

revision = "20261014_0009"
down_revision = "20261014_0008"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("users", sa.Column("public_id", sa.String(22)))
    op.add_column(
        "users",
        sa.Column(
            "follow_list_public",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("1"),
        ),
    )
    bind = op.get_bind()
    users = sa.table("users", sa.column("id"), sa.column("public_id"))
    for (user_id,) in bind.execute(sa.select(users.c.id)).all():
        bind.execute(
            users.update()
            .where(users.c.id == user_id)
            .values(public_id=secrets.token_urlsafe(9))
        )
    op.alter_column(
        "users", "public_id", existing_type=sa.String(22), nullable=False
    )
    op.create_unique_constraint("uq_users_public_id", "users", ["public_id"])
    op.create_table(
        "user_follows",
        sa.Column(
            "follower_id",
            sa.BigInteger(),
            sa.ForeignKey(
                "users.id", name="fk_user_follows_follower", ondelete="CASCADE"
            ),
            primary_key=True,
        ),
        sa.Column(
            "followee_id",
            sa.BigInteger(),
            sa.ForeignKey(
                "users.id", name="fk_user_follows_followee", ondelete="CASCADE"
            ),
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
    op.create_index("idx_user_follows_followee", "user_follows", ["followee_id"])


def downgrade():
    op.drop_table("user_follows")
    op.drop_constraint("uq_users_public_id", "users", type_="unique")
    op.drop_column("users", "follow_list_public")
    op.drop_column("users", "public_id")
