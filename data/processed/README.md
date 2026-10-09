# processed

정해진 스키마에 맞춰 정제한 데이터를 둡니다. 적재 스크립트(`backend/scripts/`)는 이 폴더만 읽습니다.

## 들어갈 파일

한 줄에 한 건씩 적는 JSON Lines 형식을 권장합니다. 파일을 나눠 두면 사조 → 작가 → 작품 → 문서 순서로 적재하기 쉽습니다.

| 파일 | 한 줄의 필드 | 적재되는 테이블 |
| --- | --- | --- |
| `movements.jsonl` | `slug`, `name`, `name_en`, `description` | `art_movements` |
| `artists.jsonl` | `slug`, `name`, `name_en`, `movement_slug`, `birth_year`, `death_year`, `nationality`, `summary`, `portrait_url` | `artists` |
| `artworks.jsonl` | `slug`, `artist_slug`, `movement_slug`, `title`, `title_en`, `year_label`, `year_start`, `medium`, `dimensions`, `collection`, `description`, `image_url`, `image_source_url`, `image_license`, `is_featured` | `artworks` |
| `documents.jsonl` | `doc_type`, `title`, `content`, `artist_slugs`, `artwork_slug`, `source_url`, `source_name`, `license` | `documents`, `document_artists` |

## 규칙

- 다른 항목을 가리킬 때는 slug를 씁니다 (`artist_slug`, `movement_slug`, `artwork_slug`). 적재 스크립트가 slug로 DB의 id를 찾아 연결합니다.
- 청크와 임베딩은 여기 저장하지 않습니다. `build_chunks` 스크립트가 DB의 문서를 읽어 바로 만듭니다.
- `year_label`은 화면에 보일 원문 표기(예: `c. 1889`), `year_start`는 정렬용 숫자입니다.
- `is_featured`는 좋아요가 없는 신규 사용자에게 보여 줄 대표 작품에 표시합니다. 작가마다 한두 점씩 고르게 지정합니다.
- 이 폴더의 파일은 전처리 스크립트로 다시 만들 수 있어야 합니다. 손으로 고친 내용은 다음 실행 때 사라집니다.
