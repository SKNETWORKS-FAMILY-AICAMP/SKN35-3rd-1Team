"""작품 좋아요. 모두 로그인 필요."""

from fastapi import APIRouter, status

from app.api.stub import not_implemented
from app.core.auth import CurrentUser
from app.schemas.catalog import ArtworkCard

router = APIRouter(tags=["likes"])


@router.put("/artworks/{artwork_id}/like", status_code=status.HTTP_204_NO_CONTENT)
def like_artwork(artwork_id: int, user: CurrentUser) -> None:
    """좋아요. 여러 번 호출해도 결과가 같다."""
    not_implemented()


@router.delete("/artworks/{artwork_id}/like", status_code=status.HTTP_204_NO_CONTENT)
def unlike_artwork(artwork_id: int, user: CurrentUser) -> None:
    """좋아요 취소. 좋아요가 없어도 204."""
    not_implemented()


@router.get("/me/likes")
def list_my_likes(user: CurrentUser) -> list[ArtworkCard]:
    """내가 좋아요한 작품 (최근순)."""
    not_implemented()
