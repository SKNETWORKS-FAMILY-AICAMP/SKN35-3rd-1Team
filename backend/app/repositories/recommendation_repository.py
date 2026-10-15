"""Candidates for recommendations. Queries D–G in ``docs/db/02_queries.sql``.

Vector SQL (``VEC_COSINE_DISTANCE``) is TiDB-only and lives only here. Results
carry ids and distances, never the embedding column. Picking (one per artist,
fallbacks) is the service's job.

Recommendations only return artworks that have an image, so cards never show
an empty frame.
"""

from typing import NamedTuple

from sqlalchemy import ColumnElement, bindparam, func, select, text
from sqlalchemy.orm import Session

from app.models import (
    Artist,
    ArtistFollow,
    Artwork,
    ArtworkEmbedding,
    ArtworkLike,
    ArtworkView,
)

ArtworkRow = tuple[Artwork, str]

_HAS_IMAGE = "a.image_url IS NOT NULL AND a.image_url <> ''"


def _has_image() -> ColumnElement[bool]:
    return Artwork.image_url.is_not(None) & (Artwork.image_url != "")


class Candidate(NamedTuple):
    artwork_id: int
    artist_id: int
    # The seed this candidate is closest to; recommendation reasons name it.
    seed_id: int
    distance: float


def has_embedding(db: Session, artwork_id: int) -> bool:
    stmt = select(ArtworkEmbedding.artwork_id).where(
        ArtworkEmbedding.artwork_id == artwork_id
    )
    return db.scalar(stmt) is not None


_SIMILAR = text(
    f"""
    SELECT knn.artwork_id, knn.distance
    FROM (
        SELECT e.artwork_id,
               VEC_COSINE_DISTANCE(
                   e.embedding,
                   (SELECT s.embedding FROM artwork_embeddings AS s
                    WHERE s.artwork_id = :artwork_id)
               ) AS distance
        FROM artwork_embeddings AS e
        ORDER BY distance
        LIMIT :knn
    ) AS knn
    JOIN artworks AS a ON a.id = knn.artwork_id
    WHERE knn.artwork_id <> :artwork_id
      AND {_HAS_IMAGE}
    ORDER BY knn.distance, knn.artwork_id
    LIMIT :limit
    """
)


def similar_artwork_ids(db: Session, *, artwork_id: int, limit: int) -> list[int]:
    """Nearest artworks to one artwork, closest first. Empty if it has no vector."""

    if not has_embedding(db, artwork_id):
        return []
    # The pure KNN inner query also returns the artwork itself and may hit
    # imageless artworks; take a few extra.
    rows = db.execute(
        _SIMILAR, {"artwork_id": artwork_id, "knn": limit + 4, "limit": limit}
    )
    return [artwork_id for artwork_id, _ in rows]


_CANDIDATES = text(
    f"""
    SELECT artwork_id, artist_id, seed_id, distance
    FROM (
        SELECT cand.artwork_id,
               a.artist_id,
               seed.artwork_id AS seed_id,
               VEC_COSINE_DISTANCE(cand.embedding, seed.embedding) AS distance,
               ROW_NUMBER() OVER (
                   PARTITION BY cand.artwork_id
                   ORDER BY VEC_COSINE_DISTANCE(cand.embedding, seed.embedding),
                            seed.artwork_id
               ) AS nearest
        FROM artwork_embeddings AS seed
        JOIN artwork_embeddings AS cand ON cand.artwork_id <> seed.artwork_id
        JOIN artworks AS a ON a.id = cand.artwork_id
        WHERE seed.artwork_id IN :seed_ids
          AND cand.artwork_id NOT IN :exclude_ids
          AND {_HAS_IMAGE}
    ) AS ranked
    WHERE nearest = 1
    ORDER BY distance, artwork_id
    LIMIT :limit
    """
).bindparams(
    bindparam("seed_ids", expanding=True), bindparam("exclude_ids", expanding=True)
)


def candidates(
    db: Session, *, seed_ids: list[int], exclude_ids: set[int], limit: int = 30
) -> list[Candidate]:
    """Artworks closest to any seed (min distance over seeds), closest first.

    Seeds themselves are always excluded.
    """

    if not seed_ids:
        return []
    exclude = sorted(set(exclude_ids) | set(seed_ids))
    rows = db.execute(
        _CANDIDATES, {"seed_ids": seed_ids, "exclude_ids": exclude, "limit": limit}
    )
    return [Candidate(int(a), int(r), int(s), float(d)) for a, r, s, d in rows]


# --- seeds and fallbacks ----------------------------------------------------


def liked_artwork_ids(db: Session, *, user_id: int) -> list[int]:
    """Most recent first."""

    stmt = (
        select(ArtworkLike.artwork_id)
        .where(ArtworkLike.user_id == user_id)
        .order_by(ArtworkLike.created_at.desc(), ArtworkLike.artwork_id.desc())
    )
    return list(db.scalars(stmt))


def recent_viewed_artwork_ids(db: Session, *, user_id: int, limit: int) -> list[int]:
    last_viewed = func.max(ArtworkView.last_viewed_at)
    stmt = (
        select(ArtworkView.artwork_id)
        .where(ArtworkView.user_id == user_id)
        .group_by(ArtworkView.artwork_id)
        .order_by(last_viewed.desc(), ArtworkView.artwork_id.desc())
        .limit(limit)
    )
    return list(db.scalars(stmt))


def followed_artist_ids(db: Session, *, user_id: int) -> list[int]:
    """Most recent first."""

    stmt = (
        select(ArtistFollow.artist_id)
        .where(ArtistFollow.user_id == user_id)
        .order_by(ArtistFollow.created_at.desc(), ArtistFollow.artist_id.desc())
    )
    return list(db.scalars(stmt))


def artworks_by_artists(db: Session, *, artist_ids: list[int]) -> list[ArtworkRow]:
    """Curated first, then by year."""

    if not artist_ids:
        return []
    stmt = (
        select(Artwork, Artist.name)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(Artwork.artist_id.in_(artist_ids), _has_image())
        .order_by(Artwork.is_featured.desc(), Artwork.year_start, Artwork.id)
    )
    return [tuple(row) for row in db.execute(stmt)]


def fallback_artworks(db: Session) -> list[ArtworkRow]:
    """Every artwork with an image, by id. The service shuffles them (curated first)."""

    stmt = (
        select(Artwork, Artist.name)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(_has_image())
        .order_by(Artwork.id)
    )
    return [tuple(row) for row in db.execute(stmt)]
