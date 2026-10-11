# 고흐·고갱 데이터 보강 요청

지금 데이터는 해설 구조가 좋아서(`[화면 관찰]`, `[근거 있는 해석]`, `[질문 대응 한계]`) 그대로 씁니다. 다만 스토리텔링 챗봇에 쓰기에는 두 가지가 비어 있어서 보강을 부탁드립니다.

- **대표작이 없습니다.** 지금 12점이 모두 메트로폴리탄 소장품이라 유명작이 빠져 있습니다. 기획서 데모 질문인 "고흐 자화상은 왜 귀가 없어?"에 답할 작품이 없습니다.
- **생애 이야기가 없습니다.** 생애 문서가 543~589자 요약 하나뿐이라 귀 사건, 테오, 타히티 같은 질문에 근거가 거의 없습니다.

형식은 지금 쓰는 `data/raw/<작가>/dataset.json` 그대로 두고 항목만 추가하면 됩니다. 전처리(`backend/scripts/preprocess.py`)는 A가 합니다. 일정상 전처리 마감이 10/12이므로 **1순위만이라도 먼저** 부탁드립니다.

## 1순위: 대표작 추가 (작가당 3~4점)

| 작가 | 추가할 작품 |
| --- | --- |
| 고흐 | **귀에 붕대를 감은 자화상** (필수), 별이 빛나는 밤, 아를의 해바라기, 밤의 카페 테라스 또는 감자 먹는 사람들 |
| 고갱 | **우리는 어디서 와서 무엇이며 어디로 가는가**, 설교 후의 환상, 황색 그리스도 |

- `artworks`에 작품을 넣고, `documents`에 그 작품의 `artwork_commentary` 해설을 넣습니다. 지금 해설과 같은 구조로, 500자 이상 써 주세요.
- 메트 소장품이 아니면 `object_number`에는 소장처의 소장 번호를 넣고, `image_api_url`은 `null`로 둡니다.
- 이미지는 위키미디어 공용(Wikimedia Commons)의 퍼블릭 도메인 파일을 쓰면 됩니다. `image_source_url`에 파일 페이지 주소를 남깁니다.

## 2순위: 생애 문서를 주제별로 추가

`documents`에 `artist_bio`를 여러 개 넣을 수 있습니다. 사람들이 많이 물어볼 장면을 주제별 문서로 나눠 주세요. 문서마다 500자 이상, 출처는 필수입니다.

| 작가 | 주제 |
| --- | --- |
| 고흐 | 동생 테오와 편지 / 아를의 노란 집과 귀 사건 / 생레미 요양원 / 오베르에서의 죽음 / 초기 네덜란드 시절 (감자 먹는 사람들) |
| 고갱 | 증권 중개인에서 화가로 / 가족을 떠난 이유 / 퐁타벤과 브르타뉴 / 두 번의 타히티 체류 / 마르키즈 제도에서의 말년 |

```json
{
  "document_key": "van-gogh-bio-arles-ear",
  "doc_type": "artist_bio",
  "title": "아를의 노란 집과 귀 사건",
  "year": "1888",
  "artist_slugs": ["vincent-van-gogh"],
  "artwork_slug": null,
  "content": "…500자 이상…",
  "source_url": "https://…",
  "source_name": "…",
  "license": "…",
  "content_author": "…",
  "copyright_notice": "…",
  "source_rights_note": "…",
  "review_status": "draft"
}
```

## 3순위: 연표 `timeline.json`

작가 폴더에 `timeline.json`을 추가합니다. 형식은 `data/raw/rembrandt/timeline.json`과 같습니다. 사건 하나에 2~4문장을 쓰고, 관련 작품의 slug를 연결해 주세요. 이게 있으면 챗봇이 "이 그림 그릴 때 고흐는 어땠어?"에 생애 이야기로 답할 수 있습니다.

고흐·고갱 폴더의 `sources.json`은 렘브란트 폴더와 형식이 달라서, 사건마다 `source_url`을 직접 적습니다.

```json
{
  "artist_slug": "vincent-van-gogh",
  "license": "CC BY 4.0",
  "events": [
    {
      "year": "1888",
      "title": "고갱과의 두 달, 그리고 귀",
      "story": "…사실 위주로 2~4문장. 기록에 없는 해석은 '…로 보기도 한다'처럼 구분…",
      "people": ["폴 고갱"],
      "related_artworks": ["self-portrait-with-bandaged-ear"],
      "source_url": "https://…",
      "source_name": "…"
    }
  ]
}
```

## 지켜 주실 것

- slug는 영문 소문자와 하이픈만 씁니다 (예: `self-portrait-with-bandaged-ear`).
- 연표의 `related_artworks`에는 `artworks`에 실제로 있는 slug만 넣습니다. 없는 slug가 있으면 전처리 검증에서 멈춥니다.
- 사실과 해석을 구분합니다. 지금 해설처럼 "단정하지 않는다"는 원칙을 연표에도 그대로 적용합니다.
- 작성 후 `data/raw/schemas/artist-dataset.schema.json`으로 검증하면 형식 오류를 미리 잡을 수 있습니다.

## 참고: 전처리 결과 확인 방법

`backend/`에서 아래를 실행하면 추가한 데이터가 제대로 들어갔는지 확인할 수 있습니다. 오류가 있으면 어느 항목이 문제인지 출력합니다.

```bash
uv run python -m scripts.preprocess
```
