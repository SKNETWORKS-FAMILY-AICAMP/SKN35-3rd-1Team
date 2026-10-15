"""Owner-scoped diary reads and bounded, public-only cursor pagination."""

from datetime import date

from sqlalchemy import delete, select
from sqlalchemy import update as sa_update
from sqlalchemy.orm import Session

from app.core import timeutil
from app.models import Artist, Artwork, DiaryEntry, User


def rows():
    return (
        select(DiaryEntry, User.nickname, Artwork, Artist.name, User.public_id)
        .join(User, User.id == DiaryEntry.user_id)
        .outerjoin(Artwork, Artwork.id == DiaryEntry.artwork_id)
        .outerjoin(Artist, Artist.id == Artwork.artist_id)
    )


def own(db: Session, user_id: int, entry_id: int):
    return db.execute(
        rows().where(DiaryEntry.user_id == user_id, DiaryEntry.id == entry_id)
    ).first()


def for_artwork(db: Session, user_id: int, artwork_id: int):
    return db.execute(
        rows().where(DiaryEntry.user_id == user_id, DiaryEntry.artwork_id == artwork_id)
    ).first()


def month(db: Session, user_id: int, start: date, end: date):
    return db.execute(
        rows()
        .where(
            DiaryEntry.user_id == user_id,
            DiaryEntry.entry_date >= start,
            DiaryEntry.entry_date < end,
        )
        .order_by(DiaryEntry.entry_date.desc(), DiaryEntry.id.desc())
    ).all()


def feed(
    db: Session,
    *,
    limit: int,
    before_id: int | None,
    artwork_id: int | None,
    author_id: int | None = None,
):
    query = rows().where(DiaryEntry.is_public.is_(True))
    if author_id is not None:
        query = query.where(DiaryEntry.user_id == author_id)
    if before_id is not None:
        query = query.where(DiaryEntry.id < before_id)
    if artwork_id is not None:
        query = query.where(DiaryEntry.artwork_id == artwork_id)
    return db.execute(query.order_by(DiaryEntry.id.desc()).limit(limit + 1)).all()


def create(
    db: Session,
    *,
    user_id: int,
    day: date,
    content: str,
    is_public: bool,
    artwork_id: int | None,
) -> int:
    now = timeutil.utcnow()
    entry = DiaryEntry(
        user_id=user_id,
        entry_date=day,
        content=content,
        is_public=is_public,
        artwork_id=artwork_id,
        created_at=now,
        updated_at=now,
    )
    db.add(entry)
    db.flush()
    return entry.id


def update(
    db: Session,
    *,
    user_id: int,
    entry_id: int,
    content: str,
    is_public: bool,
    artwork_id: int | None,
) -> int:
    """Returns the number of the owner's rows changed (0 when not found)."""
    return db.execute(
        sa_update(DiaryEntry)
        .where(DiaryEntry.user_id == user_id, DiaryEntry.id == entry_id)
        .values(
            content=content,
            is_public=is_public,
            artwork_id=artwork_id,
            updated_at=timeutil.utcnow(),
        )
    ).rowcount


def remove(db: Session, user_id: int, entry_id: int):
    db.execute(
        delete(DiaryEntry).where(
            DiaryEntry.user_id == user_id, DiaryEntry.id == entry_id
        )
    )
    db.commit()
