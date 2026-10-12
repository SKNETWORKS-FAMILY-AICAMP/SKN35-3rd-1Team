"""Recommendation rules with fake repositories (no TiDB, no vectors)."""

from datetime import date
from types import SimpleNamespace

import pytest

from app.models import Artist, Artwork
from app.repositories import catalog_repository, recommendation_repository
from app.repositories.recommendation_repository import Candidate
from app.services import catalog_service, recommendation_service

# artwork id -> (artist id, title); artist ids 1..5
WORKS = {
    1: (1, "별이 빛나는 밤"),
    2: (1, "해바라기"),
    3: (2, "야경"),
    4: (2, "자화상"),
    5: (3, "수련"),
    6: (4, "생트빅투아르 산"),
    7: (5, "인왕제색도"),
    8: (3, "인상, 해돋이"),
}
ARTISTS = {i: f"작가{i}" for i in range(1, 6)}
FEATURED: set[int] = set()


def _artwork(artwork_id: int) -> Artwork:
    artist_id, title = WORKS[artwork_id]
    return Artwork(
        id=artwork_id,
        slug=f"w{artwork_id}",
        title=title,
        title_en=None,
        artist_id=artist_id,
        movement_id=None,
        year_label=None,
        image_url=None,
        is_featured=artwork_id in FEATURED,
    )


def _artist(artist_id: int) -> Artist:
    return Artist(
        id=artist_id,
        slug=f"a{artist_id}",
        name=ARTISTS[artist_id],
        name_en=None,
        movement_id=None,
        birth_year=None,
        death_year=None,
        summary=None,
        portrait_url=None,
    )


def _row(artwork_id: int):
    artwork = _artwork(artwork_id)
    return artwork, ARTISTS[artwork.artist_id]


def _cand(artwork_id: int, seed_id: int, distance: float) -> Candidate:
    return Candidate(artwork_id, WORKS[artwork_id][0], seed_id, distance)


@pytest.fixture
def repo(monkeypatch):
    """Configurable fake repositories; tests set the fields they need."""

    state = SimpleNamespace(
        liked=[],
        viewed=[],
        followed=[],
        pool=[],
        similar=[],
        fallback=list(WORKS),
        candidate_calls=[],
    )

    def candidates(db, *, seed_ids, exclude_ids, limit):
        state.candidate_calls.append(
            {"seed_ids": seed_ids, "exclude_ids": exclude_ids, "limit": limit}
        )
        return state.pool if seed_ids else []

    rr = recommendation_repository
    monkeypatch.setattr(rr, "liked_artwork_ids", lambda db, user_id: state.liked)
    monkeypatch.setattr(
        rr, "recent_viewed_artwork_ids", lambda db, user_id, limit: state.viewed[:limit]
    )
    monkeypatch.setattr(rr, "followed_artist_ids", lambda db, user_id: state.followed)
    monkeypatch.setattr(rr, "candidates", candidates)
    monkeypatch.setattr(
        rr,
        "artworks_by_artists",
        lambda db, artist_ids: [_row(i) for i in WORKS if WORKS[i][0] in artist_ids],
    )
    monkeypatch.setattr(
        rr, "fallback_artworks", lambda db: [_row(i) for i in state.fallback]
    )
    monkeypatch.setattr(
        rr, "similar_artwork_ids", lambda db, artwork_id, limit: state.similar[:limit]
    )
    monkeypatch.setattr(
        catalog_repository, "get_artworks", lambda db, ids: {i: _row(i) for i in ids}
    )
    monkeypatch.setattr(
        catalog_repository, "get_artists", lambda db, ids: {i: _artist(i) for i in ids}
    )
    monkeypatch.setattr(
        catalog_repository,
        "list_artists",
        lambda db, movement_id=None: [_artist(i) for i in ARTISTS],
    )
    monkeypatch.setattr(catalog_service, "ensure_artwork", lambda db, artwork_id: None)
    monkeypatch.setattr(recommendation_service, "_today", lambda: date(2026, 10, 12))
    FEATURED.clear()
    yield state
    FEATURED.clear()


# --- artworks ---------------------------------------------------------------


def test_one_artwork_per_artist_in_distance_order(repo) -> None:
    repo.liked = [1]
    repo.pool = [
        _cand(2, 1, 0.1),
        _cand(3, 1, 0.2),
        _cand(4, 1, 0.25),
        _cand(5, 1, 0.3),
    ]
    result = recommendation_service.recommend_artworks(None, user_id=1)
    # 4 shares artist 2 with 3, so 5 takes the third slot.
    assert [r.id for r in result] == [2, 3, 5]
    assert len({r.artist_id for r in result}) == 3


def test_liked_artworks_are_excluded_and_recent_likes_are_seeds(repo) -> None:
    repo.liked = list(range(100, 112))  # 12 likes, newest first
    recommendation_service.recommend_artworks(None, user_id=1)
    call = repo.candidate_calls[0]
    assert call["seed_ids"] == list(range(100, 110))
    assert call["exclude_ids"] == set(range(100, 112))
    assert call["limit"] == 30


def test_reason_names_the_nearest_liked_artwork(repo) -> None:
    repo.liked = [1, 3]
    repo.pool = [_cand(5, 1, 0.1), _cand(6, 3, 0.2), _cand(7, 1, 0.3)]
    reasons = [
        r.reason for r in recommendation_service.recommend_artworks(None, user_id=1)
    ]
    assert reasons == [
        "『별이 빛나는 밤』을 좋아해서",
        "『야경』을 좋아해서",
        "『별이 빛나는 밤』을 좋아해서",
    ]


def test_views_are_seeds_when_there_are_no_likes(repo) -> None:
    repo.viewed = [2, 1, 3, 4, 5, 6]
    repo.pool = [_cand(7, 2, 0.1), _cand(5, 1, 0.2), _cand(6, 2, 0.3)]
    result = recommendation_service.recommend_artworks(None, user_id=1)
    assert repo.candidate_calls[0]["seed_ids"] == [2, 1, 3, 4, 5]
    assert result[0].reason == "최근 본 『해바라기』와 비슷해서"


def test_new_user_gets_followed_artist_work_then_random_fill(repo) -> None:
    repo.followed = [2]
    result = recommendation_service.recommend_artworks(None, user_id=1)
    assert len(result) == 3
    assert (result[0].id, result[0].reason) == (3, "팔로우한 작가2의 작품")
    # The rest are random, one per artist, not artist 2 again.
    assert len({r.artist_id for r in result}) == 3
    assert all(r.reason is None for r in result[1:])


def test_random_fill_prefers_curated(repo) -> None:
    FEATURED.update({5, 6, 7})
    result = recommendation_service.recommend_artworks(None, user_id=1)
    assert {r.id for r in result} == {5, 6, 7}


def test_random_fill_is_stable_within_a_day(monkeypatch, repo) -> None:
    def ids() -> list[int]:
        return [
            r.id for r in recommendation_service.recommend_artworks(None, user_id=1)
        ]

    first = ids()
    assert ids() == first
    days = set()
    for day in range(1, 11):
        monkeypatch.setattr(
            recommendation_service, "_today", lambda d=day: date(2026, 11, d)
        )
        days.add(tuple(ids()))
    assert len(days) > 1


def test_fill_does_not_repeat_picked_or_liked(repo) -> None:
    repo.liked = [6]
    repo.pool = [_cand(7, 6, 0.1)]
    repo.fallback = [7, 6, 1, 3]
    result = recommendation_service.recommend_artworks(None, user_id=1)
    assert result[0].id == 7
    assert sorted(r.id for r in result) == [1, 3, 7]


def test_fill_allows_same_artist_when_nothing_else_is_left(repo) -> None:
    repo.fallback = [1, 2, 3]  # artists 1, 1, 2
    result = recommendation_service.recommend_artworks(None, user_id=1)
    assert sorted(r.id for r in result) == [1, 2, 3]


# --- artists ----------------------------------------------------------------


def test_artists_ranked_by_summed_similarity_without_followed(repo) -> None:
    repo.liked = [1]
    repo.followed = [3]
    repo.pool = [
        _cand(5, 1, 0.05),  # artist 3 (followed): skipped
        _cand(6, 1, 0.1),  # artist 4: 0.9
        _cand(3, 1, 0.2),  # artist 2: 0.8 ...
        _cand(4, 1, 0.3),  # ... + 0.7 = 1.5
        _cand(2, 1, 0.4),  # artist 1: 0.6
    ]
    result = recommendation_service.recommend_artists(None, user_id=1)
    assert [r.id for r in result] == [2, 4, 1]
    assert result[0].reason == "『별이 빛나는 밤』을 좋아해서"


def test_new_user_still_gets_three_artists(repo) -> None:
    repo.followed = [1, 2]
    result = recommendation_service.recommend_artists(None, user_id=1)
    assert sorted(r.id for r in result) == [3, 4, 5]
    assert all(r.reason is None for r in result)


# --- similar ----------------------------------------------------------------


def test_similar_keeps_distance_order(repo) -> None:
    repo.similar = [5, 3, 7]
    assert [a.id for a in recommendation_service.similar(None, artwork_id=1)] == [
        5,
        3,
        7,
    ]


def test_similar_is_empty_without_vectors(repo) -> None:
    assert recommendation_service.similar(None, artwork_id=1) == []


@pytest.mark.parametrize(
    ("title", "expected"),
    [("야경", "을"), ("해바라기", "를"), ("Water Lilies", "을(를)")],
)
def test_object_particle(title: str, expected: str) -> None:
    assert recommendation_service._josa(title, "을", "를") == expected
