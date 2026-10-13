"""FastAPI application entry point.

Run from ``backend/``::

    uv run uvicorn app.main:app --reload
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import collection_mcp
from app.api.router import api_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers

settings = get_settings()


@asynccontextmanager
async def lifespan(app):
    server = collection_mcp.new_transport()
    async with server.session_manager.run():
        yield


app = FastAPI(title="ArtLog API", lifespan=lifespan)
register_exception_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "MCP-Protocol-Version",
        "Mcp-Session-Id",
    ],
    expose_headers=["Mcp-Session-Id"],
)

app.include_router(api_router, prefix="/api")

app.mount("/mcp", collection_mcp.mcp_app)
