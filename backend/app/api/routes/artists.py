"""작가 목록·상세."""

from fastapi import APIRouter

from app.api.stub import not_implemented
from app.schemas.catalog import ArtistCard, ArtistDetail

router = APIRouter(tags=["catalog"])


@router.get("/artists")
def list_artists(movement_id: int | None = None) -> list[ArtistCard]:
    """작가 목록. `movement_id`로 사조별 필터."""
    not_implemented()


@router.get("/artists/{artist_id}")
def get_artist(artist_id: int) -> ArtistDetail:
    """작가 상세."""
    not_implemented()
