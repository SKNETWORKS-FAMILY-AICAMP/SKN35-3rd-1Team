# 프론트엔드 엔드포인트 점검표

점검일: 2026-10-12. 기준은 `docs/api.md`, 서버 라우터·Pydantic 스키마와 Railway의 OpenAPI입니다.

## 실제 서버 연결

서버는 도슨트 답변 생성(`POST /chat`)을 뺀 모든 경로가 구현되어 있습니다. 채팅 기록·비슷한 작품·맞춤 추천도 동작하며, 도슨트 답변만 아직 `501`입니다. 서버 인증은 `AUTH_MODE=dev`라 아무 Bearer 토큰이나 개발용 사용자 한 명으로 처리됩니다(Firebase 토큰 검증 전). 자동 테스트는 MockClient로 요청 경로·메서드·파라미터·응답 처리만 검증합니다.
- `API_BASE_URL=https://skn35-3rd-1team-production.up.railway.app/`
- `ARTLOG_DEMO=false`, `AUTH_PROVIDER=firebase`
- 공통 접두사는 `/api`. 루트 주소, 끝의 `/`, `/api/`를 모두 처리합니다.
- 실제 요청에는 TiDB의 숫자 `id`를 사용합니다. `slug` 또는 미리보기 ID를 보내지 않습니다.
- 목록은 JSON 배열입니다. 작품·작가의 카드/상세 스키마는 `backend/app/schemas/catalog.py`, 캘린더는 `library.py`가 기준입니다.
- 검색 API가 없어 받아 둔 전체 목록을 로컬에서 검색·필터·정렬합니다.

2026-10-12 Railway에서 health 200, 사조 4개·작가 8명·작품 219점을 확인했습니다. TiDB에 TLS로 직접 접속해 같은 개수와 `20261012_0005` 마이그레이션, `users.firebase_uid/email/nickname` 컬럼을 확인했습니다. 운영 Vercel 주소의 CORS와 Authorization·PUT·DELETE 허용도 확인했습니다.

## 경로

| 메서드 | 경로 | 인증 | 현재 서버 상태 |
| --- | --- | --- | --- |
| GET | `/api/health` | 없음 | 구현 |
| GET | `/api/movements` | 없음 | 구현 |
| GET | `/api/artists?movement_id=...` | 선택 | 구현 |
| GET | `/api/artists/{artist_id}` | 선택 | 구현 |
| GET | `/api/artworks?artist_id=...&movement_id=...` | 선택 | 구현 |
| GET | `/api/artworks/{artwork_id}` | 선택 | 구현 |
| PUT / DELETE | `/api/artworks/{artwork_id}/like` | 필요 | 구현, 204 |
| GET | `/api/me/likes` | 필요 | 구현, 작품 카드 배열 |
| PUT / DELETE | `/api/artists/{artist_id}/follow` | 필요 | 구현, 204 |
| GET | `/api/me/follows` | 필요 | 구현, 작가 카드 배열 |
| POST | `/api/artworks/{artwork_id}/views` | 필요 | 구현, 204 |
| GET | `/api/me/library/calendar?month=YYYY-MM` | 필요 | 구현 |
| GET | `/api/me/library/days/{YYYY-MM-DD}` | 필요 | 구현 |
| POST | `/api/artworks/{artwork_id}/chat` | 선택 | 501, 준비 중 |
| GET | `/api/artworks/{artwork_id}/similar` | 없음 | 501, 준비 중 |
| GET | `/api/me/recommendations/artworks` | 필요 | 501, 준비 중 |
| GET | `/api/me/recommendations/artists` | 필요 | 501, 준비 중 |

캘린더는 `[{date, artwork_count, total_views}]`이고 감상한 날짜만 반환합니다. 하루 상세는 작품 카드에 `view_count`, `last_viewed_at`을 더한 배열입니다. 서버는 서울 기준 같은 작품·같은 날의 열람 횟수를 누적합니다. 프론트는 화면 세션 내 중복 열람 요청을 줄입니다.

## Firebase 인증

이메일 가입·로그인·비밀번호 재설정은 Flutter Firebase SDK가 담당합니다. 팀 서버에는 `/api/auth/login`, `/api/auth/signup`이 없으며 운영 Firebase 모드에서 호출하지 않습니다. `AUTH_PROVIDER=api`의 기존 어댑터는 이전 목업 호환용이며 현재 서버에서는 지원하지 않습니다.

요청마다 Firebase SDK에서 ID 토큰을 받아 `Authorization: Bearer <ID token>`으로 전송합니다. UID를 요청 본문·경로·쿼리로 보내지 않습니다. 401이면 강제로 갱신해 한 번만 재시도하며, 계속 실패하면 한국어 오류를 표시합니다. 서버 거부만으로 Firebase 세션을 강제로 로그아웃시키지 않습니다.

이번 변경의 서버 `AUTH_MODE=firebase`는 `firebase_admin.auth.verify_id_token`으로 검증한 uid·email·name만 `get_or_create_by_firebase_uid`에 전달합니다. name이 없으면 이메일 앞부분을 사용합니다. 검증에 실패하면 401이며 사용자 행을 생성하지 않습니다. 서버 인증 정보는 [배포 설정](../../infra/README.md)을 참고합니다.

Railway의 `AUTH_MODE=dev`에서는 모든 Bearer 토큰이 개발용 한 계정입니다. **코드 병합·Railway 배포와 서버 서비스 계정 설정 후 담당자가 `AUTH_MODE=firebase`로 전환해야 운영 계정별 기록이 분리됩니다.**

## 도슨트와 오류

도슨트 계약은 `{question, history}`이며 질문은 1~500자, history는 직전 12개 `{role, content}`입니다. 응답 계약은 `{answer, refused, sources}`이고 실제 응답에 포함된 출처만 표시합니다. 현재 서버는 501이므로 기능 준비 중 안내를 표시합니다. 실제 API 실패를 예시 답변이나 예시 작품으로 대체하지 않습니다.

401/403/404/429/501, 기타 서버 실패·시간 초과·연결 오류·잘못된 JSON을 구분해 안내합니다. 실패한 좋아요·팔로우는 화면 상태를 확정하지 않습니다. 감상 메모는 서버 API가 없어 Firebase UID별로 현재 브라우저에만 저장합니다.

## 검증 범위

Flutter 요청 계약 테스트는 경로·메서드·숫자 ID·필터·날짜·토큰 갱신·오류 처리를 확인합니다. 백엔드 테스트는 검증 실패 401·사용자 생성 금지와 UID별 사용자 재사용/분리를 확인합니다. 실제 토큰 및 TiDB 통합 검증 결과는 [Firebase·배포 안내](firebase-vercel.md)에 기록합니다. 현재 운영 Railway의 개발 인증 모드와 로컬 Firebase 모드의 검증 결과를 구분합니다.
