"""고른 작품 범위 안에서 질문과 가까운 청크를 찾는다 (docs/rag-handoff.md 5절).

1. TiDB 에서 범위 문서 id 를 구한다 (그 작품의 해설 + 작가의 생애·연표·비교 문서).
2. Chroma 에서 그 문서들의 청크 안에서만 질문과 가까운 k 개를 찾는다.
3. 거리와 상관없이 항상 넣을 청크를 붙인다: 그 작품을 언급한 연표 사건, 범위 안의 `답변 시 주의` 보정문.
4. 제목·출처·라이선스·편집 근거를 TiDB 에서 붙여 LangChain Document 로 돌려준다.

결과 형식 (기획서 v2 의 약속 2, app/rag/README.md):
    Document.page_content = 청크 본문 (머리말 `문서 제목 > 섹션` 포함, 프롬프트에 그대로 넣을 수 있음)
    Document.metadata = {
        chunk_id, chunk_index, document_id, doc_key, doc_type, title, source_name, source_url, license,
        distance,        # 코사인 거리, 작을수록 가까움
        pinned,          # True 면 거리 순위가 아니라 항상 넣는 규칙으로 들어온 청크 (거절 판단에서 제외해야 함)
        annotation,      # None | "감상 포인트" | "답변 시 주의" (프롬프트 규칙 7·8, 출처 표시)
        basis_sources,   # annotation 이 있을 때만 편집 근거 [{"source_name", "source_url"}], 없으면 []
    }
순서: 거리 순위 k 개 (오름차순) → 항상 넣는 청크 (오름차순). 범위가 비면 빈 리스트 (C 가 거절).
"""

from collections.abc import Callable

from chromadb.api.models.Collection import Collection
from langchain_core.documents import Document
from sqlalchemy.orm import Session

from app.clients import chroma_client, embedding_client
from app.rag.chunking import annotation_section
from app.repositories import document_repository as repo

TOP_K = 5


def retrieve(
    session: Session,
    artwork_id: int,
    question: str,
    k: int = TOP_K,
    *,
    collection: Collection | None = None,
    embed: Callable[[str], list[float]] | None = None,
) -> list[Document]:
    scope = repo.scope_document_ids(session, artwork_id)
    if not scope:  # 없는 작품. Chroma 의 $in 에 빈 목록을 넣으면 오류가 나므로 여기서 끝낸다
        return []
    vector = (embed or embedding_client.embed_query)(question)
    collection = collection or chroma_client.chunks_collection()

    ranked = _hits(collection.query(
        query_embeddings=[vector], n_results=k, where={"document_id": {"$in": scope}},
        include=["documents", "metadatas", "distances"],
    ))
    have = {h["id"] for h in ranked}
    extra = [str(i) for i in repo.pinned_chunk_ids(session, artwork_id, scope) if str(i) not in have]
    pinned = _hits(collection.query(
        query_embeddings=[vector], ids=extra, n_results=len(extra),
        include=["documents", "metadatas", "distances"],
    )) if extra else []

    hits = [(h, False) for h in ranked] + [(h, True) for h in pinned]
    sources = repo.document_sources(session, {h["metadata"]["document_id"] for h, _ in hits})
    return [_document(h, sources[h["metadata"]["document_id"]], is_pinned) for h, is_pinned in hits]


def _hits(result: dict) -> list[dict]:
    """Chroma query 결과(질문 1개)를 행 단위로 편다. 거리는 이미 오름차순."""
    return [
        {"id": i, "content": doc, "metadata": meta, "distance": dist}
        for i, doc, meta, dist in zip(
            result["ids"][0], result["documents"][0], result["metadatas"][0], result["distances"][0], strict=True
        )
    ]


def _document(hit: dict, source: repo.DocumentSource, pinned: bool) -> Document:
    annotation = annotation_section(hit["content"])
    return Document(
        page_content=hit["content"],
        metadata={
            "chunk_id": int(hit["id"]),
            "chunk_index": hit["metadata"]["chunk_index"],
            "document_id": source.document_id,
            "doc_key": source.doc_key,
            "doc_type": source.doc_type,
            "title": source.title,
            "source_name": source.source_name,
            "source_url": source.source_url,
            "license": source.license,
            "distance": round(float(hit["distance"]), 4),
            "pinned": pinned,
            "annotation": annotation,
            "basis_sources": source.basis_sources if annotation else [],
        },
    )
