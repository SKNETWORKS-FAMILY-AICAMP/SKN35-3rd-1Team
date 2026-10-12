"""Collect every route module under the ``/api`` prefix."""

from fastapi import APIRouter

from app.api.routes import (
    artists,
    artworks,
    chat,
    follows,
    health,
    library,
    likes,
    movements,
    recommendations,
)

api_router = APIRouter()
for module in (
    health,
    movements,
    artists,
    artworks,
    chat,
    likes,
    follows,
    library,
    recommendations,
):
    api_router.include_router(module.router)
