"""열람 기록과 내 서재 캘린더. 모두 로그인 필요.

날짜는 서버에서 `APP_TIMEZONE`(Asia/Seoul) 기준으로 계산한다.
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.stub import not_implemented
from app.core.auth import CurrentUser
from app.schemas.library import CalendarDay, ViewedArtwork

router = APIRouter(tags=["library"])

Month = Annotated[str, Query(pattern=r"^\d{4}-(0[1-9]|1[0-2])$", examples=["2026-10"])]


@router.post("/artworks/{artwork_id}/views", status_code=status.HTTP_204_NO_CONTENT)
def record_view(artwork_id: int, user: CurrentUser) -> None:
    """작품 열람 기록. 같은 날 다시 보면 `view_count`만 증가."""
    not_implemented()


@router.get("/me/library/calendar")
def get_calendar(month: Month, user: CurrentUser) -> list[CalendarDay]:
    """월별 감상 기록. 본 날만 날짜순으로 담는다."""
    not_implemented()


@router.get("/me/library/days/{day}")
def get_day(day: date, user: CurrentUser) -> list[ViewedArtwork]:
    """그날 본 작품 목록 (마지막으로 본 순)."""
    not_implemented()
