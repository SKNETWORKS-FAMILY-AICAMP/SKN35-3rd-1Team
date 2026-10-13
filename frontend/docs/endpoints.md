# 프론트엔드 엔드포인트 점검표

점검일: 2026-10-13 · 기준: 모든 팀 브랜치를 통합한 dev · 공식 계약: [docs/api.md](../../docs/api.md).

실제 모드는 `API_BASE_URL=https://skn35-3rd-1team-production.up.railway.app/`, `ARTLOG_DEMO=false`, `AUTH_PROVIDER=firebase`입니다. 경로에는 DB 숫자 ID를 쓰며 공통 접두사 `/api`를 한 번만 붙입니다. 목록은 평평한 JSON 배열입니다. 별도 검색 API 없이 전체 목록을 로컬 검색·필터·정렬합니다.

| 메서드 | 경로 (`/api` 생략) | 로그인 | 프론트 사용 |
| --- | --- | --- | --- |
| GET | `/movements`, `/artists`, `/artworks` | 없음 | 카탈로그·필터·검색 |
| GET | `/artists/{id}`, `/artworks/{id}` | 없음 | 상세 화면 |
| GET | `/artworks/{id}/similar` | 없음 | 비슷한 작품. 실제 서버 200·3개 확인 |
| POST | `/artworks/{id}/chat` | 선택 | 질문·history 전송. 기준 서버 코드는 답변 생성 501 |
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

## 인증·계정 변경

Firebase 이메일 가입·로그인·재설정과 Google 팝업 로그인은 Flutter SDK에서 처리합니다. Google의 첫 로그인도 동일 Firebase 사용자/ID 토큰 흐름을 사용합니다. 운영 모드는 서버의 `/auth/login`·`/auth/signup`을 호출하지 않습니다. SDK에서 요청마다 ID 토큰을 받아 Bearer 헤더로 보내며 UID를 별도 본문·경로에 보내지 않습니다. 401은 한 번만 토큰을 강제 갱신하고 다시 거절되면 안내합니다. Firebase 세션을 임의로 로그아웃시키지 않습니다.

계정 변경 시 기존 개인 요청은 새 계정으로 재시도하지 않고 늦은 응답을 버립니다. 서재·대화·입력도 초기화합니다. 서버 `AUTH_MODE=dev`에서는 모든 토큰이 한 개발 사용자로 처리되므로 서버의 Firebase 모드 확인은 별도로 필요합니다. 이번 작업에서 Railway 설정을 변경하거나 현재 모드 값을 확인하지 않았습니다.

## 대화·출처

- 질문 1~500자, history 직전 최대 12개 `{role, content}`, 각 content 최대 4000자.
- 실패한 질문은 재시도 history에 중복 넣지 않습니다.
- 응답 `{answer, refused, sources}`의 출처·원문·라이선스만 표시합니다. `refused: true`는 범위 밖 안내 말풍선입니다.
- 저장 대화 `{role, content, refused, sources, created_at}`를 복원하고 다시 질문할 때 맥락으로 보냅니다.
- 내 대화 목록은 `{artwork, last_message, updated_at}`이며 UTC 시각을 서울 시각으로 표시합니다.
- 실제 답변 생성과 `chat_service.save_exchange` 호출은 서버 담당 후속 작업입니다.

## 추천·서재·실패

맞춤 추천은 카드에 `reason`이 더해진 평평한 응답입니다. 서버 순서를 유지하고 nullable reason은 표시하지 않습니다. 좋아요·팔로우가 바뀌면 추천을 새로 요청합니다. 날짜 상세는 작품 카드에 `view_count`·`last_viewed_at`이 추가된 배열입니다. 감상 메모는 서버 API가 없어 현재 브라우저에만 UID별로 저장합니다.

ERD 점검 후 캘린더의 `artwork_count`는 날짜별 작품 수, `total_views`는 반복 감상을 포함한 횟수로 분리해 사용합니다. 날짜 상세의 `view_count`도 표시합니다. 같은 작품을 다시 열면 POST `/artworks/{id}/views`를 다시 보내며 동시 중복 호출만 억제합니다. `is_featured`는 공개 작품 목록의 큐레이터 순서·대표 작품에 반영합니다.

출처에 선택 필드 `basis_sources: [{source_name, source_url}]`가 오면 원문과 별도로 ‘편집 보강 근거’를 표시합니다. 통합 dev의 공통 API 계약에 포함되며, 필드 생략 시 기존 응답과도 호환됩니다. 전체 ERD 대응은 [ERD 연결 점검](erd-mapping.md)에 정리했습니다.

401/403/404/422/429/501/503, 기타 서버 실패·시간 초과·연결 오류·잘못된 JSON을 구분합니다. 미리보기 데이터로 대체하지 않습니다. 추천·대화 복원·대화 목록은 각각 로딩·빈 상태·오류·재시도를 제공합니다. 대화 초기화 실패 시 기존 내용을 유지합니다.

## 검증과 인수인계

실제 공개 API에서 health·OpenAPI·유사 작품을 확인했습니다. 개인 기능은 MockClient·가짜 Firebase 세션으로 API 계약·화면·계정 변경을 검사했으며 운영 개인 계정의 서버 저장 전체 성공을 의미하지 않습니다. 전체 작업·담당자 후속 조치·전달 문구는 [프론트 인수인계](frontend-handoff.md)를 참고하세요.

## 회원 온보딩

나이대·성별·설명 스타일은 선택형 온보딩에서 받고 UID별로 이 브라우저에만 저장합니다. 통합 ERD에 user_preferences 저장 구조는 있으나 프로필 API는 아직 없으므로 추가 경로를 호출하거나 챗 요청에 임의의 필드를 넣지 않습니다. age_range와 birth_year, explanation_style과 tone/explanation_level의 차이는 계약 확정 후 연결합니다. 프로필 저장·맞춤 말투를 위한 후속 계약 제안은 [인수인계](frontend-handoff.md)의 Google 로그인·회원 온보딩 절을 참고하세요.
