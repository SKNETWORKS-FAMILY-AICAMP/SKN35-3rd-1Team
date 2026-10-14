"""발표용 계정(dev-user)에 감상글·좋아요·컬렉션·설정을 채운다.

``backend/`` 에서 실행::

    uv run python -m scripts.seed_demo_user            # 채우기
    uv run python -m scripts.seed_demo_user --dry-run  # 바뀔 내용만 세고 되돌림
    uv run python -m scripts.seed_demo_user --remove   # 이 스크립트가 넣은 감상글·컬렉션만 지움

AUTH_MODE=dev 에서 모든 요청이 처리되는 계정(users.firebase_uid = DEV_USER_UID)만 대상으로 한다.
계정이 없으면 만들지 않고 멈춘다. 여러 번 돌려도 결과가 같다: 감상글은 날짜, 컬렉션은 이름 기준으로
갱신하고, 좋아요·담기·열람은 이미 있으면 건너뛴다. 기존 좋아요·팔로우·열람과 이미 저장된 설정은
바꾸지 않는다. 도슨트 대화는 실제 RAG 답변이 아니면 출처가 거짓이 되므로 넣지 않는다.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import UTC, date, datetime, time
from zoneinfo import ZoneInfo

from sqlalchemy import delete, select
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import SessionLocal
from app.models import (
    Artwork,
    ArtworkLike,
    ArtworkView,
    Collection,
    CollectionItem,
    DiaryEntry,
    User,
    UserPreference,
)

# (날짜, 작품 slug, 공개 여부, 본문)
DIARY = [
    (date(2026, 10, 3), "impression-sunrise", True,
     "항구의 안개 속에서 붉은 해 하나만 또렷하게 보였다. 형태를 정확히 그리기보다 그 순간의 공기를 붙잡으려 한 것 같아서, 오래 보고 있으니 나도 새벽 바닷가에 서 있는 기분이 들었다."),
    (date(2026, 10, 5), "geumgang-jeondo", True,
     "봉우리들이 한 화면 안에 빽빽하게 모여 있는데 답답하지 않고 오히려 위로 솟는 힘이 느껴졌다. 직접 본 산을 기억으로 다시 짜 맞춘 그림이라는 설명을 듣고 다시 보니, 사진과는 다른 '본 것 같은' 풍경이었다."),
    (date(2026, 10, 7), "the-night-watch", False,
     "도슨트에게 빛이 왜 한쪽에만 몰려 있는지 물어봤다. 인물이 많은데도 시선이 자연스럽게 가운데로 모이는 게 신기했다. 다음에는 인물 한 명씩 따로 살펴보고 싶다."),
    (date(2026, 10, 9), "seodang", True,
     "훈장님 앞에서 울고 있는 아이와 키득거리는 친구들 표정이 너무 생생하다. 배경을 거의 그리지 않았는데도 서당 안 분위기가 그대로 전해진다. 보면서 나도 모르게 웃었다."),
    (date(2026, 10, 11), "the-kiss", True,
     "금빛 장식 속에서 두 사람의 얼굴과 손만 부드럽게 드러나 있다. 화려한 무늬 때문에 오히려 인물이 더 조용하게 느껴지는 게 묘했다. 컬렉션 '빈의 황금빛'의 첫 작품으로 담았다."),
    (date(2026, 10, 13), "cafe-terrace-at-night", False,
     "노란 차양 아래 불빛과 푸른 밤하늘이 맞닿아 있다. 검은색 없이 밤을 그렸다는 점이 계속 마음에 남는다. 언젠가 실제로 이 거리를 걸어 보고 싶다."),
]

LIKES = [
    "impression-sunrise", "geumgang-jeondo", "seodang", "the-kiss",
    "cafe-terrace-at-night", "the-night-watch", "mont-sainte-victoire",
]

# 이름 → (소개, 작품 slug 목록)
COLLECTIONS = {
    "빛을 그린 화가들": (
        "빛이 화면의 주인공처럼 느껴졌던 작품들을 모았어요.",
        ["impression-sunrise", "water-lilies", "cafe-terrace-at-night",
         "the-night-watch", "supper-at-emmaus"],
    ),
    "조선의 산수와 풍속": (
        "정선의 산과 김홍도의 사람들. 우리 옛 그림 속 풍경과 일상.",
        ["geumgang-jeondo", "inwangjesaekdo", "seodang", "ssireum"],
    ),
    "빈의 황금빛": (
        "클림트와 실레, 같은 도시에서 전혀 다르게 그려진 사람들.",
        ["the-kiss", "judith-i", "death-and-the-maiden-schiele"],
    ),
}

PREFERENCE = {
    "explanation_priorities": ["background", "technique", "artist_life"],
    "conversation_style": "easy",
    "tone": "easy",  # 0006 호환 컬럼. mypage_service 가 저장할 때와 같은 값으로 맞춘다
    "explanation_level": "easy",
    "onboarding_completed": True,
}


def at_local(day: date, hour: int) -> datetime:
    """앱 시간대(Asia/Seoul)의 그날 그 시각을 DB 저장 형식인 naive UTC 로 바꾼다."""
    tz = ZoneInfo(get_settings().app_timezone)
    return datetime.combine(day, time(hour), tz).astimezone(UTC).replace(tzinfo=None)


def artwork_ids(session: Session) -> dict[str, int]:
    slugs = {s for _, s, _, _ in DIARY} | set(LIKES)
    slugs |= {s for _, works in COLLECTIONS.values() for s in works}
    found = dict(session.execute(select(Artwork.slug, Artwork.id).where(Artwork.slug.in_(slugs))).all())
    missing = sorted(slugs - set(found))
    if missing:
        raise SystemExit("DB 에 없는 작품: " + ", ".join(missing))
    return found


def seed(session: Session, user_id: int, ids: dict[str, int]) -> Counter:
    stats: Counter = Counter()

    if session.get(UserPreference, user_id) is None:
        session.add(UserPreference(user_id=user_id, **PREFERENCE))
        stats["설정 추가"] += 1
    else:
        stats["설정 유지(이미 있음)"] += 1

    for slug in LIKES:
        r = session.execute(insert(ArtworkLike).values(user_id=user_id, artwork_id=ids[slug]).prefix_with("IGNORE"))
        stats["좋아요 추가" if r.rowcount else "좋아요 유지"] += 1

    existing = {d.entry_date: d for d in session.scalars(
        select(DiaryEntry).where(DiaryEntry.user_id == user_id, DiaryEntry.entry_date.in_([d for d, *_ in DIARY])))}
    for day, slug, public, content in DIARY:
        written = at_local(day, 21)
        values = {"artwork_id": ids[slug], "is_public": public, "content": content}
        entry = existing.get(day)
        if entry is None:
            session.add(DiaryEntry(user_id=user_id, entry_date=day, created_at=written, updated_at=written, **values))
            stats["감상글 추가"] += 1
        elif any(getattr(entry, k) != v for k, v in values.items()):
            for k, v in values.items():
                setattr(entry, k, v)
            stats["감상글 갱신"] += 1
        else:
            stats["감상글 유지"] += 1
        # 감상글을 쓴 날 그 작품을 본 기록. 이미 있으면 횟수를 늘리지 않는다
        viewed = at_local(day, 20)
        r = session.execute(insert(ArtworkView).values(
            user_id=user_id, artwork_id=ids[slug], viewed_on=day, view_count=1,
            first_viewed_at=viewed, last_viewed_at=viewed).prefix_with("IGNORE"))
        stats["열람 추가" if r.rowcount else "열람 유지"] += 1

    for name, (description, works) in COLLECTIONS.items():
        col = session.scalar(select(Collection).where(Collection.user_id == user_id, Collection.name == name))
        if col is None:
            col = Collection(user_id=user_id, name=name, description=description)
            session.add(col)
            session.flush()
            stats["컬렉션 추가"] += 1
        elif col.description != description:
            col.description = description
            stats["컬렉션 갱신"] += 1
        else:
            stats["컬렉션 유지"] += 1
        for slug in works:
            r = session.execute(insert(CollectionItem).values(collection_id=col.id, artwork_id=ids[slug]).prefix_with("IGNORE"))
            stats["담기 추가" if r.rowcount else "담기 유지"] += 1
    return stats


def remove(session: Session, user_id: int) -> Counter:
    """시드가 넣은 감상글(날짜·본문이 같은 것)과 컬렉션(이름이 같은 것)만 지운다."""
    stats: Counter = Counter()
    for day, _, _, content in DIARY:
        r = session.execute(delete(DiaryEntry).where(
            DiaryEntry.user_id == user_id, DiaryEntry.entry_date == day, DiaryEntry.content == content))
        stats["감상글 삭제"] += r.rowcount
    r = session.execute(delete(Collection).where(
        Collection.user_id == user_id, Collection.name.in_(list(COLLECTIONS))))
    stats["컬렉션 삭제(담긴 작품 포함)"] += r.rowcount
    return stats


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="바뀔 내용만 세고 되돌림")
    parser.add_argument("--remove", action="store_true", help="시드 감상글·컬렉션만 지움")
    args = parser.parse_args(argv)

    uid = get_settings().dev_user_uid
    with SessionLocal() as session:
        user = session.scalar(select(User).where(User.firebase_uid == uid))
        if user is None:
            raise SystemExit(f"firebase_uid={uid} 계정이 없습니다. 앱에 한 번 접속해 계정을 만든 뒤 실행하세요.")
        print(f"대상: {user.email} (id {user.id})")
        stats = remove(session, user.id) if args.remove else seed(session, user.id, artwork_ids(session))
        for key, n in stats.items():
            print(f"  {key}: {n}")
        if args.dry_run:
            session.rollback()
            print("[dry-run] 커밋하지 않았습니다.")
        else:
            session.commit()
            print("커밋했습니다.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
