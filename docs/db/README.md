# docs/db

TiDB 스키마 설계와 실행용 SQL입니다.

| 파일 | 내용 |
| --- | --- |
| `db-design.md` | 설계 문서 전체 (권장 구조, 테이블 명세, 인덱스, 추천 흐름, 주의사항, 출처) |
| `00_erd.mmd` | Mermaid ERD 원본 |
| `01_schema_mvp.sql` | 먼저 만들 테이블 12개 |
| `02_queries.sql` | 기능별 쿼리 예시 (좋아요, 열람, 캘린더, RAG 검색, 추천) |
| `03_schema_later.sql` | 나중에 추가할 테이블 (채팅 저장, 유사도 사전 계산) |
| `04_vector_index_tidb.sql` | 작품 수가 크게 늘었을 때 붙일 벡터 인덱스 |

## 사용 방법

- 테이블은 `01_schema_mvp.sql`을 실행해서 만들거나 Alembic 마이그레이션으로 만듭니다. 둘 중 하나만 씁니다.
- `VECTOR(1536)`의 1536은 임베딩 모델의 차원 수입니다. 모델을 정한 뒤 루트 `.env`의 `EMBEDDING_DIM`과 같은 값으로 맞춥니다.
- `02_queries.sql`은 `backend/app/repositories/`를 작성할 때 참고합니다.

## 확인이 필요한 점

SQL은 TiDB v8.5.8 파서로 문법 검사를 통과했고 관계형 부분은 MariaDB에서 실행해 확인했습니다. 벡터 거리 계산과 외래 키 동작은 실제 TiDB 클러스터에서 아직 실행해 보지 않았습니다. 클러스터를 만든 직후 `db-design.md` 4장의 확인 쿼리를 먼저 돌려 보세요.
