"""추천. `similar`는 공개, `/me/...`는 로그인 필요."""

from fastapi import APIRouter

from app.api.stub import not_implemented
from app.core.auth import CurrentUser
from app.schemas.catalog import ArtworkCard
from app.schemas.recommendation import RecommendedArtist, RecommendedArtwork

router = APIRouter(tags=["recommendations"])


@router.get("/artworks/{artwork_id}/similar")
def similar_artworks(artwork_id: int) -> list[ArtworkCard]:
    """이 작품과 비슷한 작품 3개 (가까운 순)."""
    not_implemented()


@router.get("/me/recommendations/artworks")
def recommend_artworks(user: CurrentUser) -> list[RecommendedArtwork]:
    """좋아요 기반 맞춤 작품 3개. 좋아요가 없으면 대체 추천."""
    not_implemented()


@router.get("/me/recommendations/artists")
def recommend_artists(user: CurrentUser) -> list[RecommendedArtist]:
    """추천 작가 3명. 팔로우한 작가는 제외."""
    not_implemented()
