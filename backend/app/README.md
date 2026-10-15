# backend/app

FastAPI 애플리케이션 패키지입니다. 진입점 `main.py`를 이 폴더에 둡니다.

## main.py 가 하는 일

앱 생성, CORS 설정, 예외 처리기 등록, `api/`의 라우터 연결까지만 합니다. 서비스 로직은 넣지 않습니다.

## 계층과 의존 방향

```text
api/routes → services → repositories → models
                 └────→ rag → repositories
                         └──→ clients
```

| 폴더 | 한 줄 역할 | 이 폴더가 해서는 안 되는 일 |
| --- | --- | --- |
| `api/` | 요청을 받아 서비스를 호출하고 응답을 돌려줌 | DB 조회, 추천 계산 |
| `services/` | 기능의 흐름과 규칙 | SQL 작성, HTTP 응답 형식 결정 |
| `repositories/` | TiDB 읽기·쓰기 | 추천 순위 결정 같은 판단 |
| `models/` | 테이블 정의 | 로직 |
| `schemas/` | API 입출력 형식 | DB 접근 |
| `rag/` | 검색과 답변 생성 | 좋아요·팔로우 같은 사용자 기록 처리 |
| `clients/` | 외부 임베딩·LLM API 호출 | 프롬프트 내용 결정 |
| `core/` | 설정, 인증, 예외, 공통 의존성 | 기능별 로직 |
| `db/` | 엔진과 세션 | 쿼리 |

화살표 반대 방향으로 import하지 않습니다. 계층을 건너뛰는 것(라우터가 repository를 직접 호출)도 피합니다.
