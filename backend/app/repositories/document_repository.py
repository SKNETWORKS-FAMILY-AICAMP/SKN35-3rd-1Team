"""챗봇 검색에 쓰는 TiDB 조회. 벡터 거리는 Chroma 가 계산하고, 여기서는 범위와 출처만 다룬다 (docs/rag-handoff.md 5·6절)."""

from dataclasses import dataclass, field

from sqlalchemy import func, select, union
from sqlalchemy.orm import Session

from app.models import (
    Artist,
    Artwork,
    Document,
    DocumentArtist,
    DocumentArtwork,
    DocumentBasis,
    DocumentChunk,
)
from app.rag.chunking import ANNOTATION_SECTIONS, annotation_section

CORRECTION = ANNOTATION_SECTIONS[1]  # "답변 시 주의": 원문의 오래된 정보·오류를 바로잡은 보정문


@dataclass(frozen=True)
class DocumentSource:
    """답변 아래 출처 표시에 쓰는 값."""

    document_id: int
    doc_key: str
    doc_type: str
    title: str
    source_name: str | None
    source_url: str | None
    license: str | None
    # 덧붙인 절(감상 포인트·답변 시 주의)의 편집 근거: [{"source_name", "source_url"}]
    basis_sources: list[dict[str, str | None]] = field(default_factory=list)


def scope_document_ids(session: Session, artwork_id: int) -> list[int]:
    """① 그 작품의 해설 + ②③ 그 작가가 연결된 생애·연표·비교 문서. 작품이 없으면 빈 목록."""
    own = select(Document.id).where(Document.artwork_id == artwork_id)
    by_artist = (
        select(DocumentArtist.document_id)
        .join(Artwork, Artwork.artist_id == DocumentArtist.artist_id)
        .where(Artwork.id == artwork_id)
    )
    return sorted(session.scalars(select(union(own, by_artist).subquery().c[0])))


def pinned_chunk_ids(session: Session, artwork_id: int, scope_ids: list[int]) -> list[int]:
    """거리와 상관없이 항상 넣을 청크.

    - ④ 그 작품을 언급한 연표 사건(document_artworks). 질문 벡터만으로는 상위에 오지 않을 수 있다.
    - 범위 안 문서의 `답변 시 주의` 보정문. 짧아서 순위에서 밀리면 원문의 틀린 정보로 답하게 된다.
    """
    timeline = select(DocumentChunk.id).join(
        DocumentArtwork, DocumentArtwork.document_id == DocumentChunk.document_id
    ).where(DocumentArtwork.artwork_id == artwork_id)
    ids = set(session.scalars(timeline))
    if scope_ids:
        header = func.substring_index(DocumentChunk.content, "\n", 1)
        rows = session.execute(
            select(DocumentChunk.id, DocumentChunk.content)
            .where(DocumentChunk.document_id.in_(scope_ids), header.like(f"%> {CORRECTION}%"))
        )
        ids |= {i for i, content in rows if annotation_section(content) == CORRECTION}
    return sorted(ids)


def document_sources(session: Session, document_ids: set[int]) -> dict[int, DocumentSource]:
    if not document_ids:
        return {}
    docs = session.scalars(select(Document).where(Document.id.in_(document_ids))).all()
    basis: dict[int, list[dict[str, str | None]]] = {d.id: list(d.basis_external_sources or []) for d in docs}
    rows = session.execute(
        select(DocumentBasis.document_id, Document.source_name, Document.source_url)
        .join(Document, Document.id == DocumentBasis.basis_document_id)
        .where(DocumentBasis.document_id.in_(document_ids))
        .order_by(DocumentBasis.document_id, Document.doc_key)
    )
    for doc_id, name, url in rows:
        basis[doc_id].insert(0, {"source_name": name, "source_url": url})  # 데이터셋 안 근거를 앞에
    return {
        d.id: DocumentSource(
            document_id=d.id, doc_key=d.doc_key, doc_type=d.doc_type.value, title=d.title,
            source_name=d.source_name, source_url=d.source_url, license=d.license, basis_sources=basis[d.id],
        )
        for d in docs
    }


def artwork_artist_slug(session: Session, artwork_id: int) -> str | None:
    """질문 분류(app.rag.classifier)에 넘길 '고른 작품의 작가' slug. 없는 작품이면 None."""
    return session.scalar(select(Artist.slug).join(Artwork, Artwork.artist_id == Artist.id).where(Artwork.id == artwork_id))
