"""작가 팔로우. 모두 로그인 필요."""

from fastapi import APIRouter, status

from app.api.stub import not_implemented
from app.core.auth import CurrentUser
from app.schemas.catalog import ArtistCard

router = APIRouter(tags=["follows"])


@router.put("/artists/{artist_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
def follow_artist(artist_id: int, user: CurrentUser) -> None:
    """팔로우. 여러 번 호출해도 결과가 같다."""
    not_implemented()


@router.delete("/artists/{artist_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
def unfollow_artist(artist_id: int, user: CurrentUser) -> None:
    """팔로우 취소. 팔로우가 없어도 204."""
    not_implemented()


@router.get("/me/follows")
def list_my_follows(user: CurrentUser) -> list[ArtistCard]:
    """내가 팔로우한 작가."""
    not_implemented()
