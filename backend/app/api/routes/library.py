"""열람 기록과 내 서재 캘린더. 모두 로그인 필요.

날짜는 서버에서 `APP_TIMEZONE`(Asia/Seoul) 기준으로 계산한다.
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.core.auth import CurrentUser
from app.db.session import DbSession
from app.schemas.library import CalendarDay, ViewedArtwork
from app.services import library_service

router = APIRouter(tags=["library"])

Month = Annotated[str, Query(pattern=r"^\d{4}-(0[1-9]|1[0-2])$", examples=["2026-10"])]


@router.post("/artworks/{artwork_id}/views", status_code=status.HTTP_204_NO_CONTENT)
def record_view(artwork_id: int, user: CurrentUser, db: DbSession) -> None:
    """작품 열람 기록. 같은 날 다시 보면 `view_count`만 증가. 없는 작품이면 404."""
    library_service.record_view(db, user_id=user.id, artwork_id=artwork_id)


@router.get("/me/library/calendar")
def get_calendar(month: Month, user: CurrentUser, db: DbSession) -> list[CalendarDay]:
    """월별 감상 기록. 본 날만 날짜순으로 담는다."""
    return library_service.calendar(db, user_id=user.id, month=month)


@router.get("/me/library/days/{day}")
def get_day(day: date, user: CurrentUser, db: DbSession) -> list[ViewedArtwork]:
    """그날 본 작품 목록 (마지막으로 본 순)."""
    return library_service.viewed_on_day(db, user_id=user.id, day=day)
