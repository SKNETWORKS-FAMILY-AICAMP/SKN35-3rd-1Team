# RAG 담당(B) 인계 문서

데이터는 DB에 모두 들어가 있습니다. B는 **청킹·임베딩 → 검색 → 답변 생성**만 만들면 됩니다. 이 문서는 위에서부터 순서대로 따라 하면 되도록 썼습니다.

기준: 2026-10-12 · 작가 8명 · 작품 219점 · 문서 361건 (모두 한국어, 모두 검토 완료)

**저장 위치 (10/12 결정)**: 청크와 벡터는 **TiDB에 원본으로 저장**하고(`document_chunks`, `artwork_embeddings`), 같은 내용을 **Chroma에 옮겨 검색은 Chroma로** 합니다. TiDB에 벡터가 있으므로 Chroma가 날아가도 OpenAI를 다시 부르지 않고 그대로 복원할 수 있고, 검색 결과를 TiDB `VEC_COSINE_DISTANCE`와 비교해 볼 수도 있습니다.

```text
documents ─(build_chunks: 자르기·임베딩)→ TiDB document_chunks ─(sync_chroma: 옮기기)→ Chroma chunks
artworks  ─(build_artwork_embeddings)───→ TiDB artwork_embeddings ─(sync_chroma)──────→ Chroma artworks
```

## 0. 한눈에 보기

### 지금 상태

| 항목 | 상태 | 비고 |
| --- | --- | --- |
| 전처리 (`data/processed/`) | 완료 | 검토 필요 0건 |
| DB 스키마 | 완료 | Alembic `20261012_0003`까지 적용 |
| 카탈로그·문서 적재 | 완료 | 사조 4 · 작가 8 · 작품 219 · 문서 361 · 작가 연결 134 · 작품 연결 173 · 근거 연결 135 |
| 검색 범위 SQL (5절) | 실제 DB에서 확인 | 『야경』 범위 28건, 연표 연결 1건 |
| `document_chunks` (TiDB) | **비어 있음 → B** | 3·4절 |
| `artwork_embeddings` (TiDB) | **비어 있음 → B** | 4절 |
| Chroma `chunks`·`artworks` 컬렉션 | **비어 있음 → B** | 4절 동기화 |
| 검색·답변 서비스 (`app/rag`, `app/services`) | **비어 있음 → B** | 5·6절 |

### B가 할 일 (순서대로)

1. **환경 준비** — 루트 `.env`에 `OPENAI_API_KEY`와 Chroma 접속 정보를 추가합니다 (`.env.example`에는 아직 없음). 로컬 실험은 `chromadb.PersistentClient(path=...)`, 배포·공용 적재는 Railway의 Chroma 서버에 `chromadb.HttpClient`로 붙습니다. `chromadb`·`langchain-chroma` 의존성은 별도로 추가합니다.
   - 완료 기준: `uv run python -m scripts.check_db`가 `missing=(none)`이고, Chroma `heartbeat()`가 응답
2. **청킹·임베딩 스크립트** `backend/scripts/build_chunks.py` — 청크가 없는 문서만 골라 잘라서 임베딩하고 TiDB `document_chunks`에 넣습니다 (1·3·4절).
   - 완료 기준: 모든 문서에 청크가 1개 이상, 다시 실행하면 0건 처리
3. **작품 임베딩 스크립트** `backend/scripts/build_artwork_embeddings.py` — 작품 219점의 벡터를 TiDB `artwork_embeddings`에 넣습니다 (4절).
   - 완료 기준: 219행
4. **Chroma 동기화 스크립트** `backend/scripts/sync_chroma.py` — TiDB의 청크·작품 벡터를 Chroma로 옮기고, TiDB에서 사라진 것은 Chroma에서도 지웁니다. 임베딩을 다시 만들지 않습니다 (4절).
   - 완료 기준: Chroma `chunks` 개수 = `document_chunks` 행 수, `artworks` 개수 = 219, 다시 실행하면 추가·삭제 0건
5. **검색 함수** (`app/rag`) — 고른 작품 범위 안에서만 Chroma로 벡터 검색하고, 연표 사건을 항상 붙입니다 (5절).
6. **답변 생성** (`app/services`) — 6절의 시스템 프롬프트 규칙과 출처 표시를 적용합니다.
7. **검증** — 9절 테스트 질문 27개를 돌려서 기대 문서가 근거로 나오는지, 거절해야 할 질문을 거절하는지 확인합니다.

### B가 쓰는 저장소

| 구분 | 대상 |
| --- | --- |
| B가 **읽기만** (TiDB) | `documents`, `artworks`, `artists`, `art_movements`, `document_artists`, `document_artworks`, `document_basis_documents` |
| B가 **씀** (TiDB, 원본) | `document_chunks`, `artwork_embeddings` |
| B가 **씀** (Chroma, 검색용 사본) | `chunks` 컬렉션, `artworks` 컬렉션 — `sync_chroma`만 씀 |
| RAG 범위 아님 (TiDB) | `users`, `artwork_likes`, `artist_follows`, `artwork_views` — 서비스에서는 앱이 채우고, 발표용 시연 데이터는 `scripts/seed_demo_users.py`(미작성, 담당 미정)로 넣을 예정 |

연결 고리는 `document_chunks.document_id` → `documents.id`, `artwork_embeddings.artwork_id` → `artworks.id`, 그리고 Chroma id = TiDB 행 id 세 가지입니다. Chroma 검색 결과의 `document_id`로 출처·연표·작가 연결을 TiDB에서 조회합니다.

## 1. 데이터 읽기

청크에 `document_id`를 넣어야 하므로 **DB에서 읽습니다.** 청크가 아직 없는 문서만 고르면 처음 실행과 재실행을 같은 코드로 처리할 수 있습니다.

```python
# backend/ 에서 실행
from sqlalchemy import select
from app.db.session import SessionLocal
from app.models import Document

with SessionLocal() as session:
    todo = session.scalars(select(Document).where(~Document.chunks.any())).all()
    # 처음에는 361건, 다 처리한 뒤에는 0건
```

DB 없이 빠르게 실험만 해 볼 때는 같은 내용을 파일에서 읽을 수 있습니다. 파일을 직접 열지 말고 `load_processed()`를 쓰세요 (전처리가 중간에 실패한 결과를 걸러 줍니다).

```python
from scripts.preprocess import load_processed
docs = load_processed("documents.jsonl")   # list[dict], 361건
```

### 작가 별칭 (`artist_aliases.jsonl`)

질문 속 작가를 알아보는 데 씁니다 ("고흐", "반 고흐", "Van Gogh"는 모두 `vincent-van-gogh`). 기획된 10명 전부가 들어 있고, `status`가 `collected`(데이터 있음) 또는 `planned`(수집 전, 클림트·실레)입니다. 목록에 없는 작가(피카소 등)는 다루지 않는 작가입니다. `confusable`은 이름이 비슷하지만 연결하면 안 되는 이름입니다 (예: 모네 ↔ 마네, 정선 ↔ 강원도 정선). 이 파일은 DB에 넣지 않았으므로 `load_processed("artist_aliases.jsonl")`로 읽습니다.

## 2. 문서 한 건의 모양

```json
{
  "doc_key": "rembrandt/timeline-05",
  "doc_type": "artist_bio",
  "title": "렘브란트 판 레인 연표: 1641–1642 아들 티투스의 탄생과 사스키아의 죽음, 그리고 『야경』",
  "content": "1641–1642 · 아들 티투스의 탄생과 …\n…\n등장 인물: 사스키아 (아내), 티투스 (아들)\n관련 작품: 『야경』",
  "artist_slugs": ["rembrandt"],
  "artwork_slug": null,
  "source_url": "https://en.wikipedia.org/wiki/Rembrandt",
  "source_name": "Wikipedia (영문)",
  "license": "CC BY-SA 4.0",
  "lang": "ko",
  "topic": "연표",
  "related_artwork_slugs": ["the-night-watch"],
  "basis_doc_keys": [],
  "basis_external_sources": [],
  "needs_review": false
}
```

| 필드 (파일) | DB 위치 | 쓰는 곳 |
| --- | --- | --- |
| `doc_key` | `documents.doc_key` (UNIQUE) | 문서 고유 키. 문의할 때 이 값을 알려 주세요 |
| `doc_type` | `documents.doc_type` | `artist_bio` / `artwork_commentary` / `artist_comparison` |
| `title`, `source_name`, `source_url`, `license` | `documents` 같은 이름 | 답변 아래 출처 표시 (6절) |
| `artwork_slug` | `documents.artwork_id` | 해설 문서의 대상 작품 |
| `artist_slugs` | `document_artists` | 생애·비교 문서의 작가 |
| `related_artwork_slugs` | `document_artworks` | 연표 사건이 언급하는 작품 |
| `basis_doc_keys` | `document_basis_documents` | 덧붙인 보충·보정문의 근거 문서. 출처 표시에 함께 씀 |
| `basis_external_sources` | `documents.basis_external_sources` (JSON) | 데이터셋 밖 근거 `[{"source_name", "source_url"}]` |
| `topic` | `documents.topic` | 생애 문서의 성격 (`연표`, `생애 전체`, `주변 인물` 등) |
| `needs_review` | `documents.needs_review` | 지금은 361건 모두 `false` (7절) |

## 3. 청킹

문서 길이가 종류마다 크게 달라서, 한 가지 길이로 일괄 자르지 말고 종류별로 자르는 것을 권장합니다.

| 문서 | 건수 | 본문 길이 (최소 / 중앙값 / 최대) | 권장 |
| --- | --- | --- | --- |
| 연표 (`topic: "연표"`) | 71 | 131 / 199 / 296자 | 자르지 않음. 문서 하나 = 청크 하나 |
| 고흐·고갱 팀 작성 문서 | 62 | 543 / 1,202 / 1,399자 | 짧은 문서는 자르지 않음. 작품 해설은 `## 감상 포인트` 앞뒤로 나눌 수 있음. `[화면 관찰]`, `[근거 있는 해석]` 같은 구간 표시는 그대로 둠 |
| 모네·세잔 주제 문서 | 8 | 590 / 634 / 649자 | 문서 하나 = 청크 하나 |
| 위키 원문·번역본 | 130 | 347 / 2,079 / 33,056자 | `## 제목` 섹션 단위로 먼저 나누고, 긴 섹션만 문단 경계에서 다시 자름 |
| 김홍도·정선 기관 원문·번역본 | 89 | 214 / 850 / 6,922자 | `##` 절을 먼저 나누고 긴 절은 문단·문장 경계로 다시 자름 |

규칙:

- **머리말을 붙입니다.** 청크 앞에 `문서 제목 > 섹션 제목`을 붙이면 짧은 조각도 맥락을 잃지 않습니다. 예: `카라바조의 생애 (영문 번역) > 추방과 죽음 (1606–1610) > 몰타`. 섹션 제목 줄(`## …`)은 본문에서 빼고 머리말로만 씁니다.
- **덧붙인 절은 제목을 유지합니다.** `## 감상 포인트`(편집 보충문)와 `## 답변 시 주의`(보정문)는 원문 뒤에 붙인 절입니다. 이 절을 자른 청크도 머리말에 절 제목이 남아 있어야 LLM이 원문과 구분할 수 있습니다.
- **`content`에는 머리말까지 포함해 저장하고, 같은 텍스트로 임베딩합니다.** 검색 결과를 그대로 프롬프트에 넣을 수 있습니다.
- 본문 합계는 약 65만 자입니다. 500자 기준 약 1,300개 청크이고, 섹션 경계에서 자르면 조금 더 늘어납니다 (추정).

저장 형식 (TiDB):

```python
from langchain_openai import OpenAIEmbeddings
from app.models import DocumentChunk

EMBEDDING_MODEL = "text-embedding-3-small"
embeddings = OpenAIEmbeddings(model=EMBEDDING_MODEL)

for doc in todo:                                   # 1절의 청크 없는 문서
    pieces = split(doc)                            # 위 규칙대로 자른 문자열 목록 (머리말 포함)
    vectors = embeddings.embed_documents(pieces)   # 여러 건 묶어 호출
    session.add_all(
        DocumentChunk(document_id=doc.id, chunk_index=i, content=text,
                      embedding=vec, embedding_model=EMBEDDING_MODEL)
        for i, (text, vec) in enumerate(zip(pieces, vectors))
    )
session.commit()
```

- `(document_id, chunk_index)`는 UNIQUE입니다. `chunk_index`는 0부터 매깁니다.
- `content` 컬럼은 `TEXT`(약 64KB)라 청크 하나로는 넉넉합니다.

## 4. 임베딩과 Chroma 동기화

- **차원**: DB 컬럼은 `VECTOR(1536)`입니다 (`backend/app/models/base.py`의 `EMBEDDING_DIMENSION`). `text-embedding-3-small`(1536차원) 기준입니다. 다른 모델을 쓰려면 Alembic 마이그레이션으로 컬럼을 바꾸고, Chroma 컬렉션도 지우고 다시 만들어야 합니다.
- **모델 이름 기록**: `embedding_model`에 모델 이름을 꼭 넣습니다. 모델이 섞이면 거리 값이 의미가 없어집니다. 검색할 때 질문도 같은 모델로 임베딩합니다.
- **비용**: 여러 건을 묶어 호출하고, 이미 TiDB에 있는 벡터는 다시 만들지 않습니다. Chroma는 TiDB 벡터를 옮기기만 하므로 OpenAI 비용이 들지 않습니다.
- **겹치는 문서**: 같은 주제를 한국어 원문과 번역본이 함께 다루는 경우가 있습니다 (예: 『야경』, 키아로스쿠로). 내용이 겹치는 청크가 상위에 나란히 나오면 `doc_key`가 다른 것을 하나씩만 고르면 됩니다.

### Chroma 동기화 (`sync_chroma.py`)

TiDB가 원본이고 Chroma는 검색용 사본입니다. **Chroma id는 TiDB 행 id**(`document_chunks.id`, `artwork_embeddings.artwork_id`)를 문자열로 바꾼 값입니다. id 집합만 비교하면 추가할 것과 지울 것이 바로 나옵니다.

```python
from itertools import batched                            # Python 3.12+
import chromadb
from sqlalchemy import select
from sqlalchemy.orm import undefer
from app.models import Document, DocumentChunk

client = chromadb.HttpClient(host=..., port=...)        # 로컬 실험은 chromadb.PersistentClient(path=...)
chunks = client.get_or_create_collection(
    "chunks",                                           # 개발용·발표용은 이름을 나눔 (예: chunks_dev)
    metadata={"hnsw:space": "cosine", "embedding_model": EMBEDDING_MODEL},
)

in_chroma = set(chunks.get(include=[])["ids"])
with SessionLocal() as session:
    in_tidb = {str(i) for i in session.scalars(select(DocumentChunk.id))}

    gone = list(in_chroma - in_tidb)                    # 본문이 바뀌어 TiDB에서 지워진 청크
    if gone:
        chunks.delete(ids=gone)

    new_ids = [int(i) for i in in_tidb - in_chroma]
    rows = session.execute(
        select(DocumentChunk, Document)
        .join(Document, Document.id == DocumentChunk.document_id)
        .where(DocumentChunk.id.in_(new_ids))
        .options(undefer(DocumentChunk.embedding))      # embedding은 deferred 컬럼
    ).all()
    for batch in batched(rows, 500):                    # 한 번에 너무 많이 넣지 않음
        chunks.add(
            ids=[str(c.id) for c, _ in batch],
            documents=[c.content for c, _ in batch],
            embeddings=[list(c.embedding) for c, _ in batch],
            metadatas=[{
                "document_id": d.id,
                "doc_key": d.doc_key,
                "doc_type": d.doc_type.value,
                "artwork_id": d.artwork_id or 0,        # Chroma 메타데이터에는 None을 넣을 수 없음
                "chunk_index": c.chunk_index,
            } for c, d in batch],
        )
```

- 컬렉션을 만들 때 거리 함수를 `cosine`으로 지정합니다 (Chroma 기본값은 `l2`). 이미 만든 컬렉션의 거리 함수는 바꿀 수 없습니다.
- 메타데이터에는 검색 범위와 TiDB 조회에 필요한 값만 넣습니다. 제목·출처·라이선스는 `document_id`로 TiDB에서 조회합니다 (5·6절). 작가 목록은 넣지 않고, 범위는 5절처럼 TiDB에서 문서 id로 구합니다.
- Chroma가 비거나 날아가면 컬렉션을 지우고 `sync_chroma`만 다시 돌리면 복원됩니다.

### 작품 벡터 (`artwork_embeddings` → Chroma `artworks`)

추천용 작품 벡터입니다. TiDB에는 작품 하나에 한 행입니다 (`artwork_id`가 PK). Chroma `artworks` 컬렉션의 id는 `artwork_id`이고, 메타데이터에 `artist_id`, `movement_id`(값이 없으면 `0`)를 넣으면 "같은 작가 제외" 같은 조건을 `where`로 걸 수 있습니다. 작품 설명이 바뀌면 벡터도 바뀌므로, 219건은 매번 `upsert`로 전부 덮어써도 됩니다.

- 임베딩할 텍스트: `제목 / 사조 이름 / 재료·기법(medium) / 설명(description)`을 한 덩어리로 만듭니다.
- 작가 이름을 넣으면 같은 작가 작품끼리 더 가까워집니다. 넣을지는 팀에서 정합니다.
- 연작(건초더미, 수련 등)은 `collection`·`dimensions`가 비어 있을 수 있습니다 (의도된 null).

## 5. 검색: 작품을 골랐을 때의 범위

챗봇은 사용자가 고른 작품 범위 안에서만 답합니다. **범위에 드는 문서 id를 TiDB에서 먼저 구하고, Chroma에서는 그 문서들의 청크 안에서만 검색합니다.** 범위 안 문서는 많아야 수십 건이라 `$in` 필터 하나로 충분합니다.

| 근거 | 찾는 방법 | 비고 |
| --- | --- | --- |
| ① 그 작품의 해설 | `documents.artwork_id = :artwork_id` | 한국어 원문과 번역본이 둘 다 있을 수 있음 (예: 야경) |
| ② 그 작가의 생애·주변 인물·연표 | `document_artists.artist_id = 작품의 작가` | 연표 사건 전부 포함 |
| ③ 그 작가가 들어간 비교 문서 | ②와 같음 (`artist_comparison`도 `document_artists`에 연결) | 예: 고흐·고갱 비교, 명암 기법 |
| ④ 그 작품을 언급한 연표 사건 | `document_artworks.artwork_id = :artwork_id` | ②에 이미 포함됨. **거리와 상관없이 항상 컨텍스트에 넣는 용도** |

④가 필요한 이유: 사용자가 『야경』을 고르고 "그때 렘브란트는 어땠어?"라고 물으면, 질문 벡터만으로는 "사스키아의 죽음" 사건이 상위에 오지 않을 수 있습니다. 작품과 연결된 연표 사건을 거리 순위와 별개로 항상 넣으면 스토리텔링 답변이 안정됩니다.

```sql
-- ①②③ 범위에 드는 문서 id (TiDB)
SELECT id FROM documents WHERE artwork_id = :artwork_id                      -- ①
UNION
SELECT da.document_id FROM document_artists AS da                           -- ②③
JOIN artworks AS aw ON aw.artist_id = da.artist_id
WHERE aw.id = :artwork_id;

-- ④ 작품과 연결된 연표 사건 (거리와 상관없이 함께 넣음, TiDB)
SELECT d.id, d.doc_key, d.title, d.content, d.source_name, d.source_url
FROM document_artworks AS dw
JOIN documents AS d ON d.id = dw.document_id
WHERE dw.artwork_id = :artwork_id
ORDER BY d.doc_key;
```

```python
# 범위 안에서 질문과 가까운 청크 5개 (Chroma)
result = chunks.query(
    query_embeddings=[embeddings.embed_query(question)],
    n_results=5,
    where={"document_id": {"$in": scope_ids}},          # 위 ①②③의 결과
    include=["documents", "metadatas", "distances"],
)
# result["distances"][0]: 코사인 거리, 작을수록 비슷함 (이미 오름차순)
# 제목·출처·라이선스는 metadatas의 document_id로 TiDB documents에서 한 번에 조회
```

- `scope_ids`가 비어 있으면 Chroma를 부르지 말고 바로 거절합니다 (`$in`에 빈 목록을 넣으면 오류).
- `include`에 `embeddings`를 넣지 않습니다. 벡터가 통째로 네트워크로 넘어옵니다.
- LangChain을 쓰면 `langchain_chroma.Chroma(client=client, collection_name="chunks", embedding_function=embeddings)`의 `similarity_search_with_score(question, k=5, filter={"document_id": {"$in": scope_ids}})`로 같은 검색을 할 수 있습니다.
- **비교·디버깅용**: TiDB에도 같은 벡터가 있으므로 `docs/db/02_queries.sql` C절처럼 `VEC_COSINE_DISTANCE`로 같은 범위를 검색해 Chroma 결과와 비교할 수 있습니다. 상위 결과가 크게 다르면 동기화가 덜 된 것입니다.
- 범위 조건(①②③)과 ④는 실제 DB에서 확인했습니다 (『야경』 28건·연표 1건, 「해인사」 12건·연표 0건, 「아레아레아」 20건·연표 0건). 거리 정렬은 청크가 생긴 뒤에 확인하면 됩니다.

## 6. 답변 생성

### 시스템 프롬프트에 넣을 규칙

문서 본문에는 답변 규칙을 넣지 않았습니다 (같은 문단이 여러 문서에 있으면 검색 품질이 떨어지기 때문). 아래 규칙을 프롬프트에 넣어 주세요.

1. **범위**: 고른 작품 범위에서 찾은 근거로만 답한다. 근거가 없으면 모른다고 답하고, 데이터가 없는 작가(클림트·실레)나 다루지 않는 작가(피카소 등)는 다루지 않는다고 답한다.
2. **판본 구분**: 같은 제목의 다른 판본·연작이 많다 (해바라기, 씨 뿌리는 사람, 랑글루아 다리, 가셰 박사 등). 제목만으로 합치지 말고 연도·소장처·소장 번호로 구분한다.
3. **해석의 강도**: 작가 편지나 기관 연구가 의도를 밝히지 않았으면 '시선을 이끈다', '연상시킬 수 있다'처럼 가능한 해석으로 말한다.
4. **단정 금지**: 인물의 신원, 사물의 개수, 색과 정신질환의 관계처럼 문서에 없는 내용은 단정하지 않는다.
5. **사후 해석 금지**: 훗날의 사건(귀 사건, 죽음 등)을 그림이 미리 예고했다고 서술하지 않는다.
6. **이미지 한계**: 이 시스템은 그림을 보지 않는 문서 RAG다. 문서에 없는 화면 세부를 물으면 답을 유보한다.
7. **보정문 우선**: `## 답변 시 주의` 절은 원문의 오래된 정보나 오류를 바로잡은 것이다. 원문과 다르면 이 절을 따른다 (예: 육상묘도의 '영조 6년'은 '영조 1년').
8. **보충문 표시**: `## 감상 포인트` 절은 팀이 덧붙인 편집 보충문이다. 원출처 기관이 직접 쓴 글처럼 말하지 않는다.

### 출처 표시

- 답변 아래에 근거 문서의 `title`, `source_name`, `source_url`을 보여 줍니다.
- 번역본은 제목 끝에 `(영문 번역)`, `source_name`에 `· 한국어 번역 (gpt-5.4-mini)`가 붙어 있고, `source_url`은 영어 원문 주소입니다.
- 근거 청크가 `## 감상 포인트`나 `## 답변 시 주의` 절에서 나왔으면 편집 근거도 함께 보여 줍니다. `document_basis_documents`로 연결된 문서의 `source_name`·`source_url`과, `basis_external_sources`의 이름·URL입니다.

### 라이선스

- `license`에 적힌 그대로 보여 주면 됩니다. 고흐·고갱 팀 작성 해설은 `CC BY 4.0 (… 새로 작성한 해설문에만 적용)`처럼 적용 범위가 괄호 안에 있습니다. 괄호를 자르면 Met 같은 기관 원문의 라이선스로 오해되므로 자르지 않습니다.
- **공공누리 변경금지 문서**: 국립중앙박물관 큐레이터 해설 5건은 공공누리 제3유형(출처표시+변경금지)이고, 그중 `kim-hong-do/artwork-world-curator`는 제4유형(상업적 이용금지 추가)입니다. 검색 근거로 쓰고 출처를 표시하는 것은 괜찮지만, 답변에서 원문을 길게 그대로 옮기거나 개작한 글을 원문처럼 내보이지 않습니다.

## 7. 데이터가 바뀔 때

- A가 원본을 고치면 전처리 → 검토 → `load_catalog` / `load_documents` 순서로 다시 적재합니다.
- 적재는 `doc_key` 기준 갱신이라 `documents.id`가 유지됩니다.
- **본문이 바뀐 문서는 `load_documents`가 그 문서의 TiDB 청크를 지웁니다.** 그래서 A가 적재한 뒤 B가 `build_chunks` → `sync_chroma` 순서로 한 번 더 돌리면 됩니다. `build_chunks`는 청크가 없어진 문서만 다시 만들고, `sync_chroma`는 지워진 청크 id를 Chroma에서 빼고 새 청크를 넣습니다.
- 청킹 방식이나 임베딩 모델을 바꾸면 전체를 다시 만들어야 합니다 (`document_chunks`를 비우고 `build_chunks`, Chroma `chunks` 컬렉션을 지우고 `sync_chroma`).
- `needs_review`: 지금은 361건 모두 `false`입니다. 새 작가 문서가 들어오거나 승인된 문서의 본문이 바뀌면 그 문서만 `true`가 되고, A가 검토 후 다시 `false`로 바꿉니다. `true`인 문서를 검색에서 뺄지는 B가 정하면 됩니다. 검토 기록은 `data/mappings/reviews.json`과 [`data-review-2026-10-12.md`](data-review-2026-10-12.md)에 있습니다.

## 8. 알고 있어야 할 약점

| 약점 | 영향 | 상태 |
| --- | --- | --- |
| 고흐·고갱 작품 해설은 작품당 1,000~1,400자 | 기관 웹페이지 해설을 복제하지 않은 팀 작성 요약이라 세부 근거는 `basis_external_sources`(Met·NGA·MoMA·위키백과 등)에 의존 | 각 25점·50건 사실 확인 완료. 판본 혼동 등 14건 수정, 50건 공통 반복 문단 제거, 43건 출처 보강 |
| 모네·세잔의 새 연표·주제 문서는 팀 작성 자료 | 고유명사·사건 연결을 확인해야 했음 | 28건 검토·승인 완료 |
| 클림트·실레 데이터 없음 | 이 작가 질문은 거절해야 정상 | 수집 대기. 환각 방지 테스트에 활용 가능 |
| 김홍도·정선 기관 원문의 오래된 정보와 학설 | 현재 정보와 확정 사실처럼 답할 위험 | 60점·89문서. 5개 문서에 `답변 시 주의` 보정 레이어와 근거 연결 적용 |
| 위키 원문·번역본은 위키백과 기반 | 원문 자체는 위키백과 수준의 정확도 | 원문 대조 후 검토·승인 완료 |
| 번역본 59건은 기계 번역 | 고유명사 표기, 원문 누락 가능성 | 원문 대조·오류 수정·승인 완료 |
| 연작(건초더미, 수련 등)은 작품 하나가 여러 그림을 대표 | 소장처·크기가 비어 있음 | 의도된 null |

## 9. 검색 테스트용 질문

작품을 고른 상태에서 이 질문을 넣었을 때 아래 문서가 근거로 나와야 합니다. 문서 내용을 직접 확인해서 고른 쌍입니다. E(테스트 담당)의 질문셋과 합쳐서 쓰면 됩니다.

| # | 고른 작품 | 질문 | 나와야 할 문서 (`doc_key`) / 기대 답 |
| --- | --- | --- | --- |
| 1 | 야경 | 야경 그릴 때 렘브란트에게 무슨 일이 있었어? | `rembrandt/timeline-05` |
| 2 | 니콜라스 튈프 박사의 해부학 수업 | 해부대 위의 시신은 누구야? | `rembrandt/the-anatomy-lesson-of-dr-tulp`, `rembrandt/timeline-02` |
| 3 | 돌아온 탕자 | 이 그림을 그릴 무렵 렘브란트의 가족은 어떻게 됐어? | `rembrandt/timeline-14`, `rembrandt/timeline-13` |
| 4 | 유대인 신부 | 렘브란트는 왜 헨드리케와 결혼하지 않았어? | `rembrandt/timeline-07`, `rembrandt/people-hendrickje.en` |
| 5 | 베레모와 세운 옷깃의 자화상 | 렘브란트는 왜 파산했어? | `rembrandt/timeline-08`, `rembrandt/timeline-04`, `rembrandt/bio.en` |
| 6 | 골리앗의 머리를 든 다윗 | 골리앗 얼굴이 카라바조라는 게 무슨 뜻이야? | `caravaggio/david-with-the-head-of-goliath`, `caravaggio/timeline-11` |
| 7 | 성 마태오를 부르심 | 카라바조는 왜 로마에서 도망쳤어? | `caravaggio/timeline-07`, `caravaggio/bio.en` |
| 8 | 홀로페르네스의 목을 베는 유디트 | 유디트의 모델은 누구야? | `caravaggio/judith-beheading-holofernes`, `caravaggio/timeline-04` |
| 9 | 성 마태오를 부르심 | 렘브란트와 카라바조의 명암 표현은 어떻게 달라? | `_comparisons/tenebrism`, `_comparisons/chiaroscuro` |
| 10 | 사이프러스가 있는 밀밭 | 고흐와 고갱은 어떤 관계였어? | `_comparisons/comparison-van-gogh-and-gauguin-arles` |
| 11 | 인상, 해돋이 | 인상주의라는 이름이 이 그림에서 나왔어? | `claude-monet/impression-sunrise` |
| 12 | 귀에 붕대를 감은 자화상 | 고흐 자화상은 왜 귀가 없어? (기획서 데모 질문) | `vincent-van-gogh/commentary-self-portrait-with-bandaged-ear`, `vincent-van-gogh/timeline-06`, `vincent-van-gogh/van-gogh-bio-arles-ear` |
| 13 | (아무 작품) | 피카소의 대표작은? | 근거 없음. **거절이 정답** |
| 14 | (아무 작품) | 클림트의 키스는 언제 그렸어? | 근거 없음 (데이터 미수집). **거절이 정답** |
| 15 | 다나에 | 다나에의 모델은 누구야? | `rembrandt/danae` (사스키아였다가 헤이르처 디르크스로 고쳐 그림), `rembrandt/timeline-03`, `rembrandt/timeline-06` |
| 16 | 카드 사기꾼 | 이 그림을 누가 샀어? | `caravaggio/the-cardsharps`, `caravaggio/timeline-02` (델 몬테 추기경) |
| 17 | 목욕하는 밧세바 | 밧세바의 모델은 누구야? | `rembrandt/bathsheba-at-her-bath`, `rembrandt/timeline-07` (헨드리케 스토펠스) |
| 18 | 인왕제색도 | 지금 어디에 소장돼 있어? | `jeong-seon/inwangjesaekdo`, `jeong-seon/inwangjesaekdo-aks`, `jeong-seon/bio` (현재 국립중앙박물관) |
| 19 | 육상묘도 | 육상묘가 영조 6년에 세워졌어? | `jeong-seon/yuksangmyodo` (`답변 시 주의`: 1725년은 영조 1년) |
| 20 | 단원 풍속도첩 낱장 | 이 그림이 김홍도 진품으로 확정됐어? | `kim-hong-do/artwork-world-aks` (여러 학설을 확정 사실과 구분) |
| 21 | 추성부도 | 그림에 적힌 글의 마지막 문장을 알려줘 | `kim-hong-do/chuseongbudo-inscription` (절단 이후를 추정하지 않음) |
| 22 | 씨 뿌리는 사람 (1888, 크뢸러뮐러) | 화면을 가르는 큰 나무는 무슨 뜻이야? | `vincent-van-gogh/commentary-the-sower-1888` — 그 나무는 11월 판본(반 고흐 미술관)의 요소라고 바로잡아야 함 (규칙 2) |
| 23 | 랑글루아 다리 (반 고흐 미술관) | 다리 아래 빨래하는 여자들은 누구야? | `vincent-van-gogh/commentary-the-langlois-bridge` — 빨래 장면은 크뢸러뮐러 판본(F397)이라고 구분해야 함 (규칙 2) |
| 24 | 밤의 카페 테라스 | 정확히 며칠 밤에 그렸어? | `vincent-van-gogh/commentary-cafe-terrace-at-night` — 9월 16~17일 설과 9월 초 설을 함께 소개 |
| 25 | 별이 빛나는 밤 | 고흐는 이 그림을 마음에 들어 했어? | `vincent-van-gogh/commentary-the-starry-night` — 베르나르에게 '실패작'이라고 씀 |
| 26 | 아레오이의 씨앗 | 여자가 손에 든 과일은 뭐야? | `paul-gauguin/commentary-the-seed-of-the-areoi` — 과일이 아니라 꽃이 핀 씨앗 |
| 27 | 정양사 (덕수1191) | 국립중앙박물관 큐레이터 글에 나온 그 정양사도가 이 그림이야? | `jeong-seon/jeongyangsa-deoksu-1191` — 크기가 달라 단정할 수 없다고 답해야 함 |

## 10. 문의

데이터 형식이나 값이 이상하면 A에게 `doc_key`와 함께 알려 주세요. A가 원본을 고친 뒤 전처리·적재를 다시 돌려 반영합니다. `data/processed/`의 파일이나 DB의 `documents`는 직접 고치지 않습니다 (다음 적재 때 덮어써짐).

데이터 형식 전체는 [`docs/data-spec.pdf`](data-spec.pdf), 전처리 기준은 [`docs/data-collection.md`](data-collection.md), DB 설계는 [`docs/db/db-design.md`](db/db-design.md)에 있습니다.
