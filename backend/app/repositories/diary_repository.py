"""Owner-scoped diary reads and bounded, public-only cursor pagination."""

from datetime import date

from sqlalchemy import delete, select
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.core import timeutil
from app.models import Artist, Artwork, DiaryEntry, User


def rows():
    return (
        select(DiaryEntry, User.nickname, Artwork, Artist.name)
        .join(User, User.id == DiaryEntry.user_id)
        .outerjoin(Artwork, Artwork.id == DiaryEntry.artwork_id)
        .outerjoin(Artist, Artist.id == Artwork.artist_id)
    )


def own(db: Session, user_id: int, day: date):
    return db.execute(
        rows().where(DiaryEntry.user_id == user_id, DiaryEntry.entry_date == day)
    ).first()


def month(db: Session, user_id: int, start: date, end: date):
    return db.execute(
        rows()
        .where(
            DiaryEntry.user_id == user_id,
            DiaryEntry.entry_date >= start,
            DiaryEntry.entry_date < end,
        )
        .order_by(DiaryEntry.entry_date.desc())
    ).all()


def feed(db: Session, *, limit: int, before_id: int | None, artwork_id: int | None):
    query = rows().where(DiaryEntry.is_public.is_(True))
    if before_id is not None:
        query = query.where(DiaryEntry.id < before_id)
    if artwork_id is not None:
        query = query.where(DiaryEntry.artwork_id == artwork_id)
    return db.execute(query.order_by(DiaryEntry.id.desc()).limit(limit + 1)).all()


def save(
    db: Session,
    *,
    user_id: int,
    day: date,
    content: str,
    is_public: bool,
    artwork_id: int | None,
):
    values = {
        "content": content,
        "is_public": is_public,
        "artwork_id": artwork_id,
        "updated_at": timeutil.utcnow(),
    }
    if db.get_bind().dialect.name == "sqlite":
        stmt = sqlite_insert(DiaryEntry).values(
            user_id=user_id, entry_date=day, **values
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=["user_id", "entry_date"], set_=values
        )
    else:
        stmt = mysql_insert(DiaryEntry).values(
            user_id=user_id, entry_date=day, **values
        )
        stmt = stmt.on_duplicate_key_update(**values)
    db.execute(stmt)
    db.commit()
    db.expire_all()
    return own(db, user_id, day)


def remove(db: Session, user_id: int, day: date):
    db.execute(
        delete(DiaryEntry).where(
            DiaryEntry.user_id == user_id, DiaryEntry.entry_date == day
        )
    )
    db.commit()
