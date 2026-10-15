# raw

수집·작성한 원천 데이터를 작가별 JSON으로 둡니다. 원본은 고치지 않고, 정제 결과는 `processed/`에 따로 만듭니다.

## 폴더 배치

```text
raw/
├── vincent-van-gogh/
│   ├── dataset.json               작가, 작품, 생애 및 작품 해설
│   └── sources.json               자료별 원문 주소, 출처 이름, 이용 조건, 수집일
├── paul-gauguin/
├── _comparisons/
│   ├── van-gogh-and-gauguin.json 작가 비교 문서
│   └── sources.json               비교 문서 출처 장부
└── schemas/
    ├── artist-dataset.schema.json
    ├── comparison-document.schema.json
    └── source-manifest.schema.json
```

## 규칙

- 폴더 이름은 작가 slug와 같게 합니다. 전처리 스크립트는 JSON 내부 slug를 우선 사용합니다.
- 파일을 추가할 때 `sources.json`에 출처를 함께 적습니다. 나중에 모아서 적으려 하면 빠집니다.
- 비교 문서는 두 작가 어느 쪽 폴더에도 속하지 않으므로 `_comparisons/`에 둡니다.
- `artwork_commentary`는 `artwork_slug`로 작품 하나에 연결합니다. `artist_bio`와 `artist_comparison`만 `artist_slugs`로 `document_artists` 관계를 만듭니다.
- `sources.json`은 수집 근거와 이용 조건을 남기는 감사용 장부이며 DB 직접 적재 대상이 아닙니다.

## 검증 스키마

- 작가 폴더의 `dataset.json`: `schemas/artist-dataset.schema.json`
- `_comparisons/`의 비교 JSON: `schemas/comparison-document.schema.json`
- 모든 `sources.json`: `schemas/source-manifest.schema.json`

JSON Schema만으로는 `artist_slug`가 실제 작가와 같은지, `artwork_slug`가 작품 목록에 존재하는지, slug가 배열 안에서 중복되지 않는지까지 완전히 검사할 수 없습니다. 이 세 가지 참조 무결성 검사는 전처리 스크립트에서 추가로 확인합니다.
