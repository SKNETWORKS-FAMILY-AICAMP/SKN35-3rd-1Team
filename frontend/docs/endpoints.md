# 프론트엔드 API 연결표

갱신: **2026-10-15 · dev `6f0b40a`**. 기준은 [Flutter API 어댑터](../lib/api/artlog_api.dart)와 [서버 API 계약](../../docs/api.md)입니다. 아래 경로는 공통 접두사 `/api`를 생략합니다. `API_BASE_URL`에 `/api`가 있어도 한 번만 붙입니다.

실제 운영 빌드는 `ARTLOG_DEMO=false`, `AUTH_PROVIDER=firebase`입니다. 카탈로그는 평평한 배열을 받아 로컬 검색·필터·정렬하며, 피드/컬렉션의 페이지 응답과 구분합니다.

## 현재 화면에서 사용하는 호출

| 메서드 | 경로 | 인증 | 사용 |
| --- | --- | --- | --- |
| GET | `/movements`, `/artists`, `/artworks` | 공개 | 카탈로그, optional `artist_id`·`movement_id` 필터 |
| GET | `/artists/{id}`, `/artworks/{id}` | 공개 | 작가·작품 상세 |
| GET | `/artworks/{id}/similar` | 공개 | 관련 작품, 서버 순서 유지 |
| POST | `/artworks/{id}/views` | 필요 | 상세 열람 기록, 204 |
| PUT / DELETE | `/artworks/{id}/like` | 필요 | 작품 하트, 204 |
| GET | `/me/likes` | 필요 | 좋아요한 작품 |
| PUT / DELETE | `/artists/{id}/follow` | 필요 | 작가 하트, 204 |
| GET | `/me/follows` | 필요 | 관심 작가 |
| GET | `/me/recommendations/artworks`, `/me/recommendations/artists` | 필요 | 맞춤 추천·`reason` |
| POST | `/artworks/{id}/chat/stream` | 선택 | SSE 도슨트, 로그인 시 저장 |
| POST | `/artworks/{id}/chat` | 선택 | SSE 미지원 시 JSON 대체 |
| GET | `/artworks/{id}/chat/messages` | 필요 | 작품별 대화 복원 |
| DELETE | `/artworks/{id}/chat` | 필요 | 대화 초기화, 204 |
| GET | `/diary/feed` | 공개 | 공개 감상, `limit=12`·`before_id`·optional `artwork_id` |
| GET | `/me/diary?month=YYYY-MM` | 필요 | 월별 개인 감상 |
| GET | `/me/diary/artworks/{artwork_id}` | 필요 | 해당 작품의 내 감상, 없으면 null |
| POST | `/me/diary` | 필요 | 감상 생성, `entry_date`·`content`·`is_public`·`artwork_id` |
| PUT / DELETE | `/me/diary/{entry_id}` | 필요 | 해당 글 수정·삭제. 날짜가 아닌 글 ID 사용 |
| GET | `/me/library/calendar?month=YYYY-MM` | 필요 | 월별 열람 집계 |
| GET | `/me/library/days/{YYYY-MM-DD}` | 필요 | 날짜별 열람 작품·횟수 |
| GET | `/me/profile` | 필요 | 내 계정 프로필 읽기 |
| GET / POST | `/me/taste` | 필요 | AI 취향 소개 조회·생성 |
| GET | `/me/collections` | 필요 | 직접 저장한 모음 |
| POST | `/me/collections` | 필요 | 모음 생성, optional 최초 `artwork_ids` |
| PUT / DELETE | `/me/collections/{id}` | 필요 | 제목·설명 수정 / 모음 삭제 |
| GET | `/me/collections/{id}/items` | 필요 | 모음 작품, `limit=12`·`before_id` |
| PUT / DELETE | `/me/collections/{id}/items/{artwork_id}` | 필요 | 작품 담기·꺼내기 |
| GET | `/me/collections/auto`, `/me/collections/auto/{key}` | 필요 | 최근·반복·작가·월별 및 AI 테마 상세 |
| POST | `/me/collections/themes/refresh` | 필요 | 관심 신호에 따라 캐시 재사용·AI 테마 갱신 |
| GET | `/me/critiques` | 필요 | 내 감상 목록, `limit=12`·`before_id` |
| GET / PUT | `/me/social` | 필요 | 공개 ID·팔로우 목록 공개 설정 |
| GET | `/users/{public_id}` | 공개 | 다른 감상가 프로필 |
| GET | `/users/{public_id}/diary` | 공개 | 해당 감상가의 공개 글, `limit=12`·`before_id` |
| PUT / DELETE | `/users/{public_id}/follow` | 필요 | 감상가 팔로우·취소, 204 |
| GET | `/users/{public_id}/followers`, `/users/{public_id}/following` | 공개 정책 적용 | 공개 설정에 따른 목록 |

## 어댑터는 있지만 현재 전용 UI가 없는 호출

| 메서드·경로 | 코드와 현재 노출 |
| --- | --- |
| `GET /me/chats` | `chats()` 존재. 현재 내 피드에 저장 대화 목록 탭 없음 |
| `GET /me/activity?limit=20&offset=0` | 활동 어댑터 존재. 현재 전용 활동 탭 없음 |
| `PUT /me/profile` | 생년월일·말투·완료 여부 모델/저장 메서드 존재. 현재 온보딩·프로필 수정 폼 없음 |
| `POST /me/collections/chat` | `message`·optional `collection_id` 요청, 제안 적용 메서드 존재. 현재 컬렉션 채팅 입력 UI 없음 |
| `POST /auth/login` | 이전 `AUTH_PROVIDER=api` 어댑터. 운영 Firebase 로그인에서 호출하지 않으며 현재 서버 지원 로그인으로 안내하지 않음 |

MCP는 외부 클라이언트의 `/mcp/` 전송 계층입니다. Flutter가 별도 MCP 연결로 토큰을 우회 전달하지 않습니다. 컬렉션 제안이 있더라도 사용자의 저장 동작을 거쳐 일반 CRUD를 실행하는 정책을 유지합니다.

## SSE·질문 계약

```json
{
  "question": "이 그림의 구도를 설명해 주세요.",
  "history": [{"role": "user", "content": "작가가 누구인가요?"}],
  "explanation_style": "standard"
}
```

질문 1~500자, 최근 history 최대 12개·각 content 최대 4000자이며 설명은 `easy`·`standard`·`deep`입니다. 실패한 질문 재시도 시 같은 질문을 history에 중복 삽입하지 않습니다.

SSE는 `token`·`replace`·`done`·`error` 이벤트를 처리합니다. 최종 `done`의 `answer`, `refused`, `sources`, optional `suggestion`으로 메시지를 확정합니다. 출처는 문서 ID·제목·자료 유형·기관·URL·라이선스와 optional `basis_sources`를 표시합니다.

404·405·501일 때만 JSON 경로로 전환합니다. 중간 오류·무응답·503은 자동 재전송하지 않습니다. 응답 헤더와 스트림 무응답에 45초 제한을 적용하며 이를 전체 생성 시간 제한으로 설명하지 않습니다. 종료 이벤트 없이 연결이 닫히면 실패로 안내합니다.

실제 모드에는 프론트 질문 주제별 거절 규칙이 없습니다. `ARTLOG_DEMO=true`의 예시 응답과 서버의 분류·RAG·`refused` 판단을 구분합니다.

## 인증·계정 변경·오류

Firebase 이메일·Google 인증은 SDK에서 수행하고 ID 토큰을 Bearer 헤더에 넣습니다. UID를 사용자 선택 본문에 넣지 않습니다. 401은 같은 세션에서 토큰을 한 번 갱신합니다. 계정이 바뀐 개인 요청은 새 계정 토큰으로 재전송하지 않고 늦은 응답을 버립니다.

빈 204 응답은 JSON으로 읽지 않습니다. 401/403/404/409/422/429/501/503, 네트워크·시간 초과·형식 오류를 안내합니다. 컬렉션 10개·30점 초과의 409 안내를 표시하며 실제 API 실패를 데모 데이터로 바꾸지 않습니다.

## 기록·공개 범위

공개 범위는 저장할 때 반영하며 새 감상은 기본 비공개입니다. 작품별 한 편·하루 여러 편을 허용합니다. 본인 글만 삭제 UI를 제공하고 서버가 소유권을 재검증합니다. 성공 시 피드·개인 기록을 갱신하고 실패 시 글을 유지합니다.

캘린더 날짜는 서버의 서울 날짜 문자열을 따릅니다. `artwork_count`는 서로 다른 작품 수, `total_views`·`view_count`는 반복 열람 횟수입니다. 동일 상세의 동시 POST는 억제하지만 나중 재방문은 다시 기록합니다.

최신 화면·남은 작업은 [인수인계](frontend-handoff.md), 테이블 대응은 [ERD 안내](erd-mapping.md)를 참고하세요.
