"""Daily journal and public impressions share one source of truth."""

from datetime import UTC, date

from sqlalchemy.orm import Session

from app.core.timeutil import month_range
from app.repositories import diary_repository as repo
from app.schemas.diary import DiaryEntry, DiaryFeed, DiaryWrite
from app.services.catalog_service import ensure_artwork, to_artwork_card


def serialize(row) -> DiaryEntry:
    entry, nickname, artwork, artist_name = row
    return DiaryEntry(
        id=entry.id,
        entry_date=entry.entry_date,
        content=entry.content,
        is_public=entry.is_public,
        author_name=nickname or "감상가",
        artwork=to_artwork_card(artwork, artist_name) if artwork else None,
        created_at=entry.created_at.replace(tzinfo=UTC),
        updated_at=entry.updated_at.replace(tzinfo=UTC),
    )


def get_day(db: Session, user_id: int, day: date) -> DiaryEntry | None:
    row = repo.own(db, user_id, day)
    return serialize(row) if row else None


def get_month(db: Session, user_id: int, month: str) -> list[DiaryEntry]:
    start, end = month_range(month)
    return [serialize(row) for row in repo.month(db, user_id, start, end)]


def save(db: Session, user_id: int, day: date, body: DiaryWrite) -> DiaryEntry:
    if body.artwork_id is not None:
        ensure_artwork(db, body.artwork_id)
    return serialize(repo.save(db, user_id=user_id, day=day, **body.model_dump()))


def get_feed(
    db: Session, *, limit: int, before_id: int | None, artwork_id: int | None
) -> DiaryFeed:
    rows = repo.feed(db, limit=limit, before_id=before_id, artwork_id=artwork_id)
    return DiaryFeed(
        items=[serialize(row) for row in rows[:limit]],
        next_cursor=rows[limit - 1][0].id if len(rows) > limit else None,
    )
