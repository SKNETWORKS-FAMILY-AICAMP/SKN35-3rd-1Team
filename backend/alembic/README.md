# alembic

TiDB 스키마 변경 이력입니다. 저장소에 이미 초기화되어 있으므로 `alembic init`을 다시 실행할 필요가 없습니다. 명령은 `backend/`에서 실행합니다.

```bash
uv run alembic heads          # 코드의 최신 revision (DB 연결 불필요)
uv run alembic current        # 연결한 DB의 적용 revision
uv run alembic upgrade head   # 전체 이력 적용
uv run alembic check          # 연결한 DB와 모델 차이 확인
```

현재 코드 head는 `20261014_0011`이며 서비스 테이블 22개를 정의합니다. 실제 DB 적용 상태는 `current`로 별도 확인합니다.

| revision | 변경 |
| --- | --- |
| `20261011_0001` | 초기 11개 테이블과 VECTOR(1536) |
| `20261011_0002` | 문서 검색 메타데이터 |
| `20261012_0003` | 편집 근거와 문서 연결 |
| `20261012_0004` | 채팅방·메시지 |
| `20261012_0005` | Firebase 사용자 인증 |
| `20261013_0006` | 외부 계정·개인화 설정 |
| `20261013_0007` | 감상평·공개 피드 |
| `20261014_0008` | 마이페이지 설정 확장·비공개 컬렉션 |
| `20261014_0009` | 공개 회원 ID·회원 팔로우·목록 공개 설정 |
| `20261014_0010` | 감상평 UNIQUE를 사용자×날짜에서 사용자×작품으로 변경 |
| `20261014_0011` | 사용자별 AI 감성 테마 캐시 |

`env.py`는 `app.models`의 metadata와 `core/config.py`의 DB 설정을 사용합니다. 새 변경은 `uv run alembic revision --autogenerate -m "describe change"`로 초안을 만들고 검토합니다. 특히 DROP·제약 변경·데이터 백필은 직접 확인합니다.

`docs/db/01_schema_mvp.sql`은 0006 스냅샷이므로 새 환경은 Alembic으로 구성합니다. TiDB 전용 벡터 인덱스는 필요할 때 `docs/db/04_vector_index_tidb.sql`을 참고합니다. 자동 생성된 벡터 타입 import도 확인합니다.
