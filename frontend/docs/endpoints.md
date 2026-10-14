# 프론트엔드 엔드포인트 점검표

점검일: 2026-10-14 · 기준: 모든 팀 브랜치를 통합한 dev · 공식 계약: [docs/api.md](../../docs/api.md).

실제 모드는 `API_BASE_URL=https://skn35-3rd-1team-production.up.railway.app/`, `ARTLOG_DEMO=false`, `AUTH_PROVIDER=firebase`입니다. 경로에는 DB 숫자 ID를 쓰며 공통 접두사 `/api`를 한 번만 붙입니다. 목록은 평평한 JSON 배열입니다. 별도 검색 API 없이 전체 목록을 로컬 검색·필터·정렬합니다.

| 메서드 | 경로 (`/api` 생략) | 로그인 | 프론트 사용 |
| --- | --- | --- | --- |
| GET | `/movements`, `/artists`, `/artworks` | 없음 | 카탈로그·필터·검색 |
| GET | `/artists/{id}`, `/artworks/{id}` | 없음 | 상세 화면 |
| GET | `/artworks/{id}/similar` | 없음 | 비슷한 작품. 실제 서버 200·3개 확인 |
| POST | `/artworks/{id}/chat` | 선택 | 질문·history 전송. 선택한 말투와 질문 주제를 적용한 근거 기반 JSON 답변 |
| POST | `/artworks/{id}/chat/stream` | 선택 | 같은 질문의 SSE 스트림. `token`, `replace`, `done`, `error` 이벤트 |
| GET | `/artworks/{id}/chat/messages` | 필요 | 작품별 저장 대화 복원 |
| DELETE | `/artworks/{id}/chat` | 필요 | 대화 초기화, 204 |
| GET | `/me/chats` | 필요 | 서재 대화 내역 탭, 작품별 이어보기 |
| PUT / DELETE | `/artworks/{id}/like` | 필요 | 좋아요·취소, 204 |
| GET | `/me/likes` | 필요 | 좋아요 목록 |
| PUT / DELETE | `/artists/{id}/follow` | 필요 | 팔로우·취소, 204 |
| GET | `/me/follows` | 필요 | 팔로우 목록 |
| POST | `/artworks/{id}/views` | 필요 | 로그인한 상세 열람, 204 |
| GET | `/me/library/calendar?month=YYYY-MM` | 필요 | 월별 감상 날짜·작품 수 |
| GET | `/me/library/days/{YYYY-MM-DD}` | 필요 | 선택한 날짜의 감상 작품 |
| GET | `/me/recommendations/artworks` | 필요 | 로그인 후 발견하기, 작품·추천 이유 |
| GET | `/me/recommendations/artists` | 필요 | 로그인 후 발견하기, 작가·추천 이유 |

스트리밍 경로가 404·405·501을 반환할 때만 기존 JSON 채팅으로 한 번 전환합니다. 이미 시작된 스트림의 오류·타임아웃·503은 자동 재전송하지 않아 질문 저장과 AI 호출이 중복되지 않도록 합니다. `done`의 답변·출처를 최종 결과로 사용하며, 오류가 나면 임시 답변을 지우고 사용자가 재시도할 수 있습니다. 토큰은 서버가 보낸 덩어리대로 표시해 글자별 인위적인 지연을 만들지 않습니다.

## 인증·계정 변경

Firebase 이메일 가입·로그인·재설정과 Google 팝업 로그인은 Flutter SDK에서 처리합니다. Google의 첫 로그인도 동일 Firebase 사용자/ID 토큰 흐름을 사용합니다. 운영 모드는 서버의 `/auth/login`·`/auth/signup`을 호출하지 않습니다. SDK에서 요청마다 ID 토큰을 받아 Bearer 헤더로 보내며 UID를 별도 본문·경로에 보내지 않습니다. 401은 한 번만 토큰을 강제 갱신하고 다시 거절되면 안내합니다. Firebase 세션을 임의로 로그아웃시키지 않습니다.

계정 변경 시 기존 개인 요청은 새 계정으로 재시도하지 않고 늦은 응답을 버립니다. 서재·대화·입력도 초기화합니다. 서버 `AUTH_MODE=dev`에서는 모든 토큰이 한 개발 사용자로 처리되므로 서버의 Firebase 모드 확인은 별도로 필요합니다. 이번 작업에서 Railway 설정을 변경하거나 현재 모드 값을 확인하지 않았습니다.

## 대화·출처

- 질문 1~500자, history 직전 최대 12개 `{role, content}`, 각 content 최대 4000자.
- 실패한 질문은 재시도 history에 중복 넣지 않습니다.
- 응답 `{answer, refused, sources}`의 출처·원문·라이선스만 표시합니다. `refused: true`는 범위 밖 안내 말풍선입니다.
- 저장 대화 `{role, content, refused, sources, created_at}`를 복원하고 다시 질문할 때 맥락으로 보냅니다.
- 내 대화 목록은 `{artwork, last_message, updated_at}`이며 UTC 시각을 서울 시각으로 표시합니다.
- 서버 답변 생성과 로그인 사용자의 `chat_service.save_exchange`를 연결했습니다. 실제 운영에는 AI·Chroma 설정과 DB 마이그레이션이 필요합니다.

## 추천·서재·실패

맞춤 추천은 카드에 `reason`이 더해진 평평한 응답입니다. 서버 순서를 유지하고 nullable reason은 표시하지 않습니다. 좋아요·팔로우가 바뀌면 추천을 새로 요청합니다. 날짜 상세는 작품 카드에 `view_count`·`last_viewed_at`이 추가된 배열입니다. 감상·비평은 서버의 다이어리 API에 저장하며 기본 비공개입니다.

ERD 점검 후 캘린더의 `artwork_count`는 날짜별 작품 수, `total_views`는 반복 감상을 포함한 횟수로 분리해 사용합니다. 날짜 상세의 `view_count`도 표시합니다. 같은 작품을 다시 열면 POST `/artworks/{id}/views`를 다시 보내며 동시 중복 호출만 억제합니다. `is_featured`는 공개 작품 목록의 큐레이터 순서·대표 작품에 반영합니다.

출처에 선택 필드 `basis_sources: [{source_name, source_url}]`가 오면 원문과 별도로 ‘편집 보강 근거’를 표시합니다. 통합 dev의 공통 API 계약에 포함되며, 필드 생략 시 기존 응답과도 호환됩니다. 전체 ERD 대응은 [ERD 연결 점검](erd-mapping.md)에 정리했습니다.

401/403/404/422/429/501/503, 기타 서버 실패·시간 초과·연결 오류·잘못된 JSON을 구분합니다. 미리보기 데이터로 대체하지 않습니다. 추천·대화 복원·대화 목록은 각각 로딩·빈 상태·오류·재시도를 제공합니다. 대화 초기화 실패 시 기존 내용을 유지합니다.

## 검증과 인수인계

실제 공개 API에서 health·OpenAPI·유사 작품을 확인했습니다. 개인 기능은 MockClient·가짜 Firebase 세션으로 API 계약·화면·계정 변경을 검사했으며 운영 개인 계정의 서버 저장 전체 성공을 의미하지 않습니다. 전체 작업·담당자 후속 조치·전달 문구는 [프론트 인수인계](frontend-handoff.md)를 참고하세요.

## 회원 온보딩

생년월일(선택) → 대화 스타일의 2단계입니다. 실제 모드에서는 GET/PUT `/api/me/profile`로 계정에 저장하며 완료 여부도 서버가 보관합니다. 도슨트 프롬프트에는 말투만 적용하고 설명 주제는 사용자의 질문으로 정합니다. 생년월일은 AI로 보내지 않습니다. 이전 브라우저 프로필의 나이대를 정확한 생년월일로 추정하거나 자동 업로드하지 않습니다. 미리보기에서는 UID별 로컬 저장을 유지합니다.


## 감상평·다이어리

`GET /api/diary/feed`, `GET /api/me/diary?month=YYYY-MM`, `POST /api/me/diary`, `PUT/DELETE /api/me/diary/{entry_id}`, `GET /api/me/diary/artworks/{artwork_id}`를 사용합니다. 감상평은 작품마다 한 편이고 하루 개수 제한은 없습니다. 상세 계약은 `docs/api.md`를 참고합니다. 공개 감상은 `/community`, 작품별 감상은 상세 화면, 개인 감상 목록과 캘린더는 `/library`의 내 피드에서 확인합니다.

본인 글에는 공개 피드 카드·작품 상세 감상·내 피드 목록에 삭제 버튼을 표시합니다. 로그인 사용자와 글 작성자의 공개 ID가 일치할 때만 제공하며, 확인 후 날짜가 아닌 해당 `entry_id`로 삭제합니다. 계정 전환 시 확인창을 닫고, 성공하면 피드·감상 기록을 갱신합니다. 실패 시 글을 유지하며 재시도할 수 있습니다. 서버는 별도로 삭제 대상의 소유권을 검증합니다.

공개 설정은 저장 시 반영되며 새 글은 기본 비공개입니다. 체험 모드에서는 브라우저에만 저장되고 실제 공유로 표시하지 않습니다. 기존 브라우저 메모는 작성란에 불러오되 사용자가 저장하기 전 서버로 전송하지 않습니다.


## 마이페이지·컬렉션

`/mypage`는 상단 계정 버튼으로 진입합니다. GET `/me/collections`, POST/PUT/DELETE `/me/collections/{id}`, GET `/me/collections/{id}/items`, PUT/DELETE `/me/collections/{id}/items/{artwork_id}`를 사용합니다. 생성은 POST `/me/collections`입니다. 작품 목록은 12점씩, 활동은 20개씩, 내 감상·비평은 12개씩 더 불러옵니다.

AI 취향 소개는 GET/POST `/me/taste`, 컬렉션 채팅은 POST `/me/collections/chat`입니다. 채팅 응답의 `proposal`을 사용자에게 보여주고 확인 버튼을 누른 뒤 해당 CRUD API로 저장합니다. MCP를 화면에서 별도 호출해 토큰을 전달하는 우회 흐름은 없습니다. 외부 MCP 클라이언트는 별도 `/mcp/` 전송 계층에서 같은 소유권 검사 서비스를 사용합니다.

운영 전환과 전체 계약은 [마이페이지 인수인계](../../docs/mypage-and-collections-2026-10-14.md)를 참고하세요.
