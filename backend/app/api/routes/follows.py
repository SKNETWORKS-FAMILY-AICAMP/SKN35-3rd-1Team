"""작가 팔로우. 모두 로그인 필요."""

from fastapi import APIRouter, status

from app.core.auth import CurrentUser
from app.db.session import DbSession
from app.schemas.catalog import ArtistCard
from app.services import follow_service

router = APIRouter(tags=["follows"])


@router.put("/artists/{artist_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
def follow_artist(artist_id: int, user: CurrentUser, db: DbSession) -> None:
    """팔로우. 여러 번 호출해도 결과가 같다. 없는 작가면 404."""
    follow_service.follow(db, user_id=user.id, artist_id=artist_id)


@router.delete("/artists/{artist_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
def unfollow_artist(artist_id: int, user: CurrentUser, db: DbSession) -> None:
    """팔로우 취소. 팔로우가 없어도 204."""
    follow_service.unfollow(db, user_id=user.id, artist_id=artist_id)


@router.get("/me/follows")
def list_my_follows(user: CurrentUser, db: DbSession) -> list[ArtistCard]:
    """내가 팔로우한 작가 (최근순)."""
    return follow_service.list_followed(db, user_id=user.id)
