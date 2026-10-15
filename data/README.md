# data

수집한 미술 문서, 정제 결과, 작품 이미지를 관리합니다. 원본을 적재용 파일로 바꾸는 기준은 [`docs/data-collection.md`](../docs/data-collection.md)에 있습니다.

| 폴더 | 내용 | 누가 쓰는가 |
| --- | --- | --- |
| `raw/` | 수집한 원본. 수정하지 않음 | 수집 담당 전원 |
| `processed/` | 스키마에 맞춰 정제한 결과 | 전처리 스크립트가 만들고 적재 스크립트가 읽음 |
| `images/` | 개발·시연용 작품 이미지와 출처 정보 | 데이터 담당 |
| `mappings/` | 원본에 없는 값을 사람이 채우는 `catalog.json`(사조, 작가·작품 정보, 카드 설명), `document_supplements.json`(출처 기반 보충 해설), `document_corrections.json`(최신 사실·불확실성·절단 주의), 검수 장부 | 전처리 스크립트가 읽음 |

## 문서 스키마 (팀 약속)

정제한 문서 한 건은 아래 필드를 가집니다. DB의 `documents` 테이블과 그대로 대응합니다.

| 필드 | 필수 | 설명 |
| --- | --- | --- |
| `doc_type` | 필수 | `artist_bio`(작가 생애), `artwork_commentary`(작품 해설), `artist_comparison`(작가 비교) |
| `title` | 필수 | 문서 제목. 답변 출처에 표시됨 |
| `content` | 필수 | 정제한 본문 |
| `artist_slugs` | 생애·비교 문서 | 관련 작가의 slug 목록. 생애는 1개, 비교는 2개 이상 |
| `artwork_slug` | 해설 문서 | 해설 대상 작품의 slug |
| `source_url` | 필수 | 원문 주소. 여러 자료를 참고한 비교 문서는 가장 많이 참고한 자료의 주소 |
| `source_name` | 권장 | 출처 이름 (예: 국립현대미술관) |
| `license` | 권장 | 이용 조건 |
| `basis_doc_keys` | 편집 보강 문서 | 보충·보정문을 작성할 때 근거로 삼은 수집 문서 키. DB `document_basis_documents`로 연결 |
| `basis_external_sources` | 편집 보강 문서 | 데이터셋 밖의 공식 보정 근거. `source_name`, `source_url` 목록 |

작가와 작품을 가리킬 때는 숫자 id가 아니라 `slug`를 씁니다. DB의 자동 증가 id는 적재할 때마다 달라질 수 있기 때문입니다. slug는 영문 소문자와 하이픈으로 짓습니다 (예: `vincent-van-gogh`, `the-starry-night`).

## 규칙

- 해설 텍스트와 이미지는 이용 조건이 다를 수 있으므로 각각 출처와 이용 조건을 남깁니다.
- 이용 조건이 분명한 자료를 우선합니다.
- 출처가 없는 문서는 적재하지 않습니다. 답변에 근거를 표시할 수 없기 때문입니다.
