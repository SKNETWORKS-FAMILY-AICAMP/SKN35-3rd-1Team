# repositories

TiDB를 읽고 쓰는 코드를 모읍니다. SQL과 벡터 거리 계산은 이 폴더에만 있습니다.

## 들어갈 파일

| 파일 | 담당 테이블 | 주요 함수 예시 |
| --- | --- | --- |
| `user_repository.py` | `users` | 이메일로 조회, 생성 |
| `catalog_repository.py` | `art_movements`, `artists`, `artworks` | 작가별·사조별 목록, 상세, 큐레이션 작품 |
| `document_repository.py` | `documents`, `document_artists`, `document_chunks` | 작품의 검색 범위 문서 찾기, 범위 안에서 질문 벡터와 가까운 청크 찾기 |
| `activity_repository.py` | `artwork_likes`, `artist_follows`, `artwork_views` | 좋아요 추가·삭제, 최근 좋아요, 열람 upsert, 월별 열람 집계 |
| `recommendation_repository.py` | `artwork_embeddings` | 한 작품과 가까운 작품, 여러 시드와 가까운 후보, 후보를 작가별로 묶기 |

쿼리 예시는 `docs/db/02_queries.sql`에 기능별로 있습니다.

## 규칙

- **벡터 SQL은 여기에만**: `VECTOR` 타입과 `VEC_COSINE_DISTANCE`는 TiDB 전용이라 다른 DB에서 돌지 않습니다. 한 곳에 모아 두면 서비스 테스트는 가짜 repository로 돌릴 수 있습니다.
- **벡터 컬럼을 조회하지 않기**: 결과에 `embedding`을 포함하지 않습니다. 필요한 것은 id와 거리 값입니다.
- **거리는 오름차순**: `VEC_COSINE_DISTANCE`는 작을수록 비슷합니다.
- **판단은 서비스에서**: repository는 "가까운 후보 30개"까지만 돌려줍니다. 작가당 1개 제한이나 신규 사용자 분기는 서비스가 합니다.
- **중복 요청 처리**: 좋아요와 팔로우는 `INSERT IGNORE`, 열람은 `ON DUPLICATE KEY UPDATE`로 처리해 같은 요청이 두 번 와도 오류가 나지 않게 합니다.
- 함수는 세션을 인자로 받습니다. repository 안에서 세션을 새로 만들지 않습니다.
