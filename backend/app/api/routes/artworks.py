"""작품 목록·상세."""

from fastapi import APIRouter

from app.db.session import DbSession
from app.schemas.catalog import ArtworkCard, ArtworkDetail
from app.services import catalog_service

router = APIRouter(tags=["catalog"])


@router.get("/artworks")
def list_artworks(
    db: DbSession, artist_id: int | None = None, movement_id: int | None = None
) -> list[ArtworkCard]:
    """작품 목록. `artist_id`, `movement_id`로 필터."""
    return catalog_service.list_artworks(
        db, artist_id=artist_id, movement_id=movement_id
    )


@router.get("/artworks/{artwork_id}")
def get_artwork(artwork_id: int, db: DbSession) -> ArtworkDetail:
    """작품 상세. 없으면 404."""
    return catalog_service.get_artwork(db, artwork_id)
