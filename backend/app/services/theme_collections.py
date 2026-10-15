"""Mood playlists inferred from likes/views, selected only from real catalog IDs.

Like a music app's personal mixes, themes follow a feeling or scene ("잔잔한
저녁에 어울리는 그림") across artists, not an artist, movement or date.

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
import re
import time
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
POOL_SIZE = 50
PER_ARTIST = 4  # discoveries per artist, so moods can cross artists
MAX_THEMES = 4  # the model drafts a few more; invalid ones are dropped
# Ask once more (with the reasons) when fewer survive, if time allows: the
# client gives up after 45 s and one model call may take up to 25 s.
MIN_THEMES = 2
RETRY_WITHIN = 15  # seconds
# Bump when the prompt or pool changes so existing snapshots are remade once.
GENERATION = 2
COOLDOWN = timedelta(minutes=30)
logger = logging.getLogger(__name__)


class ThemeDraft(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    description: str = Field(min_length=1, max_length=240)
    artwork_ids: list[Annotated[int, Field(strict=True, gt=0)]] = Field(
        min_length=3, max_length=8
    )
    # Self-check only (not trusted): makes the model notice one-artist picks.
    artists: list[str] = Field(default_factory=list, max_length=8)


class ThemeDrafts(BaseModel):
    themes: list[ThemeDraft] = Field(min_length=1, max_length=6)


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
    """Bounded pool: every interest seed, then discoveries spread over artists.

    Discoveries prefer the seeds' artists and movements but take at most
    PER_ARTIST works per artist, so a mood can gather works across artists.
    """
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
    ).all()
    per_artist: dict[int, int] = {}
    picked = []
    for row in rows:
        artwork = row[0]
        if artwork.id not in evidence:
            if per_artist.get(artwork.artist_id, 0) >= PER_ARTIST:
                continue
            per_artist[artwork.artist_id] = per_artist.get(artwork.artist_id, 0) + 1
        picked.append(row)
        if len(picked) == POOL_SIZE:
            break
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
        for a, artist, movement in picked
    ]


def generate(pool, feedback=None):
    data = {"artworks": pool}
    if feedback:
        data["previous_attempt"] = feedback
    return collection_assistant.generate(
        ThemeDrafts,
        "당신은 음악 앱의 개인 플레이리스트처럼 그림을 큐레이션합니다. interest.liked와 views로 "
        "이 사람이 끌린 그림들의 분위기·장면·빛·계절·시간·정서를 읽고, 서로 다른 감성의 "
        "테마 컬렉션 후보를 3~5개 만드세요(근거가 부족하면 더 적어도 됩니다). 좋아요와 반복 조회에 "
        "더 무게를 두세요. 제목은 '잔잔한 저녁에 어울리는 그림', '비 갠 오후의 산책', "
        "'혼자 머무는 고요한 방'처럼 그 순간의 기분이나 장면을 떠올리게 하는 자연스러운 "
        "한국어로 짓고, 예시를 그대로 쓰지 마세요. 제목과 description에 작가 이름(성만 쓰는 "
        "'모네의', '고흐의'도 안 됩니다), 사조, 시대, 국가, 연도를 쓰지 말고, 작가·사조·시대별로 "
        "묶지 마세요. 후보에 여러 작가가 있으므로 각 테마에는 반드시 서로 다른 작가 2명 "
        "이상의 작품을 담고, artists에 담은 작품들의 작가 이름을 적어 확인하세요. 한 작가만 "
        "담긴 테마와 interest가 있는 작품이 하나도 없는 테마는 버려집니다. 분위기 해석은 각 작품 설명에 실제로 "
        "나오는 장면·소재·빛·색·계절·시간대에 근거해야 합니다. 설명이 그 분위기를 뒷받침하지 "
        "않는 작품은 넣지 마세요. 아침·해돋이와 저녁·노을·밤처럼 상반된 시간대나 계절을 한 "
        "테마에 섞지 말고, 설명에 시간대나 계절 단서가 없는 작품은 그런 테마에 넣지 마세요. "
        "각 모음은 제공된 ID 중 3~8점(가능하면 4~6점)을, 감정이 자연스럽게 이어지는 "
        "감상 순서로 고르세요. 각 모음에 실제 좋아했거나 본 작품을 적어도 1점 포함하고, "
        "분위기가 맞으면 아직 보지 않은 작품도 섞어 발견을 도우세요. 모음끼리 작품과 분위기가 "
        "겹치지 않게 하세요. description에는 이 그림들을 함께 볼 때의 느낌을 감상을 권하는 "
        "60자 안팎의 한국어 1문장으로 쓰세요. 사용자가 무엇을 좋아요/조회했는지는 쓰지 마세요. 실제 행동 "
        "근거는 서버가 붙입니다. 분위기는 감상의 해석으로 표현하고, 설명에 없는 사실(기법, "
        "제작 배경, 실제 색상)을 단정하지 마세요. 사용자 신상/성격/정신상태를 추론하지 마세요. "
        "입력에 없는 작품 ID나 작품 정보를 만들지 마세요. previous_attempt가 있으면 kept와 "
        "겹치지 않는 새 테마만, rejected의 이유를 고쳐서 만드세요.",
        data,
    )


def _names(pool):
    """Artist names, their 2+ letter parts ('모네', '고흐') and movement names."""
    names = set()
    for a in pool:
        names.add(a["artist"])
        names.update(part for part in a["artist"].split() if len(part) >= 2)
        if a["movement"]:
            names.add(a["movement"])
    return names


def _mood_line(text, names):
    """First sentence of the AI mood text that names no artist or movement."""
    for sentence in re.split(r"(?<=[.!?。])\s+", text.strip()):
        if sentence and not any(n in sentence for n in names):
            return sentence
    return ""


def pick_themes(items, pool, evidence, version, rejected=None):
    """Grounded themes in draft order, at most MAX_THEMES.

    Keys carry the signal version so stale links 404. Dropped drafts are
    reported in ``rejected`` (name, reason) for one corrective retry.
    """
    rejected = [] if rejected is None else rejected
    allowed = {a["id"] for a in pool}
    artists = {a["id"]: a["artist"] for a in pool}
    names = _names(pool)
    themes = []
    for item in items:
        if len(themes) == MAX_THEMES:
            break
        ids = list(dict.fromkeys(i for i in item.artwork_ids if i in allowed))
        # Moods, not artist/movement groupings (those read as auto collections).
        if any(n in item.name for n in names):
            reason = "제목에 작가나 사조 이름이 있음"
        elif len(ids) < 3:
            reason = "실제 후보 작품이 3점 미만"
        elif not set(ids).intersection(evidence):
            reason = "interest가 있는 작품이 없음"
        elif len(set(artists.values())) > 1 and len({artists[i] for i in ids}) < 2:
            reason = "한 작가의 작품만 담김"
        elif any(
            # Mostly the same works (of the smaller one) means the same mood.
            len(set(ids) & set(t["artwork_ids"])) / min(len(ids), len(t["artwork_ids"]))
            > 0.6
            for t in themes
        ):
            reason = "다른 테마와 작품이 거의 같음"
        else:
            reason = None
        if reason:
            rejected.append({"name": item.name, "reason": reason})
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
                "description": (reason + _mood_line(item.description, names)).strip(),
                "artwork_ids": ids,
            }
        )
    return themes


def validated(draft, pool, evidence, version):
    if draft is None:
        raise ValueError("No structured theme response")
    themes = pick_themes(draft.themes, pool, evidence, version)
    if not themes:
        raise ValueError("No grounded theme")
    return themes


def drafted(pool, evidence, version):
    """One model call, plus one corrective call if fewer than MIN_THEMES survive."""
    started = time.monotonic()
    draft = generate(pool)
    if draft is None:
        raise ValueError("No structured theme response")
    items, rejected = list(draft.themes), []
    themes = pick_themes(items, pool, evidence, version, rejected)
    if (
        len(themes) < MIN_THEMES
        and rejected
        and time.monotonic() - started < RETRY_WITHIN
    ):
        feedback = {"kept": [t["name"] for t in themes], "rejected": rejected}
        try:
            retry = generate(pool, feedback)
        except HTTPException:
            retry = None  # keep what the first call gave
        if retry is not None:
            themes = pick_themes(items + list(retry.themes), pool, evidence, version)
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
        "generation": GENERATION,
    }


def changed(cache, evidence):
    """Meaningful change since the snapshot was made (always for a first one)."""
    if cache is None or not cache.generated_at or not cache.basis:
        return True
    now = basis(evidence)
    if cache.basis.get("generation") != GENERATION:
        return True
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
        themes = drafted(pool, evidence, fingerprint[:8])
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
