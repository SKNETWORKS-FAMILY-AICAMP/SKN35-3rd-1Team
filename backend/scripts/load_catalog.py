"""data/processed 의 사조·작가·작품을 TiDB 에 적재한다.

``backend/`` 에서 실행::

    uv run python -m scripts.load_catalog            # 적재
    uv run python -m scripts.load_catalog --dry-run  # 바뀔 내용만 세고 되돌림

slug 를 기준으로 있으면 갱신하고 없으면 추가한다. processed 에 없는 행은 지우지 않는다
(좋아요·조회 기록이 작품을 참조할 수 있으므로). 대신 개수를 알려 준다.
"""

from __future__ import annotations

import argparse
from collections import Counter

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models import Artist, ArtMovement, Artwork
from scripts.preprocess import load_processed

MOVEMENT_FIELDS = ("name", "name_en", "description")
ARTIST_FIELDS = ("name", "name_en", "birth_year", "death_year", "nationality", "summary", "portrait_url")
ARTWORK_FIELDS = (
    "title", "title_en", "year_label", "year_start", "medium", "dimensions", "collection",
    "description", "image_url", "image_source_url", "image_license", "is_featured",
)


def upsert(session: Session, model: type, rows: list[dict], fields: tuple[str, ...],
           resolve: dict[str, callable] | None = None) -> tuple[dict[str, int], Counter, int]:
    """slug 기준 upsert. 돌려주는 값: (slug → id, 추가/갱신/유지 개수, processed 에 없는 DB 행 수)."""
    existing = {obj.slug: obj for obj in session.scalars(select(model))}
    stats: Counter = Counter()
    for row in rows:
        values = {f: row.get(f) for f in fields}
        for column, fn in (resolve or {}).items():
            values[column] = fn(row)
        obj = existing.get(row["slug"])
        if obj is None:
            session.add(model(slug=row["slug"], **values))
            stats["추가"] += 1
        elif any(getattr(obj, k) != v for k, v in values.items()):
            for k, v in values.items():
                setattr(obj, k, v)
            stats["갱신"] += 1
        else:
            stats["유지"] += 1
    session.flush()
    ids = {slug: id_ for slug, id_ in session.execute(select(model.slug, model.id))}
    orphans = len(set(ids) - {r["slug"] for r in rows})
    return ids, stats, orphans


def load(session: Session) -> dict[str, tuple[Counter, int]]:
    movements = load_processed("movements.jsonl")
    artists = load_processed("artists.jsonl")
    artworks = load_processed("artworks.jsonl")

    movement_ids, m_stats, m_orphans = upsert(session, ArtMovement, movements, MOVEMENT_FIELDS)

    def movement_id(row: dict) -> int | None:
        slug = row.get("movement_slug")
        if slug and slug not in movement_ids:
            raise ValueError(f"{row['slug']}: 사조 '{slug}' 가 없습니다")
        return movement_ids.get(slug) if slug else None

    artist_ids, a_stats, a_orphans = upsert(
        session, Artist, artists, ARTIST_FIELDS, {"movement_id": movement_id})

    def artist_id(row: dict) -> int:
        if row["artist_slug"] not in artist_ids:
            raise ValueError(f"{row['slug']}: 작가 '{row['artist_slug']}' 가 없습니다")
        return artist_ids[row["artist_slug"]]

    _, w_stats, w_orphans = upsert(
        session, Artwork, artworks, ARTWORK_FIELDS, {"artist_id": artist_id, "movement_id": movement_id})
    return {"사조": (m_stats, m_orphans), "작가": (a_stats, a_orphans), "작품": (w_stats, w_orphans)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="processed 사조·작가·작품 → TiDB")
    parser.add_argument("--dry-run", action="store_true", help="바뀔 내용만 세고 커밋하지 않음")
    args = parser.parse_args(argv)

    with SessionLocal() as session:
        result = load(session)
        if args.dry_run:
            session.rollback()
        else:
            session.commit()

    for name, (stats, orphans) in result.items():
        note = f" · processed 에 없는 DB 행 {orphans}" if orphans else ""
        print(f"{name}: 추가 {stats['추가']} · 갱신 {stats['갱신']} · 유지 {stats['유지']}{note}")
    print("[dry-run] 커밋하지 않았습니다." if args.dry_run else "커밋했습니다.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
