# RAG 담당 인계 문서

전처리가 끝난 문서로 청킹·임베딩·검색을 시작하는 데 필요한 내용만 모았습니다. 데이터 형식 전체는 [`docs/data-spec.pdf`](data-spec.pdf), 전처리 기준은 [`docs/data-collection.md`](data-collection.md)에 있습니다.

기준: 2026-10-11 전처리 결과 (작가 6명, 작품 65점, 문서 150건)

## 1. 바로 시작하기

읽을 파일은 `data/processed/documents.jsonl` 하나입니다. 파일을 직접 열지 말고 `load_processed()`로 읽습니다. 마지막으로 성공한 전처리 결과만 돌려주고, 파일이 중간에 바뀌었으면 예외를 냅니다.

```python
# backend/ 에서 실행
from scripts.preprocess import load_processed

docs = load_processed("documents.jsonl")   # list[dict], 150건
```

DB 적재를 기다릴 필요는 없습니다. 이 파일로 청킹·임베딩·검색을 먼저 실험해 볼 수 있습니다. LangChain `Document`로 바꾸는 예시는 [`data/processed/README.md`](../data/processed/README.md)에 있습니다.

### 역할 나눔

| 단계 | 담당 | 읽는 것 | 쓰는 테이블 |
| --- | --- | --- | --- |
| 적재 | A | `data/processed/*.jsonl` | `art_movements`, `artists`, `artworks`, `documents`, `document_artists`, `document_artworks` |
| 청킹·임베딩 | B | DB `documents` | `document_chunks`, `artwork_embeddings` |

B는 `documents`를 읽기만 하고 자기 테이블에만 씁니다. 연결 고리는 `document_chunks.document_id` → `documents.id` 하나입니다.

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
  "needs_review": true
}
```

| 필드 | 검색에서 쓰는 곳 |
| --- | --- |
| `doc_key` | 문서 고유 키. DB `documents.doc_key` (UNIQUE) |
| `doc_type` | `artist_bio` / `artwork_commentary` / `artist_comparison` |
| `title`, `source_name`, `source_url` | 답변 아래 출처 표시 |
| `artwork_slug` | 해설 문서의 대상 작품 → DB `documents.artwork_id` |
| `artist_slugs` | 생애·비교 문서의 작가 → DB `document_artists` |
| `related_artwork_slugs` | 연표 사건이 언급하는 작품 → DB `document_artworks` |
| `topic` | 생애 문서의 성격 (`연표`, `생애 전체`, `주변 인물` 등) |
| `needs_review` | 사람 검토 전 문서 (4절) |

## 3. 청킹 권장

문서 성격이 세 가지로 크게 달라서, 한 가지 길이로 일괄 자르기보다 종류별로 다르게 자르는 것을 권장합니다.

| 문서 | 건수 | 본문 길이 (최소 / 중앙값 / 최대) | 권장 |
| --- | --- | --- | --- |
| 연표 (`topic: "연표"`) | 51 | 130 / 189 / 296자 | 자르지 않음. 문서 하나 = 청크 하나 |
| 고흐·고갱 팀 작성 문서 | 40 | 543 / 656 / 850자 | 자르지 않음. `[화면 관찰]`, `[근거 있는 해석]` 같은 구간 표시는 그대로 둠 |
| 위키 원문·번역본 | 59 | 523 / 2,845 / 33,056자 | `## 제목` 섹션 단위로 먼저 나누고, 긴 섹션만 문단 경계에서 다시 자름 |

- 청크 앞에 `문서 제목 > 섹션 제목`을 붙여서 임베딩하면 짧은 조각도 맥락을 잃지 않습니다. 예: `카라바조의 생애 (영문 번역) > 추방과 죽음 (1606–1610) > 몰타`
- 섹션 제목 줄(`## …`)은 본문이 아니므로 청크 본문에서는 빼고 위의 머리말로만 씁니다.
- 500자 기준으로 자르면 전체 약 720개 청크가 나옵니다 (본문 합계 약 31만 자).

### 임베딩

- DB 컬럼은 `VECTOR(1536)`입니다. `text-embedding-3-small`(1536차원)을 기준으로 설계했습니다. 다른 모델을 쓰려면 차원 수를 먼저 정하고 Alembic 마이그레이션으로 컬럼을 바꿔야 합니다.
- `document_chunks.embedding_model`에 모델 이름을 꼭 넣습니다. 모델이 섞이면 거리 값이 의미가 없어집니다.
- 문서 150건이 모두 한국어입니다 (`lang: "ko"`). 영어 위키백과 원문 35건은 한국어로 번역해 넣었습니다 (7절).
- 같은 주제를 한국어 원문과 번역본이 함께 다루는 경우가 있습니다 (예: 『야경』, 키아로스쿠로). 내용이 겹치는 청크가 상위에 나란히 나오면 `doc_key`가 다른 것을 하나씩만 고르면 됩니다.

## 4. 작품을 골랐을 때 검색 범위

챗봇은 사용자가 고른 작품 범위 안에서만 답합니다. 범위를 SQL로 먼저 좁히고 그 안에서만 벡터 거리를 계산합니다. 범위 안 청크가 많아야 수백 개라 벡터 인덱스 없이 정확 검색으로 충분합니다.

| 근거 | 찾는 방법 | 비고 |
| --- | --- | --- |
| ① 그 작품의 해설 | `documents.artwork_id = :artwork_id` | 한국어 원문과 번역본이 둘 다 있을 수 있음 (예: 야경) |
| ② 그 작가의 생애·주변 인물·연표 | `document_artists.artist_id = 작품의 작가` | 연표 사건 전부 포함 |
| ③ 그 작가가 들어간 비교 문서 | ②와 같음 (`artist_comparison`도 `document_artists`에 연결) | 예: 고흐·고갱 비교, 명암 기법 |
| ④ 그 작품을 언급한 연표 사건 | `document_artworks.artwork_id = :artwork_id` | ②에 이미 포함됨. **거리와 상관없이 항상 컨텍스트에 넣는 용도** |

④가 중요한 이유: 사용자가 『야경』을 고르고 "그때 렘브란트는 어땠어?"라고 물으면, 질문 벡터만으로는 "사스키아의 죽음" 사건이 상위에 오지 않을 수 있습니다. 작품과 연결된 연표 사건은 거리 순위와 별개로 항상 넣어 주면 스토리텔링 답변이 안정됩니다.

```sql
-- 범위 안에서 질문과 가까운 청크 5개 (docs/db/02_queries.sql C절과 같은 방식)
SELECT c.id AS chunk_id, c.content,
       d.id AS document_id, d.doc_key, d.doc_type, d.title, d.source_name, d.source_url, d.needs_review,
       VEC_COSINE_DISTANCE(c.embedding, :question_vec) AS distance
FROM document_chunks AS c
JOIN documents AS d ON d.id = c.document_id
WHERE c.document_id IN (
        SELECT id FROM documents WHERE artwork_id = :artwork_id                      -- ①
        UNION
        SELECT da.document_id FROM document_artists AS da                           -- ②③
        JOIN artworks AS aw ON aw.artist_id = da.artist_id
        WHERE aw.id = :artwork_id
      )
ORDER BY distance
LIMIT 5;

-- ④ 작품과 연결된 연표 사건 (거리와 상관없이 함께 넣음)
SELECT d.id, d.doc_key, d.title, d.content, d.source_name, d.source_url
FROM document_artworks AS dw
JOIN documents AS d ON d.id = dw.document_id
WHERE dw.artwork_id = :artwork_id
ORDER BY d.doc_key;
```

- `SELECT` 목록에 `c.embedding`을 넣지 않습니다. 벡터가 통째로 네트워크로 넘어옵니다.
- `VEC_COSINE_DISTANCE`는 거리라 작을수록 비슷합니다. 항상 오름차순입니다.
- 위 SQL은 문법만 맞춘 예시이며, 실제 DB에서는 아직 실행해 보지 않았습니다 (테이블이 비어 있음).

## 5. 출처 표시와 검토 상태

- **출처**: `title`, `source_name`, `source_url`을 답변 아래에 보여 줍니다. 번역본은 제목 끝에 `(영문 번역)`, `source_name`에 `· 한국어 번역 (gpt-5.4-mini)`가 붙어 있고, `source_url`은 영어 원문 주소입니다.
- **`needs_review`**: 150건 중 126건이 `true`입니다 (연표 51, 기계 번역 35, 고흐·고갱 팀 작성 40). 데모 전까지는 **검색에서 빼지 않는 것**을 권장합니다. 빼면 문서 대부분이 사라집니다. 필요하면 답변에 "검토 중인 자료"라고 표시하는 정도로 씁니다.
- 검수가 끝난 문서는 A가 `review --approve`로 기록하고 다시 적재하면 `needs_review`가 `false`로 바뀝니다.

## 6. 데이터가 바뀔 때

- 적재는 `doc_key` 기준으로 갱신합니다. 문서를 지우고 다시 넣지 않으므로 `documents.id`가 유지되고, 청크도 남아 있습니다.
- **본문이 바뀐 문서만** 다시 청킹·임베딩하면 됩니다. 적재 쪽에서 본문이 바뀐 문서의 청크를 지우는 방식으로 맞출 예정이므로, B는 "청크가 없는 문서"만 처리하면 됩니다.
- 청킹 방식이나 임베딩 모델을 바꾸면 전체를 다시 만들어야 합니다.

## 7. 알고 있어야 할 약점

| 약점 | 영향 | 상태 |
| --- | --- | --- |
| 고흐·고갱 작품 해설은 작품당 600~850자 (청크 1~2개) | 작품 하나만 깊게 묻는 질문에는 근거가 빨리 바닥남. 대신 주제별 생애 문서와 연표가 보강됨 | 보강 완료 (고흐 작품 14·문서 31, 고갱 작품 13·문서 32) |
| 클림트, 실레, 김홍도, 정선 데이터 없음 | 이 작가 질문은 거절해야 정상 | 수집 대기. 환각 방지 테스트에 활용 가능 |
| 위키 원문·번역본은 내용 검수 전 | 위키백과 수준의 정확도 | `needs_review`로 표시됨 |
| 번역본 35건은 기계 번역 | 고유명사 표기는 용어집으로 맞췄고, 원문과 섹션·문단 수가 같은지, 다른 언어 문자가 섞이지 않았는지 자동 검사함 | 사람이 읽어 보는 검수는 아직 |
| 연작(건초더미, 수련 등)은 작품 하나가 여러 그림을 대표 | 소장처·크기가 비어 있음 | 의도된 null |

## 8. 검색 테스트용 질문

작품을 고른 상태에서 이 질문을 넣었을 때 아래 문서가 근거로 나와야 합니다. 문서 내용을 직접 확인해서 고른 쌍입니다. E(테스트 담당)의 질문셋과 합쳐서 쓰면 됩니다.

| # | 고른 작품 | 질문 | 나와야 할 문서 (`doc_key`) |
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

## 9. 문의

데이터 형식이나 값이 이상하면 A에게 `doc_key`와 함께 알려 주세요. 원본을 고친 뒤 전처리를 다시 돌려 반영합니다. `data/processed/`의 파일은 직접 고치지 않습니다 (다음 전처리 때 덮어써짐).
