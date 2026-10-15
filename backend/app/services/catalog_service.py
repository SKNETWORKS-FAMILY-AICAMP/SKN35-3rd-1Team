"""Movement, artist and artwork lists and details."""

from typing import Any

from sqlalchemy.orm import Session

from app.core.exceptions import NotFoundError
from app.models import Artwork
from app.repositories import catalog_repository
from app.schemas.catalog import (
    ArtistCard,
    ArtistDetail,
    ArtworkCard,
    ArtworkDetail,
    Movement,
)


def to_artwork_card[CardT: ArtworkCard](
    artwork: Artwork, artist_name: str, model: type[CardT] = ArtworkCard, **extra: Any
) -> CardT:
    """Build an artwork card (or a subclass) from a row; ``extra`` fills subclass fields."""

    columns = {c.key: getattr(artwork, c.key) for c in Artwork.__table__.columns}
    return model.model_validate({**columns, "artist_name": artist_name, **extra})


def list_movements(db: Session) -> list[Movement]:
    return [Movement.model_validate(m) for m in catalog_repository.list_movements(db)]


def list_artists(db: Session, *, movement_id: int | None = None) -> list[ArtistCard]:
    artists = catalog_repository.list_artists(db, movement_id=movement_id)
    return [ArtistCard.model_validate(a) for a in artists]


def get_artist(db: Session, artist_id: int) -> ArtistDetail:
    artist = catalog_repository.get_artist(db, artist_id)
    if artist is None:
        raise NotFoundError("작가를 찾을 수 없습니다.")
    return ArtistDetail.model_validate(artist)


def list_artworks(
    db: Session, *, artist_id: int | None = None, movement_id: int | None = None
) -> list[ArtworkCard]:
    rows = catalog_repository.list_artworks(
        db, artist_id=artist_id, movement_id=movement_id
    )
    return [to_artwork_card(artwork, name) for artwork, name in rows]


def get_artwork(db: Session, artwork_id: int) -> ArtworkDetail:
    row = catalog_repository.get_artwork(db, artwork_id)
    if row is None:
        raise NotFoundError("작품을 찾을 수 없습니다.")
    artwork, name = row
    return to_artwork_card(artwork, name, ArtworkDetail)


def ensure_artwork(db: Session, artwork_id: int) -> None:
    if not catalog_repository.artwork_exists(db, artwork_id):
        raise NotFoundError("작품을 찾을 수 없습니다.")


def ensure_artist(db: Session, artist_id: int) -> None:
    if not catalog_repository.artist_exists(db, artist_id):
        raise NotFoundError("작가를 찾을 수 없습니다.")
