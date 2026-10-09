# models

TiDB 테이블과 1:1로 대응하는 SQLAlchemy 모델을 둡니다. 테이블 정의의 기준은 `docs/db/01_schema_mvp.sql`입니다.

## 들어갈 파일

| 파일 | 모델 | 테이블 |
| --- | --- | --- |
| `base.py` | `Base` | (제약 이름 규칙을 가진 공통 부모) |
| `user.py` | `User` | `users` |
| `catalog.py` | `ArtMovement`, `Artist`, `Artwork` | `art_movements`, `artists`, `artworks` |
| `document.py` | `Document`, `DocumentArtist`, `DocumentChunk` | `documents`, `document_artists`, `document_chunks` |
| `activity.py` | `ArtworkLike`, `ArtistFollow`, `ArtworkView` | `artwork_likes`, `artist_follows`, `artwork_views` |
| `embedding.py` | `ArtworkEmbedding` | `artwork_embeddings` |
| `__init__.py` | 위 모델을 모두 import | Alembic이 전체 테이블을 인식하게 함 |

## 규칙

- **id 타입**: PK와 FK는 전부 `BigInteger`입니다. TiDB는 FK 양쪽 타입이 다르면 FK 생성을 거부합니다.
- **연결 테이블**: 좋아요, 팔로우, 열람은 `secondary=`가 아니라 클래스로 선언합니다. `created_at`, `view_count` 같은 컬럼을 다뤄야 하기 때문입니다.
- **중복 방지**: 좋아요는 `(user_id, artwork_id)`, 팔로우는 `(user_id, artist_id)`, 열람은 `(user_id, viewed_on, artwork_id)`를 복합 PK로 둡니다.
- **벡터 컬럼**: `VectorType(차원)`에 `deferred=True`를 붙입니다. 객체를 조회할 때 벡터가 자동으로 딸려 오지 않습니다.
- **문서 종류**: `doc_type`은 `artist_bio`, `artwork_commentary`, `artist_comparison` 세 가지입니다. DB에는 문자열로 저장하고 Python Enum으로 검증합니다.
- **삭제 연쇄**: `relationship(..., passive_deletes=True)`로 DB의 `ON DELETE CASCADE`에 맡깁니다.
- **제약 이름**: `Base`의 `MetaData(naming_convention=...)`로 고정합니다. Alembic이 만드는 이름이 매번 같아집니다.
- 모델을 API 응답으로 그대로 내보내지 않습니다. 응답은 `schemas/`를 거칩니다.
