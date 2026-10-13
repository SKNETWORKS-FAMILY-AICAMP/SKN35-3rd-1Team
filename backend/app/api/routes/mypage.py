"""Authenticated account settings, private collections and collection assistant."""

from typing import Annotated

from fastapi import APIRouter, Query, Response

from app.core.auth import CurrentUser
from app.db.session import DbSession
from app.schemas.mypage import (
    ActivityOut,
    ArtworkPage,
    CollectionChatReply,
    CollectionChatRequest,
    CollectionOut,
    CollectionWrite,
    CritiquePage,
    ProfileOut,
    ProfileWrite,
    TasteOut,
)
from app.services import collection_assistant
from app.services import mypage_service as service

router = APIRouter(prefix="/me", tags=["mypage"])
Limit = Annotated[int, Query(ge=1, le=30)]
Cursor = Annotated[int | None, Query(gt=0)]


def private(response):
    response.headers["Cache-Control"] = "private, no-store"


@router.get("/profile")
def profile(user: CurrentUser, db: DbSession, response: Response) -> ProfileOut:
    private(response)
    return service.get_profile(db, user)


@router.put("/profile")
def save_profile(
    body: ProfileWrite, user: CurrentUser, db: DbSession, response: Response
) -> ProfileOut:
    private(response)
    return service.save_profile(db, user, body)


@router.get("/collections")
def collections(
    user: CurrentUser, db: DbSession, response: Response
) -> list[CollectionOut]:
    private(response)
    return service.collections(db, user.id)


@router.post("/collections", status_code=201)
def create(
    body: CollectionWrite, user: CurrentUser, db: DbSession, response: Response
) -> CollectionOut:
    private(response)
    return service.save_collection(db, user.id, body)


@router.put("/collections/{collection_id}")
def update(
    collection_id: int,
    body: CollectionWrite,
    user: CurrentUser,
    db: DbSession,
    response: Response,
) -> CollectionOut:
    private(response)
    return service.save_collection(db, user.id, body, collection_id)


@router.delete("/collections/{collection_id}", status_code=204)
def remove(collection_id: int, user: CurrentUser, db: DbSession):
    service.delete_collection(db, user.id, collection_id)


@router.get("/collections/{collection_id}/items")
def artworks(
    collection_id: int,
    user: CurrentUser,
    db: DbSession,
    response: Response,
    limit: Limit = 12,
    before_id: Cursor = None,
) -> ArtworkPage:
    private(response)
    return service.collection_page(db, user.id, collection_id, limit, before_id)


@router.put("/collections/{collection_id}/items/{artwork_id}")
def add(
    collection_id: int,
    artwork_id: int,
    user: CurrentUser,
    db: DbSession,
    response: Response,
) -> CollectionOut:
    private(response)
    return service.add_artwork(db, user.id, collection_id, artwork_id)


@router.delete("/collections/{collection_id}/items/{artwork_id}", status_code=204)
def remove_art(collection_id: int, artwork_id: int, user: CurrentUser, db: DbSession):
    service.remove_artwork(db, user.id, collection_id, artwork_id)


@router.get("/critiques")
def critiques(
    user: CurrentUser,
    db: DbSession,
    response: Response,
    limit: Limit = 12,
    before_id: Cursor = None,
) -> CritiquePage:
    private(response)
    return service.critiques(db, user.id, limit, before_id)


@router.get("/activity")
def activity(
    user: CurrentUser,
    db: DbSession,
    response: Response,
    limit: Limit = 20,
    offset: Annotated[int, Query(ge=0, le=10000)] = 0,
) -> list[ActivityOut]:
    private(response)
    return service.activity(db, user.id, limit, offset)


@router.get("/taste")
def taste(user: CurrentUser, db: DbSession, response: Response) -> TasteOut:
    private(response)
    return service.get_taste(db, user.id)


@router.post("/taste")
def generate_taste(user: CurrentUser, db: DbSession, response: Response) -> TasteOut:
    private(response)
    return collection_assistant.make_taste(db, user.id)


@router.post("/collections/chat")
def chat(
    body: CollectionChatRequest, user: CurrentUser, db: DbSession, response: Response
) -> CollectionChatReply:
    private(response)
    return collection_assistant.propose(db, user.id, body)
