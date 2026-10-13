"""TiDB 의 청크·작품 벡터를 Chroma 로 옮긴다. 임베딩을 다시 만들지 않으므로 OpenAI 비용이 들지 않는다.

backend/ 에서 실행::

    uv run python -m scripts.sync_chroma --dry-run   # 추가·삭제할 건수만 출력 (Chroma 에 쓰지 않음)
    uv run python -m scripts.sync_chroma             # 동기화
    uv run python -m scripts.sync_chroma --reset     # 컬렉션을 지우고 처음부터 (모델·거리 함수를 바꿨을 때, 복구할 때)

순서: build_chunks · build_artwork_embeddings (TiDB 에 벡터 저장) → sync_chroma (docs/rag-handoff.md 4절).

- 청크(`chunks` 컬렉션): id = document_chunks.id. id 집합만 비교해 새 청크는 넣고 TiDB 에서 사라진 청크는 지운다.
  build_chunks 는 바뀐 문서의 청크를 지우고 새 id 로 넣으므로 id 비교만으로 본문 변경까지 따라간다.
- 작품(`artworks` 컬렉션): id = artwork_embeddings.artwork_id. 벡터가 같은 id 로 덮어써지므로 219건을 매번 upsert 한다.
- 메타데이터에는 검색 범위와 TiDB 조회에 필요한 값만 넣는다. 제목·출처·라이선스는 document_id 로 TiDB 에서 조회한다.
  Chroma 메타데이터에는 None 을 넣을 수 없어서 없는 id 는 0 으로 넣는다.
"""

import argparse
from collections.abc import Callable, Iterable, Iterator
from dataclasses import dataclass
from itertools import batched

from chromadb.api.models.Collection import Collection
from sqlalchemy import select
from sqlalchemy.orm import Session, undefer

from app.clients import chroma_client
from app.models import Artwork, ArtworkEmbedding, Document, DocumentChunk

# Chroma 한 번 호출에 넣는 건수. Chroma Cloud 는 요청당 300건 한도가 있어 그보다 작게 둔다
# (서버의 get_max_batch_size() 는 1,000 을 알려 주지만 실제 쿼터는 300 이라 믿을 수 없음).
BATCH = 250
TIDB_FETCH = 200  # TiDB 에서 벡터를 한 번에 읽는 행 수 (행마다 벡터 약 6KB)


@dataclass(frozen=True)
class Record:
    id: int
    embedding: list[float]
    document: str
    metadata: dict[str, int | str]


@dataclass
class Result:
    added: int = 0
    upserted: int = 0
    deleted: int = 0


def sync_chunks(
    collection: Collection,
    tidb_ids: set[int],
    fetch: Callable[[list[int]], Iterable[Record]],
    dry_run: bool = False,
) -> Result:
    """id 집합 차이로 추가·삭제한다. fetch 는 TiDB 에서 해당 id 의 청크를 읽는다 (테스트에서는 가짜 함수)."""
    in_chroma = chroma_ids(collection)
    gone = sorted(in_chroma - tidb_ids)
    new = sorted(tidb_ids - in_chroma)
    result = Result(added=len(new), deleted=len(gone))
    if dry_run:
        return result
    for ids in batched(gone, BATCH):
        collection.delete(ids=[str(i) for i in ids])
    for records in batched(fetch(new), BATCH):
        collection.add(**_payload(records))
    return result


def sync_artworks(collection: Collection, records: list[Record], dry_run: bool = False) -> Result:
    """전부 upsert 하고, TiDB 에 없는 작품은 지운다."""
    in_chroma = chroma_ids(collection)
    gone = sorted(in_chroma - {r.id for r in records})
    result = Result(upserted=len(records), deleted=len(gone))
    if dry_run:
        return result
    for ids in batched(gone, BATCH):
        collection.delete(ids=[str(i) for i in ids])
    for batch in batched(records, BATCH):
        collection.upsert(**_payload(batch))
    return result


def chroma_ids(collection: Collection) -> set[int]:
    """컬렉션의 id 전부. Chroma Cloud 는 get() 한 번에 300개까지만 돌려주므로 나눠서 끝까지 읽는다."""
    ids: set[int] = set()
    while page := collection.get(include=[], limit=BATCH, offset=len(ids))["ids"]:
        ids |= {int(i) for i in page}
    return ids


def _payload(records: Iterable[Record]) -> dict:
    records = list(records)
    return {
        "ids": [str(r.id) for r in records],
        "embeddings": [r.embedding for r in records],
        "documents": [r.document for r in records],
        "metadatas": [r.metadata for r in records],
    }


def chunk_ids(session: Session) -> set[int]:
    return set(session.scalars(select(DocumentChunk.id)))


def fetch_chunks(session: Session, ids: list[int]) -> Iterator[Record]:
    for part in batched(ids, TIDB_FETCH):
        rows = session.execute(
            select(DocumentChunk, Document.doc_key, Document.doc_type, Document.artwork_id)
            .join(Document, Document.id == DocumentChunk.document_id)
            .where(DocumentChunk.id.in_(part))
            .options(undefer(DocumentChunk.embedding))  # embedding 은 deferred 컬럼
            .order_by(DocumentChunk.id)
        )
        for c, doc_key, doc_type, artwork_id in rows:
            yield Record(
                id=c.id,
                embedding=c.embedding.tolist(),
                document=c.content,
                metadata={
                    "document_id": c.document_id,
                    "doc_key": doc_key,
                    "doc_type": doc_type.value,
                    "artwork_id": artwork_id or 0,
                    "chunk_index": c.chunk_index,
                },
            )


def fetch_artworks(session: Session) -> list[Record]:
    rows = session.execute(
        select(ArtworkEmbedding, Artwork.title, Artwork.artist_id, Artwork.movement_id)
        .join(Artwork, Artwork.id == ArtworkEmbedding.artwork_id)
        .options(undefer(ArtworkEmbedding.embedding))
        .order_by(ArtworkEmbedding.artwork_id)
    )
    return [
        Record(
            id=e.artwork_id,
            embedding=e.embedding.tolist(),
            document=title,
            metadata={"artist_id": artist_id, "movement_id": movement_id or 0},
        )
        for e, title, artist_id, movement_id in rows
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="추가·삭제할 건수만 출력")
    parser.add_argument("--reset", action="store_true", help="두 컬렉션을 지우고 처음부터 다시 넣음")
    args = parser.parse_args(argv)

    # import 할 때 DB 엔진을 만들므로 테스트에서 피하려고 여기서 가져옴
    from app.core.config import get_settings
    from app.db.session import SessionLocal

    settings = get_settings()
    chroma = chroma_client.client()
    chroma.heartbeat()  # 접속이 안 되면 여기서 바로 실패
    print(f"{chroma_client.describe()} · 컬렉션 {settings.chroma_chunks_collection}, {settings.chroma_artworks_collection}")
    if args.reset and not args.dry_run:
        for name in (settings.chroma_chunks_collection, settings.chroma_artworks_collection):
            if name in {c.name for c in chroma.list_collections()}:
                chroma.delete_collection(name)
                print(f"  컬렉션 {name} 삭제")

    chunks = chroma_client.chunks_collection(chroma)
    artworks = chroma_client.artworks_collection(chroma)
    with SessionLocal() as session:
        ids = chunk_ids(session)
        r1 = sync_chunks(chunks, ids, lambda new: fetch_chunks(session, new), args.dry_run)
        r2 = sync_artworks(artworks, fetch_artworks(session), args.dry_run)

    print(f"청크: 추가 {r1.added} · 삭제 {r1.deleted}  |  작품: upsert {r2.upserted} · 삭제 {r2.deleted}")
    if args.dry_run:
        return 0
    n_chunks, n_artworks = chunks.count(), artworks.count()
    print(f"Chroma 청크 {n_chunks}개 (TiDB {len(ids)}) · 작품 {n_artworks}개 (TiDB {r2.upserted})")
    if n_chunks != len(ids) or n_artworks != r2.upserted:
        print("[경고] Chroma 와 TiDB 의 개수가 다릅니다. 다시 실행하거나 --reset 으로 복구하세요.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
