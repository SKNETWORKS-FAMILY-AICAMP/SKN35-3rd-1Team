# infra

로컬 실행과 배포에 필요한 설정 파일을 둡니다.

## 들어갈 파일

- `docker-compose.yml`: 백엔드와 프론트엔드를 함께 띄우는 구성
- `backend.Dockerfile`, `frontend.Dockerfile`
- 배포 환경별 설정 예시 (비밀값 제외)

## 배포 구성

| 대상 | 위치 | 설정 |
| --- | --- | --- |
| 백엔드 API | Railway | 루트 `railway.toml` → `infra/backend.Dockerfile`. 빌드 컨텍스트는 저장소 루트 |
| 프론트엔드 | Vercel | `frontend/vercel.json` (Root Directory `frontend`) |

Railway 서비스의 Root Directory는 비워 둡니다(저장소 루트). `pyproject.toml`과 `uv.lock`이 루트에 있기 때문입니다. `backend/`·의존성 파일이 바뀐 push만 다시 배포합니다.

Railway 환경변수:

| 이름 | 값 |
| --- | --- |
| `TIDB_HOST`, `TIDB_PORT`, `TIDB_USERNAME`, `TIDB_PASSWORD`, `TIDB_DATABASE` | TiDB Cloud 접속 정보 |
| `CORS_ORIGINS` | `https://artlog-skn35-1team.vercel.app` (여러 개면 쉼표로 구분) |
| `AUTH_MODE` | 개발은 `dev`, Firebase 검증 코드 배포와 서버 인증 정보 설정 후 `firebase` |
| `FIREBASE_PROJECT_ID` | `skn35-3rd-1team` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | 서비스 계정 JSON 전체를 Railway 비밀 환경변수로 주입. 대안은 `GOOGLE_APPLICATION_CREDENTIALS`로 서버에 마운트한 JSON 파일 지정 |

Firebase 모드에서는 Admin SDK가 서명·만료·프로젝트를 검증한 ID 토큰의 UID만 TiDB 사용자로 매핑합니다. 검증 실패는 401이며 개발 사용자로 대체하지 않습니다. 관리자 JSON은 서버에서만 사용하고 Vercel 또는 Git에 넣지 않습니다. `AUTH_MODE` 전환은 이 코드가 dev에 병합되어 Railway에 배포된 뒤 진행합니다.

마이그레이션은 컨테이너 시작 시 자동 실행하지 않습니다. 기존 데이터가 있으면 실패하는 마이그레이션(`0005`)이 있어서, 로컬에서 확인한 뒤 `uv run alembic upgrade head`로 직접 적용합니다.

로컬 빌드 확인:

```bash
docker build -f infra/backend.Dockerfile -t artlog-api .
docker run --rm -p 8000:8000 --env-file .env artlog-api
```

## TiDB 는 어디서 실행하는가

TiDB는 TiDB Cloud의 클러스터를 사용하므로 `docker-compose.yml`에 넣지 않습니다. 백엔드 컨테이너가 환경변수의 접속 정보로 클라우드에 연결합니다.

팀원마다 같은 클러스터를 쓰면 서로의 데이터가 섞입니다. 개발용과 발표용 데이터베이스 이름을 나누고, 테스트는 별도 데이터베이스에서 돌립니다.

## 확인할 설정

| 항목 | 내용 |
| --- | --- |
| CORS | 백엔드가 프론트 주소(`CORS_ORIGINS`)를 허용해야 브라우저 요청이 통과합니다. |
| API 주소 | Flutter의 `API_BASE_URL`은 빌드할 때 고정됩니다. 실제 서버 모드는 `ARTLOG_DEMO=false`를 함께 설정합니다. 배포 주소가 바뀌면 다시 빌드합니다. |
| 연결 수명 | TiDB Cloud Starter는 오래 열린 연결을 끊을 수 있습니다. 엔진의 `pool_recycle` 설정을 유지합니다. |
| 시간대 | 컨테이너 시간대와 무관하게 열람 날짜는 `APP_TIMEZONE` 기준으로 계산합니다. |

## 규칙

- 비밀번호, TiDB 접속 문자열, API 키, 인증서 원본을 이 폴더나 Git에 커밋하지 않습니다.
- 이미지에 `.env`를 복사해 넣지 않습니다. 실행할 때 환경변수로 주입합니다.
- 발표 전에 발표용 데이터베이스에서 추천과 챗봇을 한 번씩 실행해 정상 동작을 확인합니다.
