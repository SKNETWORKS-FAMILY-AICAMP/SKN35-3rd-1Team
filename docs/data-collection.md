# 데이터 수집과 전처리 기준

수집한 원본(`data/raw/`)을 적재용 파일(`data/processed/`)로 바꾸는 기준입니다. 전처리는 A가 맡고, 이 문서는 그 결과를 받아 적재·검색을 하는 다음 담당자(B)를 위해 씁니다.

한 줄 요약: **원본은 형식을 정하지 않고 모아 둔 그대로 받고, 바꾸는 일은 전부 전처리 스크립트([`backend/scripts/preprocess.py`](../backend/scripts/preprocess.py))에서 합니다.** 다음 담당자는 `data/raw/`를 직접 읽지 않고 `data/processed/`의 파일 4개만 믿고 작업하면 됩니다.

## 1. 전체 흐름

```text
data/raw/<작가 slug>/             수집 원본 (전원, 형식 자유, 고치지 않음)
data/mappings/catalog.json        원본에 없는 값을 사람이 채우는 곳 (A)
        │
        │  backend/scripts/preprocess.py  (A)
        │    - 원본 형식별로 읽어 한 가지 형태로 모음
        │    - 위키 문법·목록 섹션 정리, 작품 카드 정보 채우기
        │    - 연표 사건 하나를 문서 하나로
        │    - 검증에 실패하면 결과를 쓰지 않음
        ▼
data/processed/*.jsonl            적재용 파일 4개 (팀 약속, 형식이 바뀌면 공지)
        │
        │  backend/scripts/load_*.py, build_*.py  (B)
        ▼
TiDB  art_movements → artists → artworks → documents → document_chunks
```

| 단계 | 담당 | 입력 | 출력 |
| --- | --- | --- | --- |
| 수집 | 전원 | 웹 자료 | `data/raw/<작가 slug>/` |
| 전처리 | A | `data/raw/`, `data/mappings/catalog.json` | `data/processed/*.jsonl` |
| 적재 | B | `data/processed/*.jsonl` | TiDB 테이블 |
| 청킹·임베딩 | B | TiDB `documents` | TiDB `document_chunks`, `artwork_embeddings` |

실행은 `backend/`에서 합니다.

```bash
uv run python -m scripts.preprocess
```

## 2. 원본 (raw)

수집 담당에게는 자료를 모아 두는 것만 요청했습니다. 원본의 형식은 정하지 않으며, 작가마다 달라도 됩니다. 수집할 때 지켜 달라고 한 것은 두 가지뿐입니다.

- 문서마다 원문 주소(`source_url`)를 남깁니다. 출처가 없는 문서는 적재하지 않습니다.
- 원본은 고치지 않습니다. 각주나 오탈자가 있어도 그대로 두고, 정제는 전처리에서 합니다.

폴더 이름은 작가 slug로 씁니다. 전처리 스크립트는 폴더 안의 파일을 보고 형식을 고릅니다. 새 형식이 들어오면 이 표에 추가하고 스크립트에 읽는 함수를 붙입니다.

| 원본 형식 | 작가 | 읽는 함수 | 전처리에서 하는 일 |
| --- | --- | --- | --- |
| `dataset.json` (+ `sources.json`) | 고흐, 고갱 | `read_dataset` | 작가·작품·문서가 이미 구조화되어 있어 필드 이름만 맞춤. `sources.json`은 감사용 장부라 읽지 않음 |
| 문서별 `*.md` + `sources.json` | 모네, 세잔, 렘브란트, 카라바조 | `read_markdown` | `sources.json`의 항목 하나가 md 파일 하나. 위키 문법 정리, 작품 카드 만들기 |
| `timeline.json` | 렘브란트, 카라바조 | `read_timeline` | 연표 사건 하나를 생애 문서 하나로 만듦 |
| `_comparisons/*.json` | 고흐·고갱 | `read_comparisons` | 비교 문서 (`document` 키가 있는 형식) |
| `_comparisons/*.md` + `sources.<이름>.json` | 렘브란트·카라바조 | `read_comparisons` | 명암 기법 문서 (테네브리즘, 키아로스쿠로) |

- 파일 이름에 `.en`이 붙은 md(`bio.en.md`)는 같은 주제의 영어 문서입니다. 한국어 문서가 없거나 짧을 때 함께 수집했습니다.
- `*.ko.md`는 영어 원문의 한국어 번역본입니다 ([`backend/scripts/translate.py`](../backend/scripts/translate.py), `gpt-5.4-mini`). `sources.json` 항목의 `translation`에 번역 파일, 모델, 날짜, 원문 해시가 기록됩니다. 렘브란트·카라바조의 영어 문서 13건을 번역했습니다.
- `sources.json` 항목에 `artwork` 묶음(연도, 재료, 크기, 소장처 등)이나 `artist` 묶음(생몰년, 국적)이 있으면 작품 카드와 작가 정보에 그대로 씁니다. 렘브란트·카라바조는 수집할 때 위키데이터(CC0)에서 받아 본문과 대조해 넣었습니다.
- `timeline.json`의 각 사건은 근거를 `source_file`(같은 폴더의 원문 파일)이나 `source_url`로 적습니다. 렘브란트 연표가 예시입니다.

## 3. 기준표 (slug)

다른 항목을 가리킬 때는 숫자 id가 아니라 slug를 씁니다. 적재할 때마다 DB id가 달라질 수 있기 때문입니다. slug는 영문 소문자와 하이픈만 씁니다. 이 표를 바꾸면 다음 담당자에게 알립니다.

### 사조 (`movements.jsonl`)

실제 사조 단위로 나눕니다. 원본이 이미 `post-impressionism`처럼 사조 단위로 적혀 있었기 때문입니다. 기획서의 화면 탭(예: 인상주의·후기인상주의)은 화면에서 사조를 묶어 보여 줍니다.

| slug | name | name_en | 작가 |
| --- | --- | --- | --- |
| `baroque` | 바로크 | Baroque | 렘브란트, 카라바조 |
| `impressionism` | 인상주의 | Impressionism | 모네 |
| `post-impressionism` | 후기 인상주의 | Post-Impressionism | 세잔, 고흐, 고갱 |

나머지 작가가 들어오면 `data/mappings/catalog.json`의 `movements`에 사조를 추가합니다.

### 작가 (`artists.jsonl`)

| slug | name | 원본 형식 |
| --- | --- | --- |
| `rembrandt` | 렘브란트 판 레인 | md + `timeline.json` |
| `caravaggio` | 카라바조 | md + `timeline.json` |
| `claude-monet` | 클로드 모네 | md |
| `paul-cezanne` | 폴 세잔 | md |
| `vincent-van-gogh` | 빈센트 반 고흐 | `dataset.json` |
| `paul-gauguin` | 폴 고갱 | `dataset.json` |

클림트, 실레, 김홍도, 정선은 아직 원본이 없습니다.

### 사람이 정하는 값은 `data/mappings/catalog.json`에

원본에 없는 값은 이 파일에 손으로 채우고, 전처리 스크립트가 읽어 덮어씁니다. `data/processed/`는 손으로 고치지 않습니다. 다음 실행 때 사라집니다.

| 키 | 내용 | 지금 들어 있는 값 |
| --- | --- | --- |
| `movements` | 사조 목록 | 3개 |
| `artists` | 원본에 작가 정보가 없거나 고칠 값 | 모네·세잔의 생몰년·국적·사조, 작가 6명의 초상 이미지(`portrait_url`) |
| `artworks` | 원본에 작품 정보가 없거나 고칠 값 | 모네·세잔 작품 10점의 카드 정보(단일 작품 5점은 재료·크기 포함), 고흐·고갱 12점의 이미지 주소, 영어 문서만 있는 작품 7점의 한국어 카드 설명 |

값은 원문 첫 문단, 위키데이터(CC0), 메트 오픈 액세스 API에서 확인한 것만 넣습니다. 확인할 수 없으면 `null`로 둡니다. 이 값은 원본 형식과 관계없이 마지막에 덮어씁니다 (`dataset.json` 형식인 고흐·고갱도 포함).

- 작가 초상: 위키데이터 P18의 위키미디어 공용 파일 (모두 퍼블릭 도메인)
- 고흐·고갱 작품 이미지: 메트 API의 `primaryImageSmall`. 12점 모두 `isPublicDomain: true`를 확인했습니다
- 연작(건초더미, 수련, 루앙 대성당, 생트빅투아르산, 카드놀이하는 사람들)은 재료·크기·연도를 하나로 정할 수 없어 `null`로 둡니다

## 4. 변환 규칙 (raw → processed)

### 4-1. 문서 종류

| `doc_type` | `artist_slugs` | `artwork_slug` | 원본 |
| --- | --- | --- | --- |
| `artist_bio` | 작가 1명 | `null` | 생애(`bio.md`, `bio.en.md`), 주변 인물(`people-*.md`), 자화상·장소·영향 문서, 연표 사건 |
| `artwork_commentary` | `[]` (작품을 통해 작가와 연결) | 작품 slug (필수) | 작품별 해설 |
| `artist_comparison` | 작가 2명 이상 | `null` | 작가 비교, 명암 기법 문서 |

생애 문서는 `topic`으로 성격을 구분합니다: `생애 전체`, `주변 인물`, `작품 세계`, `장소`, `영향`, `기법`, `연표`. 원본에 `topic`이 없으면 `null`입니다.

### 4-2. 작품 카드 (`artworks.jsonl`)

작품 해설 문서 하나에서 작품 카드 하나를 만듭니다. 값은 아래 순서로 채우고, 뒤에 오는 것이 앞의 것을 덮어씁니다.

1. 원본의 작품 정보 (`dataset.json`의 `artworks`, `sources.json` 항목의 `artwork` 묶음)
2. `data/mappings/catalog.json`의 `artworks`

- `description`(카드용 짧은 설명)은 매핑 파일에 없으면 한국어 해설 문서의 첫 문단 앞 두 문장으로 만듭니다. 영어 문서만 있는 작품은 매핑 파일에 한국어로 직접 씁니다.
- 한 작품에 한국어·영어 해설이 둘 다 있으면 작품 카드는 1개, 해설 문서는 2개입니다 (예: `rembrandt/the-night-watch`, `rembrandt/the-night-watch.en`).
- `movement_slug`가 비어 있으면 작가의 사조를 따릅니다.
- `image_url`은 쿼리 문자열(`?utm_source=...`)을 지운 주소로 저장합니다.
- `image_source_url`(이용 조건을 확인할 원본 페이지)이 없고 이미지가 위키미디어 파일이면, 파일 설명 페이지 주소(`commons.wikimedia.org/wiki/File:...`)를 만들어 넣습니다.

### 4-2-1. 번역본

번역본이 있으면 영어 원문 대신 번역본을 문서로 내보냅니다. 같은 내용이 한국어·영어로 두 번 들어가면 검색 결과가 겹치기 때문입니다.

- `doc_key`는 원문과 같게 둡니다 (예: `rembrandt/bio.en`). 검수 기록과 재적재 키가 흔들리지 않게 하기 위해서입니다.
- `lang`은 `ko`, 제목 끝은 `(영문 번역)`, `source_name`은 `Wikipedia (영문) · 한국어 번역 (모델)`, `source_url`은 영어 원문 주소입니다.
- 기계 번역이라 항상 `needs_review: true`로 시작합니다. 고유명사 표기는 스크립트의 용어집(연표·카드와 같은 표기)을 따르게 했습니다.
- 원문이 바뀌면 원문 해시가 달라져 전처리가 경고합니다. `uv run python -m scripts.translate --artists <작가>`를 다시 실행하면 바뀐 문서만 새로 번역합니다.
- 작품 카드 설명은 사람이 쓴 설명 > 한국어 원문 > 번역본 순서로 고릅니다.
- 번역 품질 확인: 13건 모두 원문과 섹션 제목 수·문단 수가 같고, 용어집과 다른 표기는 0건이었습니다.

### 4-3. 연도

화면용 원문 표기(`year_label`)와 정렬용 숫자(`year_start`)로 나눕니다. 숫자를 확실히 정할 수 없으면 `null`로 둡니다. 추정한 숫자를 넣지 않습니다.

| 예 | `year_label` | `year_start` |
| --- | --- | --- |
| 단일 연도 | `1642` | 1642 |
| 추정 | `c. 1893` | 1893 |
| 기간 | `1665–1669` | 1665 |
| 연작처럼 한 해로 정할 수 없음 | `1890년대–1920년대` | null |

### 4-4. 본문 정제

본문은 지우기만 하고 요약하거나 다시 쓰지 않습니다. 답변의 근거로 출처와 함께 보여 주는 원문이기 때문입니다.

- **섹션 제목**: 위키 문법(`== 제목 ==`, `=== 제목 ===`)을 마크다운 제목(`## 제목`, `### 제목`)으로 바꿉니다. 지우지 않는 이유는 청킹할 때 섹션 경계로 쓰기 위해서입니다.
- **통째로 지우는 섹션**: 같이 보기, 각주, 내용주, 참고 문헌, 외부 링크, 갤러리, See also, References, Notes, External links, Further reading, Bibliography, 작품 목록·전시 목록·대중문화 섹션. 하위 섹션도 함께 지웁니다. 전체 목록은 스크립트의 `DROP_SECTIONS`에 있습니다.
- **빈 섹션**: 제목만 있고 본문이 없는 섹션은 지웁니다.
- **공백**: 줄 끝 공백을 지우고, 세 줄 이상 이어지는 빈 줄은 한 줄로 줄입니다. 문단 구분은 유지합니다.
- 고흐·고갱의 `dataset.json` 본문은 팀이 새로 쓴 글이라 앞뒤 공백만 정리합니다.

### 4-5. 연표 (`timeline.json` → 문서)

사건 하나가 문서 하나가 됩니다. 청크 하나에 이야기 하나가 온전히 들어가게 하려는 것입니다.

```text
title:   렘브란트 판 레인 연표: 1641–1642 아들 티투스의 탄생과 사스키아의 죽음, 그리고 『야경』
content: 1641–1642 · 아들 티투스의 탄생과 사스키아의 죽음, 그리고 『야경』
         (이야기 2~4문장)
         등장 인물: 사스키아 (아내), 티투스 (아들)
         관련 작품: 『야경』
topic:   연표
related_artwork_slugs: ["the-night-watch"]
```

- 연표는 위키백과 원문을 바탕으로 팀이 쓴 글이라 이용 조건은 원문과 같은 `CC BY-SA 4.0`이고, `needs_review: true`로 표시해 두었습니다.
- 기록에 없는 해석은 "…로 보기도 한다", "기록으로 남아 있지는 않다"처럼 사실과 구분해 씁니다.

### 4-6. 검토 상태 (`needs_review`)

사람 검토가 끝나지 않은 문서는 `needs_review: true`로 표시해 processed까지 그대로 넘깁니다. 전처리에서 막지 않는 이유는, 연표와 고흐·고갱 데이터 전체가 검토 전 상태라 막으면 핵심 데이터가 빠지기 때문입니다.

| 원본 | `needs_review` |
| --- | --- |
| md 형식 `sources.json`, `timeline.json` | `needs_review` 값 그대로 (사건별 값이 있으면 그것을 우선) |
| `dataset.json`, 비교 json | `record_status`가 `draft…`이거나 `review_status`가 검수 완료(`검수 완료`, `reviewed`, `approved`)가 아니면 `true` |

현재 83건 중 44건이 `true`입니다 (연표 29, 고흐·고갱 문서 15). 적재·검색에서 이 값을 어떻게 쓸지는 6절에 있습니다.

**검수 기록 (`data/mappings/reviews.json`)**: 원본 파일을 고치지 않고 검수 결과를 따로 기록합니다. 검수할 때의 본문 해시를 함께 저장하므로, 검수 뒤 본문이 바뀌면 자동으로 다시 `needs_review: true`가 되고 경고가 나옵니다. `backend/`에서 실행합니다.

```bash
uv run python -m scripts.preprocess review --list
uv run python -m scripts.preprocess review --approve "rembrandt/timeline-*" --reviewer 이름
uv run python -m scripts.preprocess
```

`--approve`에는 `doc_key`나 `*` 패턴을 여러 개 넣을 수 있습니다. 기록만 하고 processed는 바꾸지 않으므로, 마지막 줄처럼 전처리를 다시 실행해야 반영됩니다.

### 4-7. 출처

| 필드 | 규칙 |
| --- | --- |
| `source_url` | 필수. 없으면 검증 오류로 멈춥니다 (답변에 근거를 표시할 수 없음) |
| `source_name` | 원본 값을 그대로 씁니다 (`위키백과`, `Wikipedia (영문)`, 미술관 이름 등) |
| `license` | 위키백과와 연표는 `CC BY-SA 4.0`, 팀이 새로 쓴 요약은 원본에 적힌 조건 (예: `CC BY 4.0`) |

## 5. 결과 파일 (다음 담당자에게 넘기는 것)

파일 목록, 필드, LangChain `Document`로 바꾸는 예시는 [`data/processed/README.md`](../data/processed/README.md)에 있습니다. 여기서는 값에 관한 약속만 적습니다.

- 인코딩은 UTF-8, 한 줄에 JSON 한 건(JSON Lines)입니다.
- 값이 없으면 키를 빼지 않고 `null`로 둡니다. `artist_slugs`와 `related_artwork_slugs`는 항상 배열입니다.
- 문서는 `doc_key`(`<작가 slug>/<원본 파일 이름>`, 연표는 `<작가 slug>/timeline-NN`)로 구분합니다.
- 같은 입력이면 같은 파일이 나옵니다. 줄 순서는 slug(문서는 `doc_key`) 순입니다.

### 검증

전처리 스크립트는 파일을 쓰기 전에 아래를 검사합니다. **오류**가 하나라도 있으면 기존 결과를 그대로 두고 `_FAILED.json`에 이유를 남긴 뒤 종료 코드 1로 끝납니다. **경고**는 출력만 합니다. 출력 교체 방식과 `_SUCCESS.json`은 [`data/processed/README.md`](../data/processed/README.md)에 있습니다.

| 구분 | 검사 |
| --- | --- |
| 오류 | `doc_type`이 `artist_bio`, `artwork_commentary`, `artist_comparison` 중 하나다 |
| 오류 | 작가의 사조, 작품의 사조(비어 있으면 작가 사조로 채운 값)가 `movements`에 있다 |
| 오류 | 작가 이름, 작품 제목이 비어 있지 않다 |
| 오류 | 작품의 `artist_slug`, 문서의 `artist_slugs`·`artwork_slug`·`related_artwork_slugs`가 실제로 있다 |
| 오류 | 작품 slug 형식이 맞고 160자 이하, 문서 제목은 255자 이하다 |
| 오류 | `doc_key`가 중복되지 않는다 |
| 오류 | 모든 문서에 `source_url`이 있다 |
| 오류 | 생애 문서는 작가 1명, 비교 문서는 2명 이상이다 |
| 오류 | 작가마다 생애 문서가 1건 이상, 작품이 3점 이상이다 (기획서 기준 5점, 최소 3점) |
| 경고 | 작품 카드 설명(`description`)이 비어 있다 |
| 경고 | 본문이 200자 미만이다 (연표는 제외) |

## 6. 다음 담당자(B)가 알아야 할 것

**기획서 문서 스키마와 달라진 점**

| 기획서 | processed | 이유 |
| --- | --- | --- |
| `artist` (이름) | `artist_slugs` (작품은 `artist_slug`) | 표기 흔들림 제거, DB 연결 키 |
| `doc_type` 한글 2종 | `artist_bio`, `artwork_commentary`, `artist_comparison` | DB 값과 일치, 비교 문서 추가 |
| `year` 하나 | `year_label` + `year_start` | 화면 표기와 정렬을 분리 |
| 문서 1종 파일 | 파일 4개 (사조·작가·작품·문서) | 작품 목록 화면과 FK 순서 때문 |
| 없음 | `doc_key`, `lang`, `topic`, `related_artwork_slugs` | 검색 메타데이터 (DB 컬럼 아님) |

**청킹 권장**

- 연표(`topic: "연표"`)는 100~400자로 짧으니 자르지 않고 문서 하나를 청크 하나로 씁니다.
- 위키백과 원문은 `## 제목` 섹션 단위로 먼저 나누고, 긴 섹션만 다시 자르면 문맥이 덜 끊깁니다.

**적재 순서**: `movements` → `artists` → `artworks` → `documents`. 자세한 내용은 [`backend/scripts/README.md`](../backend/scripts/README.md)에 있습니다.

**알아 둘 점**

- **분량 차이**: 렘브란트·카라바조는 작가당 본문이 약 12만 자, 고흐·고갱은 약 5,000자입니다. 챗봇은 선택한 작품 범위 안에서 검색하므로 큰 문제는 아니지만, 고흐·고갱은 스토리텔링 재료가 부족합니다. 보강 요청은 [`docs/data-request-gogh-gauguin.md`](data-request-gogh-gauguin.md)에 있습니다.
- **영어 문서**: 렘브란트·카라바조·모네·세잔에는 영어 원문(`lang: "en"`)이 섞여 있습니다. 다국어 임베딩이라 한국어 질문으로도 검색되지만, 답변 출처가 영어로 표시될 수 있습니다.

**검색 메타데이터와 검토 상태의 DB 저장**

processed의 `doc_key`, `lang`, `topic`, `related_artwork_slugs`, `needs_review`는 적재 후에도 남도록 아래 위치에 저장합니다 (Alembic 마이그레이션 `20261011_0002`). 적재 스크립트는 이 값을 버리지 말고 함께 넣어야 합니다.

| processed 필드 | 저장 위치 | 이유 |
| --- | --- | --- |
| `doc_key` | `documents.doc_key VARCHAR(191) UNIQUE` | 재적재 때 문서를 지우고 다시 넣는 대신 키로 갱신할 수 있음 |
| `lang`, `topic` | `documents.lang VARCHAR(8)`, `documents.topic VARCHAR(30) NULL` | 문서 단위 속성. 청크마다 복사할 필요 없음 |
| `needs_review` | `documents.needs_review TINYINT(1) NOT NULL DEFAULT 0` | 검색에서 뺄지, 답변에 표시할지는 질의 시점에 정함 |
| `related_artwork_slugs` | 새 연결 테이블 `document_artworks(document_id, artwork_id)` | `document_artists`와 같은 구조. 작품을 고르면 그 작품의 연표 사건을 SQL 조인으로 찾을 수 있음 |

청크 메타데이터(JSON)에 넣는 방법도 있지만, 지금 설계는 챗봇 검색 범위를 `WHERE document_id IN (...)`처럼 SQL로 좁히는 방식이라 관계형으로 두는 편이 일관됩니다.

**다시 받을 때**: 데이터가 보완되면 A가 processed 파일을 새로 만듭니다. 사조·작가·작품은 slug 기준으로 갱신(upsert)하면 되지만, 문서는 지우고 다시 넣으므로 청킹·임베딩도 다시 돌려야 합니다.

## 7. 작가별 현황

전처리 결과 기준입니다 (2026-10-11). 숫자는 문서 건수이고, 한국어·영어 문서를 모두 셉니다.

| 작가 | 작품 | 생애 | 연표 사건 | 작품 해설 | 비교 | 영어 문서 | 비고 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 렘브란트 | 5 | 7 | 15 | 7 | 4 | 9 | 주변 인물(사스키아, 헨드리케, 티투스) 포함 |
| 카라바조 | 5 | 4 | 14 | 5 | 4 | 4 | 카라바조 화파 포함 |
| 클로드 모네 | 5 | 1 | 0 | 5 | 0 | 1 | |
| 폴 세잔 | 5 | 1 | 0 | 5 | 0 | 3 | |
| 빈센트 반 고흐 | 6 | 1 | 0 | 6 | 1 | 0 | 대표작·생애 보강 요청함 |
| 폴 고갱 | 6 | 1 | 0 | 6 | 1 | 0 | 대표작·생애 보강 요청함 |
| 구스타프 클림트 | | | | | | | 원본 없음 |
| 에곤 실레 | | | | | | | 원본 없음 |
| 김홍도 | | | | | | | 원본 없음 |
| 정선 | | | | | | | 원본 없음 |

비교 문서 4건(렘브란트·카라바조)은 명암 기법 문서(테네브리즘, 키아로스쿠로의 한국어·영어)입니다. 두 작가를 직접 비교하는 문서는 아직 없습니다.

## 8. 아직 정하지 않은 것

- 렘브란트·카라바조 비교 문서: 기법 문서와 연표로 대신할지, 고흐·고갱처럼 비교 글을 따로 쓸지
- 연표를 다른 작가(모네, 세잔, 고흐, 고갱)에도 만들지
- 조선 회화처럼 영어 제목이 없는 작품의 slug 짓기 (예: 로마자 `mudo` vs 번역 `dancing-boy`)
- 작품 이미지를 외부 주소(위키미디어)로 쓸지, `data/images/`에 사본을 둘지
