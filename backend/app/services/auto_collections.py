"""Collections computed from the owner's view history, like auto playlists.

They are not stored: each request reads ``artwork_views`` again, so they follow
what the member keeps looking at. The chat assistant and MCP tools use the same
functions to fill a new saved collection, so the model never picks artworks.

Keys: ``recent``, ``frequent``, ``artist-{artist_id}``, ``month-YYYY-MM``.
"""

import re
from dataclasses import dataclass

from fastapi import HTTPException
from sqlalchemy import func, select

from app.core.collection_limits import MAX_COLLECTION_ARTWORKS
from app.core.timeutil import local_date, month_range, utcnow
from app.models import Artist, Artwork, ArtworkView
from app.schemas.mypage import AutoCollectionOut
from app.services import catalog_service

MAX_ITEMS = MAX_COLLECTION_ARTWORKS
TOP_ARTISTS = 3  # artist collections shown on the collection page
MIN_ARTIST_WORKS = 2  # an artist collection needs at least this many viewed works
MIN_FREQUENT_VIEWS = 2  # "자주 본 작품" only lists works viewed this often
_KEY = re.compile(r"^(recent|frequent|artist-(\d+)|month-(\d{4})-(\d{2}))$")


@dataclass(frozen=True)
class Basis:
    kind: str  # recent | frequent | artist | month
    artist_id: int | None = None
    month: str | None = None  # YYYY-MM


def _per_artwork(user_id: int, basis: Basis):
    last = func.max(ArtworkView.last_viewed_at).label("last")
    total = func.sum(ArtworkView.view_count).label("total")
    q = (
        select(ArtworkView.artwork_id, last, total)
        .where(ArtworkView.user_id == user_id)
        .group_by(ArtworkView.artwork_id)
    )
    if basis.kind == "month":
        start, end = month_range(basis.month)
        q = q.where(ArtworkView.viewed_on >= start, ArtworkView.viewed_on < end)
    return q.subquery(), last, total


def artworks(db, user_id: int, basis: Basis, limit: int = MAX_ITEMS):
    """Viewed artworks for one basis, the cover (first item) first."""
    views, _, _ = _per_artwork(user_id, basis)
    q = (
        select(Artwork, Artist.name)
        .join(views, views.c.artwork_id == Artwork.id)
        .join(Artist, Artist.id == Artwork.artist_id)
    )
    if basis.kind == "frequent":
        q = q.where(views.c.total >= MIN_FREQUENT_VIEWS).order_by(
            views.c.total.desc(), views.c.last.desc()
        )
    else:
        q = q.order_by(views.c.last.desc())
    if basis.kind == "artist":
        q = q.where(Artwork.artist_id == basis.artist_id)
    rows = db.execute(q.order_by(Artwork.id).limit(min(limit, MAX_ITEMS))).all()
    return [catalog_service.to_artwork_card(a, name) for a, name in rows]


def top_artists(db, user_id: int, n: int = TOP_ARTISTS) -> list[tuple[int, str]]:
    """Artists with the most distinct viewed artworks."""
    count = func.count(func.distinct(ArtworkView.artwork_id))
    rows = db.execute(
        select(Artist.id, Artist.name)
        .join(Artwork, Artwork.artist_id == Artist.id)
        .join(ArtworkView, ArtworkView.artwork_id == Artwork.id)
        .where(ArtworkView.user_id == user_id)
        .group_by(Artist.id, Artist.name)
        .having(count >= MIN_ARTIST_WORKS)
        .order_by(count.desc(), func.max(ArtworkView.last_viewed_at).desc())
        .limit(n)
    ).all()
    return [(i, name) for i, name in rows]


def resolve(
    db,
    kind: str,
    artist_query: str | None = None,
    month: int | None = None,
    year: int | None = None,
) -> tuple[Basis, str | None]:
    """Turn requested criteria into a basis and artist name.

    Raises ValueError with a message for the member when the criteria are unclear.
    """
    from app.services.mypage_service import find_artists

    if kind == "artist":
        artists = find_artists(db, artist_query or "")
        if len(artists) != 1:
            raise ValueError(
                f"‘{artist_query}’ 작가를 찾지 못했어요."
                if artist_query and not artists
                else "어느 작가인지 정확한 이름을 알려주세요."
            )
        ((artist_id, artist_name),) = artists
        return Basis("artist", artist_id=artist_id), artist_name
    if kind == "month":
        if month is None or not 1 <= month <= 12:
            raise ValueError("몇 월에 본 작품을 모을지 알려주세요.")
        today = local_date(utcnow())
        # A month without a year means the latest one that has started.
        year = year or (today.year if month <= today.month else today.year - 1)
        return Basis("month", month=f"{year}-{month:02d}"), None
    if kind in ("recent", "frequent"):
        return Basis(kind), None
    raise ValueError("최근 본 작품, 자주 본 작품, 작가, 월 중에서 골라 주세요.")


def name_for(basis: Basis, artist_name: str | None = None) -> str:
    if basis.kind == "recent":
        return "최근 본 작품"
    if basis.kind == "frequent":
        return "자주 본 작품"
    if basis.kind == "artist":
        return f"{artist_name} 모음"
    year, month = map(int, basis.month.split("-"))
    this_year = local_date(utcnow()).year
    return f"{month}월의 감상" if year == this_year else f"{year}년 {month}월의 감상"


DESCRIPTIONS = {
    "recent": "최근에 감상한 순서대로 모았어요.",
    "frequent": "여러 번 다시 본 작품이에요.",
    "artist": "이 작가의 작품 중 감상한 그림이에요.",
    "month": "이 달에 감상한 작품이에요.",
}


def key_for(basis: Basis) -> str:
    if basis.kind == "artist":
        return f"artist-{basis.artist_id}"
    if basis.kind == "month":
        return f"month-{basis.month}"
    return basis.kind


def parse_key(key: str) -> Basis:
    m = _KEY.match(key)
    if m is None:
        raise HTTPException(404, "자동 컬렉션을 찾을 수 없어요.")
    if m.group(2):
        return Basis("artist", artist_id=int(m.group(2)))
    if m.group(3):
        if not 1 <= int(m.group(4)) <= 12:
            raise HTTPException(404, "자동 컬렉션을 찾을 수 없어요.")
        return Basis("month", month=f"{m.group(3)}-{m.group(4)}")
    return Basis(key)


def _summary(db, user_id, basis: Basis, artist_name=None) -> AutoCollectionOut | None:
    works = artworks(db, user_id, basis)
    if not works:
        return None
    return AutoCollectionOut(
        key=key_for(basis),
        name=name_for(basis, artist_name),
        description=DESCRIPTIONS[basis.kind],
        artwork_count=len(works),
        cover=works[0],
    )


def collections(db, user_id: int) -> list[AutoCollectionOut]:
    """Auto collections that currently have artworks, in display order."""
    this_month = local_date(utcnow()).strftime("%Y-%m")
    bases = [
        (Basis("recent"), None),
        (Basis("frequent"), None),
        *[(Basis("artist", artist_id=i), name) for i, name in top_artists(db, user_id)],
        (Basis("month", month=this_month), None),
    ]
    return [s for b, name in bases if (s := _summary(db, user_id, b, name))]


def collection(db, user_id: int, key: str) -> tuple[AutoCollectionOut, list]:
    basis = parse_key(key)
    artist_name = None
    if basis.kind == "artist":
        artist_name = db.scalar(select(Artist.name).where(Artist.id == basis.artist_id))
        if artist_name is None:
            raise HTTPException(404, "자동 컬렉션을 찾을 수 없어요.")
    works = artworks(db, user_id, basis)
    summary = AutoCollectionOut(
        key=key_for(basis),
        name=name_for(basis, artist_name),
        description=DESCRIPTIONS[basis.kind],
        artwork_count=len(works),
        cover=works[0] if works else None,
    )
    return summary, works
