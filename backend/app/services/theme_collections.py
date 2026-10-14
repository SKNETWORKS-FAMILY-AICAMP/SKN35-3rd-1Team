"""AI playlists inferred from likes/views, selected only from real catalog IDs.

The explicit refresh POST is called automatically when opening collections.
Snapshots keep list/detail consistent across workers and restarts. An atomic
database claim bounds generation to once per user per 30 minutes, including
failed attempts. The snapshot has no expiry: like a personal playlist it is
only remade on a meaningful change (a like added/removed, or NEW_VIEWS_TO_REFRESH
newly viewed works since it was made), so one stray view does not reshape it.
"""

import hashlib
import json
import logging
from datetime import timedelta
from typing import Annotated

from fastapi import HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import case, func, or_, select, update
from sqlalchemy.exc import IntegrityError

from app.core.timeutil import utcnow
from app.models import (
    Artist,
    ArtMovement,
    Artwork,
    ArtworkLike,
    ArtworkView,
    ThemeCollectionCache,
)
from app.schemas.mypage import (
    AutoCollectionDetail,
    AutoCollectionOut,
    ThemeCollectionsOut,
)
from app.services import catalog_service, collection_assistant

MIN_SIGNALS = 3
NEW_VIEWS_TO_REFRESH = 3
COOLDOWN = timedelta(minutes=30)
logger = logging.getLogger(__name__)


class ThemeDraft(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    description: str = Field(min_length=1, max_length=240)
    artwork_ids: list[Annotated[int, Field(strict=True, gt=0)]] = Field(
        min_length=3, max_length=8
    )


class ThemeDrafts(BaseModel):
    themes: list[ThemeDraft] = Field(min_length=1, max_length=2)


def signals(db, user_id):
    likes = db.scalars(
        select(ArtworkLike.artwork_id)
        .where(ArtworkLike.user_id == user_id)
        .order_by(ArtworkLike.created_at.desc(), ArtworkLike.artwork_id)
        .limit(30)
    ).all()
    views = db.execute(
        select(ArtworkView.artwork_id, func.sum(ArtworkView.view_count))
        .where(ArtworkView.user_id == user_id)
        .group_by(ArtworkView.artwork_id)
        .order_by(func.max(ArtworkView.last_viewed_at).desc(), ArtworkView.artwork_id)
        .limit(30)
    ).all()
    evidence = {i: {"liked": True, "views": 0} for i in likes}
    for i, count in views:
        evidence.setdefault(i, {"liked": False, "views": 0})["views"] = min(
            int(count), 3
        )
    fingerprint = hashlib.sha256(
        json.dumps(evidence, sort_keys=True).encode()
    ).hexdigest()
    return evidence, fingerprint


def candidates(db, evidence):
    """Bounded catalog pool: interest seeds, their artists/movements, discoveries."""
    seeds = db.scalars(select(Artwork).where(Artwork.id.in_(evidence))).all()
    artists = {a.artist_id for a in seeds}
    movements = {a.movement_id for a in seeds if a.movement_id is not None}
    priority = case(
        (Artwork.id.in_(evidence), 0),
        (Artwork.artist_id.in_(artists), 1),
        (Artwork.movement_id.in_(movements), 2),
        else_=3,
    )
    rows = db.execute(
        select(Artwork, Artist.name, ArtMovement.name)
        .join(Artist, Artist.id == Artwork.artist_id)
        .outerjoin(ArtMovement, ArtMovement.id == Artwork.movement_id)
        .where(Artwork.image_url.is_not(None), Artwork.image_url != "")
        .order_by(priority, Artwork.is_featured.desc(), Artwork.id)
        .limit(50)
    ).all()
    return [
        {
            "id": a.id,
            "title": a.title,
            "artist": artist,
            "movement": movement,
            "description": (a.description or "")[:600],
            "medium": a.medium,
            "interest": evidence.get(a.id, {"liked": False, "views": 0}),
        }
        for a, artist, movement in rows
    ]


def generate(pool):
    return collection_assistant.generate(
        ThemeDrafts,
        "당신은 개인 미술 플레이리스트 큐레이터입니다. 작품 목록의 interest.liked와 views에서 "
        "감상 취향의 공통점을 읽고, 서로 다른 테마 컬렉션 1~2개를 만드세요. "
        "좋아요와 반복 조회에 더 무게를 두세요. '잔잔한 저녁에 어울리는 그림', '빛이 머무는 풍경'처럼 "
        "구체적이고 자연스러운 한국어 제목을 붙이되 실제 제공된 작품 설명이 뒷받침하는 테마만 쓰세요. "
        "작가별 자동 모음은 이미 있으므로 작가 이름을 제목에 쓰거나 작가별로만 묶지 마세요. "
        "풍경·인물·빛·일상의 장면 등 공통된 감상 경험으로 연결하세요. 후보에 여러 작가가 있다면 "
        "각 테마에 최소 두 작가의 작품을 담으세요. "
        "예시 제목을 그대로 따를 필요는 없습니다. 각 모음은 제공된 ID 중 3~8점을 감상 순서로 고르세요. "
        "각 모음에 실제 좋아했거나 본 작품을 적어도 1점 포함하고, 테마에 맞으면 아직 보지 않은 작품도 "
        "섞어 발견을 도우세요. 두 모음을 같은 작품들로 채우지 마세요. description에는 "
        "이 작품들을 함께 감상할 때 느낄 수 있는 공통된 경험을 한국어 1문장으로 쓰세요. "
        "사용자가 무엇을 좋아요/조회했는지 description에 쓰지 마세요. 실제 행동 근거는 서버가 붙입니다. "
        "제목/설명에 없는 색상·기법·시간대·감정을 사실로 단정하지 마세요. 사용자 신상/성격/정신상태를 "
        "추론하지 마세요. 입력에 없는 작품 ID나 작품 정보를 만들지 마세요.",
        {"artworks": pool},
    )


def validated(draft, pool, evidence, version):
    """Grounded themes; keys carry the signal version so stale links 404."""
    if draft is None:
        raise ValueError("No structured theme response")
    allowed = {a["id"] for a in pool}
    artists = {a["id"]: a["artist"] for a in pool}
    themes = []
    for item in draft.themes:
        ids = list(dict.fromkeys(i for i in item.artwork_ids if i in allowed))
        if len(ids) < 3 or not set(ids).intersection(evidence):
            continue
        if len(set(artists.values())) > 1 and len({artists[i] for i in ids}) < 2:
            continue
        if any(
            len(set(ids) & set(t["artwork_ids"]))
            / len(set(ids) | set(t["artwork_ids"]))
            > 0.8
            for t in themes
        ):
            continue
        liked = [
            a for a in pool if a["id"] in ids and evidence.get(a["id"], {}).get("liked")
        ]
        seen = [a for a in pool if a["id"] in ids and a["id"] in evidence]
        seed = (liked or seen)[0]
        title = seed["title"][:60]
        reason = (
            f"{'좋아요한' if liked else '감상한'} ‘{title}’에서 이어지는 모음이에요. "
        )
        themes.append(
            {
                "key": f"theme-{len(themes) + 1}-{version}",
                "name": item.name,
                "description": reason + item.description,
                "artwork_ids": ids,
            }
        )
    if not themes:
        raise ValueError("No grounded theme")
    return themes


def _detail(db, theme):
    rows = db.execute(
        select(Artwork, Artist.name)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(Artwork.id.in_(theme["artwork_ids"]))
    ).all()
    cards = {a.id: catalog_service.to_artwork_card(a, name) for a, name in rows}
    works = [cards[i] for i in theme["artwork_ids"] if i in cards]
    summary = AutoCollectionOut(
        key=theme["key"],
        name=theme["name"],
        description=theme["description"],
        artwork_count=len(works),
        cover=works[0] if works else None,
    )
    return AutoCollectionDetail(collection=summary, items=works)


def _result(db, cache, message=None):
    details = [_detail(db, theme) for theme in (cache.themes if cache else [])]
    return ThemeCollectionsOut(
        items=[d.collection for d in details if d.items], message=message
    )


def basis(evidence):
    return {
        "liked": sorted(i for i, e in evidence.items() if e["liked"]),
        "seen": sorted(evidence),
    }


def changed(cache, evidence):
    """Meaningful change since the snapshot was made (always for a first one)."""
    if cache is None or not cache.generated_at or not cache.basis:
        return True
    now = basis(evidence)
    if now["liked"] != cache.basis["liked"]:
        return True
    return len(set(now["seen"]) - set(cache.basis["seen"])) >= NEW_VIEWS_TO_REFRESH


def refresh(db, user_id):
    evidence, fingerprint = signals(db, user_id)
    if len(evidence) < MIN_SIGNALS:
        return ThemeCollectionsOut(
            message="작품을 3점 정도 감상하거나 좋아요해 보세요. 취향을 따라 AI 모음이 생겨요."
        )
    cache = db.get(ThemeCollectionCache, user_id)
    now = utcnow()
    if not changed(cache, evidence):
        return _result(db, cache)
    if cache is None:
        cache = ThemeCollectionCache(user_id=user_id, themes=[])
        db.add(cache)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
        cache = db.get(ThemeCollectionCache, user_id)
    # Claim before the network call, shared by all Railway workers.
    claimed = db.execute(
        update(ThemeCollectionCache)
        .where(
            ThemeCollectionCache.user_id == user_id,
            or_(
                ThemeCollectionCache.attempted_at.is_(None),
                ThemeCollectionCache.attempted_at <= now - COOLDOWN,
            ),
        )
        .values(attempted_at=now)
    ).rowcount
    db.commit()
    if not claimed:
        return _result(
            db,
            cache,
            None
            if cache.themes
            else "아직 AI 취향 모음을 준비하지 못했어요. 조금 뒤 다시 확인해 주세요.",
        )
    try:
        pool = candidates(db, evidence)
        if len(pool) < 3:
            return _result(db, cache, "테마로 묶을 작품을 더 준비하고 있어요.")
        themes = validated(generate(pool), pool, evidence, fingerprint[:8])
    except Exception as exc:  # noqa: BLE001 -- keep saved and auto collections usable.
        logger.warning("Theme generation unavailable: %s", type(exc).__name__)
        db.rollback()  # a failed query must not break reading the last snapshot
        return _result(
            db,
            cache,
            "AI 취향 모음을 지금 만들지 못했어요. 기존 컬렉션은 계속 볼 수 있어요.",
        )
    cache.themes, cache.fingerprint, cache.generated_at = themes, fingerprint, now
    cache.basis = basis(evidence)
    db.commit()
    return _result(db, cache)


def detail(db, user_id, key):
    cache = db.get(ThemeCollectionCache, user_id)
    for theme in cache.themes if cache else []:
        if theme["key"] == key:
            return _detail(db, theme)
    raise HTTPException(
        404, "이 취향 모음을 찾을 수 없어요. 컬렉션에서 다시 확인해 주세요."
    )
