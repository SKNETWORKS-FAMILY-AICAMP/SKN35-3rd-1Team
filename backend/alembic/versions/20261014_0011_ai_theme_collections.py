"""Cache personal AI theme playlists independently of saved collections."""

import sqlalchemy as sa
from alembic import op

revision = "20261014_0011"
down_revision = "20261014_0010"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "theme_collection_cache",
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("fingerprint", sa.String(64)),
        sa.Column("themes", sa.JSON(), nullable=False),
        sa.Column("basis", sa.JSON()),
        sa.Column("generated_at", sa.DateTime()),
        sa.Column("attempted_at", sa.DateTime()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_general_ci",
    )


def downgrade():
    op.drop_table("theme_collection_cache")
