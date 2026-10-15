# mcp

외부 MCP 클라이언트용 컬렉션 도구 서버입니다. `main.py`가 `collection_server.mcp_app`을 `/mcp`에 마운트하고, 앱 수명 동안 `new_transport()`의 세션 관리자를 실행합니다.

- `collection_server.py`: 공식 Python SDK의 stateless Streamable HTTP 서버. 매 요청의 Firebase ID 토큰(`core/auth.py`)으로 사용자를 확인합니다. 도구: `list_collections`, `search_artworks`, `create_collection`, `add_artwork_to_collection`, `list_auto_collections`, `create_collection_from_views`.

도구 인자에는 user_id가 없고, REST와 같은 소유권 검사·중복 방지 서비스(`services/mypage_service.py`, `services/auto_collections.py`)를 호출합니다. 직접 DB를 변경하지 않습니다. 접속 방법과 설정은 [API 명세](../../../docs/api.md)의 MCP 절을 참고합니다.

패키지 이름이 외부 `mcp` 라이브러리와 같지만, import는 항상 `app.mcp...` 절대 경로로 하므로 `from mcp.server.fastmcp import ...`는 라이브러리를 가리킵니다.
