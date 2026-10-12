"""data/processed 의 문서와 연결 정보를 TiDB 에 적재한다. load_catalog 를 먼저 실행해야 한다.

``backend/`` 에서 실행::

    uv run python -m scripts.load_documents            # 적재
    uv run python -m scripts.load_documents --dry-run  # 바뀔 내용만 세고 되돌림

- documents: doc_key 기준 upsert. 본문이 바뀐 문서는 기존 청크를 지운다(build_chunks 가 다시 만든다).
- document_artists / document_artworks / document_basis_documents: processed 문서마다 통째로 다시 맞춘다.
- processed 에 없는 DB 문서는 지우지 않고 개수만 알려 준다.
"""

from __future__ import annotations

import argparse
from collections import Counter

from sqlalchemy import delete, insert, select
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models import (
    Artist,
    Artwork,
    Document,
    DocumentArtist,
    DocumentArtwork,
    DocumentBasis,
    DocumentChunk,
)
from scripts.preprocess import load_processed

FIELDS = ("doc_type", "title", "content", "source_url", "source_name", "license", "lang", "topic",
          "needs_review", "basis_external_sources")


def lookup(ids: dict[str, int], slug: str, what: str, doc_key: str) -> int:
    if slug not in ids:
        raise ValueError(f"{doc_key}: {what} '{slug}' 가 DB 에 없습니다. load_catalog 를 먼저 실행하세요.")
    return ids[slug]


def load(session: Session) -> tuple[Counter, dict[str, int]]:
    rows = load_processed("documents.jsonl")
    artist_ids = dict(session.execute(select(Artist.slug, Artist.id)).all())
    artwork_ids = dict(session.execute(select(Artwork.slug, Artwork.id)).all())
    existing = {d.doc_key: d for d in session.scalars(select(Document))}
    stats: Counter = Counter()
    changed_content: list[int] = []

    for row in rows:
        key = row["doc_key"]
        values = {f: row[f] for f in FIELDS}
        values["artwork_id"] = lookup(artwork_ids, row["artwork_slug"], "작품", key) if row["artwork_slug"] else None
        doc = existing.get(key)
        if doc is None:
            session.add(Document(doc_key=key, **values))
            stats["추가"] += 1
        elif any(getattr(doc, k) != v for k, v in values.items()):
            if doc.content != values["content"]:
                changed_content.append(doc.id)
            for k, v in values.items():
                setattr(doc, k, v)
            stats["갱신"] += 1
        else:
            stats["유지"] += 1
    session.flush()

    if changed_content:
        stats["청크 삭제"] = session.execute(
            delete(DocumentChunk).where(DocumentChunk.document_id.in_(changed_content))).rowcount

    doc_ids = dict(session.execute(select(Document.doc_key, Document.id)).all())
    loaded = [doc_ids[r["doc_key"]] for r in rows]
    links = {"작가 연결": [], "작품 연결": [], "근거 연결": []}
    for row in rows:
        key, did = row["doc_key"], doc_ids[row["doc_key"]]
        links["작가 연결"] += [{"document_id": did, "artist_id": lookup(artist_ids, s, "작가", key)}
                           for s in dict.fromkeys(row["artist_slugs"])]
        links["작품 연결"] += [{"document_id": did, "artwork_id": lookup(artwork_ids, s, "작품", key)}
                           for s in dict.fromkeys(row["related_artwork_slugs"])]
        links["근거 연결"] += [{"document_id": did, "basis_document_id": lookup(doc_ids, b, "근거 문서", key)}
                           for b in dict.fromkeys(row["basis_doc_keys"])]
    for name, model in (("작가 연결", DocumentArtist), ("작품 연결", DocumentArtwork), ("근거 연결", DocumentBasis)):
        session.execute(delete(model).where(model.document_id.in_(loaded)))
        if links[name]:
            session.execute(insert(model), links[name])
    counts = {name: len(v) for name, v in links.items()}
    counts["processed 에 없는 DB 문서"] = len(set(doc_ids) - {r["doc_key"] for r in rows})
    counts["검토 필요 문서"] = sum(r["needs_review"] for r in rows)
    return stats, counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="processed 문서 → TiDB")
    parser.add_argument("--dry-run", action="store_true", help="바뀔 내용만 세고 커밋하지 않음")
    args = parser.parse_args(argv)

    with SessionLocal() as session:
        stats, counts = load(session)
        if args.dry_run:
            session.rollback()
        else:
            session.commit()

    print(f"문서: 추가 {stats['추가']} · 갱신 {stats['갱신']} · 유지 {stats['유지']}"
          + (f" · 본문 변경으로 청크 {stats['청크 삭제']}개 삭제" if stats["청크 삭제"] else ""))
    print(" · ".join(f"{k} {v}" for k, v in counts.items()))
    print("[dry-run] 커밋하지 않았습니다." if args.dry_run else "커밋했습니다.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
