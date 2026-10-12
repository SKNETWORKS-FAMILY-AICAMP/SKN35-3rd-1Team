# 프론트엔드 엔드포인트 점검표

점검일: 2026-10-12. 기준은 `backend/app/api/routes/README.md`, `backend/app/schemas/README.md`, `backend/app/models/catalog.py`입니다. 변경 범위는 `frontend/`뿐입니다.

## 확인 결과

서버 경로 문서에 **초안**이라고 명시되어 있습니다. routes·schemas 디렉터리에 실행 가능한 라우터·응답 모델이 없고, 확정 명세로 안내된 `docs/api.md`도 없습니다. 따라서 아래의 “대조”는 문서와 클라이언트의 일치 여부이며 실제 서버의 존재·응답을 확인했다는 뜻이 아닙니다. 자동 테스트는 MockClient로 요청 경로·메서드·파라미터·응답 처리만 검증합니다.

공통 접두사는 `/api`입니다. `/api/v1` 또는 문서에 없는 검색·감상 메모 저장 경로를 만들지 않았습니다. 실제 API 호출에는 DB의 숫자 `id`를 문자열로 변환해 사용합니다. `slug`는 별도 필드이며 미리보기 ID와 섞지 않습니다. 인증이 필요한 요청은 `Authorization: Bearer <access_token>`을 보냅니다.

| 메서드 | 경로 | 인증 | 프론트 사용 / 대조 |
| --- | --- | --- | --- |
| POST | `/api/auth/login` | 없음 | 기존 API 인증 모드에서만 사용 / JSON 형식 임시 |
| POST | `/api/auth/signup` | 없음 | 문서에 존재 / 가입 규격 미확정으로 호출 안 함 |
| GET | `/api/movements` | 없음 | 목록, 일치 |
| GET | `/api/artists` | 없음 | 목록, `movement_id` 지원 |
| GET | `/api/artists/{artist_id}` | 없음 | 작가 상세, 일치 |
| GET | `/api/artworks` | 없음 | 목록, `artist_id`, `movement_id` 지원 |
| GET | `/api/artworks/{artwork_id}` | 없음 | 작품 상세, 일치 |
| POST | `/api/artworks/{artwork_id}/chat` | 없음 | 도슨트, 일치 |
| PUT / DELETE | `/api/artworks/{artwork_id}/like` | 필요 | 좋아요 / 취소, 일치 |
| GET | `/api/me/likes` | 필요 | 로그인 후 좋아요 목록, 일치 |
| PUT / DELETE | `/api/artists/{artist_id}/follow` | 필요 | 팔로우 / 취소, 일치 |
| GET | `/api/me/follows` | 필요 | 로그인 후 팔로우 목록, 일치 |
| POST | `/api/artworks/{artwork_id}/views` | 필요 | 작품 상세 열람, 일치 |
| GET | `/api/me/library/calendar?month=YYYY-MM` | 필요 | 월별 감상 수, 일치 / 응답 임시 |
| GET | `/api/me/library/days/{YYYY-MM-DD}` | 필요 | 날짜별 감상 작품, 일치 / 응답 임시 |
| GET | `/api/artworks/{artwork_id}/similar` | 없음 | 관련 작품, 일치 |
| GET | `/api/me/recommendations/artworks` | 필요 | 클라이언트 메서드 준비, 현재 화면에서 호출 안 함 |
| GET | `/api/me/recommendations/artists` | 필요 | 클라이언트 메서드 준비, 현재 화면에서 호출 안 함 |

## Firebase 인증 모드

`AUTH_PROVIDER=firebase`에서는 Firebase SDK의 이메일 로그인·회원가입·비밀번호 재설정을 사용합니다. 기존 `/api/auth/login`, `/api/auth/signup`으로 Firebase 비밀번호나 ID 토큰을 보내지 않습니다. 문서에 없는 토큰 교환 엔드포인트도 추가하지 않았습니다.

API 모드에서 보호된 요청은 Firebase의 `getIdToken()`으로 얻은 토큰을 Bearer 헤더로 보냅니다. 401이면 강제로 토큰을 갱신해 한 번만 재시도하고, 계속 거절되면 오류를 표시합니다. 서버가 아직 Firebase ID 토큰을 검증하지 못하는 경우를 로그인 실패와 구분하기 위해 Firebase 계정을 강제로 로그아웃시키지 않습니다.

**백엔드 담당자 필요 사항:** Firebase Admin SDK 또는 검증된 JWT 검증기로 ID 토큰을 검증하고 `uid`를 내부 사용자와 매핑해야 합니다. 프로젝트 ID는 `skn35-3rd-1team`입니다. 프론트엔드의 로그인 표시 자체는 서버 자원 접근 권한을 부여하지 않습니다. 이번 작업에서는 백엔드를 수정하지 않았습니다.

현재 배포는 `ARTLOG_DEMO=true` + Firebase 인증입니다. 작품 12점·도슨트 예시·감상 기록은 미리보기이며, 로그인은 실제 Firebase로 처리합니다. 서버 API를 연결할 때는 `ARTLOG_DEMO=false`와 HTTPS `API_BASE_URL`을 설정해야 합니다.

## 도슨트

문서에 명시된 요청 필드는 `question`, `history`입니다. 현재 질문은 `question`으로 한 번만 보내고 `history`에는 직전 12개 메시지만 포함합니다. history 개별 항목의 `{role, content}`와 12개 제한은 프론트의 임시 결정이며 서버 확인이 필요합니다. 대화는 서버 저장을 가정하지 않습니다.

```json
{"question":"이 작품은 언제 그렸나요?","history":[{"role":"user","content":"작품을 소개해 주세요."},{"role":"assistant","content":"이전 답변"}]}
```

문서에 명시된 응답은 다음과 같습니다. 필수 응답 필드가 없으면 오류를 표시합니다. 응답의 출처만 화면에 표시하고 비어 있는 출처를 만들어 붙이지 않습니다. `refused: true`이면 안내 말풍선으로 표시합니다.

```json
{"answer":"근거에 따른 답변","refused":false,"sources":[{"document_id":123,"title":"작품 해설","doc_type":"artwork_commentary","source_name":"국립중앙박물관","source_url":"https://example.org/source"}]}
```

## 서버 담당자와 확정할 응답 형식

다음은 현재 어댑터의 가정이며 **확정된 서버 명세가 아닙니다.** 확정 시 `lib/api/artlog_api.dart`, `lib/models.dart`를 조정하면 됩니다.

- 로그인: JSON `{email, password}` 요청, `{access_token: string}` 응답. OAuth2 form 방식인지, 로그인 식별자가 무엇인지, 토큰 갱신이 필요한지 확인해야 합니다. JWT는 브라우저 저장소에 저장하지 않습니다.
- 목록: JSON 배열 또는 `{items: [...]}` / `{data: [...]}`. 페이지 정보·커서·총 개수는 미확정입니다. 카드와 상세의 차이도 확인해야 합니다.
- 작품: `id`, `slug`, `title`, `title_en`, `artist_id`, `movement_id`, `year_label`, `medium`, `dimensions`, `collection`, `description`, `image_url`, `image_source_url`, `image_license`. 필드 이름은 DB 모델과 대조했습니다. `artist_name` 또는 중첩 `artist`가 없으면 별도 작가 목록에서 이름을 찾습니다.
- 작가: `id`, `slug`, `name`, `name_en`, `birth_year`, `death_year`, `movement_id`, `summary`, `portrait_url`. 사조 이름이 없으면 사조 목록에서 조합할 수 있습니다. 카드의 `is_liked`·`is_followed` 사용 여부는 아직 미정이라 `/me/likes`, `/me/follows`를 사용합니다.
- 캘린더: `[{date: "2026-10-12", artwork_count: 2}]` 가정. `viewed_on` / `count` 별칭도 지원합니다. 실제 응답 래퍼와 필드명 확인이 필요합니다.
- 하루 상세·좋아요·팔로우: 작품/작가 카드 목록 가정. 관계 테이블만 응답한다면 카드 변환 규격을 추가로 확정해야 합니다.
- 좋아요·팔로우·열람 POST: 2xx 성공으로 처리하고 204의 빈 본문도 허용합니다. 요청 본문은 문서가 없어 보내지 않습니다.
- 이미지: 공개 HTTPS URL 또는 웹 사이트 기준 `/...` 경로를 가정합니다. API 서버에 상대적인 이미지 경로·CORS·인증 이미지 제공 방식은 확정해야 합니다.
- 추천: 서버 순서를 유지합니다. 맞춤 추천 API는 메서드만 준비했고 별도 추천 화면은 없습니다. 추천의 `reason`을 표시하려면 응답 스키마 확정 후 연결합니다.

## 실패 처리와 검증 범위

인증 없이 보호된 경로는 요청하지 않습니다. 401은 토큰을 비우고 로그인 상태를 초기화합니다. 403/404/429/5xx·네트워크 실패·잘못된 JSON에 사용자 안내를 표시합니다. 실패한 좋아요·팔로우는 상태를 바꾸지 않고 중복 클릭 중 요청을 막습니다. 열람은 서울 기준 날짜와 작품별로 세션 내 중복 요청을 줄이며 서버도 중복 처리 규칙을 확정해야 합니다.

실제 모드에서 API 실패를 예시 데이터로 숨기지 않습니다. 웹과 API 출처가 다르면 서버의 CORS 설정이 필요합니다. 실제 서버가 제공되면 로그인 → 목록/상세 → 대화/출처 → 좋아요/팔로우 → 캘린더 → 401 복구를 통합 검증해야 합니다.
