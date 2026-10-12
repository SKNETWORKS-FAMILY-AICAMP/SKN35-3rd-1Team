"""Likes, follows and daily views.

Writes are idempotent at the SQL level: likes and follows use ``INSERT IGNORE``,
views use ``ON DUPLICATE KEY UPDATE``. The caller commits.
"""

from datetime import date, datetime
from typing import NamedTuple

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.orm import Session

from app.models import Artist, ArtistFollow, Artwork, ArtworkLike, ArtworkView


class CalendarRow(NamedTuple):
    viewed_on: date
    artwork_count: int
    total_views: int


class ViewedRow(NamedTuple):
    artwork: Artwork
    artist_name: str
    view_count: int
    last_viewed_at: datetime


# --- likes ------------------------------------------------------------------


def add_like(db: Session, *, user_id: int, artwork_id: int) -> None:
    db.execute(
        insert(ArtworkLike)
        .values(user_id=user_id, artwork_id=artwork_id)
        .prefix_with("IGNORE")
    )


def remove_like(db: Session, *, user_id: int, artwork_id: int) -> None:
    db.execute(
        delete(ArtworkLike).where(
            ArtworkLike.user_id == user_id, ArtworkLike.artwork_id == artwork_id
        )
    )


def list_liked_artworks(db: Session, *, user_id: int) -> list[tuple[Artwork, str]]:
    stmt = (
        select(Artwork, Artist.name)
        .join(ArtworkLike, ArtworkLike.artwork_id == Artwork.id)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(ArtworkLike.user_id == user_id)
        .order_by(ArtworkLike.created_at.desc(), Artwork.id.desc())
    )
    return [tuple(row) for row in db.execute(stmt)]


# --- follows ----------------------------------------------------------------


def add_follow(db: Session, *, user_id: int, artist_id: int) -> None:
    db.execute(
        insert(ArtistFollow)
        .values(user_id=user_id, artist_id=artist_id)
        .prefix_with("IGNORE")
    )


def remove_follow(db: Session, *, user_id: int, artist_id: int) -> None:
    db.execute(
        delete(ArtistFollow).where(
            ArtistFollow.user_id == user_id, ArtistFollow.artist_id == artist_id
        )
    )


def list_followed_artists(db: Session, *, user_id: int) -> list[Artist]:
    stmt = (
        select(Artist)
        .join(ArtistFollow, ArtistFollow.artist_id == Artist.id)
        .where(ArtistFollow.user_id == user_id)
        .order_by(ArtistFollow.created_at.desc(), Artist.id.desc())
    )
    return list(db.scalars(stmt))


# --- views ------------------------------------------------------------------


def record_view(
    db: Session, *, user_id: int, artwork_id: int, viewed_on: date, now: datetime
) -> None:
    """One row per user, day and artwork; a repeat view bumps ``view_count``."""

    stmt = insert(ArtworkView).values(
        user_id=user_id,
        artwork_id=artwork_id,
        viewed_on=viewed_on,
        view_count=1,
        first_viewed_at=now,
        last_viewed_at=now,
    )
    db.execute(
        stmt.on_duplicate_key_update(
            view_count=ArtworkView.view_count + 1,
            last_viewed_at=stmt.inserted.last_viewed_at,
        )
    )


def calendar(db: Session, *, user_id: int, start: date, end: date) -> list[CalendarRow]:
    """Days in ``[start, end)`` with at least one view, oldest first."""

    stmt = (
        select(
            ArtworkView.viewed_on,
            func.count().label("artwork_count"),
            func.sum(ArtworkView.view_count).label("total_views"),
        )
        .where(
            ArtworkView.user_id == user_id,
            ArtworkView.viewed_on >= start,
            ArtworkView.viewed_on < end,
        )
        .group_by(ArtworkView.viewed_on)
        .order_by(ArtworkView.viewed_on)
    )
    return [
        CalendarRow(day, int(count), int(total))
        for day, count, total in db.execute(stmt)
    ]


def viewed_on_day(db: Session, *, user_id: int, day: date) -> list[ViewedRow]:
    """Artworks viewed on ``day``, most recently viewed first."""

    stmt = (
        select(Artwork, Artist.name, ArtworkView.view_count, ArtworkView.last_viewed_at)
        .join(ArtworkView, ArtworkView.artwork_id == Artwork.id)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(ArtworkView.user_id == user_id, ArtworkView.viewed_on == day)
        .order_by(ArtworkView.last_viewed_at.desc(), Artwork.id.desc())
    )
    return [ViewedRow(*row) for row in db.execute(stmt)]
