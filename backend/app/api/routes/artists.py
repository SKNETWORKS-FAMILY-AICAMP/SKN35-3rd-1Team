"""작가 목록·상세."""

from fastapi import APIRouter

from app.db.session import DbSession
from app.schemas.catalog import ArtistCard, ArtistDetail
from app.services import catalog_service

router = APIRouter(tags=["catalog"])


@router.get("/artists")
def list_artists(db: DbSession, movement_id: int | None = None) -> list[ArtistCard]:
    """작가 목록. `movement_id`로 사조별 필터."""
    return catalog_service.list_artists(db, movement_id=movement_id)


@router.get("/artists/{artist_id}")
def get_artist(artist_id: int, db: DbSession) -> ArtistDetail:
    """작가 상세. 없으면 404."""
    return catalog_service.get_artist(db, artist_id)
