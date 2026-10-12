from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    """Liveness check for Railway; does not touch the database."""

    return {"status": "ok"}
