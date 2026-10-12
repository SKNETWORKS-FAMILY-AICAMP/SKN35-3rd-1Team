"""My library calendar. Dates are Asia/Seoul days computed by the server."""

from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.catalog import ArtworkCard


class CalendarDay(BaseModel):
    date: date
    # Distinct artworks viewed that day.
    artwork_count: int
    # Sum of view_count (reopening the same artwork counts again).
    total_views: int


class ViewedArtwork(ArtworkCard):
    view_count: int
    last_viewed_at: datetime
