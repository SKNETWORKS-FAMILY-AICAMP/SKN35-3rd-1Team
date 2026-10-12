"""Artwork likes. Like and unlike are idempotent."""

from sqlalchemy.orm import Session

from app.repositories import activity_repository
from app.schemas.catalog import ArtworkCard
from app.services import catalog_service


def like(db: Session, *, user_id: int, artwork_id: int) -> None:
    catalog_service.ensure_artwork(db, artwork_id)
    activity_repository.add_like(db, user_id=user_id, artwork_id=artwork_id)
    db.commit()


def unlike(db: Session, *, user_id: int, artwork_id: int) -> None:
    """No existence check: removing a like that is not there is still a success."""

    activity_repository.remove_like(db, user_id=user_id, artwork_id=artwork_id)
    db.commit()


def list_liked(db: Session, *, user_id: int) -> list[ArtworkCard]:
    rows = activity_repository.list_liked_artworks(db, user_id=user_id)
    return [catalog_service.to_artwork_card(artwork, name) for artwork, name in rows]
