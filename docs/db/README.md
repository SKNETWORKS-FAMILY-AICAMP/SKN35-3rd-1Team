# docs/db

TiDB 스키마 설계와 실행용 SQL입니다.

2026-10-14 마이페이지 확장: Alembic head `20261014_0008`에서 사용자 설정을 확장하고 `collections`·`collection_items`를 추가했습니다. 0007의 `diary_entries`를 포함해 서비스 모델은 20테이블입니다. `00_erd.mmd`에는 새 관계를 반영했습니다. PNG/SVG도 20테이블로 다시 생성했습니다. `01_schema_mvp.sql`은 0006의 17테이블 스냅샷이므로 신규 환경은 Alembic 전체 마이그레이션을 사용합니다. 운영 적용은 별도로 필요하며 이번 코드 작업에서 실행하지 않았습니다.

| 파일 | 내용 |
| --- | --- |
| `db-design.md` | 설계 문서 전체 (권장 구조, 테이블 명세, 인덱스, 추천 흐름, 주의사항, 출처) |
| `00_erd.mmd` | SQLAlchemy 모델에서 생성한 Mermaid ERD 원본 (서비스 테이블 20개) |
| `00_erd.png` | 빠르게 확인하는 ERD 이미지 |
| `00_erd.svg` | 확대해도 선명한 ERD 이미지 |
| `01_schema_mvp.sql` | 서비스 테이블 17개의 TiDB/MySQL 호환 기준 SQL |
| `02_queries.sql` | 기능별 쿼리 예시 (좋아요, 열람, 캘린더, RAG 검색, 추천) |
| `03_schema_later.sql` | 나중에 추가할 테이블 (유사도 사전 계산 등) |
| `04_vector_index_tidb.sql` | 작품 수가 크게 늘었을 때 붙일 벡터 인덱스 |

## 사용 방법

- 테이블은 `01_schema_mvp.sql`을 실행해서 만들거나 Alembic 마이그레이션으로 만듭니다. 둘 중 하나만 씁니다.
- `VECTOR(1536)`의 1536은 임베딩 모델의 차원 수입니다. 모델을 정한 뒤 루트 `.env`의 `EMBEDDING_DIM`과 같은 값으로 맞춥니다.
- `02_queries.sql`은 `backend/app/repositories/`를 작성할 때 참고합니다.
- ERD를 다시 만들 때는 `backend/`에서 `uv run python -m scripts.render_erd`를 실행합니다.

## 확인이 필요한 점

2026-10-13 기준 운영 TiDB Serverless v8.5.3의 `3rd_project`에 Alembic `20261013_0006`까지 적용했습니다. 서비스 테이블 17개와 Alembic 관리 테이블 1개가 있으며, 당시 모델 기준 누락 테이블은 없었습니다. 0007·0008의 운영 적용 여부는 별도 확인해야 합니다. `social_accounts`와 `user_preferences`의 외래 키도 실제 TiDB에서 확인했습니다.
