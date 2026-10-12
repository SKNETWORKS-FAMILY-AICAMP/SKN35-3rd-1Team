"""View dates and calendar rules, with a fake repository (no TiDB).

Cases come from ``contracts/activity-cases.json`` (view-003, view-004, view-005).
Timestamps are naive UTC on purpose: that is what the DATETIME columns store.
"""

# ruff: noqa: DTZ001

from datetime import UTC, date, datetime
from types import SimpleNamespace

import pytest

from app.core import timeutil
from app.models import Artwork
from app.repositories import activity_repository
from app.repositories.activity_repository import CalendarRow, ViewedRow
from app.services import catalog_service, library_service


class FakeDb:
    def __init__(self) -> None:
        self.commits = 0

    def commit(self) -> None:
        self.commits += 1


@pytest.fixture
def recorded(monkeypatch) -> list[dict]:
    calls: list[dict] = []
    monkeypatch.setattr(catalog_service, "ensure_artwork", lambda db, artwork_id: None)
    monkeypatch.setattr(
        activity_repository, "record_view", lambda db, **kwargs: calls.append(kwargs)
    )
    return calls


@pytest.mark.parametrize(
    ("utc", "kst_day"),
    [
        # view-003: still the 11th in UTC, already the 12th in Seoul.
        (datetime(2026, 10, 11, 15, 0), date(2026, 10, 12)),
        (datetime(2026, 10, 11, 14, 59), date(2026, 10, 11)),
        # view-004: last day of the month vs. first day of the next.
        (datetime(2026, 10, 31, 14, 59), date(2026, 10, 31)),
        (datetime(2026, 10, 31, 15, 0), date(2026, 11, 1)),
    ],
)
def test_view_day_is_seoul_date(recorded, utc: datetime, kst_day: date) -> None:
    db = FakeDb()
    library_service.record_view(db, user_id=1, artwork_id=7, now=utc)
    assert recorded == [
        {"user_id": 1, "artwork_id": 7, "viewed_on": kst_day, "now": utc}
    ]
    assert db.commits == 1


@pytest.mark.parametrize(
    ("month", "expected"),
    [
        ("2026-10", (date(2026, 10, 1), date(2026, 11, 1))),
        ("2026-12", (date(2026, 12, 1), date(2027, 1, 1))),
        ("2028-02", (date(2028, 2, 1), date(2028, 3, 1))),
    ],
)
def test_month_range_is_end_exclusive(month: str, expected) -> None:
    assert timeutil.month_range(month) == expected


def test_calendar_queries_the_month(monkeypatch) -> None:
    seen = {}

    def fake_calendar(db, *, user_id, start, end):
        seen.update(user_id=user_id, start=start, end=end)
        return [CalendarRow(date(2026, 10, 12), 2, 5)]

    monkeypatch.setattr(activity_repository, "calendar", fake_calendar)
    days = library_service.calendar(FakeDb(), user_id=3, month="2026-10")
    assert seen == {"user_id": 3, "start": date(2026, 10, 1), "end": date(2026, 11, 1)}
    assert [d.model_dump() for d in days] == [
        {"date": date(2026, 10, 12), "artwork_count": 2, "total_views": 5}
    ]


def _artwork(artwork_id: int) -> Artwork:
    return Artwork(
        id=artwork_id,
        slug=f"a{artwork_id}",
        title="작품",
        title_en=None,
        artist_id=1,
        movement_id=None,
        year_label=None,
        image_url=None,
        is_featured=False,
    )


def test_day_list_keeps_order_and_marks_utc(monkeypatch) -> None:
    rows = [
        ViewedRow(_artwork(2), "모네", 3, datetime(2026, 10, 12, 5, 0)),
        ViewedRow(_artwork(1), "모네", 1, datetime(2026, 10, 12, 1, 0)),
    ]
    monkeypatch.setattr(activity_repository, "viewed_on_day", lambda db, **k: rows)
    result = library_service.viewed_on_day(
        SimpleNamespace(), user_id=1, day=date(2026, 10, 12)
    )
    # view-005: per-artwork view_count, newest last_viewed_at first.
    assert [(r.id, r.view_count) for r in result] == [(2, 3), (1, 1)]
    assert result[0].artist_name == "모네"
    assert result[0].last_viewed_at == datetime(2026, 10, 12, 5, 0, tzinfo=UTC)
