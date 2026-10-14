"""Public member profiles and member-to-member follows.

Paths take the opaque ``public_id``; the follower always comes from the verified token.
"""

from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.core.auth import CurrentUser, OptionalUser
from app.db.session import DbSession
from app.schemas.diary import DiaryFeed
from app.schemas.social import MemberCard, MemberProfile, SocialSettings
from app.services import social_service as service

router = APIRouter(tags=["social"])


def no_store(response: Response) -> None:
    response.headers["Cache-Control"] = "private, no-store"


@router.get("/me/social")
def my_social(user: CurrentUser, db: DbSession, response: Response) -> MemberProfile:
    no_store(response)
    return service.profile(db, user, user)


@router.put("/me/social")
def save_social(
    body: SocialSettings, user: CurrentUser, db: DbSession, response: Response
) -> MemberProfile:
    no_store(response)
    return service.save_settings(db, user, body)


@router.get("/users/{public_id}")
def member_profile(
    public_id: str, user: OptionalUser, db: DbSession, response: Response
) -> MemberProfile:
    no_store(response)
    return service.profile(db, service.member(db, public_id), user)


@router.get("/users/{public_id}/diary")
def member_diary(
    public_id: str,
    db: DbSession,
    response: Response,
    limit: Annotated[int, Query(ge=1, le=30)] = 12,
    before_id: Annotated[int | None, Query(gt=0)] = None,
) -> DiaryFeed:
    no_store(response)
    return service.public_diary(
        db, service.member(db, public_id), limit=limit, before_id=before_id
    )


@router.put("/users/{public_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
def follow_member(public_id: str, user: CurrentUser, db: DbSession) -> None:
    service.follow(db, user, service.member(db, public_id), True)


@router.delete("/users/{public_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
def unfollow_member(public_id: str, user: CurrentUser, db: DbSession) -> None:
    service.follow(db, user, service.member(db, public_id), False)


@router.get("/users/{public_id}/followers")
def member_followers(
    public_id: str, user: OptionalUser, db: DbSession, response: Response
) -> list[MemberCard]:
    no_store(response)
    return service.members(db, service.member(db, public_id), user, followers=True)


@router.get("/users/{public_id}/following")
def member_following(
    public_id: str, user: OptionalUser, db: DbSession, response: Response
) -> list[MemberCard]:
    no_store(response)
    return service.members(db, service.member(db, public_id), user, followers=False)
