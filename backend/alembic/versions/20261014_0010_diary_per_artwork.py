"""Impressions are limited per artwork instead of per day.

A member may write any number of impressions a day, but only one per artwork.
Entries without an artwork (NULL) are not limited by the unique key.

Revision ID: 20261014_0010
Revises: 20261014_0009
"""

from alembic import op

revision = "20261014_0010"
down_revision = "20261014_0009"
branch_labels = None
depends_on = None


def upgrade():
    # Add the replacement indexes first so the user_id foreign key always has one.
    op.create_index("ix_diary_user_date", "diary_entries", ["user_id", "entry_date"])
    op.create_unique_constraint(
        "uq_diary_user_artwork", "diary_entries", ["user_id", "artwork_id"]
    )
    op.drop_constraint("uq_diary_user_date", "diary_entries", type_="unique")


def downgrade():
    # Fails if a member has two entries on one day; remove those first.
    op.create_unique_constraint(
        "uq_diary_user_date", "diary_entries", ["user_id", "entry_date"]
    )
    op.drop_constraint("uq_diary_user_artwork", "diary_entries", type_="unique")
    op.drop_index("ix_diary_user_date", "diary_entries")
