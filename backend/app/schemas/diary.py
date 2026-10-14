"""No email, Firebase UID or internal user ID is returned to the public feed.

``author_id`` is the author's opaque public profile id.
"""

from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.schemas.catalog import ArtworkCard


class DiaryWrite(BaseModel):
    model_config = ConfigDict(extra="forbid")
    content: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)
    ]
    is_public: bool = False
    artwork_id: Annotated[int, Field(gt=0)] | None = None


class DiaryEntry(BaseModel):
    id: int
    entry_date: date
    content: str
    is_public: bool
    author_name: str
    author_id: str
    artwork: ArtworkCard | None
    created_at: datetime
    updated_at: datetime


class DiaryFeed(BaseModel):
    items: list[DiaryEntry]
    next_cursor: int | None = None
