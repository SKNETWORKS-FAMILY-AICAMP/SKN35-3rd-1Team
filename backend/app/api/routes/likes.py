"""작품 좋아요. 모두 로그인 필요."""

from fastapi import APIRouter, status

from app.core.auth import CurrentUser
from app.db.session import DbSession
from app.schemas.catalog import ArtworkCard
from app.services import like_service

router = APIRouter(tags=["likes"])


@router.put("/artworks/{artwork_id}/like", status_code=status.HTTP_204_NO_CONTENT)
def like_artwork(artwork_id: int, user: CurrentUser, db: DbSession) -> None:
    """좋아요. 여러 번 호출해도 결과가 같다. 없는 작품이면 404."""
    like_service.like(db, user_id=user.id, artwork_id=artwork_id)


@router.delete("/artworks/{artwork_id}/like", status_code=status.HTTP_204_NO_CONTENT)
def unlike_artwork(artwork_id: int, user: CurrentUser, db: DbSession) -> None:
    """좋아요 취소. 좋아요가 없어도 204."""
    like_service.unlike(db, user_id=user.id, artwork_id=artwork_id)


@router.get("/me/likes")
def list_my_likes(user: CurrentUser, db: DbSession) -> list[ArtworkCard]:
    """내가 좋아요한 작품 (최근순)."""
    return like_service.list_liked(db, user_id=user.id)
