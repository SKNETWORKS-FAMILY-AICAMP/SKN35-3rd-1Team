"""Account settings and private collection contracts; identity never comes from JSON."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.timeutil import local_date, utcnow
from app.schemas.catalog import ArtworkCard
from app.schemas.diary import DiaryEntry

Priority = Literal["technique", "background", "artist_life"]
DEFAULT_PRIORITIES = ["background", "technique", "artist_life"]


class ProfileWrite(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    birth_date: date | None = None
    explanation_priorities: list[Priority] = Field(
        default_factory=lambda: DEFAULT_PRIORITIES.copy(), min_length=3, max_length=3
    )
    conversation_style: Literal["easy", "professional"] = "easy"
    onboarding_completed: bool = True

    @field_validator("birth_date")
    @classmethod
    def valid_date(cls, value):
        if value is not None and not date(1900, 1, 1) <= value <= local_date(utcnow()):
            raise ValueError("생년월일을 확인해 주세요.")
        return value

    @field_validator("explanation_priorities")
    @classmethod
    def unique_priorities(cls, value):
        if len(set(value)) != 3:
            raise ValueError("설명 항목은 한 번씩 선택해 주세요.")
        return value


class ProfileOut(ProfileWrite):
    nickname: str


class CollectionWrite(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=1, max_length=80)
    description: str = Field(default="", max_length=500)


class CollectionOut(CollectionWrite):
    id: int
    artwork_count: int
    previews: list[ArtworkCard]


class ArtworkPage(BaseModel):
    items: list[ArtworkCard]
    next_cursor: int | None = None


class CritiquePage(BaseModel):
    items: list[DiaryEntry]
    next_cursor: int | None = None


class ActivityOut(BaseModel):
    kind: Literal["view", "like", "diary", "collection"]
    title: str
    occurred_at: datetime
    artwork_id: int | None = None
    entry_date: date | None = None


class TasteOut(BaseModel):
    summary: str | None = None
    evidence: list[ArtworkCard] = Field(default_factory=list)
    generated_at: datetime | None = None
    stale: bool = False


class CollectionChatRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    message: str = Field(min_length=1, max_length=500)
    collection_id: int | None = Field(default=None, gt=0)


class CollectionAction(BaseModel):
    action: Literal["create", "add"]
    collection_id: int | None = None
    artwork_id: int | None = None
    name: str | None = None


class CollectionChatReply(BaseModel):
    answer: str
    proposal: CollectionAction | None = None
