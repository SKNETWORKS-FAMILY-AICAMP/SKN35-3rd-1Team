# API 명세

확정일: 2026-10-12 · 갱신: 2026-10-14. 이 문서가 프론트와 백엔드의 공식 계약입니다. 기준 코드는 `backend/app/schemas/`(요청·응답 모델)와 `backend/app/api/routes/`(경로)이며, `backend/tests/test_api.py`가 OpenAPI를 기준으로 이 계약을 고정합니다. 서버를 띄우면 `/docs`(Swagger)와 `/openapi.json`에서 같은 내용을 볼 수 있습니다.

명세를 바꿀 때는 스키마·라우트·`test_api.py`·이 문서를 같은 PR에서 함께 고칩니다.

## 공통 규칙

- **접두사**: REST 경로는 `/api`로 시작합니다. 외부 도구용 MCP 전송 계층은 `/mcp/`입니다. `/api/v1`은 쓰지 않습니다.
- **id**: 경로의 `{artwork_id}`, `{artist_id}`는 DB의 숫자 `id`입니다. `slug`는 응답에만 있는 별도 필드입니다.
- **인증**: 로그인은 프론트의 Firebase Auth가 처리하고 서버에 로그인·회원가입 API는 없습니다. 로그인이 필요한 요청은 `Authorization: Bearer <Firebase ID 토큰>`을 보냅니다. 사용자 id는 URL이나 본문으로 보내지 않고 서버가 토큰에서 꺼냅니다(`/api/me/...`). 처음 보는 uid는 서버가 `users`에 한 번 등록합니다.
- **목록**: JSON 배열을 그대로 반환합니다. `{items: ...}` 같은 래퍼가 없습니다.
- **페이지네이션 없음**: 작품 219점·작가 8명 규모입니다. 규모가 커지면 기존 응답을 깨지 않도록 `?limit=&offset=`를 추가하거나 `/v2`를 둡니다.
- **카드와 상세**: 목록은 카드 모델, 상세는 카드에 필드를 더한 상세 모델을 반환합니다.
- **본문 없는 성공**: 좋아요·팔로우·열람 기록·대화 초기화는 `204 No Content`입니다. 요청 본문도 없습니다.
- **오류**: FastAPI 기본 형식 `{"detail": ...}`입니다.

| 상태 | 의미 |
| --- | --- |
| `401` | 토큰이 없거나 검증 실패. `WWW-Authenticate: Bearer` 헤더 포함 |
| `404` | 없는 작품·작가 id. 상세 조회, 좋아요·팔로우 `PUT`, 열람 `POST`에 적용. 취소 `DELETE`는 항상 `204` |
| `422` | 요청 검증 실패 (질문 길이, `month` 형식, 날짜 형식 등). `detail`은 오류 항목 배열 |
| `501` | 경로만 있고 아직 구현되지 않음 (개발 중에만). 도슨트 POST는 2026-10-14에 구현했으며 AI·검색 연결 실패는 503으로 안내 |

## 검색

**검색 API는 두지 않습니다. 작품·작가 검색은 프론트 로컬 검색입니다.**

프론트는 `GET /api/artworks`, `GET /api/artists`로 전체 목록을 받은 뒤 클라이언트에서 거릅니다. 작품은 제목·영문 제목·작가 이름으로, 작가는 이름·영문 이름·사조 이름으로 대소문자 구분 없이 부분 일치합니다. 사조·작가 필터는 서버의 `movement_id`, `artist_id` 쿼리를 써도 되고 로컬에서 걸러도 됩니다.

이유: 페이지네이션이 없어 전체 목록을 이미 한 번에 받고, 219점 규모라 서버 왕복 없이 입력할 때마다 바로 결과를 보여 주는 편이 빠릅니다. 규모가 커지면 `GET /api/artworks?q=`를 추가합니다. 선택 쿼리라 기존 클라이언트는 그대로 동작합니다.

## 엔드포인트

로그인: 공백은 불필요, **선택**은 토큰이 있으면 로그인 사용자로 처리, **필요**는 토큰이 없으면 `401`.

| 메서드 | 경로 | 응답 | 로그인 | 설명 |
| --- | --- | --- | --- | --- |
| GET | `/api/health` | `{"status": "ok"}` | | 서버 상태 확인 |
| GET | `/api/movements` | `Movement[]` | | 사조 목록 |
| GET | `/api/artists?movement_id=` | `ArtistCard[]` | | 작가 목록. `movement_id` 선택 |
| GET | `/api/artists/{artist_id}` | `ArtistDetail` | | 작가 상세 |
| GET | `/api/artworks?artist_id=&movement_id=` | `ArtworkCard[]` | | 작품 목록. 두 필터 모두 선택 |
| GET | `/api/artworks/{artwork_id}` | `ArtworkDetail` | | 작품 상세 |
| GET | `/api/artworks/{artwork_id}/similar` | `ArtworkCard[]` | | 비슷한 작품 3개, 가까운 순. 작품 벡터가 없으면 빈 배열 |
| POST | `/api/artworks/{artwork_id}/chat` | `ChatResponse` | 선택 | 도슨트 질문. 로그인 상태면 질문과 답변을 저장 |
| POST | `/api/artworks/{artwork_id}/chat/stream` | SSE | 선택 | 같은 질문을 실시간으로 전송하고 완료 시 저장 |
| GET | `/api/artworks/{artwork_id}/chat/messages` | `ChatMessageOut[]` | 필요 | 이 작품과 나눈 내 대화, 오래된 순. 대화가 없으면 빈 배열 |
| DELETE | `/api/artworks/{artwork_id}/chat` | `204` | 필요 | 이 작품 대화 초기화. 대화가 없어도 `204` |
| GET | `/api/me/chats` | `ChatSummary[]` | 필요 | 내가 대화한 작품, 최근 대화순 |
| PUT | `/api/artworks/{artwork_id}/like` | `204` | 필요 | 좋아요. 여러 번 호출해도 결과 동일 |
| DELETE | `/api/artworks/{artwork_id}/like` | `204` | 필요 | 좋아요 취소. 좋아요가 없어도 `204` |
| GET | `/api/me/likes` | `ArtworkCard[]` | 필요 | 좋아요한 작품, 최근순 |
| PUT | `/api/artists/{artist_id}/follow` | `204` | 필요 | 팔로우. 여러 번 호출해도 결과 동일 |
| DELETE | `/api/artists/{artist_id}/follow` | `204` | 필요 | 팔로우 취소. 팔로우가 없어도 `204` |
| GET | `/api/me/follows` | `ArtistCard[]` | 필요 | 팔로우한 작가 |
| POST | `/api/artworks/{artwork_id}/views` | `204` | 필요 | 열람 기록. 같은 날 다시 보면 `view_count`만 증가 |
| GET | `/api/me/library/calendar?month=YYYY-MM` | `CalendarDay[]` | 필요 | 월별 감상 기록. 본 날만 날짜순 |
| GET | `/api/me/library/days/{YYYY-MM-DD}` | `ViewedArtwork[]` | 필요 | 그날 본 작품, 마지막으로 본 순 |
| GET | `/api/me/recommendations/artworks` | `RecommendedArtwork[]` | 필요 | 좋아요 기반 맞춤 작품 3개, 작가당 1개. 좋아요가 없으면 최근 열람 → 팔로우한 작가 작품 → 큐레이션 작품 무작위(사용자·날짜별로 고정, 새로고침해도 같은 결과). 이미지 없는 작품은 나오지 않음 |
| GET | `/api/me/recommendations/artists` | `RecommendedArtist[]` | 필요 | 추천 작가 3명. 유사도 합산 순위 상위 3명, 팔로우한 작가 제외(좋아요한 작품의 작가는 포함) |

날짜는 서버가 `Asia/Seoul` 기준으로 계산합니다.

## 응답 모델

`?`가 붙은 필드는 `null`일 수 있습니다. 필드는 항상 존재하며 생략되지 않습니다.

### Movement

| 필드 | 타입 |
| --- | --- |
| `id` | int |
| `slug` | string |
| `name` | string |
| `name_en` | string? |
| `description` | string? |

### ArtistCard / ArtistDetail

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `id` | int | |
| `slug` | string | |
| `name` | string | |
| `name_en` | string? | |
| `movement_id` | int? | |
| `birth_year` | int? | |
| `death_year` | int? | |
| `summary` | string? | 짧은 소개 |
| `portrait_url` | string? | |
| `nationality` | string? | **상세만** |

### ArtworkCard / ArtworkDetail

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `id` | int | |
| `slug` | string | |
| `title` | string | |
| `title_en` | string? | |
| `artist_id` | int | |
| `artist_name` | string | 작가 목록을 따로 조회하지 않아도 됨 |
| `movement_id` | int? | |
| `year_label` | string? | 예: `"1889"`, `"18세기 후반"` |
| `image_url` | string? | |
| `is_featured` | bool | |
| `medium` | string? | **상세만** |
| `dimensions` | string? | **상세만** |
| `collection` | string? | **상세만**. 소장처 |
| `description` | string? | **상세만** |
| `image_source_url` | string? | **상세만**. 이미지 원본 페이지 |
| `image_license` | string? | **상세만**. 이미지 라이선스 |

카드에는 좋아요·팔로우 여부(`is_liked`, `is_followed`)가 없습니다. 로그인 후 `/api/me/likes`, `/api/me/follows`로 받습니다.

### 도슨트 채팅

요청 `ChatRequest`:

| 필드 | 타입 | 제약 |
| --- | --- | --- |
| `question` | string | 필수, 1~500자 |
| `history` | `ChatTurn[]` | 선택(기본 `[]`), 직전 메시지 최대 12개 |

`ChatTurn`은 `{role: "user" | "assistant", content: string(1~4000자)}`입니다. 답변 맥락은 로그인 여부와 관계없이 항상 `history`로 받습니다. 서버 저장 기록은 대화 복원용입니다.

```json
{"question":"이 작품은 언제 그렸나요?","history":[{"role":"user","content":"작품을 소개해 주세요."},{"role":"assistant","content":"이전 답변"}]}
```

응답 `ChatResponse`:

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `answer` | string | 답변 본문 |
| `refused` | bool | 근거 문서가 없어 답변을 거절했으면 `true` |
| `sources` | `Source[]` | 답변 근거. 거절이면 빈 배열일 수 있음 |

스트리밍 경로는 같은 `ChatRequest`를 받습니다. `Accept: text/event-stream`을 보내면 `token` (`{"content":"추가 문자열"}`), `replace` (`{"content":"수정된 전체 문자열"}`), `done` (검증된 `ChatResponse`), `error` (`{"message":"안내 문구"}`) 이벤트를 순서대로 받습니다. `done`의 답변과 출처가 최종 결과이며 로그인 사용자의 대화도 이 시점에 저장됩니다. `history`는 브라우저가 보내며, 로그인 시 Firebase ID 토큰을 `Authorization: Bearer` 헤더에 포함합니다.

`Source`:

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `document_id` | int | |
| `title` | string | |
| `doc_type` | string | `artist_bio` \| `artwork_commentary` \| `artist_comparison` |
| `source_name` | string? | 출처 기관·사이트 |
| `source_url` | string? | |
| `license` | string? | 출처 라이선스. 화면에 출처와 함께 표시 |
| `basis_sources` | `BasisSource[]` | 편집 보충문·보정문의 근거. 해당하지 않으면 `[]` 또는 생략 |

`BasisSource`는 `{source_name: string?, source_url: string?}`입니다. `감상 포인트`나 `답변 시 주의` 절을 답변 근거로 사용했을 때 원문 출처와 구분해 표시합니다.

```json
{"answer":"근거에 따른 답변","refused":false,"sources":[{"document_id":123,"title":"작품 해설","doc_type":"artwork_commentary","source_name":"국립중앙박물관","source_url":"https://example.org/source","license":"공공누리 제1유형","basis_sources":[{"source_name":"국립중앙박물관 연구자료","source_url":"https://example.org/basis"}]}]}
```

`ChatMessageOut` (저장된 대화):

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `id` | int | |
| `role` | `"user"` \| `"assistant"` | |
| `content` | string | |
| `refused` | bool | |
| `sources` | `Source[]` | 질문이면 빈 배열 |
| `created_at` | datetime | ISO 8601 |

`ChatSummary` (내 대화 목록): `artwork`(`ArtworkCard`), `last_message`(string, 최근 메시지 미리보기), `updated_at`(datetime).

### 내 서재

`CalendarDay`:

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `date` | date | `YYYY-MM-DD` |
| `artwork_count` | int | 그날 본 서로 다른 작품 수 |
| `total_views` | int | `view_count` 합계 (같은 작품을 다시 열면 더해짐) |

`ViewedArtwork`: `ArtworkCard` 필드 + `view_count`(int), `last_viewed_at`(datetime).

### 추천

`RecommendedArtwork`는 `ArtworkCard`, `RecommendedArtist`는 `ArtistCard`에 `reason`(string?)을 더한 평평한 형태입니다. `reason` 예: `"『별이 빛나는 밤』을 좋아해서"`. 대체 추천이면 `null`입니다.

## 노출하지 않는 값

응답은 DB 모델이 아니라 스키마로 변환해 반환합니다. `firebase_uid`, `embedding` 같은 내부 컬럼은 어떤 응답에도 없습니다(`test_responses_never_expose_private_columns`).


## 감상평·다이어리 API (20261013_0007)

하루에 사용자당 감상평 한 편을 저장합니다. 공개 피드·캘린더·다이어리는 같은 `diary_entries` 데이터를 사용합니다. 기본은 비공개입니다.

| 메서드 | 경로 | 인증 | 동작 |
| --- | --- | --- | --- |
| GET | `/api/diary/feed?limit=12&before_id=123&artwork_id=42` | 불필요 | 공개 글만 최신 id순, artwork_id·before_id는 선택. limit 1~30 |
| GET | `/api/me/diary?month=YYYY-MM` | 필요 | 내 월별 감상평, 날짜 내림차순 |
| GET | `/api/me/diary/YYYY-MM-DD` | 필요 | 내 날짜별 감상평. 없으면 null |
| PUT | `/api/me/diary/YYYY-MM-DD` | 필요 | 내 날짜별 감상평 생성·수정·공개 범위 변경 |
| DELETE | `/api/me/diary/YYYY-MM-DD` | 필요 | 내 글 삭제, 204 |

PUT 본문: `content`(공백 제거 후 1~2000자), `is_public`(기본 false), `artwork_id`(선택, null 허용). 사용자 식별 필드는 받지 않으며 검증된 로그인 사용자로 결정합니다.

응답 글: `id`, `entry_date`, `content`, `is_public`, `author_name`, `artwork`(ArtworkCard 또는 null), `created_at`, `updated_at`(UTC). 이메일·Firebase UID·내부 사용자 ID는 반환하지 않습니다.
피드 응답: `{items: DiaryEntry[], next_cursor: int|null}`. 다음 페이지는 before_id=next_cursor. 공개 피드는 no-store, 개인 조회는 private/no-store입니다. 비공개 전환·삭제는 다음 조회부터 피드에서 제외됩니다.

운영 전 `alembic upgrade head`로 0007을 적용하고 백엔드를 배포해야 합니다. AUTH_MODE=firebase 설정과 기존 인증 정보는 운영 담당자가 확인합니다. 이번 코드 변경에서 운영 DB나 배포 설정을 직접 변경하지 않았습니다.


## 마이페이지·컬렉션 API (20261014_0008)

모든 경로는 Firebase 인증이 필요하고 응답은 `Cache-Control: private, no-store`입니다. 사용자는 토큰에서 결정하며 본문의 user_id/UID 필드는 허용하지 않습니다. 다른 계정의 컬렉션 ID에는 404를 반환합니다.

| 메서드 | 경로 | 응답·용도 |
| --- | --- | --- |
| GET / PUT | `/api/me/profile` | 설정 조회·전체 교체. 미설정은 `onboarding_completed=false` |
| GET | `/api/me/collections` | 컬렉션 최대 50개, 개수와 미리보기 3점, 수정 시각 내림차순 |
| POST | `/api/me/collections` | 생성 201. 동일 계정 이름 중복은 409 |
| PUT / DELETE | `/api/me/collections/{id}` | 이름·소개 수정 / 묶음 삭제 204 |
| GET | `/api/me/collections/{id}/items?limit=12&before_id=...` | `{items: ArtworkCard[], next_cursor: int?}`. 작품 ID 내림차순, limit 1~30 |
| PUT / DELETE | `/api/me/collections/{id}/items/{artwork_id}` | 작품 담기(컬렉션 응답, 중복 무해) / 꺼내기 204 |
| GET | `/api/me/critiques?limit=12&before_id=...` | `{items: DiaryEntry[], next_cursor: int?}`. 본인의 공개·비공개 다이어리, ID 내림차순 |
| GET | `/api/me/activity?limit=20&offset=0` | `ActivityOut[]`, 최신 감상·좋아요·다이어리·컬렉션 변경. limit 최대30, offset 최대10000 |
| GET / POST | `/api/me/taste` | 저장한 AI 취향 소개 조회 / 근거 변경 시 생성 |
| POST | `/api/me/collections/chat` | 컬렉션 요청 분석·제안. 이 요청만으로 DB를 변경하지 않음 |

ProfileWrite: `{birth_date: "YYYY-MM-DD" | null, explanation_priorities: ["background","technique","artist_life"], conversation_style: "easy" | "professional", onboarding_completed: true}`. 생일은 1900-01-01~서울의 오늘, 세 우선순위는 정확히 한 번씩 담은 순열입니다. 생일은 선택 사항이며 지우면 null입니다. PUT은 전체 교체이고 생략된 설정은 기본값이 됩니다. 서버는 birth_year·tone·explanation_level의 호환 필드도 갱신합니다. GET은 nickname을 추가합니다. 성별과 이전 나이대는 새 요청에 포함하지 않습니다.

CollectionWrite: `{name: string(1~80), description: string(0~500)}`. CollectionOut은 `{id, name, description, artwork_count, previews: ArtworkCard[]}`입니다. 컬렉션은 기본 비공개이며 별도 공개 API는 없습니다. 한 컬렉션에는 최대 500점을 담습니다. 묶음을 삭제해도 좋아요·다이어리와 카탈로그 작품은 유지합니다.

ActivityOut: `{kind: "view"|"like"|"diary"|"collection", title, occurred_at: UTC datetime, artwork_id: int?, entry_date: date?}`. 최근 상태의 활동 집계이며 변경 이벤트를 영구 보관하는 감사 로그는 아닙니다. 좋아요 취소·컬렉션 삭제 시 해당 항목은 목록에서 사라집니다.

TasteOut: `{summary: string?, evidence: ArtworkCard[], generated_at: UTC datetime?, stale: bool}`. 근거는 본인 좋아요·컬렉션의 중복 제거 작품 최대100점입니다. 개인 글·생년월일·이메일·UID는 모델에 전달하지 않습니다. 동일 근거는 저장 결과를 재사용하고 변경 후 30초 이내 재생성 요청은 429입니다. 근거가 없으면 생성 409, AI 설정·응답 문제는 503입니다.

CollectionChatRequest: `{message: string(1~500), collection_id: int?}`. 응답 `{answer, proposal: {action: "create"|"add", name: string?, collection_id: int?, artwork_id: int?} | null}`. 동명 작품이나 다수 검색 결과는 추가 질문으로 처리합니다. 화면에서 사용자가 제안을 확정하면 위의 컬렉션 CRUD 경로를 호출하고 서버에서 소유권·작품 존재를 다시 확인합니다.

## MCP 컬렉션 도구

`/mcp/`는 공식 Python SDK의 stateless Streamable HTTP입니다. 일반 REST `/api` 접두사가 붙지 않습니다. 매 요청에 유효한 Firebase ID 토큰을 Bearer 헤더로 보내야 하며 `Accept: application/json, text/event-stream`을 사용합니다. 도구: `list_collections`, `search_artworks(query)`, `create_collection(name)`, `add_artwork_to_collection(collection_id, artwork_id)`. 도구 인자에 user_id가 없으며 REST와 같은 소유권 검사·중복 방지 서비스를 사용합니다. 별도 OAuth 로그인·동적 클라이언트 등록은 제공하지 않습니다. 운영 Host 허용 목록은 `MCP_ALLOWED_HOSTS`, 브라우저 Origin은 `CORS_ORIGINS`에 설정합니다.

## 도슨트 개인 설정 반영 (프롬프트 v2026-10-14.1)

`POST /api/artworks/{id}/chat`는 기존 분류·승인 문서 검색을 답변 생성과 연결합니다. 기본 쉬운 말투 또는 전문용어 스타일, 설명 순서는 서버 사용자 설정에서 읽습니다. 생년월일은 사용하지 않습니다. 근거가 없으면 거절하며, 인용한 chunk ID가 검색 결과에 없거나 비어 있어도 거절합니다. 출처 URL·라이선스·편집 보강 근거는 DB 검색 메타데이터에서만 구성합니다. 로그인 대화는 기존 `chat_service.save_exchange`로 저장합니다. 실제 생성 품질은 운영 모델·검색 자료를 연결한 별도 평가가 필요합니다.
