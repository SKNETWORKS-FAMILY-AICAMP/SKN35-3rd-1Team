# db

TiDB 연결과 세션을 관리합니다. 마이그레이션 파일은 여기가 아니라 `backend/alembic/`에 둡니다.

## 들어갈 파일

- `session.py`: 엔진 생성, 세션 팩토리, 요청마다 세션을 열고 닫는 `get_db`

## 연결 설정

TiDB는 MySQL 호환이라 `mysql+pymysql://사용자:비밀번호@호스트:4000/docent` 형태의 주소를 씁니다. TiDB Cloud는 TLS가 필요하므로 CA 인증서 관련 옵션을 함께 넘깁니다. 정확한 주소는 TiDB Cloud 콘솔의 Connect 화면에서 복사합니다.

엔진에는 아래 두 옵션을 둡니다.

| 옵션 | 이유 |
| --- | --- |
| `pool_recycle=300` | TiDB Cloud Starter는 오래 열린 연결을 끊을 수 있습니다. 5분마다 새로 맺습니다. |
| `pool_pre_ping=True` | 끊긴 연결을 쓰기 전에 감지해 다시 연결합니다. |

## 규칙

- 쿼리는 여기 쓰지 않습니다. 쿼리는 `repositories/`의 몫입니다.
- 트랜잭션은 요청 단위로 묶습니다. 커밋과 롤백을 어디서 할지(세션 의존성 또는 서비스) 한 가지로 정해 섞지 않습니다.
- 접속 정보는 `core/config.py`를 통해서만 읽습니다.
