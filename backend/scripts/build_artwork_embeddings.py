"""DB `artworks` 로 작품 대표 벡터를 만들어 `artwork_embeddings` 에 넣는다 (추천용, 작품당 1행).

backend/ 에서 실행::

    uv run python -m scripts.build_artwork_embeddings --dry-run       # 임베딩할 글 미리 보기 (API 호출·쓰기 없음)
    uv run python -m scripts.build_artwork_embeddings                 # 전체 실행
    uv run python -m scripts.build_artwork_embeddings --with-artist   # 작가 이름까지 넣어 임베딩

임베딩할 글은 `제목 / 사조 / 재료·기법 / 설명` 한 덩어리다 (docs/rag-handoff.md 4절).
작가 이름을 넣으면 같은 작가 작품끼리 더 가까워지므로 기본으로는 넣지 않는다 (팀 결정 전).
작품 설명이 바뀌면 벡터도 바뀌어야 하는데 작품은 219점뿐이라, 매번 전부 다시 만들어 덮어쓴다 (API 호출 3번).
Chroma `artworks` 컬렉션으로 옮기는 일은 sync_chroma 가 한다.
"""

import argparse
from collections.abc import Callable
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.orm import Session

from app.clients import embedding_client
from app.models import Artist, ArtMovement, Artwork, ArtworkEmbedding

ROWS_PER_INSERT = 100


@dataclass(frozen=True)
class ArtworkRow:
    id: int
    title: str
    title_en: str | None
    artist_name: str
    movement_name: str | None
    medium: str | None
    description: str | None


def artwork_text(w: ArtworkRow, with_artist: bool = False) -> str:
    """임베딩할 글. 값이 없는 줄은 뺀다 (연작은 재료가 비어 있기도 함)."""
    title = f"{w.title} ({w.title_en})" if w.title_en and w.title_en != w.title else w.title
    lines = [
        f"제목: {title}",
        f"작가: {w.artist_name}" if with_artist else None,
        f"사조: {w.movement_name}" if w.movement_name else None,
        f"재료·기법: {w.medium}" if w.medium else None,
        f"설명: {w.description}" if w.description else None,
    ]
    return "\n".join(line for line in lines if line)


def load(session: Session) -> list[ArtworkRow]:
    """작품의 사조가 비어 있으면 작가의 대표 사조를 쓴다 (전처리 규칙과 같음)."""
    own = ArtMovement.__table__.alias("own_movement")
    artist_movement = ArtMovement.__table__.alias("artist_movement")
    rows = session.execute(
        select(
            Artwork.id, Artwork.title, Artwork.title_en, Artist.name.label("artist_name"),
            own.c.name.label("own_movement"), artist_movement.c.name.label("artist_movement"),
            Artwork.medium, Artwork.description,
        )
        .join(Artist, Artist.id == Artwork.artist_id)
        .outerjoin(own, own.c.id == Artwork.movement_id)
        .outerjoin(artist_movement, artist_movement.c.id == Artist.movement_id)
        .order_by(Artwork.id)
    )
    return [
        ArtworkRow(r.id, r.title, r.title_en, r.artist_name, r.own_movement or r.artist_movement, r.medium, r.description)
        for r in rows
    ]


def write(
    session: Session,
    artworks: list[ArtworkRow],
    model: str,
    embed: Callable[[list[str]], list[list[float]]],
    with_artist: bool = False,
) -> int:
    """전부 임베딩한 뒤 upsert 하고 한 번 커밋한다. API 가 실패하면 DB 를 건드리지 않는다."""
    vectors = embed([artwork_text(w, with_artist) for w in artworks])
    rows = [
        {"artwork_id": w.id, "embedding": v, "embedding_model": model}
        for w, v in zip(artworks, vectors, strict=True)
    ]
    table = ArtworkEmbedding.__table__
    for start in range(0, len(rows), ROWS_PER_INSERT):
        stmt = insert(table).values(rows[start : start + ROWS_PER_INSERT])
        session.execute(
            stmt.on_duplicate_key_update(embedding=stmt.inserted.embedding, embedding_model=stmt.inserted.embedding_model)
        )
    session.commit()
    return len(rows)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="임베딩할 글만 출력하고 API 호출·DB 쓰기를 하지 않음")
    parser.add_argument("--with-artist", action="store_true", help="작가 이름을 임베딩 글에 넣음")
    args = parser.parse_args(argv)

    # import 할 때 DB 엔진을 만들므로 테스트에서 피하려고 여기서 가져옴
    from app.db.session import SessionLocal

    model = embedding_client.model_name()
    with SessionLocal() as session:
        artworks = load(session)
        if not artworks:
            print("artworks 테이블이 비어 있습니다. 카탈로그 적재(load_catalog)를 먼저 실행하세요.")
            return 1
        texts = [artwork_text(w, args.with_artist) for w in artworks]
        print(f"모델 {model} · 작품 {len(artworks)}점 · {sum(map(len, texts)):,}자 · 작가 이름 {'포함' if args.with_artist else '제외'}")
        print(f"설명 없음 {sum(not w.description for w in artworks)}점 · 사조 없음 {sum(not w.movement_name for w in artworks)}점")
        if args.dry_run:
            print("--- 예시 ---\n" + texts[0])
            return 0
        written = write(session, artworks, model, embedding_client.embed_texts, args.with_artist)
    print(f"완료: 작품 벡터 {written}행 기록 (추가·갱신)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
