"""Artist follows. Follow and unfollow are idempotent."""

from sqlalchemy.orm import Session

from app.repositories import activity_repository
from app.schemas.catalog import ArtistCard
from app.services import catalog_service


def follow(db: Session, *, user_id: int, artist_id: int) -> None:
    catalog_service.ensure_artist(db, artist_id)
    activity_repository.add_follow(db, user_id=user_id, artist_id=artist_id)
    db.commit()


def unfollow(db: Session, *, user_id: int, artist_id: int) -> None:
    """No existence check: removing a follow that is not there is still a success."""

    activity_repository.remove_follow(db, user_id=user_id, artist_id=artist_id)
    db.commit()


def list_followed(db: Session, *, user_id: int) -> list[ArtistCard]:
    artists = activity_repository.list_followed_artists(db, user_id=user_id)
    return [ArtistCard.model_validate(a) for a in artists]
