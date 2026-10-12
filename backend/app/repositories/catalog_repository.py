"""Reads for movements, artists and artworks.

Artwork queries return ``(Artwork, artist_name)`` rows so cards can show the
artist without a second request.
"""

from sqlalchemy import Select, select
from sqlalchemy.orm import Session

from app.models import Artist, ArtMovement, Artwork

ArtworkRow = tuple[Artwork, str]


def list_movements(db: Session) -> list[ArtMovement]:
    return list(db.scalars(select(ArtMovement).order_by(ArtMovement.id)))


def list_artists(db: Session, *, movement_id: int | None = None) -> list[Artist]:
    stmt = select(Artist).order_by(Artist.birth_year, Artist.id)
    if movement_id is not None:
        stmt = stmt.where(Artist.movement_id == movement_id)
    return list(db.scalars(stmt))


def get_artist(db: Session, artist_id: int) -> Artist | None:
    return db.get(Artist, artist_id)


def _artworks() -> Select[ArtworkRow]:
    return select(Artwork, Artist.name).join(Artist, Artist.id == Artwork.artist_id)


def list_artworks(
    db: Session, *, artist_id: int | None = None, movement_id: int | None = None
) -> list[ArtworkRow]:
    stmt = _artworks().order_by(Artwork.artist_id, Artwork.year_start, Artwork.id)
    if artist_id is not None:
        stmt = stmt.where(Artwork.artist_id == artist_id)
    if movement_id is not None:
        stmt = stmt.where(Artwork.movement_id == movement_id)
    return [tuple(row) for row in db.execute(stmt)]


def get_artwork(db: Session, artwork_id: int) -> ArtworkRow | None:
    row = db.execute(_artworks().where(Artwork.id == artwork_id)).first()
    return tuple(row) if row else None


def get_artworks(db: Session, artwork_ids: list[int]) -> dict[int, ArtworkRow]:
    if not artwork_ids:
        return {}
    rows = db.execute(_artworks().where(Artwork.id.in_(artwork_ids)))
    return {artwork.id: (artwork, name) for artwork, name in rows}


def get_artists(db: Session, artist_ids: list[int]) -> dict[int, Artist]:
    if not artist_ids:
        return {}
    return {
        a.id: a for a in db.scalars(select(Artist).where(Artist.id.in_(artist_ids)))
    }


def artwork_exists(db: Session, artwork_id: int) -> bool:
    return db.scalar(select(Artwork.id).where(Artwork.id == artwork_id)) is not None


def artist_exists(db: Session, artist_id: int) -> bool:
    return db.scalar(select(Artist.id).where(Artist.id == artist_id)) is not None
