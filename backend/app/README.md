# backend/app

FastAPI 애플리케이션 패키지입니다. 진입점 `main.py`를 이 폴더에 둡니다.

## main.py 가 하는 일

앱 생성, CORS 설정, 예외 처리기 등록, `/api` 라우터 연결과 `/mcp` 마운트·전송 세션 수명 관리를 담당합니다. 서비스 로직은 넣지 않습니다.

## 계층과 의존 방향

```text
api/routes ─→ docent ─→ services ─→ repositories → models
     │           └────→ rag ─→ repositories
     │                    └──→ clients
     └─→ services
mcp ────→ services
```

| 폴더 | 한 줄 역할 | 이 폴더가 해서는 안 되는 일 |
| --- | --- | --- |
| `api/` | 요청을 받아 서비스를 호출하고 응답을 돌려줌 | DB 조회, 추천 계산 |
| `docent/` | 도슨트 채팅 답변 흐름: 질문 분류·범위 판정·검색·답변 생성·출처 검증·SSE·컬렉션 담기 제안 | 사용자 기록을 직접 변경하기 (저장은 서비스 호출) |
| `services/` | 도메인 기능의 흐름과 규칙. 마이페이지·소셜·테마는 직접 DB 쿼리도 사용 | 라우터 등록, RAG 검색 호출 |
| `repositories/` | TiDB 읽기·쓰기 | 추천 순위 결정 같은 판단 |
| `models/` | 테이블 정의 | 로직 |
| `schemas/` | API 입출력 형식 | DB 접근 |
| `rag/` | 청킹·질문 분류·검색·프롬프트 (도슨트가 쓰는 재료) | 서비스 호출, LLM 답변 생성 |
| `mcp/` | 외부 MCP 클라이언트용 컬렉션 도구 서버(`/mcp`) | 서비스를 거치지 않은 DB 변경 |
| `clients/` | 임베딩 API·Chroma 연결 | 프롬프트 내용 결정 |
| `core/` | 설정, 인증, 예외, 공통 의존성 | 기능별 로직 |
| `db/` | 엔진과 세션 | 쿼리 |

도슨트 답변 생성·출처 검증·SSE는 `docent/`에 있습니다. `mcp/collection_server.py`는 서비스 계층을 호출하는 외부 도구 진입점입니다. 기존 구조와 실제 예외를 확인하며 변경합니다.
