"""추천. `similar`는 공개, `/me/...`는 로그인 필요."""

from fastapi import APIRouter

from app.core.auth import CurrentUser
from app.db.session import DbSession
from app.schemas.catalog import ArtworkCard
from app.schemas.recommendation import RecommendedArtist, RecommendedArtwork
from app.services import recommendation_service

router = APIRouter(tags=["recommendations"])


@router.get("/artworks/{artwork_id}/similar")
def similar_artworks(artwork_id: int, db: DbSession) -> list[ArtworkCard]:
    """이 작품과 비슷한 작품 3개 (가까운 순). 작품 벡터가 없으면 빈 배열."""
    return recommendation_service.similar(db, artwork_id=artwork_id)


@router.get("/me/recommendations/artworks")
def recommend_artworks(user: CurrentUser, db: DbSession) -> list[RecommendedArtwork]:
    """좋아요 기반 맞춤 작품 3개 (작가당 1개). 좋아요가 없으면 대체 추천."""
    return recommendation_service.recommend_artworks(db, user_id=user.id)


@router.get("/me/recommendations/artists")
def recommend_artists(user: CurrentUser, db: DbSession) -> list[RecommendedArtist]:
    """추천 작가 3명. 팔로우한 작가는 제외."""
    return recommendation_service.recommend_artists(db, user_id=user.id)
