"""사조 목록."""

from fastapi import APIRouter

from app.api.stub import not_implemented
from app.schemas.catalog import Movement

router = APIRouter(tags=["catalog"])


@router.get("/movements")
def list_movements() -> list[Movement]:
    """사조 목록."""
    not_implemented()
