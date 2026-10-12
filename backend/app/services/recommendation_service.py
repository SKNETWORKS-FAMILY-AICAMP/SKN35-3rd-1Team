"""Similar artworks and personal recommendations (docs/db/db-design.md, section 5).

Seeds are the 10 most recent likes. With no likes, the 5 most recently viewed
artworks are the seeds instead. Candidates come from the repository already
ranked by distance; this module only picks and explains them. Personal lists
are always filled to three items: works by followed artists come next, then a
random pick of curated artworks, then any artwork with an image.

Artist recommendations rank every unfollowed artist, including artists whose
works the user already liked, and keep the top three.

The random fallback is seeded by user and Seoul date, so it changes daily but
not on every refresh.
"""

import random
from collections.abc import Iterable, Sequence
from datetime import date
from typing import Literal

from sqlalchemy.orm import Session

from app.core import timeutil
from app.repositories import catalog_repository, recommendation_repository
from app.repositories.recommendation_repository import Candidate
from app.schemas.catalog import ArtistCard, ArtworkCard
from app.schemas.recommendation import RecommendedArtist, RecommendedArtwork
from app.services import catalog_service

COUNT = 3
LIKE_SEEDS = 10
VIEW_SEEDS = 5
POOL = 30

SeedKind = Literal["like", "view"]


def similar(db: Session, *, artwork_id: int) -> list[ArtworkCard]:
    """Closest artworks to this one. Empty until artwork vectors are loaded."""

    catalog_service.ensure_artwork(db, artwork_id)
    ids = recommendation_repository.similar_artwork_ids(
        db, artwork_id=artwork_id, limit=COUNT
    )
    rows = catalog_repository.get_artworks(db, ids)
    return [catalog_service.to_artwork_card(*rows[i]) for i in ids if i in rows]


def recommend_artworks(db: Session, *, user_id: int) -> list[RecommendedArtwork]:
    liked, seeds, kind = _seeds(db, user_id)
    pool = recommendation_repository.candidates(
        db, seed_ids=seeds, exclude_ids=set(liked), limit=POOL
    )

    # (artwork id, artist id, seed id or None, fixed reason or None)
    picked: list[tuple[int, int, int | None, str | None]] = []
    for c in _one_per_artist(pool):
        picked.append((c.artwork_id, c.artist_id, c.seed_id, None))
        if len(picked) == COUNT:
            break

    if len(picked) < COUNT:
        taken = set(liked) | set(seeds)
        followed = recommendation_repository.followed_artist_ids(db, user_id=user_id)
        by_followed = [
            (a.id, a.artist_id, f"팔로우한 {name}의 작품")
            for a, name in recommendation_repository.artworks_by_artists(
                db, artist_ids=followed
            )
        ]
        rows = recommendation_repository.fallback_artworks(db)
        rng = _daily_rng(user_id)
        curated = _shuffled([a for a, _ in rows if a.is_featured], rng)
        others = _shuffled([a for a, _ in rows if not a.is_featured], rng)
        fallback = [(a.id, a.artist_id, None) for a in curated + others]
        for artwork_id, artist_id, reason in _fill(
            picked, by_followed + fallback, taken
        ):
            picked.append((artwork_id, artist_id, None, reason))

    seed_ids = [s for _, _, s, _ in picked if s is not None]
    rows = catalog_repository.get_artworks(db, [p[0] for p in picked] + seed_ids)
    result = []
    for artwork_id, _, seed_id, reason in picked:
        if seed_id is not None and kind is not None:
            reason = _seed_reason(rows[seed_id][0].title, kind)
        artwork, name = rows[artwork_id]
        result.append(
            catalog_service.to_artwork_card(
                artwork, name, RecommendedArtwork, reason=reason
            )
        )
    return result


def recommend_artists(db: Session, *, user_id: int) -> list[RecommendedArtist]:
    """Artists ranked by summed similarity over the candidate pool, minus followed ones."""

    liked, seeds, kind = _seeds(db, user_id)
    followed = set(recommendation_repository.followed_artist_ids(db, user_id=user_id))
    pool = recommendation_repository.candidates(
        db, seed_ids=seeds, exclude_ids=set(liked), limit=POOL
    )

    scores: dict[int, float] = {}
    nearest_seed: dict[int, int] = {}
    for c in pool:
        if c.artist_id in followed:
            continue
        scores[c.artist_id] = scores.get(c.artist_id, 0.0) + (1 - c.distance)
        nearest_seed.setdefault(c.artist_id, c.seed_id)
    ranked = sorted(scores, key=lambda a: (-scores[a], a))[:COUNT]

    if len(ranked) < COUNT:
        candidates = _shuffled(catalog_repository.list_artists(db), _daily_rng(user_id))
        for artist in candidates:
            if artist.id not in followed and artist.id not in ranked:
                ranked.append(artist.id)
            if len(ranked) == COUNT:
                break

    artists = catalog_repository.get_artists(db, ranked)
    seed_rows = catalog_repository.get_artworks(db, list(nearest_seed.values()))
    result = []
    for artist_id in ranked:
        reason = None
        if artist_id in nearest_seed and kind is not None:
            reason = _seed_reason(seed_rows[nearest_seed[artist_id]][0].title, kind)
        card = ArtistCard.model_validate(artists[artist_id])
        result.append(RecommendedArtist(**card.model_dump(), reason=reason))
    return result


# --- helpers ----------------------------------------------------------------


def _today() -> date:
    return timeutil.local_date(timeutil.utcnow())


def _daily_rng(user_id: int) -> random.Random:
    return random.Random(f"{user_id}:{_today().isoformat()}")


def _shuffled[T](items: Sequence[T], rng: random.Random) -> list[T]:
    out = list(items)
    rng.shuffle(out)
    return out


def _seeds(db: Session, user_id: int) -> tuple[list[int], list[int], SeedKind | None]:
    """(all liked ids, seed ids, seed kind)."""

    liked = recommendation_repository.liked_artwork_ids(db, user_id=user_id)
    if liked:
        return liked, liked[:LIKE_SEEDS], "like"
    viewed = recommendation_repository.recent_viewed_artwork_ids(
        db, user_id=user_id, limit=VIEW_SEEDS
    )
    return liked, viewed, ("view" if viewed else None)


def _one_per_artist(pool: list[Candidate]) -> Iterable[Candidate]:
    seen: set[int] = set()
    for c in pool:
        if c.artist_id not in seen:
            seen.add(c.artist_id)
            yield c


def _fill(
    picked: list[tuple[int, int, int | None, str | None]],
    options: list[tuple[int, int, str | None]],
    taken: set[int],
) -> list[tuple[int, int, str | None]]:
    """Top up to COUNT from ``options``: new artists first, then any artist."""

    used_ids = taken | {p[0] for p in picked}
    used_artists = {p[1] for p in picked}
    extra: list[tuple[int, int, str | None]] = []
    for new_artists_only in (True, False):
        for artwork_id, artist_id, reason in options:
            if len(picked) + len(extra) == COUNT:
                return extra
            if artwork_id in used_ids or (
                new_artists_only and artist_id in used_artists
            ):
                continue
            extra.append((artwork_id, artist_id, reason))
            used_ids.add(artwork_id)
            used_artists.add(artist_id)
    return extra


def _seed_reason(title: str, kind: SeedKind) -> str:
    if kind == "like":
        return f"『{title}』{_josa(title, '을', '를')} 좋아해서"
    return f"최근 본 『{title}』{_josa(title, '과', '와')} 비슷해서"


def _josa(word: str, after_consonant: str, after_vowel: str) -> str:
    """Korean particle for the last syllable; both forms when it is not Hangul."""

    last = word.rstrip()[-1:]
    if "가" <= last <= "힣":
        has_final = (ord(last) - ord("가")) % 28 != 0
        return after_consonant if has_final else after_vowel
    return f"{after_consonant}({after_vowel})"
