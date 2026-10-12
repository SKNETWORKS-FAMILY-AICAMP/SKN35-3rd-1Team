"""Service-level errors and their HTTP mapping.

Services raise these instead of ``HTTPException`` so they stay HTTP-agnostic;
``register_exception_handlers`` turns them into ``{"detail": ...}`` responses.
"""

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class NotFoundError(Exception):
    def __init__(self, detail: str) -> None:
        super().__init__(detail)
        self.detail = detail


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(NotFoundError)
    def _not_found(request: Request, exc: NotFoundError) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND, content={"detail": exc.detail}
        )
