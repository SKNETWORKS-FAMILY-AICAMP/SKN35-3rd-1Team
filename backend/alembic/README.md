# alembic

TiDB 스키마 변경 이력을 관리합니다. 명령은 `backend/`에서 실행합니다.

```bash
uv run alembic upgrade head
uv run alembic current
uv run alembic check
```

최초 migration인 `versions/20261011_0001_create_mvp_schema.py`가 ERD의 11개
테이블, 외래 키, 일반 인덱스와 `VECTOR(1536)` 컬럼을 생성합니다. 선택 사항인
HNSW 인덱스는 데이터 규모가 커졌을 때 `docs/db/04_vector_index_tidb.sql`로
별도 적용합니다.

새 모델 변경은 아래처럼 migration 후보를 만든 뒤 생성 내용을 검토해서
커밋합니다.

```bash
uv run alembic revision --autogenerate -m "describe change"
uv run alembic upgrade head
```

DB 스키마 변경 이력을 관리합니다.

## 처음 한 번 초기화하기

`alembic init`은 대상 폴더가 비어 있어야 실행됩니다. 이 README가 들어 있는 상태로 실행하면 "Directory alembic already exists and is not empty" 오류가 납니다. 그래서 README를 잠시 밖으로 옮겼다가 되돌립니다. `backend/`에서 실행합니다.

```bash
mv alembic/README.md alembic-notes.md     # 폴더 비우기
alembic init alembic                      # alembic/ 내용과 alembic.ini 생성
mv alembic-notes.md alembic/README.md     # 이 문서 되돌리기
```

## 들어갈 파일

- `env.py`: `app.models`의 `Base.metadata`를 `target_metadata`로 연결합니다. DB 주소는 `app.core.config`에서 읽습니다.
- `script.py.mako`: 마이그레이션 파일 틀
- `versions/`: 마이그레이션 파일

## 자주 쓰는 명령

```bash
alembic revision --autogenerate -m "create catalog tables"
alembic upgrade head
alembic downgrade -1
```

## 이 프로젝트에서 주의할 점

- **벡터 타입 import**: 자동 생성된 파일에 벡터 컬럼이 `tidb_vector.sqlalchemy.vector_type.VectorType(dim=1536)`으로 적힙니다. `script.py.mako`에 `import tidb_vector.sqlalchemy.vector_type`을 넣어 두지 않으면 실행할 때 NameError가 납니다.
- **벡터 인덱스**: SQLAlchemy의 `Index`로 표현할 수 없는 TiDB 전용 문법입니다. 필요해지면 `op.execute("CREATE VECTOR INDEX ...")`로 직접 작성합니다. 문법은 `docs/db/04_vector_index_tidb.sql`에 있습니다.
- **SQL 파일과 병행 금지**: `docs/db/01_schema_mvp.sql`로 테이블을 만들었다면 Alembic은 그 상태를 모릅니다. 테이블 생성은 둘 중 한 가지 방법으로만 합니다.
- **자동 생성 결과 확인**: autogenerate는 초안입니다. 적용 전에 반드시 열어서 의도하지 않은 DROP이 없는지 확인합니다.
