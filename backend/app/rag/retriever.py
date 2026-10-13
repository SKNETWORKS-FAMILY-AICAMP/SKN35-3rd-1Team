"""고른 작품 범위 안에서 질문과 가까운 청크를 찾는다 (docs/rag-handoff.md 5절).

1. TiDB 에서 범위 문서 id 를 구한다 (그 작품의 해설 + 작가의 생애·연표·비교 문서).
2. Chroma 에서 그 문서들의 청크 안에서만 질문과 가까운 k 개를 찾는다. 여기에 자리 두 가지를 보장한다.
   - 고른 작품 자신의 해설에서 OWN_K 개. 작가 생애 문서는 청크가 많아 상위를 다 차지하기 쉽다
     (평가: 『야경』 "인물 배치" 질문에서 야경 해설이 80위 밖).
   - 비교를 묻는 질문이면 범위 안 비교 문서에서 COMPARISON_K 개 (예: 명암 기법 문서가 17위·55위).
   두 자리는 문서마다 하나씩 돌아가며 채운다. 한국어 원문과 영문 번역본이 함께 있는 작품(야경)이나
   비교 문서가 여러 건인 작가(테네브리즘·키아로스쿠로)에서 한 문서가 자리를 다 가져가지 않게 하기 위해서다.
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
순서: 거리로 고른 청크 (2번, 오름차순) → 항상 넣는 청크 (3번, 오름차순). 범위가 비면 빈 리스트 (C 가 거절).
"""

from collections.abc import Callable

import numpy as np
from chromadb.api.models.Collection import Collection
from langchain_core.documents import Document
from sqlalchemy.orm import Session

from app.clients import chroma_client, embedding_client
from app.rag.chunking import annotation_section
from app.repositories import document_repository as repo

TOP_K = 5
OWN_K = 3  # 고른 작품 자신의 해설에 보장하는 자리
COMPARISON_K = 2  # 비교 질문일 때 비교 문서에 보장하는 자리
SEAT_POOL = 20  # 자리를 고를 후보 수 (문서마다 하나씩 고르려면 k 보다 넉넉해야 함)
COMPARISON_HINTS = ("비교", "차이", "달라", "다른 점", "다르게", "공통", "관계")
INCLUDE = ["documents", "metadatas", "distances"]


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

    def search(where: dict, n: int) -> list[dict]:
        return _hits(collection.query(query_embeddings=[vector], n_results=n, where=where, include=INCLUDE))

    in_scope = {"document_id": {"$in": scope}}
    own_scope = {"$and": [in_scope, {"artwork_id": artwork_id}]}
    found = search(in_scope, k) + _one_per_document(search(own_scope, SEAT_POOL), OWN_K)
    if is_comparison(question):
        comparisons = search({"$and": [in_scope, {"doc_type": "artist_comparison"}]}, SEAT_POOL)
        found += _one_per_document(comparisons, COMPARISON_K)
    ranked = sorted({h["id"]: h for h in found}.values(), key=lambda h: h["distance"])

    have = {h["id"] for h in ranked}
    extra = [str(i) for i in repo.pinned_chunk_ids(session, artwork_id, scope) if str(i) not in have]
    pinned = _fetch_with_distance(collection, extra, vector) if extra else []

    hits = [(h, False) for h in ranked] + [(h, True) for h in pinned]
    sources = repo.document_sources(session, {h["metadata"]["document_id"] for h, _ in hits})
    return [_document(h, sources[h["metadata"]["document_id"]], is_pinned) for h, is_pinned in hits]


def is_comparison(question: str) -> bool:
    """비교 문서 자리를 줄지 정하는 단순 규칙. 놓쳐도 일반 순위로는 검색되므로 넓게 잡지 않는다."""
    return any(hint in question for hint in COMPARISON_HINTS)


def _one_per_document(hits: list[dict], n: int) -> list[dict]:
    """거리순 후보에서 자리를 고르게 나눈다: 주제마다 1개 → 아직 안 뽑힌 문서마다 1개 → 나머지 거리순.

    주제는 한국어 원문과 영문 번역본을 하나로 본다 (`doc_key` 의 `.en` 앞부분). 그래서 비교 자리 2개를
    테네브리즘 원문·번역본이 나눠 갖지 않고 테네브리즘·키아로스쿠로가 하나씩 받는다. 같은 작품의
    원문·번역본(야경)은 두 번째 단계에서 원문도 한 자리를 받는다.
    """
    topics: set[str] = set()
    docs: set[int] = set()
    by_topic, by_doc, rest = [], [], []
    for h in hits:
        topic = h["metadata"]["doc_key"].removesuffix(".en")
        doc_id = h["metadata"]["document_id"]
        if topic not in topics:
            by_topic.append(h)
        elif doc_id not in docs:
            by_doc.append(h)
        else:
            rest.append(h)
        topics.add(topic)
        docs.add(doc_id)
    return (by_topic + by_doc + rest)[:n]


def _fetch_with_distance(collection: Collection, ids: list[str], vector: list[float]) -> list[dict]:
    """항상 넣는 청크는 get() 으로 확실히 가져오고 코사인 거리는 직접 계산한다.

    query(ids=...) 는 쓰지 않는다. Chroma Cloud 는 근사 검색 후보에 들지 못한 id 를 결과에서 빼 버려서
    (평가: 『다나에』 연표 2개 중 1개, 『카드 사기꾼』 1개 중 0개만 돌아옴) "항상 넣는다"가 깨진다.
    """
    got = collection.get(ids=ids, include=["documents", "metadatas", "embeddings"])
    q = np.asarray(vector, dtype=float)
    hits = [
        {"id": i, "content": doc, "metadata": meta,
         "distance": 1.0 - float(np.dot(q, e) / (np.linalg.norm(q) * np.linalg.norm(e)))}
        for i, doc, meta, e in zip(got["ids"], got["documents"], got["metadatas"], got["embeddings"], strict=True)
    ]
    return sorted(hits, key=lambda h: h["distance"])


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
