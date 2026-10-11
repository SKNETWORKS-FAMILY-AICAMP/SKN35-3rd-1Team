# processed

정해진 스키마에 맞춰 정제한 데이터를 둡니다. 적재 스크립트(`backend/scripts/`)는 이 폴더만 읽습니다. 원본에서 각 필드를 만드는 규칙은 [`docs/data-collection.md`](../../docs/data-collection.md)에 있습니다.

## 만드는 방법

이 폴더의 파일은 전처리 스크립트가 만듭니다. `backend/`에서 실행합니다.

```bash
uv run python -m scripts.preprocess
```

- 원본: `data/raw/`, 사람이 채우는 값: `data/mappings/catalog.json`
- 같은 입력이면 같은 파일이 나옵니다. 줄 순서는 slug(문서는 `doc_key`) 순입니다.

### 성공한 결과만 읽기 (`_SUCCESS.json`)

- 4개 파일을 `.staging/`에 모두 만든 뒤 한꺼번에 교체하고, 마지막에 `_SUCCESS.json`(파일별 sha256과 줄 수)을 씁니다.
- 검증에 실패하거나 원본을 읽다 오류가 나면 **기존 파일과 `_SUCCESS.json`은 그대로 두고** `_FAILED.json`에 실패 시각과 이유를 남깁니다. 다음에 성공하면 `_FAILED.json`은 지워집니다.
- 적재 스크립트는 파일을 직접 열지 말고 `load_processed()`로 읽습니다. `_SUCCESS.json`이 없거나 해시가 다르면(교체 도중 중단 등) 예외를 내서 불완전한 결과를 적재하지 않게 합니다.

```python
from scripts.preprocess import load_processed

artworks = load_processed("artworks.jsonl")  # list[dict]
```

## 파일

한 줄에 한 건씩 적는 JSON Lines(UTF-8)입니다. 사조 → 작가 → 작품 → 문서 순서로 적재합니다.

| 파일 | 한 줄의 필드 | 적재되는 테이블 |
| --- | --- | --- |
| `movements.jsonl` | `slug`, `name`, `name_en`, `description` | `art_movements` |
| `artists.jsonl` | `slug`, `name`, `name_en`, `movement_slug`, `birth_year`, `death_year`, `nationality`, `summary`, `portrait_url` | `artists` |
| `artworks.jsonl` | `slug`, `artist_slug`, `movement_slug`, `title`, `title_en`, `year_label`, `year_start`, `medium`, `dimensions`, `collection`, `description`, `image_url`, `image_source_url`, `image_license`, `is_featured` | `artworks` |
| `documents.jsonl` | `doc_key`, `doc_type`, `title`, `content`, `artist_slugs`, `artwork_slug`, `source_url`, `source_name`, `license`, `lang`, `topic`, `related_artwork_slugs`, `needs_review` | `documents`, `document_artists` |

### documents.jsonl 에서 DB에 없는 필드

DB 테이블에는 없지만 검색과 답변에 쓰라고 둔 값입니다. 적재할 때는 무시해도 되고, 청크 메타데이터로 넘기면 됩니다.

| 필드 | 뜻 |
| --- | --- |
| `doc_key` | 문서 고유 키 (`<작가 slug>/<원본 파일 이름>`). DB id 대신 문서를 가리킬 때 씁니다 |
| `lang` | `ko` 또는 `en`. 영어 위키백과 원문은 `en`입니다 |
| `topic` | 생애 문서의 성격: `생애 전체`, `주변 인물`, `작품 세계`, `장소`, `영향`, `기법`, `연표`. 없으면 `null` |
| `related_artwork_slugs` | 연표 사건과 연결된 작품. "이 작품을 그릴 때 작가는 어땠나" 같은 질문에서 작품으로 생애 문서를 찾을 때 씁니다 |
| `needs_review` | 사람 검토가 끝나지 않은 문서면 `true`. 원본의 `needs_review`, `review_status`(검수 완료가 아니면), `record_status`(`draft…`)에서 오고, `data/mappings/reviews.json`에 검수 기록이 있으면 `false`가 됩니다. DB `documents.needs_review`에 저장합니다 |

### 문서 종류

| `doc_type` | `artist_slugs` | `artwork_slug` | 예 |
| --- | --- | --- | --- |
| `artist_bio` | 작가 1명 | `null` | 생애, 주변 인물, 연표 사건 하나 |
| `artwork_commentary` | `[]` (작품을 통해 작가와 연결) | 작품 slug | 작품 해설 |
| `artist_comparison` | 작가 2명 이상 | `null` | 작가 비교, 명암 기법(테네브리즘, 키아로스쿠로) |

- **연표**(`topic: "연표"`)는 사건 하나가 문서 하나입니다. 100~400자로 짧으니 청킹하지 않고 문서 하나를 청크 하나로 쓰는 것을 권장합니다.
- **위키백과 원문**은 섹션 제목이 `## 제목` 형태로 남아 있습니다. 섹션 단위로 자르면 문맥이 덜 끊깁니다.
- 한 작품에 한국어·영어 해설이 둘 다 있을 수 있습니다 (예: `rembrandt/the-night-watch`, `rembrandt/the-night-watch.en`).

### Retriever 메타데이터 예

```python
from langchain_core.documents import Document

from scripts.preprocess import load_processed

docs = load_processed("documents.jsonl")
lc_docs = [
    Document(page_content=d["content"], metadata={k: v for k, v in d.items() if k != "content"})
    for d in docs
]
```

## 규칙

- 다른 항목을 가리킬 때는 slug를 씁니다 (`artist_slug`, `movement_slug`, `artwork_slug`). 적재 스크립트가 slug로 DB의 id를 찾아 연결합니다.
- 청크와 임베딩은 여기 저장하지 않습니다. `build_chunks` 스크립트가 DB의 문서를 읽어 바로 만듭니다.
- `year_label`은 화면에 보일 원문 표기(예: `c. 1889`), `year_start`는 정렬용 숫자입니다. 연작처럼 한 해로 정할 수 없으면 `null`입니다.
- `is_featured`는 좋아요가 없는 신규 사용자에게 보여 줄 대표 작품에 표시합니다. 작가마다 한두 점씩 고르게 지정합니다.
- 이 폴더의 파일은 손으로 고치지 않습니다. 다음 실행 때 사라집니다. 값을 바꾸려면 `data/mappings/catalog.json`이나 원본을 고칩니다.
