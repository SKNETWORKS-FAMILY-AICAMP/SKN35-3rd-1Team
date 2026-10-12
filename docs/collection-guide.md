# 남은 작가 데이터 수집 안내 (클림트·실레·김홍도·정선)

이 문서는 수집 담당자(또는 수집을 맡은 AI)가 그대로 따라 하면 되는 작업 지시서입니다. 결과물은 `data/raw/<작가 slug>/` 폴더 하나이고, 전처리(`backend/scripts/preprocess.py`)가 추가 코드 없이 바로 읽을 수 있어야 합니다.

참고할 완성 예시:

- `data/raw/rembrandt/`: 가장 완전한 예시 (작가·작품 정보 묶음, 영어 문서, 연표 포함)
- `data/raw/claude-monet/`: 주제 문서(`people.md`, `places.md`, `technique.md`, `influence.md`) 예시

---

## 1. 대상 작가와 slug

slug는 아래 값을 **바꾸지 말고** 그대로 씁니다. 별칭 목록(`data/mappings/artist_aliases.json`)과 이미 연결되어 있습니다.

| 작가 | 작가 slug (= 폴더 이름) | 사조 slug (`movement_slug`) | 사조 이름 |
| --- | --- | --- | --- |
| 구스타프 클림트 | `gustav-klimt` | `vienna-secession` | 빈 분리파 |
| 에곤 실레 | `egon-schiele` | `expressionism` | 표현주의 |
| 김홍도 | `kim-hong-do` | `joseon-late-painting` | 조선 후기 회화 |
| 정선 | `jeong-seon` | `joseon-late-painting` | 조선 후기 회화 |

사조는 수집 담당이 아니라 전처리 담당(A)이 `data/mappings/catalog.json`에 추가합니다. 수집 쪽에서는 위 slug만 적어 주세요.

---

## 2. 결과물 폴더 구성

```text
data/raw/gustav-klimt/
├── bio.md                    필수. 작가 생애 (한국어 위키백과 본문)
├── bio.en.md                 선택. 영어 위키백과 본문 (한국어판이 짧을 때)
├── the-kiss.md               작품 해설. 작품 하나에 파일 하나
├── the-kiss.en.md            선택. 같은 작품의 영어 문서
├── ...
├── people.md                 선택. 주변 인물
├── places.md                 선택. 활동한 장소
├── technique.md              선택. 작품 세계와 기법
├── influence.md              선택. 영향 관계
├── timeline.json             선택. 생애 연표 (6절)
└── sources.json              필수. 위 md 파일마다 항목 하나 (4절)
```

### 분량

- 생애 문서(`bio.md`) 1개 이상
- 작품 해설 **15~30점**. 기존 작가는 모네 30점, 세잔 25점, 렘브란트·카라바조 27점입니다.
- 대표작은 반드시 넣습니다 (예: 클림트 『키스』, 실레 『자화상』, 김홍도 『씨름』·『서당』, 정선 『인왕제색도』·『금강전도』).

---

## 3. md 파일 규칙

1. **본문은 원문을 복사한 그대로 둡니다.** 위키 문법(`== 제목 ==`), 각주 표식(`[1]`, `[편집]`), "같이 보기·각주·외부 링크" 섹션도 지우지 마세요. 정리는 전처리가 합니다.
2. 요약하거나 다시 쓰지 않습니다. 답변의 근거로 원문을 그대로 보여 주기 때문입니다.
3. 파일 맨 위에 제목이나 메타데이터(front matter)를 붙이지 않습니다. 본문만 넣습니다. 메타데이터는 모두 `sources.json`에 적습니다.
4. 파일 이름 규칙
   - 작품 해설: `<작품 slug>.md`
   - 영어 원문: 이름 뒤에 `.en`을 붙입니다 (`bio.en.md`, `the-kiss.en.md`). 한국어 번역은 A가 `scripts.translate`로 만들므로 `.ko.md`는 만들지 않습니다.
5. 본문이 200자보다 짧으면 경고가 나옵니다. 한국어판이 너무 짧으면 영어판(`.en.md`)도 같이 넣어 주세요.
6. 인코딩은 UTF-8로 저장합니다.

### 작품 slug 규칙

- 영문 소문자, 숫자, 하이픈만 씁니다 (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- 서양화는 영어 제목으로 씁니다: 『키스』 → `the-kiss`, 『아델레 블로흐바우어의 초상 I』 → `portrait-of-adele-bloch-bauer-i`
- 한국화는 국어의 로마자 표기법으로 씁니다: 『인왕제색도』 → `inwangjesaekdo`, 『씨름』 → `ssireum`, 『금강전도』 → `geumgang-jeondo`
- **작품 slug는 모든 작가를 통틀어 겹치면 안 됩니다.** 흔한 제목(`self-portrait`, `portrait-of-a-woman`, `landscape`)은 작가나 연도를 붙여 구분합니다: `self-portrait-with-physalis`, `schiele-self-portrait-1912`

---

## 4. `sources.json` 형식

최상위는 객체이고, **키는 md 파일 이름**, 값은 그 파일의 정보입니다. 폴더 안의 모든 md 파일에 항목이 있어야 합니다.

### 4-1. 공통 필드

| 필드 | 필수 | 설명 |
| --- | --- | --- |
| `doc_type` | 필수 | `artist_bio` (생애·인물·장소·기법·영향) 또는 `artwork_commentary` (작품 해설) |
| `title` | 필수 | 한국어 제목. 생애는 `<작가>의 생애`, 작품은 `<작품명> 해설`, 영어 문서는 끝에 ` (영문)` |
| `artist_slugs` | 필수 | `artist_bio`면 `["<작가 slug>"]`, `artwork_commentary`면 `null` |
| `artwork_slug` | 필수 | `artwork_commentary`면 작품 slug, 아니면 `null` |
| `source_url` | **필수** | 원문 주소. **없으면 적재하지 않습니다** |
| `source_name` | 필수 | `위키백과`, `Wikipedia (영문)`, `국립중앙박물관` 등 |
| `license` | 필수 | 본문 이용 조건. 위키백과는 `CC BY-SA 4.0` |
| `collected_at` | 필수 | 수집일 `YYYY-MM-DD` |
| `lang` | 필수 | `ko` 또는 `en` |
| `image_url` | 권장 | 대표 이미지 주소 (5절) |
| `image_license` | 권장 | 이미지 이용 조건 (5절) |
| `needs_review` | 필수 | 원문을 그대로 복사했으면 `false`, 직접 쓰거나 고친 글이면 `true` |
| `topic` | 선택 | `artist_bio`의 성격: `생애 전체`, `주변 인물`, `작품 세계`, `장소`, `영향`, `기법` |
| `artist` | 권장 | `bio.md` 항목에만 넣는 작가 정보 묶음 (4-2) |
| `artwork` | 권장 | 작품 해설 항목에 넣는 작품 카드 정보 묶음 (4-3) |

### 4-2. `artist` 묶음 (`bio.md` 항목에 한 번)

```json
"artist": {
  "slug": "gustav-klimt",
  "name": "구스타프 클림트",
  "name_en": "Gustav Klimt",
  "movement_slug": "vienna-secession",
  "birth_year": 1862,
  "death_year": 1918,
  "nationality": "오스트리아",
  "wikidata": "https://www.wikidata.org/wiki/Q34661"
}
```

### 4-3. `artwork` 묶음 (작품 해설 항목마다)

| 필드 | 설명 | 예 |
| --- | --- | --- |
| `slug` | `artwork_slug`와 같은 값 | `the-kiss` |
| `artist_slug` | 작가 slug | `gustav-klimt` |
| `movement_slug` | 작가와 같으면 생략 가능 | `vienna-secession` |
| `title` | 한국어 작품명 (『』 없이) | `키스` |
| `title_en` | 영어 작품명 | `The Kiss` |
| `year_label` | 화면용 연도 표기 | `1907–1908` |
| `year_start` | 정렬용 숫자. 확실하지 않으면 `null` | `1907` |
| `medium` | 재료 | `캔버스에 유채, 금박` / `종이에 수묵담채` |
| `dimensions` | 크기 | `180 × 180 cm` |
| `collection` | 소장처 | `벨베데레 궁전 오스트리아 미술관` |
| `image_source_url` | 이미지 이용 조건을 확인할 수 있는 페이지 | `https://commons.wikimedia.org/wiki/File:...` |
| `wikidata` | 위키데이터 항목 주소 | `https://www.wikidata.org/wiki/Q...` |
| `is_featured` | 대표작이면 `true` | `true` |

연도 표기 규칙:

| 경우 | `year_label` | `year_start` |
| --- | --- | --- |
| 단일 연도 | `1907` | 1907 |
| 추정 | `c. 1790` 또는 `1790년경` | 1790 |
| 기간 | `1907–1908` | 1907 |
| 정할 수 없음 (화첩, 연작) | `18세기 후반` | null |

**값은 원문 본문, 위키데이터, 소장 기관 페이지에서 확인한 것만 넣습니다. 확인할 수 없으면 `null`로 둡니다. 추정해서 채우지 마세요.**

### 4-4. 전체 예시

```json
{
  "bio.md": {
    "doc_type": "artist_bio",
    "title": "구스타프 클림트의 생애",
    "artist_slugs": ["gustav-klimt"],
    "artwork_slug": null,
    "source_url": "https://ko.wikipedia.org/wiki/%EA%B5%AC%EC%8A%A4%ED%83%80%ED%94%84_%ED%81%B4%EB%A6%BC%ED%8A%B8",
    "source_name": "위키백과",
    "license": "CC BY-SA 4.0",
    "collected_at": "2026-10-11",
    "lang": "ko",
    "image_url": "https://commons.wikimedia.org/wiki/Special:FilePath/Klimt.jpg",
    "image_license": "Public domain",
    "needs_review": false,
    "artist": {
      "slug": "gustav-klimt",
      "name": "구스타프 클림트",
      "name_en": "Gustav Klimt",
      "movement_slug": "vienna-secession",
      "birth_year": 1862,
      "death_year": 1918,
      "nationality": "오스트리아",
      "wikidata": "https://www.wikidata.org/wiki/Q34661"
    }
  },
  "the-kiss.md": {
    "doc_type": "artwork_commentary",
    "title": "키스 해설",
    "artist_slugs": null,
    "artwork_slug": "the-kiss",
    "source_url": "https://ko.wikipedia.org/wiki/...",
    "source_name": "위키백과",
    "license": "CC BY-SA 4.0",
    "collected_at": "2026-10-11",
    "lang": "ko",
    "image_url": "https://commons.wikimedia.org/wiki/Special:FilePath/...",
    "image_license": "Public domain",
    "needs_review": false,
    "artwork": {
      "slug": "the-kiss",
      "artist_slug": "gustav-klimt",
      "title": "키스",
      "title_en": "The Kiss",
      "year_label": "1907–1908",
      "year_start": 1907,
      "medium": "캔버스에 유채, 금박",
      "dimensions": "180 × 180 cm",
      "collection": "벨베데레 궁전 오스트리아 미술관",
      "image_source_url": "https://commons.wikimedia.org/wiki/File:...",
      "wikidata": "https://www.wikidata.org/wiki/Q...",
      "is_featured": true
    }
  },
  "the-kiss.en.md": {
    "doc_type": "artwork_commentary",
    "title": "키스 해설 (영문)",
    "artist_slugs": null,
    "artwork_slug": "the-kiss",
    "source_url": "https://en.wikipedia.org/wiki/The_Kiss_(Klimt)",
    "source_name": "Wikipedia (영문)",
    "license": "CC BY-SA 4.0",
    "collected_at": "2026-10-11",
    "lang": "en",
    "needs_review": false
  },
  "people.md": {
    "doc_type": "artist_bio",
    "title": "구스타프 클림트의 주변 인물과 관계",
    "artist_slugs": ["gustav-klimt"],
    "artwork_slug": null,
    "source_url": "https://ko.wikipedia.org/wiki/...",
    "source_name": "위키백과",
    "license": "CC BY-SA 4.0",
    "collected_at": "2026-10-11",
    "lang": "ko",
    "topic": "주변 인물",
    "needs_review": true
  }
}
```

같은 작품에 한국어·영어 문서가 둘 다 있으면 `artwork` 묶음은 한국어 문서 항목에만 넣어도 됩니다.

---

## 5. 이미지

- 이미지 파일은 내려받지 않고 **주소만** 적습니다.
- 우선순위: 위키미디어 공용 → 소장 기관 공개 이미지
- 위키미디어 공용 이미지는 `https://commons.wikimedia.org/wiki/Special:FilePath/<파일명>` 형식으로 적으면 됩니다. `image_license`는 파일 설명 페이지의 라이선스를 그대로 적습니다 (대부분 `Public domain`).
- 클림트(1918년 사망)·실레(1918년 사망)·김홍도·정선의 작품 자체는 저작권이 만료되었지만, **사진의 이용 조건은 사진마다 다릅니다.** 파일 설명 페이지에서 확인한 값만 적습니다.

### 김홍도·정선 추가 규칙

- 국립중앙박물관·e뮤지엄·국가유산포털 이미지를 쓸 때는 `image_license`에 **공공누리 유형**을 적습니다 (예: `공공누리 제1유형`). `image_source_url`에는 그 유형이 표시된 페이지 주소를 넣습니다.
- 공공누리 유형이 표시되지 않았거나 "이용 불가"인 이미지는 넣지 않습니다. `image_url`은 `null`로 둡니다.
- 소장처는 정식 이름으로 씁니다 (예: `국립중앙박물관`, `리움미술관`, `간송미술관`).
- 화첩 속 그림(예: 『단원 풍속도첩』의 『씨름』)은 그림 하나를 작품 하나로 봅니다. 화첩 전체를 다룬 문서는 `artist_bio`, `topic: "작품 세계"`로 둡니다.

---

## 6. `timeline.json` (선택)

생애의 큰 사건을 이야기로 정리한 연표입니다. 챗봇이 생애를 이야기처럼 들려줄 때 씁니다. 형식은 `data/raw/rembrandt/timeline.json`과 같습니다.

```json
{
  "artist_slug": "gustav-klimt",
  "purpose": "스토리텔링용 연표. 생애 사건과 작품을 연결한다. 각 사건은 같은 폴더의 원문(source_file)에 근거한다.",
  "content_author": "SKN35-3rd-1Team 데이터팀 (위키백과 원문을 바탕으로 정리)",
  "license": "CC BY-SA 4.0",
  "collected_at": "2026-10-11",
  "needs_review": true,
  "events": [
    {
      "year": "1897",
      "title": "빈 분리파 결성",
      "story": "2~4문장의 이야기.",
      "people": ["요제프 호프만 (동료)"],
      "related_artworks": ["the-kiss"],
      "source_file": "bio.md"
    }
  ]
}
```

- 사건 하나 = 이야기 하나. 10~20개 사건이면 충분합니다.
- `story`는 `source_file`로 적은 원문에 있는 사실로만 씁니다. 원문에 없는 해석은 "…로 보기도 한다"처럼 사실과 구분해 씁니다.
- `related_artworks`에는 **이 폴더에 해설 문서가 있는 작품 slug만** 넣습니다.
- `source_file`은 이 폴더의 md 파일 이름입니다. 다른 곳을 근거로 했으면 `source_file` 대신 `source_url`을 적습니다.

---

## 7. 하지 말 것

- `data/processed/`의 파일을 고치지 않습니다. 전처리를 실행하면 다시 만들어집니다.
- `data/mappings/` 파일은 고치지 않습니다 (A가 관리합니다).
- `.ko.md` 번역 파일을 직접 만들지 않습니다.
- 출처를 모르는 글, 블로그·나무위키처럼 이용 조건이 맞지 않는 글은 넣지 않습니다.
- 다른 작가 폴더의 파일을 건드리지 않습니다.

---

## 8. 제출 전 확인

- [ ] 폴더 이름이 1절의 작가 slug와 같다
- [ ] 폴더의 모든 `.md` 파일이 `sources.json`에 키로 있다 (반대로 `sources.json`의 키도 모두 실제 파일이다)
- [ ] 모든 항목에 `source_url`이 있다
- [ ] `artwork_commentary` 항목은 `artwork_slug`가 있고 `artist_slugs`가 `null`이다
- [ ] `artist_bio` 항목은 `artist_slugs`가 `["<작가 slug>"]`이고 `artwork_slug`가 `null`이다
- [ ] 작품 slug가 규칙에 맞고, 다른 작가의 작품 slug와 겹치지 않는다
- [ ] `sources.json`, `timeline.json`이 올바른 JSON이다 (`python -m json.tool sources.json`으로 확인)
- [ ] 연도·재료·크기·소장처 중 확인하지 못한 값은 `null`이다

제출 후 A가 `backend/`에서 전처리를 실행해 오류를 확인합니다.

```bash
uv run python -m scripts.preprocess
```
