"""User likes, follows, and daily artwork view aggregates."""

from __future__ import annotations

from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, Index, Integer, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import TABLE_OPTIONS, Base

if TYPE_CHECKING:
    from app.models.catalog import Artist, Artwork
    from app.models.user import User


class ArtworkLike(Base):
    __tablename__ = "artwork_likes"
    __table_args__ = (
        Index("idx_artwork_likes_user_created", "user_id", "created_at"),
        Index("idx_artwork_likes_artwork", "artwork_id"),
        TABLE_OPTIONS,
    )

    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", name="fk_artwork_likes_user", ondelete="CASCADE"),
        primary_key=True,
    )
    artwork_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "artworks.id",
            name="fk_artwork_likes_artwork",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    user: Mapped[User] = relationship(back_populates="artwork_likes")
    artwork: Mapped[Artwork] = relationship(back_populates="likes")


class ArtistFollow(Base):
    __tablename__ = "artist_follows"
    __table_args__ = (
        Index("idx_artist_follows_artist", "artist_id"),
        TABLE_OPTIONS,
    )

    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", name="fk_artist_follows_user", ondelete="CASCADE"),
        primary_key=True,
    )
    artist_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("artists.id", name="fk_artist_follows_artist", ondelete="CASCADE"),
        primary_key=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    user: Mapped[User] = relationship(back_populates="artist_follows")
    artist: Mapped[Artist] = relationship(back_populates="followers")


class ArtworkView(Base):
    __tablename__ = "artwork_views"
    __table_args__ = (
        Index("idx_artwork_views_artwork", "artwork_id"),
        TABLE_OPTIONS,
    )

    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", name="fk_artwork_views_user", ondelete="CASCADE"),
        primary_key=True,
    )
    viewed_on: Mapped[date] = mapped_column(Date, primary_key=True)
    artwork_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "artworks.id",
            name="fk_artwork_views_artwork",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    view_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default=text("1"),
    )
    first_viewed_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    last_viewed_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    user: Mapped[User] = relationship(back_populates="artwork_views")
    artwork: Mapped[Artwork] = relationship(back_populates="views")


class UserFollow(Base):
    """One member following another member's public impressions."""

    __tablename__ = "user_follows"
    __table_args__ = (
        Index("idx_user_follows_followee", "followee_id"),
        TABLE_OPTIONS,
    )

    follower_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", name="fk_user_follows_follower", ondelete="CASCADE"),
        primary_key=True,
    )
    followee_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", name="fk_user_follows_followee", ondelete="CASCADE"),
        primary_key=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
