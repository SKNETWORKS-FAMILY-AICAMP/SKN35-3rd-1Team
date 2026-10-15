# db

TiDB 연결과 세션을 관리합니다. 마이그레이션 파일은 여기가 아니라 `backend/alembic/`에 둡니다.

## 들어갈 파일

- `session.py`: 엔진 생성, 세션 팩토리, 요청마다 세션을 열고 닫는 `get_db`

## 연결 설정

TiDB는 MySQL 호환이며 이 프로젝트는 루트 `.env`의 아래 값을 읽습니다.

```dotenv
TIDB_HOST=gateway01.<region>.prod.aws.tidbcloud.com
TIDB_PORT=4000
TIDB_USERNAME=<cluster-prefix>.root
TIDB_PASSWORD=비밀번호
TIDB_DATABASE=3rd_project
```

기존 `.env`의 `HOST`, `PORT`, `USERNAME`, `PASSWORD`, `DATABASE` 이름도
호환됩니다. 완성된 `TIDB_DATABASE_URL` 하나로 지정해도 됩니다. URL을 직접
조합하지 않고 SQLAlchemy `URL.create()`를 사용하므로 비밀번호의 특수문자도
안전하게 처리합니다. TiDB Cloud 연결에는 TLS 인증서와 호스트 검증을 적용합니다.

엔진에는 아래 두 옵션을 둡니다.

| 옵션 | 이유 |
| --- | --- |
| `pool_recycle=300` | TiDB Cloud Starter는 오래 열린 연결을 끊을 수 있습니다. 5분마다 새로 맺습니다. |
| `pool_pre_ping=True` | 끊긴 연결을 쓰기 전에 감지해 다시 연결합니다. |

연결과 11개 테이블 생성 여부는 다음 명령으로 확인합니다.

```bash
uv run python -m scripts.check_db
```

## 규칙

- 쿼리는 여기 쓰지 않습니다. 쿼리는 `repositories/`의 몫입니다.
- 트랜잭션은 요청 단위로 묶습니다. 커밋과 롤백을 어디서 할지(세션 의존성 또는 서비스) 한 가지로 정해 섞지 않습니다.
- 접속 정보는 `core/config.py`를 통해서만 읽습니다.
