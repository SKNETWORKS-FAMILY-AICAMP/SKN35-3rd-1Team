"""Member profiles, member follows and follow-list visibility."""

from fastapi import HTTPException
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import User, UserFollow, UserPreference
from app.schemas.diary import DiaryFeed
from app.schemas.social import MemberCard, MemberProfile, SocialSettings
from app.services import diary_service

LIST_LIMIT = 200


def member(db: Session, public_id: str) -> User:
    row = db.scalar(select(User).where(User.public_id == public_id))
    if row is None:
        raise HTTPException(404, "이용자를 찾을 수 없어요.")
    return row


def _count(db: Session, column, user_id: int) -> int:
    return db.scalar(
        select(func.count()).select_from(UserFollow).where(column == user_id)
    )


def profile(db: Session, target: User, viewer: User | None) -> MemberProfile:
    me = viewer is not None and viewer.id == target.id
    visible = me or target.follow_list_public
    pref = db.get(UserPreference, target.id)
    return MemberProfile(
        id=target.public_id,
        nickname=target.nickname,
        intro=pref.taste_summary if pref else None,
        follower_count=_count(db, UserFollow.followee_id, target.id)
        if visible
        else None,
        following_count=_count(db, UserFollow.follower_id, target.id)
        if visible
        else None,
        follow_list_public=target.follow_list_public,
        is_following=viewer is not None
        and not me
        and db.get(UserFollow, (viewer.id, target.id)) is not None,
        is_me=me,
    )


def public_diary(db: Session, target: User, *, limit: int, before_id: int | None) -> DiaryFeed:
    return diary_service.get_feed(
        db, limit=limit, before_id=before_id, artwork_id=None, author_id=target.id
    )


def follow(db: Session, viewer: User, target: User, enable: bool) -> None:
    if viewer.id == target.id:
        raise HTTPException(400, "자기 자신은 팔로우할 수 없어요.")
    if not enable:
        db.execute(
            delete(UserFollow).where(
                UserFollow.follower_id == viewer.id,
                UserFollow.followee_id == target.id,
            )
        )
        db.commit()
        return
    if db.get(UserFollow, (viewer.id, target.id)) is not None:
        return
    db.add(UserFollow(follower_id=viewer.id, followee_id=target.id))
    try:
        db.commit()
    except IntegrityError:
        # A concurrent identical follow already created the row.
        db.rollback()


def members(
    db: Session, target: User, viewer: User | None, *, followers: bool
) -> list[MemberCard]:
    if not target.follow_list_public and (viewer is None or viewer.id != target.id):
        raise HTTPException(403, "팔로우 목록을 공개하지 않은 이용자예요.")
    other, own = (
        (UserFollow.follower_id, UserFollow.followee_id)
        if followers
        else (UserFollow.followee_id, UserFollow.follower_id)
    )
    rows = db.scalars(
        select(User)
        .join(UserFollow, other == User.id)
        .where(own == target.id)
        .order_by(UserFollow.created_at.desc(), User.id.desc())
        .limit(LIST_LIMIT)
    ).all()
    return [MemberCard(id=u.public_id, nickname=u.nickname) for u in rows]


def save_settings(db: Session, user: User, body: SocialSettings) -> MemberProfile:
    user.follow_list_public = body.follow_list_public
    db.commit()
    return profile(db, user, user)
