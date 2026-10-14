"""피드·팔로우 화면 확인용 더미 회원과 그들의 활동을 채운다.

``backend/`` 에서 실행::

    uv run python -m scripts.seed_dummy_members             # 더미 회원 12명 + 활동, dev-user 가 더미를 팔로우
    uv run python -m scripts.seed_dummy_members --fan a@b.com --fan c@d.com  # 이 계정들이 더미를 팔로우
    uv run python -m scripts.seed_dummy_members --dry-run   # 바뀔 내용만 세고 되돌림
    uv run python -m scripts.seed_dummy_members --remove    # 더미 회원과 그 활동 전부, 더미를 향한 팔로우까지 지움

더미 회원은 ``users.firebase_uid`` 가 ``dummy:`` 로 시작하고 이메일이 ``@dummy.artlog.local`` 이라
실제 로그인으로는 쓸 수 없다. 회원마다 설정·좋아요·작가 팔로우·열람·감상평·컬렉션·회원 팔로우를 넣는다.
감상평은 작품마다 한 편(diary_entries 의 (user_id, artwork_id) 유니크)이라 회원별로 작품이 겹치지 않게 고른다.
고정 시드라 여러 번 돌려도 같은 결과가 나오고, 이미 있는 행은 건너뛴다.
실제 회원 계정은 --fan 으로 고른 계정이 더미를 팔로우하는 것 말고는 바꾸지 않는다
(더미 일부가 실제 회원을 팔로우하므로 실제 회원의 팔로워 수는 늘어난다).
"""

from __future__ import annotations

import argparse
import random
from collections import Counter
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import delete, or_, select
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import SessionLocal
from app.models import (
    Artist,
    ArtistFollow,
    Artwork,
    ArtworkLike,
    ArtworkView,
    Collection,
    CollectionItem,
    DiaryEntry,
    User,
    UserFollow,
    UserPreference,
)

UID_PREFIX = "dummy:"
EMAIL_DOMAIN = "dummy.artlog.local"
SEED = 20261014
DAYS_BACK = 30

# (닉네임, 대화 스타일, 팔로우 목록 공개 여부)
MEMBERS = [
    ("모네의정원", "easy", True),
    ("새벽산책자", "easy", True),
    ("붓끝여행", "professional", True),
    ("미술관고양이", "easy", True),
    ("황금빛오후", "professional", False),
    ("단원팬", "easy", True),
    ("빛과그림자", "professional", True),
    ("주말도슨트", "easy", True),
    ("노란집", "easy", False),
    ("겸재의산", "professional", True),
    ("캔버스일기", "easy", True),
    ("느린관람객", "easy", True),
]

PRIORITIES = ["background", "technique", "artist_life", "symbolism", "history"]

# {title}, {artist} 를 채운다. 조사가 제목에 바로 붙지 않게 썼다.
IMPRESSIONS = [
    "{artist}의 「{title}」. 처음엔 그냥 지나쳤는데 색이 겹친 부분을 오래 보니 붓의 속도가 느껴졌다.",
    "「{title}」 앞에서 한참 서 있었다. 화면 가장자리까지 긴장이 이어져서 눈을 뗄 수가 없었다.",
    "도슨트 설명을 듣고 다시 본 「{title}」. 배경을 알고 나니 인물의 시선이 전혀 다르게 읽혔다.",
    "오늘의 한 점은 {artist}. 「{title}」의 빛이 하루 종일 머릿속에 남아 있다.",
    "「{title}」 — 고요한데 이상하게 소리가 들리는 그림. 다음엔 실제 크기로 보고 싶다.",
    "{artist} 작품 중에 제일 마음에 든다. 「{title}」은 볼 때마다 새로 보이는 디테일이 있다.",
    "색은 단순한데 감정은 복잡하다. 「{title}」을 보며 오늘 하루를 정리했다.",
    "친구에게 추천받아 본 「{title}」. 왜 좋아하는지 알 것 같다. 구도가 정말 단단하다.",
    "「{title}」 속 작은 인물들을 하나씩 찾아보는 재미가 있었다. {artist} 특유의 유머가 보인다.",
    "처음 보는 작품이었는데 {artist} 다운 선이 바로 보였다. 「{title}」, 저장해 둬야지.",
    "「{title}」의 여백이 좋다. 비어 있는 곳이 오히려 이야기를 더 많이 한다.",
    "비 오는 날 보기 좋은 그림. 「{title}」의 차분한 톤이 마음을 가라앉혀 줬다.",
]

COLLECTION_NAMES = [
    ("요즘 꽂힌 그림", "최근 자꾸 다시 보게 되는 작품들."),
    ("빛이 예쁜 작품", "빛이 화면의 주인공 같은 그림만 모았어요."),
    ("조용한 풍경", "보고 있으면 마음이 가라앉는 풍경들."),
    ("인물의 얼굴", "표정과 시선이 오래 남는 초상과 인물화."),
    ("언젠가 실물로", "미술관에서 직접 보고 싶은 작품 목록."),
    ("우리 옛 그림", "산수와 풍속, 조선의 그림들."),
    ("강렬한 색", "색이 먼저 말을 거는 작품들."),
]


def at_local(day: date, hour: int, minute: int = 0) -> datetime:
    """앱 시간대의 그날 그 시각을 DB 저장 형식인 naive UTC 로 바꾼다."""
    tz = ZoneInfo(get_settings().app_timezone)
    return datetime.combine(day, time(hour, minute), tz).astimezone(UTC).replace(tzinfo=None)


def today_local() -> date:
    return datetime.now(ZoneInfo(get_settings().app_timezone)).date()


def upsert_members(session: Session, stats: Counter) -> list[User]:
    users = []
    for i, (nickname, style, list_public) in enumerate(MEMBERS, 1):
        uid = f"{UID_PREFIX}member-{i:02d}"
        user = session.scalar(select(User).where(User.firebase_uid == uid))
        if user is None:
            user = User(
                firebase_uid=uid,
                email=f"member{i:02d}@{EMAIL_DOMAIN}",
                nickname=nickname,
                follow_list_public=list_public,
            )
            session.add(user)
            session.flush()
            stats["회원 추가"] += 1
        else:
            stats["회원 유지"] += 1
        if session.get(UserPreference, user.id) is None:
            rng = random.Random(f"{SEED}-pref-{i}")
            session.add(UserPreference(
                user_id=user.id,
                birth_year=rng.randint(1975, 2004),
                explanation_priorities=rng.sample(PRIORITIES, 3),
                conversation_style=style,
                tone=style,
                explanation_level="deep" if style == "professional" else "easy",
                onboarding_completed=True,
            ))
            stats["설정 추가"] += 1
        users.append(user)
    return users


def insert_ignore(session: Session, model, stats: Counter, label: str, **values) -> None:
    r = session.execute(insert(model).values(**values).prefix_with("IGNORE"))
    stats[f"{label} 추가" if r.rowcount else f"{label} 유지"] += 1


def seed_activity(session: Session, users: list[User], stats: Counter) -> None:
    artworks = session.execute(
        select(Artwork.id, Artwork.title, Artist.name, Artist.id)
        .join(Artist, Artist.id == Artwork.artist_id)
        .order_by(Artwork.id)
    ).all()
    artist_ids = sorted({a[3] for a in artworks})
    today = today_local()

    for idx, user in enumerate(users, 1):
        rng = random.Random(f"{SEED}-member-{idx}")
        # 회원마다 좋아하는 작가 2~3명을 정하고, 활동의 대부분을 그 작가 작품에서 고른다.
        fav_artists = rng.sample(artist_ids, rng.randint(2, 3))
        fav_works = [a for a in artworks if a[3] in fav_artists]
        pool = rng.sample(fav_works, min(len(fav_works), 25)) + rng.sample(artworks, 10)
        pool = list(dict.fromkeys(pool))  # 순서 유지 중복 제거

        for artist_id in fav_artists:
            insert_ignore(session, ArtistFollow, stats, "작가 팔로우", user_id=user.id, artist_id=artist_id,
                          created_at=at_local(today - timedelta(days=rng.randint(10, DAYS_BACK)), 12))

        for work in pool[: rng.randint(6, 14)]:
            day = today - timedelta(days=rng.randint(0, DAYS_BACK))
            insert_ignore(session, ArtworkLike, stats, "좋아요", user_id=user.id, artwork_id=work[0],
                          created_at=at_local(day, rng.randint(9, 23), rng.randint(0, 59)))

        # 감상평: 작품은 회원 안에서 겹치지 않는다(작품당 1편). 날짜도 흩어 둔다.
        n_diary = rng.randint(3, 7)
        days = sorted(rng.sample(range(DAYS_BACK), n_diary), reverse=True)
        diary_works = rng.sample(pool, n_diary)
        templates = rng.sample(IMPRESSIONS, n_diary)
        written_works = set(session.scalars(select(DiaryEntry.artwork_id).where(DiaryEntry.user_id == user.id)))
        for back, work, template in zip(days, diary_works, templates, strict=True):
            day = today - timedelta(days=back)
            viewed = at_local(day, rng.randint(10, 20), rng.randint(0, 59))
            insert_ignore(session, ArtworkView, stats, "열람", user_id=user.id, artwork_id=work[0], viewed_on=day,
                          view_count=rng.randint(1, 4), first_viewed_at=viewed, last_viewed_at=viewed)
            # 난수는 건너뛸 때도 뽑아야 다음 회원·컬렉션 결과가 매번 같다.
            written = viewed + timedelta(minutes=rng.randint(5, 90))
            public = rng.random() < 0.85
            if work[0] in written_works:
                stats["감상평 유지"] += 1
                continue
            session.add(DiaryEntry(
                user_id=user.id, entry_date=day, artwork_id=work[0],
                content=template.format(title=work[1], artist=work[2]),
                is_public=public, created_at=written, updated_at=written,
            ))
            stats["감상평 추가"] += 1

        # 감상평과 별개로 둘러본 작품 열람 기록
        for work in rng.sample(pool, min(len(pool), 8)):
            day = today - timedelta(days=rng.randint(0, DAYS_BACK))
            viewed = at_local(day, rng.randint(9, 22), rng.randint(0, 59))
            insert_ignore(session, ArtworkView, stats, "열람", user_id=user.id, artwork_id=work[0], viewed_on=day,
                          view_count=rng.randint(1, 3), first_viewed_at=viewed, last_viewed_at=viewed)

        for name, description in rng.sample(COLLECTION_NAMES, rng.randint(1, 3)):
            made = at_local(today - timedelta(days=rng.randint(1, DAYS_BACK)), 21)
            col = session.scalar(select(Collection).where(Collection.user_id == user.id, Collection.name == name))
            if col is None:
                col = Collection(user_id=user.id, name=name, description=description, created_at=made, updated_at=made)
                session.add(col)
                session.flush()
                stats["컬렉션 추가"] += 1
            else:
                stats["컬렉션 유지"] += 1
            for work in rng.sample(pool, rng.randint(3, 6)):
                insert_ignore(session, CollectionItem, stats, "컬렉션 담기", collection_id=col.id, artwork_id=work[0])


def seed_follows(session: Session, users: list[User], fans: list[User], stats: Counter) -> None:
    today = today_local()
    real_ids = list(session.scalars(
        select(User.id).where(User.firebase_uid.not_like(f"{UID_PREFIX}%")).order_by(User.id)))
    for idx, user in enumerate(users, 1):
        rng = random.Random(f"{SEED}-follow-{idx}")
        others = [u.id for u in users if u.id != user.id]
        targets = rng.sample(others, rng.randint(3, 7))
        # 일부는 실제 회원도 팔로우해서 실제 계정의 팔로워 목록에도 보이게 한다.
        targets += [rid for rid in real_ids if rng.random() < 0.35]
        for target in targets:
            day = today - timedelta(days=rng.randint(0, DAYS_BACK))
            insert_ignore(session, UserFollow, stats, "회원 팔로우", follower_id=user.id, followee_id=target,
                          created_at=at_local(day, rng.randint(9, 23)))
    for fan in fans:
        rng = random.Random(f"{SEED}-fan-{fan.id}")
        for user in rng.sample(users, 8):
            insert_ignore(session, UserFollow, stats, "실제 계정→더미 팔로우", follower_id=fan.id, followee_id=user.id,
                          created_at=at_local(today - timedelta(days=rng.randint(0, 7)), 20))


def remove(session: Session) -> Counter:
    stats: Counter = Counter()
    ids = list(session.scalars(select(User.id).where(User.firebase_uid.like(f"{UID_PREFIX}%"))))
    if not ids:
        return stats
    # users 를 지우면 CASCADE 로 나머지가 지워지지만, 행 수를 보여 주려고 팔로우는 먼저 센다.
    r = session.execute(delete(UserFollow).where(
        or_(UserFollow.follower_id.in_(ids), UserFollow.followee_id.in_(ids))))
    stats["회원 팔로우 삭제"] += r.rowcount
    r = session.execute(delete(User).where(User.id.in_(ids)))
    stats["회원 삭제(설정·좋아요·감상평·컬렉션 등 포함)"] += r.rowcount
    return stats


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="바뀔 내용만 세고 되돌림")
    parser.add_argument("--remove", action="store_true", help="더미 회원과 그 활동을 지움")
    parser.add_argument("--fan", action="append", default=[],
                        help="더미 8명을 팔로우할 실제 계정 이메일. 여러 번 줄 수 있다. 생략하면 dev-user")
    args = parser.parse_args(argv)

    with SessionLocal() as session:
        if args.remove:
            stats = remove(session)
        else:
            if args.fan:
                emails = [e.strip().lower() for e in args.fan]
                fans = list(session.scalars(select(User).where(User.email.in_(emails))))
                missing = set(emails) - {f.email for f in fans}
                if missing:
                    raise SystemExit("계정이 없습니다: " + ", ".join(sorted(missing)))
            else:
                fans = list(session.scalars(select(User).where(User.firebase_uid == get_settings().dev_user_uid)))
            stats: Counter = Counter()
            users = upsert_members(session, stats)
            seed_activity(session, users, stats)
            seed_follows(session, users, fans, stats)
            print("팔로우하는 실제 계정: " + (", ".join(f.email for f in fans) or "(없음)"))
        for key, n in sorted(stats.items()):
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
