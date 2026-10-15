# backend

FastAPI 서버입니다. API, TiDB 연동, RAG, 추천, 테스트를 담습니다. 프론트엔드와는 HTTP API로만 연결됩니다.

## 구성

| 폴더 | 역할 |
| --- | --- |
| `app/` | 서버 소스 코드 |
| `alembic/` | DB 마이그레이션 |
| `scripts/` | 데이터 적재, 임베딩 생성처럼 필요할 때만 돌리는 작업 |
| `tests/` | 자동 테스트와 테스트 질문셋 |

## 이 폴더 바로 아래에 둘 파일

- `alembic.ini`: Alembic 설정

의존성(`pyproject.toml`, `uv.lock`)과 비밀값(`.env`)은 이 폴더가 아니라 저장소 루트에 둡니다. `.env` 형식은 루트의 `.env.example`을 참고하고, `.env`는 커밋하지 않습니다.
설정 코드 `app/core/config.py`는 실행 위치와 관계없이 저장소 루트의 `.env`를 읽습니다. 명령은 `backend/`에서 실행합니다.

## 필요한 패키지

정확한 의존성은 루트 `pyproject.toml`과 `uv.lock`이 기준입니다. FastAPI·SQLAlchemy·TiDB Vector·Alembic·Firebase Admin·LangChain/OpenAI·Chroma·MCP SDK를 사용합니다.

현재 코드의 Alembic head는 `20261014_0011`(서비스 테이블 22개)입니다. 새 환경은 전체 이력을 적용합니다. `docs/db/01_schema_mvp.sql`은 이전 스냅샷입니다.

## 실행 예시

의존성 설치는 저장소 루트에서 `uv sync`로 한 번 합니다. 그 다음 명령은 모두 `backend/` 폴더에서 실행합니다. 그래야 `app`과 `scripts`가 패키지로 import됩니다. `uv run`은 상위 폴더의 `pyproject.toml`을 찾아 루트의 `.venv`를 씁니다.

```bash
uv run uvicorn app.main:app --reload       # 서버
uv run alembic upgrade head                # 마이그레이션 적용
uv run python -m scripts.load_catalog      # 스크립트는 -m 으로 실행
uv run pytest                              # 테스트
```
