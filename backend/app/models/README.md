# models

TiDB 테이블에 대응하는 SQLAlchemy 모델입니다. 최신 스키마 기준은 모델과 `backend/alembic/versions/`이며 현재 코드 head는 `20261014_0011`입니다. 서비스 테이블은 22개입니다. `docs/db/01_schema_mvp.sql`은 0006 시점 참고 스냅샷입니다.

| 파일 | 모델·테이블 |
| --- | --- |
| `base.py` | `Base`, 테이블 옵션, `EMBEDDING_DIMENSION=1536` |
| `user.py` | `User` → `users` (공개용 `public_id`, 팔로우 목록 공개 설정 포함) |
| `user_profile.py` | `SocialAccount`, `UserPreference` → `social_accounts`, `user_preferences` |
| `catalog.py` | `ArtMovement`, `Artist`, `Artwork` |
| `document.py` | `Document`, `DocumentArtist`, `DocumentArtwork`, `DocumentBasis`, `DocumentChunk` |
| `activity.py` | `ArtworkLike`, `ArtistFollow`, `ArtworkView`, `UserFollow` |
| `embedding.py` | `ArtworkEmbedding` |
| `chat.py` | `ChatSession`, `ChatMessage` |
| `diary.py` | `DiaryEntry` |
| `collection.py` | `Collection`, `CollectionItem` |
| `theme_collection.py` | `ThemeCollectionCache` → `theme_collection_cache` |
| `__init__.py` | 모든 모델을 import해 Alembic에 metadata 공개 |

PK·FK는 `BigInteger`로 통일합니다. 문서 종류는 `artist_bio`·`artwork_commentary`·`artist_comparison`입니다. 벡터는 `VectorType(EMBEDDING_DIMENSION)`과 `deferred=True`로 정의합니다.

좋아요·작가 팔로우·회원 팔로우는 복합 PK로 중복을 막습니다. 열람은 사용자×날짜×작품, 채팅방은 사용자×작품, 감상평은 사용자×작품(작품 없는 메모는 여러 편 허용)의 제약을 사용합니다. 테마 캐시는 사용자당 한 행이며 저장 컬렉션과 분리됩니다.

삭제 동작은 각 FK의 `ondelete`를 따릅니다. API 응답은 모델을 직접 내보내지 않고 `schemas/`로 변환합니다.
