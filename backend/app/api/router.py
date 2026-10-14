"""Collect every route module under the ``/api`` prefix."""

from fastapi import APIRouter

from app.api.routes import (
    artists,
    artworks,
    chat,
    diary,
    follows,
    health,
    library,
    likes,
    movements,
    mypage,
    recommendations,
)

api_router = APIRouter()
for module in (
    health,
    movements,
    artists,
    artworks,
    chat,
    diary,
    likes,
    follows,
    library,
    recommendations,
    mypage,
):
    api_router.include_router(module.router)
