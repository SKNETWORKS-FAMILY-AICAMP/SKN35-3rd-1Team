# routes

URL과 페이지의 연결, 화면 접근 규칙을 관리합니다.

## 들어갈 파일

- `router.tsx`: 경로와 페이지 연결 (경로 목록은 `pages/README.md`의 표)
- `ProtectedRoute.tsx`: 로그인이 필요한 화면 보호

## 규칙

- 로그인하지 않은 사용자가 `/library`에 들어오면 `/login`으로 보내고, 로그인 후 원래 가려던 곳으로 돌려보냅니다.
- 화면을 막는 것은 편의 기능입니다. 실제 권한 검사는 FastAPI가 토큰으로 합니다.
