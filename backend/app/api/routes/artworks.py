"""작품 목록·상세."""

from fastapi import APIRouter

from app.api.stub import not_implemented
from app.schemas.catalog import ArtworkCard, ArtworkDetail

router = APIRouter(tags=["catalog"])


@router.get("/artworks")
def list_artworks(
    artist_id: int | None = None, movement_id: int | None = None
) -> list[ArtworkCard]:
    """작품 목록. `artist_id`, `movement_id`로 필터."""
    not_implemented()


@router.get("/artworks/{artwork_id}")
def get_artwork(artwork_id: int) -> ArtworkDetail:
    """작품 상세."""
    not_implemented()
