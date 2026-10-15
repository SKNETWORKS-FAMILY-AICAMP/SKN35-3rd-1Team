# core

설정, 인증, 예외와 공통 규칙을 둡니다.

| 파일 | 역할 |
| --- | --- |
| `config.py` | 저장소 루트 `.env`와 환경변수에서 TiDB·Firebase·OpenAI·Chroma·CORS·MCP·시간대 설정 로드 |
| `auth.py` | Firebase ID 토큰 검증, 내부 사용자 조회·최초 등록, `CurrentUser`·`OptionalUser` 의존성 |
| `exceptions.py` | 도메인 예외와 FastAPI 예외 처리기 |
| `timeutil.py` | UTC 시각과 `APP_TIMEZONE`(기본 `Asia/Seoul`) 날짜 계산 |
| `collection_limits.py` | 계정당 컬렉션 10개·컬렉션당 작품 30점의 공통 한도 |

로그인은 프론트 Firebase Auth가 처리합니다. 서버는 별도 비밀번호 로그인이나 토큰 발급 API를 제공하지 않습니다. `AUTH_MODE=firebase`에서는 Firebase Admin SDK로 ID 토큰을 검증하고, 검증된 UID로 `users`를 찾습니다. `AUTH_MODE=dev`에서는 Bearer 토큰이 있는 요청을 고정 개발 사용자로 처리합니다. 두 모드 모두 필수 인증 경로에 토큰이 없으면 401이고, 선택 인증 경로는 익명으로 처리합니다. 선택 인증에서도 잘못된 Firebase 토큰은 401입니다.

DB 의존성은 `core/deps.py`가 아니라 `app/db/session.py`에 있습니다. 임베딩 차원 기준은 `app/models/base.py`의 `EMBEDDING_DIMENSION`이며 설정 환경변수로 바꾸지 않습니다. 비밀값은 Git에 넣지 않습니다. 열람 날짜는 DB의 `CURDATE()` 대신 `timeutil`로 계산합니다.
