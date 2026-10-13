# 검색 → 답변·배포·테스트 담당 인계

검색 계층이 무엇을 주는지, 다음 담당자가 무엇을 하면 되는지만 모았습니다. 설계 이유와 평가 근거는 [`architecture.md`](architecture.md)에 있습니다.

- 작성: 2026-10-13 · 박수휘 (검색)
- 상태: TiDB 청크 1,622개 · 작품 벡터 219개 적재 완료, **Chroma Cloud 동기화 완료**, 검색 함수 완료

2026-10-13 통합 보완: 아래 운영 적재·평가 수치는 담당자의 기존 기록입니다. 저장소 processed는 10작가·279작품·423문서(신규 검수 대기 62건)로 갱신했으며 이번 통합에서 운영 DB/Chroma를 변경하지 않았습니다. 검수 대기 문서는 SQL 범위·고정 근거·작품별 Chroma 검색·청킹 입력에서 제외됩니다. 런타임 이미지에 processed 별칭과 검증 파일을 포함하도록 수정했으며, 실제 배포 상태는 운영 담당자가 확인해야 합니다.

## 0. 지금 상태

| 항목 | 상태 |
| --- | --- |
| TiDB `document_chunks` 1,622행 · `artwork_embeddings` 219행 | ✅ 적재 완료 (`text-embedding-3-small`, 1536차원) |
| `retrieve()` 검색 함수 | ✅ 완료. E 평가셋 검색 근거 적중률 100% (23/23), 기대 문서 전부 들어온 질문 23/23 |
| 유사 작품·개인 추천 (`recommendation_repository`) | ✅ TiDB 작품 벡터로 바로 동작 |
| Chroma Cloud (`SKN_artlog`) | ✅ 청크 1,622 · 작품 219 동기화 완료 |
| 백엔드 Railway 환경변수 | ⬜ Chroma Cloud 값 전달함. 설정 전까지 배포 서버의 `retrieve()`는 동작하지 않음 (2절) |
| `POST /api/artworks/{id}/chat` | ⬜ 빈 함수 (C) |

## 1. 답변생성 담당자에게

### 검색 함수 부르기

```python
from app.rag.retriever import retrieve

docs = retrieve(db, artwork_id, body.question)   # list[langchain_core.documents.Document]
```

- `page_content`: 청크 본문. 맨 앞에 `문서 제목 > 섹션` 머리말이 붙어 있어 **그대로 프롬프트에 넣으면 됩니다.**
- 순서: 거리로 고른 청크(가까운 순) → 규칙으로 항상 넣는 청크(`pinned=True`).
- 양: 질문당 평균 6개, 최대 11개 청크. 청크 하나는 최대 약 1,200자라, 근거 전체가 최대 1만 자 안팎입니다.
- 질문 임베딩 API를 1번 부릅니다. `OPENAI_API_KEY`와 Chroma 접속 설정이 필요합니다.

### 질문 분류 (수퍼바이저) — 검색 전에

`/chat`에서 검색하기 전에 질문을 분류하면, 범위 밖 질문은 LLM 없이 바로 거절하고 추천 요청은 추천 기능으로 보낼 수 있습니다 (`app/rag/classifier.py`, 규칙 기반이라 비용·지연 없음).

```python
from app.rag.classifier import classify_artwork, refusal_message

route = classify_artwork(db, artwork_id, body.question)
if route.kind in ("refuse", "other_artist"):              # 없는 작품이면 reason == "unknown_artwork" → 404 처리
    response = ChatResponse(answer=refusal_message(route), refused=True, sources=[])
elif route.kind == "recommend_similar":
    cards = recommendation_service.similar(db, artwork_id=artwork_id)
elif route.kind == "recommend_personal":                   # 비로그인이면 similar() 로 대신
    cards = recommendation_service.recommend_artworks(db, user_id=user.id) if user else recommendation_service.similar(db, artwork_id=artwork_id)
else:                                                       # "rag"
    docs = retrieve(db, artwork_id, body.question)          # 아래 절차대로
```

| `route.kind` | 언제 | 예 |
| --- | --- | --- |
| `rag` | 기본값. 고른 작가가 나오거나, "이 그림"처럼 고른 작품을 가리키거나, 관계·영향·비교를 묻거나, 범위 밖 작가라도 **고른 작품의 범위 문서에 그 이름이 나오면** | "렘브란트와 카라바조는 어떻게 달라?", "그 사람은?", 세잔 『현대의 올랭피아』에서 "마네의 올랭피아를 패러디한 거야?" |
| `other_artist` | 데이터에 있는 **다른** 작가만 물음 | 『야경』에서 "카라바조는 왜 로마에서 도망쳤어?" |
| `refuse` | `route.reason`: `unreviewed_artist`(클림트·실레), `uncollected_artist`(미수집), `unknown_artist`(피카소·마네 등), `off_topic`(날씨·오늘 시세·구매 사이트), `unknown_artwork`(없는 작품) | "클림트의 키스는 언제 그렸어?" |
| `recommend_similar` | 고른 작품 기준 추천 | "이 작품과 비슷한 작품 추천해 줘", "이런 그림 더 보여줘" |
| `recommend_personal` | 사용자 취향 기준 추천 | "내 취향에 맞는 작품 추천해 줘", "내가 좋아할 만한 그림 있어?" |

- **원칙은 "애매하면 rag"입니다.** 잘못 거절하는 쪽이 더 나쁘기 때문에 확실한 경우만 거절합니다. rag로 간 질문은 답변 프롬프트의 "근거에 없으면 거절" 규칙이 한 번 더 거릅니다 (예: 근거 부족 질문 "사과가 정확히 몇 개야?"는 rag로 감).
- **헷갈리는 이름**: 모네↔마네, 정선↔강원도 정선·정선군, 카라바조 본명 미켈란젤로 메리시↔미켈란젤로 부오나로티, 단원 김홍도↔단원고·단원구, 빈센트 반 고흐↔테오 반 고흐, 이름이 낱말 일부인 경우(마네킹)를 테스트로 고정했습니다.
- 검증 (실제 DB): E 평가셋 30문항에서 답해야 할 질문을 하나도 막지 않았고 범위 밖 4문항(scope-001~003, evidence-003)은 모두 막았습니다. 인계 9절 27문항은 전부 맞게 분류했습니다. 테스트는 `tests/test_classifier.py` (52개).
- `refusal_message(route)`는 기본 안내 문구입니다 (예: "구스타프 클림트 자료는 아직 검토 중이에요. 검수가 끝난 소장 작품에 관해 물어봐 주세요."). 원하는 문구로 바꿔 써도 됩니다.

### `metadata` → 응답 `Source`

```python
sources, seen = [], set()
for d in docs:                                   # 답변에 실제로 쓴 청크만 고르려면 여기서 거름
    m = d.metadata
    if m["document_id"] in seen:                 # 한 문서의 여러 청크는 출처 1개로
        continue
    seen.add(m["document_id"])
    sources.append(Source(document_id=m["document_id"], title=m["title"], doc_type=m["doc_type"],
                          source_name=m["source_name"], source_url=m["source_url"], license=m["license"],
                          basis_sources=m["basis_sources"]))
```

| `metadata` 키 | 쓰는 곳 |
| --- | --- |
| `document_id`, `title`, `doc_type`, `source_name`, `source_url`, `license` | `Source`에 그대로 (이름이 같음). **`license`는 괄호까지 자르지 않음** (rag-handoff 6절) |
| `annotation` | `"답변 시 주의"`면 원문보다 우선(규칙 7), `"감상 포인트"`면 팀 보충문이라고 밝힘(규칙 8) |
| `basis_sources` | 덧붙인 절의 편집 근거 `[{source_name, source_url}]`. `Source.basis_sources`에 그대로 전달 |
| `pinned` | 규칙으로 들어온 청크(연표 사건·보정문). 거리 통계나 "가장 가까운 근거" 판단에서는 빼기 |
| `distance` | 코사인 거리. **거절 판단에 쓰지 않음** (아래) |
| `chunk_id`, `chunk_index`, `doc_key` | 로그·디버깅. 문의할 때 `doc_key`를 알려 주면 됨 |

### 거절 규칙

1. **`retrieve()`가 빈 리스트면** 없는 작품이거나 승인된 검색 근거가 없는 상태입니다. LLM을 부르지 말고 `refused: true`로 답합니다.
2. **거리 기준값으로 거절하지 마세요.** 평가에서 범위 밖 질문(피카소·클림트)의 최상위 거리가 0.64~0.82로, 정상 질문의 범위(0.33~0.84) 안에 들어갔습니다. 근거가 아무리 멀어도 문서는 돌아오므로, 프롬프트에서 "근거에 없으면 모른다고 답하고 refused" 규칙으로 판단해야 합니다.
3. 범위 밖 작가(피카소)는 범위 밖 안내, 검수 대기 작가(클림트·실레)는 검토 중 안내를 제공합니다. 작가 이름 인식에는 `load_processed("artist_aliases.jsonl")`를 사용합니다 (`collected`=승인 문서 있음, `pending_review`=검수 대기, `planned`=미수집). 관계·비교 질문이 승인된 선택 작품 문서에 근거가 있으면 rag로 유지합니다.

### 멀티턴

검색은 **마지막 질문만**으로 합니다. "그 작품은?"처럼 생략된 질문도 작품 범위 안에서 찾기 때문에 대부분 근거가 나옵니다(평가셋 멀티턴 2문항 모두 적중). 대화 이력은 답변 프롬프트에만 넣으면 됩니다. 질문을 다시 쓰는 단계(query rewrite)를 넣을지는 C가 정하고, 넣으면 그 결과 문장을 `retrieve()`에 넘기면 됩니다.

### 결정 완료

- **편집 근거 표시**: `Source`에 `basis_sources: list[{source_name, source_url}] = []`를 추가했습니다. 감상 포인트·답변 시 주의에서 나온 근거는 원문 출처와 편집 근거를 화면에서 구분해 보여 줍니다.

## 2. 배포·테스트에게

### Railway 백엔드 환경변수

| 변수 | 값 | 비고 |
| --- | --- | --- |
| `OPENAI_API_KEY` | (비밀값) | 질문 임베딩, 답변 생성 |
| `EMBEDDING_MODEL` | `text-embedding-3-small` | 적재할 때와 같아야 함 |
| `CHROMA_CHUNKS_COLLECTION` / `CHROMA_ARTWORKS_COLLECTION` | `chunks` / `artworks` | 발표용 이름. 개발용은 `chunks_dev` 등으로 나눔 |

Chroma 접속은 아래 두 방식 중 **하나만** 넣습니다. 세 Cloud 값이 모두 있으면 Cloud가 우선입니다 (`app/clients/chroma_client.py`).

| 방식 | 변수 | 값 |
| --- | --- | --- |
| **Chroma Cloud** (trychroma.com) **← 사용 중** | `CHROMA_API_KEY` / `CHROMA_TENANT` / `CHROMA_DATABASE` | API 키(비밀값, 개인 메시지로 전달) / `7bdea74c-355a-4e13-b5f7-61ad06a932d3` / `SKN_artlog` |
| (대안) Railway에 직접 띄운 Chroma | `CHROMA_HOST` / `CHROMA_PORT` / `CHROMA_SSL` | `<chroma 서비스>.railway.internal` / `8000` / `false` (내부망은 HTTP) |

Railway에 직접 띄울 때 Chroma 서비스 쪽: 이미지 `chromadb/chroma:1.5.9`(클라이언트 버전과 맞춤), 볼륨 `/data`, 포트 8000. Chroma 1.x는 자체 인증이 없으니 공개 도메인은 `sync_chroma`를 돌릴 때만 열어 두세요. 내부망 접속이 안 되면 Chroma 서비스 환경변수에 `CHROMA_HOST=::`가 필요할 수 있습니다 (Railway 내부망은 IPv6).

### 평가

```bash
uv run python -m scripts.eval_retrieval --out ../docs/eval/retrieval-<날짜>.json
```

- `docs/test-plan.md`의 "검색 근거 적중률"을 LLM 없이 계산합니다. 질문별로 검색된 `doc_key`, 거리, `pinned` 여부가 JSON에 남습니다.
- 2026-10-13 결과 (Chroma Cloud): 적중률 23/23 (100%), 기대 문서가 전부 들어온 질문 23/23, [`eval/retrieval-2026-10-13.json`](eval/retrieval-2026-10-13.json). 한국어 원문과 영문 번역본(`.en`)은 같은 근거로 셉니다.
- **질문셋을 고쳤습니다** (`tests/questions/rag-eval.json`, 기대값 4건):
  - `compare-004`: `commentary-sunflowers-arles`는 다른 작품의 해설이라 『해바라기』(1887) 범위 밖이어서 뺐습니다. 1887년 해설 안에 아를 해바라기와의 차이가 설명돼 있어 질문은 그대로 답할 수 있습니다.
  - `fact-004`·`detail-008`(야경), `compare-003`(명암): 같은 내용의 영문 번역본 키(`.en`)를 추가했습니다.
- 거절률·출처 포함률 등 나머지 지표는 `/chat`이 완성된 뒤 답변까지 포함해 재야 합니다.

## 3. 데이터 담당자에게

데이터를 다시 적재한 뒤에는 아래 순서로 실행하면 검색까지 반영됩니다. 바뀐 것만 처리하므로 몇 번을 돌려도 안전합니다.

```bash
uv run python -m scripts.build_chunks              # 본문·청킹 규칙이 바뀐 문서만 다시 임베딩
uv run python -m scripts.build_artwork_embeddings  # 작품 219점 전부 다시 (1원 미만)
uv run python -m scripts.sync_chroma               # TiDB → Chroma (비용 0원)
```

- `load_documents`가 본문이 바뀐 문서의 청크를 지우지 않아도 `build_chunks`가 직접 비교해서 다시 만듭니다.
- 클림트·실레를 추가하면 위 세 명령만 돌리면 됩니다. 코드 수정은 필요 없습니다.
- 새 덧붙인 절 제목을 만들면(`## 감상 포인트`, `## 답변 시 주의` 외) `app/rag/chunking.py`의 `ANNOTATION_SECTIONS`에 추가해야 별도 청크로 잘립니다.

## 4. 화면 구현 담당자에게

- 챗봇 응답은 질문 임베딩, Chroma 검색, LLM 답변을 거치므로 몇 초 걸립니다. 로딩 표시가 필요합니다.
- 출처의 `license`는 길 수 있습니다(예: `CC BY 4.0 (이 데이터셋의 새 한국어 해설문)`). 자르지 말고 줄바꿈으로 보여 주세요.
- 편집 근거(`basis_sources`)는 원문 출처와 구분해 화면에 표시합니다.

## 5. 문의

검색 결과가 이상하면 질문, 고른 작품, `doc_key`를 B에게 알려 주세요. 같은 질문을 TiDB 벡터로도 검색해 비교할 수 있습니다 (`architecture.md` 5절).
