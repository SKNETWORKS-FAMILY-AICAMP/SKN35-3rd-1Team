"""Reads and writes for users."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import User


def get_or_create_by_firebase_uid(
    db: Session, *, firebase_uid: str, email: str, nickname: str
) -> User:
    """Return the user for ``firebase_uid``, creating it on first sight.

    Two first requests can race; the UNIQUE key makes the loser re-read.
    """

    user = db.scalar(select(User).where(User.firebase_uid == firebase_uid))
    if user is not None:
        return user
    user = User(firebase_uid=firebase_uid, email=email, nickname=nickname)
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        return db.scalar(select(User).where(User.firebase_uid == firebase_uid))
    return user
