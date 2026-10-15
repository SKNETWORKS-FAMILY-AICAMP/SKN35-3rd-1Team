"""Dates in the app time zone (Asia/Seoul).

View dates are computed here, not with the DB's ``CURDATE()``: a UTC DB session
would put views between midnight and 9 a.m. KST on the previous day.
"""

from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

from app.core.config import get_settings


def utcnow() -> datetime:
    """Naive UTC, the form stored in DATETIME columns."""

    return datetime.now(UTC).replace(tzinfo=None)


def local_date(at_utc: datetime) -> date:
    """App-time-zone date of a naive UTC timestamp."""

    tz = ZoneInfo(get_settings().app_timezone)
    return at_utc.replace(tzinfo=UTC).astimezone(tz).date()


def month_range(month: str) -> tuple[date, date]:
    """``"2026-10"`` -> (2026-10-01, 2026-11-01), end exclusive."""

    year, mon = map(int, month.split("-"))
    start = date(year, mon, 1)
    end = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
    return start, end
