"""Account settings and private collection contracts; identity never comes from JSON."""

from datetime import date, datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

from app.core.timeutil import local_date, utcnow
from app.schemas.catalog import ArtworkCard
from app.schemas.diary import DiaryEntry


class ProfileWrite(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    # 공개 감상 피드에 표시되는 이름. 생략하면 지금 이름을 그대로 둔다.
    nickname: Annotated[str, StringConstraints(min_length=2, max_length=20)] | None = None
    birth_date: date | None = None
    conversation_style: Literal["easy", "professional"] = "easy"
    onboarding_completed: bool = True

    @field_validator("birth_date")
    @classmethod
    def valid_date(cls, value):
        if value is not None and not date(1900, 1, 1) <= value <= local_date(utcnow()):
            raise ValueError("생년월일을 확인해 주세요.")
        return value

class ProfileOut(ProfileWrite):
    nickname: str


class CollectionWrite(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=1, max_length=80)
    description: str = Field(default="", max_length=500)


class CollectionCreate(CollectionWrite):
    # Optional first artworks, kept in this order (the first one is the cover).
    artwork_ids: list[Annotated[int, Field(gt=0)]] = Field(
        default_factory=list, max_length=500
    )


class CollectionOut(CollectionWrite):
    id: int
    artwork_count: int
    # Earliest added first; the first one is the collection cover.
    previews: list[ArtworkCard]


class AutoCollectionOut(BaseModel):
    """A collection computed from the owner's view history (not stored)."""

    key: str
    name: str
    description: str
    artwork_count: int
    cover: ArtworkCard | None = None


class AutoCollectionDetail(BaseModel):
    collection: AutoCollectionOut
    items: list[ArtworkCard]


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
    # One-line AI introduction shown under the nickname.
    summary: str | None = None
    evidence: list[ArtworkCard] = Field(default_factory=list)
    # Public impressions read for the introduction (their text is not returned).
    impression_count: int = 0
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
    # create only: artworks to put in the new collection, in order.
    artwork_ids: list[int] = Field(default_factory=list)


class CollectionChoice(BaseModel):
    id: int
    name: str


class CollectionSuggestion(BaseModel):
    """Docent chat offer to collect the artwork. Nothing is saved until confirmed."""

    kind: Literal["add_artwork", "create_from_views"]
    message: str
    artwork_id: int
    # add_artwork: the member's collections to choose from (or make a new one).
    collections: list[CollectionChoice] = Field(default_factory=list)
    # create_from_views: the new collection and the viewed artworks it would hold.
    proposal: CollectionAction | None = None
    artworks: list[ArtworkCard] = Field(default_factory=list)


class CollectionChatReply(BaseModel):
    answer: str
    proposal: CollectionAction | None = None
    # Preview of the artworks a proposal would add, so the user sees them first.
    artworks: list[ArtworkCard] = Field(default_factory=list)
