"""사조 목록."""

from fastapi import APIRouter

from app.db.session import DbSession
from app.schemas.catalog import Movement
from app.services import catalog_service

router = APIRouter(tags=["catalog"])


@router.get("/movements")
def list_movements(db: DbSession) -> list[Movement]:
    """사조 목록."""
    return catalog_service.list_movements(db)
