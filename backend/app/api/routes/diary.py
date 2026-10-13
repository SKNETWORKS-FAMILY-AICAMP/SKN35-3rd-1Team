"""Private diary operations use only the identity verified by CurrentUser."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Response

from app.api.routes.library import Month
from app.core.auth import CurrentUser
from app.db.session import DbSession
from app.repositories import diary_repository
from app.schemas.diary import DiaryEntry, DiaryFeed, DiaryWrite
from app.services import diary_service

router = APIRouter(tags=["diary"])


@router.get("/diary/feed")
def feed(
    db: DbSession,
    response: Response,
    limit: Annotated[int, Query(ge=1, le=30)] = 12,
    before_id: Annotated[int | None, Query(gt=0)] = None,
    artwork_id: Annotated[int | None, Query(gt=0)] = None,
) -> DiaryFeed:
    response.headers["Cache-Control"] = "no-store"
    return diary_service.get_feed(
        db, limit=limit, before_id=before_id, artwork_id=artwork_id
    )


@router.get("/me/diary")
def month(
    month: Month, user: CurrentUser, db: DbSession, response: Response
) -> list[DiaryEntry]:
    response.headers["Cache-Control"] = "private, no-store"
    try:
        return diary_service.get_month(db, user.id, month)
    except ValueError:
        raise HTTPException(422, "올바른 연월을 입력해 주세요.") from None


@router.get("/me/diary/{day}")
def day_entry(
    day: date, user: CurrentUser, db: DbSession, response: Response
) -> DiaryEntry | None:
    response.headers["Cache-Control"] = "private, no-store"
    return diary_service.get_day(db, user.id, day)


@router.put("/me/diary/{day}")
def save(
    day: date, body: DiaryWrite, user: CurrentUser, db: DbSession, response: Response
) -> DiaryEntry:
    response.headers["Cache-Control"] = "private, no-store"
    return diary_service.save(db, user.id, day, body)


@router.delete("/me/diary/{day}", status_code=204)
def remove(day: date, user: CurrentUser, db: DbSession) -> None:
    diary_repository.remove(db, user.id, day)
