# api/routes

엔드포인트를 기능별 파일로 나눕니다. `chat.py`는 JSON 답변과 SSE 스트리밍 답변을 제공하며 `app/api/router.py`에 등록되어 있습니다. 로그인 사용자 답변은 `chat_service.save_exchange`로 저장합니다. 요청과 SSE 이벤트 명세는 `docs/api.md`를 따릅니다.

## 파일과 엔드포인트

| 파일 | 메서드와 경로 | 설명 | 로그인 |
| --- | --- | --- | --- |
| `health.py` | `GET /api/health` | 서버 상태 확인 (구현됨) | |
| `movements.py` | `GET /api/movements` | 사조 목록 | |
| `artists.py` | `GET /api/artists` | 작가 목록 (`movement_id` 필터) | |
| | `GET /api/artists/{artist_id}` | 작가 상세 | |
| `artworks.py` | `GET /api/artworks` | 작품 목록 (`artist_id`, `movement_id` 필터) | |
| | `GET /api/artworks/{artwork_id}` | 작품 상세 | |
| `chat.py` | `POST /api/artworks/{artwork_id}/chat` | 작품 도슨트 질문. 답변과 출처 반환. 로그인 상태면 기록 저장 | 선택 |
| | `POST /api/artworks/{artwork_id}/chat/stream` | 같은 질문의 실시간 SSE 답변. `done`에 최종 답변과 출처 포함 | 선택 |
| | `GET /api/artworks/{artwork_id}/chat/messages` | 이 작품과 나눈 내 대화 기록 | 필요 |
| | `DELETE /api/artworks/{artwork_id}/chat` | 이 작품 대화 초기화 | 필요 |
| | `GET /api/me/chats` | 내가 대화한 작품 목록 | 필요 |
| `likes.py` | `PUT /api/artworks/{artwork_id}/like` | 좋아요 (여러 번 호출해도 결과 동일) | 필요 |
| | `DELETE /api/artworks/{artwork_id}/like` | 좋아요 취소 | 필요 |
| | `GET /api/me/likes` | 내가 좋아요한 작품 | 필요 |
| `follows.py` | `PUT /api/artists/{artist_id}/follow` | 팔로우 | 필요 |
| | `DELETE /api/artists/{artist_id}/follow` | 팔로우 취소 | 필요 |
| | `GET /api/me/follows` | 내가 팔로우한 작가 | 필요 |
| `library.py` | `POST /api/artworks/{artwork_id}/views` | 열람 기록 남기기 | 필요 |
| | `GET /api/me/library/calendar?month=2026-10` | 날짜별 열람 작품 수 | 필요 |
| | `GET /api/me/library/days/{date}` | 그날 본 작품 목록 | 필요 |
| `recommendations.py` | `GET /api/artworks/{artwork_id}/similar` | 이 작품과 비슷한 작품 3개 | |
| | `GET /api/me/recommendations/artworks` | 좋아요 기반 맞춤 작품 3개 | 필요 |
| | `GET /api/me/recommendations/artists` | 추천 작가 3명 | 필요 |
| `diary.py` | `GET /api/diary/feed` | 공개 감상평 커서 페이지 | |
| | `GET /api/me/diary`, `GET /api/me/diary/artworks/{artwork_id}` | 월별 내 감상평 / 작품별 내 감상평 | 필요 |
| | `POST /api/me/diary`, `PUT/DELETE /api/me/diary/{entry_id}` | 작품마다 한 편 작성·수정·삭제 | 필요 |
| `mypage.py` | `GET/PUT /api/me/profile` | 닉네임·생년월일·대화 스타일·온보딩 | 필요 |
| | `GET/POST /api/me/collections`, `PUT/DELETE /api/me/collections/{collection_id}` | 비공개 컬렉션 목록·생성·수정·삭제 | 필요 |
| | `GET /api/me/collections/{collection_id}/items`, `PUT/DELETE /api/me/collections/{collection_id}/items/{artwork_id}` | 작품 커서 페이지·담기·꺼내기 | 필요 |
| | `GET /api/me/collections/auto`, `GET /api/me/collections/auto/{key}` | 감상 기록 자동 묶음 / 자동·테마 상세 | 필요 |
| | `POST /api/me/collections/themes/refresh` | AI 감성 테마 생성·캐시 재사용 | 필요 |
| | `GET /api/me/critiques`, `GET /api/me/activity` | 내 감상평 커서 페이지 / 활동 목록 | 필요 |
| | `GET/POST /api/me/taste`, `POST /api/me/collections/chat` | AI 취향 소개 / 저장 전 컬렉션 제안 | 필요 |
| `social.py` | `GET/PUT /api/me/social` | 내 공개 프로필·팔로우 목록 공개 설정 | 필요 |
| | `GET /api/users/{public_id}` | 공개 프로필 | 선택 |
| | `GET /api/users/{public_id}/diary` | 해당 회원의 공개 감상평 커서 페이지 | |
| | `PUT/DELETE /api/users/{public_id}/follow` | 회원 팔로우·취소 | 필요 |
| | `GET /api/users/{public_id}/followers`, `GET /api/users/{public_id}/following` | 팔로워·팔로잉. 비공개면 본인 외 403 | 선택 |

## 규칙

- 좋아요와 팔로우는 `PUT`/`DELETE`로 둡니다. 같은 요청이 두 번 와도 결과가 같아서 프론트가 재시도하기 쉽습니다.
- 로그인은 Firebase Auth(프론트)이고 API는 따로 없습니다. "필요" 경로는 `user: CurrentUser`(토큰 없으면 401), "선택" 경로는 `user: OptionalUser`(토큰 없으면 `None`, 익명 처리)로 사용자를 받습니다(`app/core/auth.py`). 운영 환경에서는 `AUTH_MODE=firebase`로 토큰을 검증해야 합니다. `AUTH_MODE=dev`는 모든 Bearer 토큰을 개발용 사용자 하나로 처리합니다.
- 요청·응답 모델은 `app/schemas/`에 있습니다. 카탈로그·활동 목록은 배열이고, 공개 피드·내 감상평 페이지·컬렉션 작품은 `{items, next_cursor}`입니다. 월별 내 다이어리는 배열입니다. 목록별 페이지 규칙은 공식 API 명세를 따릅니다. 오류는 `{"detail": ...}`입니다.
- 사용자 id는 URL이나 본문으로 받지 않고 토큰에서 꺼냅니다. `/api/me/...` 경로를 쓰는 이유입니다.
- DB 세션은 `db: DbSession`(`app/db/session.py`)으로 받습니다.
- 챗봇 응답에는 답변 본문과 함께 출처 목록이 반드시 포함됩니다. 형식은 `schemas/README.md`를 따릅니다.
- 맞춤 추천은 좋아요가 없는 사용자에게도 빈 배열이 아니라 대체 추천을 돌려줍니다. 분기는 서비스가 합니다.
