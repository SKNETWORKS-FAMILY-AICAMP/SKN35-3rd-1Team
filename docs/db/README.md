# docs/db

TiDB 스키마 설계와 실행용 SQL입니다.

현재 코드 head는 `20261014_0011`이고 서비스 테이블 22개를 정의합니다(`alembic_version` 포함 23개). 아래 운영 적용 기록은 당시 확인 결과이며 현재 DB 적용 상태는 `alembic current`로 별도 확인합니다.

| 구분 | 테이블 |
| --- | --- |
| 계정·설정 | `users`, `social_accounts`, `user_preferences` |
| 카탈로그 | `art_movements`, `artists`, `artworks`, `artwork_embeddings` |
| 사용자 활동 | `artwork_likes`, `artist_follows`, `artwork_views`, `chat_sessions`, `chat_messages`, `diary_entries`, `collections`, `collection_items`, `user_follows`, `theme_collection_cache` |
| 문서·RAG | `documents`, `document_artists`, `document_artworks`, `document_basis_documents`, `document_chunks` |

주요 변경:

- `diary_entries`(0007, 0010): 사용자 × 작품당 감상글 1개이고 하루 개수 제한은 없습니다(0010 이전에는 날짜당 1개). 기본은 비공개이고, 공개로 바꾼 글만 `GET /api/diary/feed`에 최신순으로 나옵니다. 다이어리와 공개 피드를 테이블 하나로 처리합니다.
- `user_preferences` 확장(0008): 생년월일, 대화 스타일(easy/professional), 온보딩 완료 여부, AI 취향 소개 캐시가 추가됐습니다. 설명 우선순위 컬럼은 호환 목적으로 남지만 현재 API는 읽거나 갱신하지 않습니다.
- `collections`·`collection_items`(0008): 비공개 '나만의 컬렉션'과 담긴 작품입니다. 앱 화면, 컬렉션 채팅, MCP 도구가 같은 저장 서비스를 씁니다.

- 회원 소셜(0009): `users.public_id`·`follow_list_public`, `user_follows`를 추가합니다.
- AI 테마 캐시(0011): `theme_collection_cache`에 사용자별 테마 스냅샷과 생성 간격을 저장합니다.

0007·0008 적용 당시에는 테이블과 컬럼을 추가했습니다. 당시 적용 전 스키마와 사용자 테이블을 백업했고 적용 후 `alembic check`에서 차이가 없었습니다. 이후 0009의 공개 ID 백필, 0010의 감상평 제약 변경, 0011의 테마 캐시를 포함한 최신 구조는 [`db-design.md`](db-design.md)를 참고합니다.

| 파일 | 내용 |
| --- | --- |
| `db-design.md` | 설계 문서 전체 (권장 구조, 테이블 명세, 인덱스, 추천 흐름, 주의사항, 출처) |
| `00_erd.mmd` | SQLAlchemy 모델에서 생성한 Mermaid ERD 원본 (서비스 테이블 22개) |
| `00_erd.png` | 빠르게 확인하는 ERD 이미지 |
| `00_erd.svg` | 확대해도 선명한 ERD 이미지 |
| `01_schema_mvp.sql` | 0006 시점 서비스 테이블 17개의 스냅샷 SQL (0007~0011 미포함) |
| `02_queries.sql` | 기능별 쿼리 예시 (좋아요, 열람, 캘린더, RAG 검색, 추천) |
| `03_schema_later.sql` | 나중에 추가할 테이블 (유사도 사전 계산 등) |
| `04_vector_index_tidb.sql` | 작품 수가 크게 늘었을 때 붙일 벡터 인덱스 |

## 사용 방법

- 새 환경의 테이블은 Alembic으로 만듭니다(`backend/`에서 `uv run alembic upgrade head`). `01_schema_mvp.sql`은 0006 스냅샷이라 최신 테이블 5개와 이후 컬럼·제약 변경이 빠져 있습니다.
- `VECTOR(1536)`의 1536은 임베딩 모델의 차원 수입니다. `backend/app/models/base.py`의 `EMBEDDING_DIMENSION`이 기준이며 `.env`의 `EMBEDDING_DIM` 설정은 사용하지 않습니다.
- `02_queries.sql`은 `backend/app/repositories/`를 작성할 때 참고합니다.
- ERD를 다시 만들 때는 `backend/`에서 `uv run python -m scripts.render_erd`를 실행합니다. Graphviz(`dot`)가 필요하고, 모델이 같으면 항상 같은 파일이 나옵니다.

## 운영 DB 적용 기록

| 날짜 | revision | 내용 |
| --- | --- | --- |
| 2026-10-13 | `20261013_0006` | 서비스 테이블 17개. `social_accounts`, `user_preferences` 외래 키 확인 |
| 2026-10-14 | `20261014_0008` | 0007 `diary_entries`, 0008 `user_preferences` 확장·`collections`·`collection_items`. 서비스 테이블 20개, `alembic check` 차이 없음 |
