# api

기능별 라우터를 묶어 `main.py`에 넘깁니다.

- `router.py`: `routes/`의 카탈로그·채팅·다이어리·활동·마이페이지·회원 소셜 라우터를 모읍니다. `/api` 접두사는 `main.py`에서 붙입니다.
- `stub.py`: 미구현 경로용 501 응답 헬퍼입니다. 현재 등록된 라우트에서는 사용하지 않습니다.

요청·응답 계약은 [API 명세](../../../docs/api.md)를 참고합니다. 로그인 의존성은 `app/core/auth.py`의 `CurrentUser`·`OptionalUser`, DB 세션은 `app/db/session.py`의 `DbSession`입니다. 라우터는 입력 검증·서비스 호출·응답 반환을 담당하며, SSE 채팅은 `StreamingResponse`를 사용합니다.

도메인 예외는 `core/exceptions.py`에서 HTTP 응답으로 변환합니다. 다이어리·마이페이지·소셜·AI 서비스는 `HTTPException`도 사용하므로 변경 시 두 경로를 함께 확인합니다. 외부 컬렉션 도구는 REST 라우터와 별도로 `main.py`가 `/mcp`에 마운트합니다.
