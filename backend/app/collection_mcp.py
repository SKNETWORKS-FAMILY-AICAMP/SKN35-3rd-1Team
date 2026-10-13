"""Official MCP Streamable HTTP transport, authenticated with Firebase ID tokens.

The app chat proposes an action and confirms it through REST. External MCP
clients invoke the same owner-scoped services; they never supply a user id.
"""

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from mcp.server.fastmcp import Context, FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from mcp.types import ToolAnnotations
from starlette.concurrency import run_in_threadpool
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.core.auth import _resolve_user
from app.core.config import get_settings
from app.db.session import SessionLocal
from app.schemas.mypage import CollectionWrite
from app.services import mypage_service as service

settings = get_settings()
mcp = FastMCP(
    "Artlog collections",
    stateless_http=True,
    json_response=True,
    streamable_http_path="/",
    transport_security=TransportSecuritySettings(
        allowed_hosts=[
            h.strip() for h in settings.mcp_allowed_hosts.split(",") if h.strip()
        ],
        allowed_origins=settings.cors_origin_list
        + ["http://localhost:*", "http://127.0.0.1:*"],
    ),
)


def authenticate(request: Request) -> int:
    header = request.headers.get("Authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(401, "로그인이 필요합니다.")
    with SessionLocal() as db:
        return _resolve_user(
            db, HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        ).id


class AuthenticatedMCP:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        try:
            actor = await run_in_threadpool(authenticate, Request(scope))
        except HTTPException as error:
            response = JSONResponse(
                {"detail": error.detail},
                status_code=error.status_code,
                headers={
                    "WWW-Authenticate": "Bearer",
                    "Cache-Control": "private, no-store",
                },
            )
            return await response(scope, receive, send)
        scope.setdefault("state", {})["artlog_user_id"] = actor

        async def private_send(message):
            if message["type"] == "http.response.start":
                message.setdefault("headers", []).append(
                    (b"cache-control", b"private, no-store")
                )
            await send(message)

        await self.app(scope, receive, private_send)


def actor(ctx: Context) -> int:
    request = ctx.request_context.request
    if request is None or not getattr(request.state, "artlog_user_id", None):
        raise ValueError("로그인이 필요합니다.")
    return request.state.artlog_user_id


@mcp.tool(annotations=ToolAnnotations(readOnlyHint=True))
def list_collections(ctx: Context) -> list[dict]:
    """List the authenticated user's private collections, counts and 3 previews."""
    with SessionLocal() as db:
        return [c.model_dump(mode="json") for c in service.collections(db, actor(ctx))]


@mcp.tool(annotations=ToolAnnotations(readOnlyHint=True))
def search_artworks(query: str, ctx: Context) -> list[dict]:
    """Search public catalog titles and artists (up to 8 results)."""
    actor(ctx)
    if not 1 <= len(query.strip()) <= 80:
        raise ValueError("검색어는 1~80자입니다.")
    with SessionLocal() as db:
        return [c.model_dump(mode="json") for c in service.search_artworks(db, query)]


@mcp.tool(annotations=ToolAnnotations(destructiveHint=False))
def create_collection(name: str, ctx: Context) -> dict:
    """Create a private collection only when the user explicitly requests it."""
    with SessionLocal() as db:
        return service.save_collection(
            db, actor(ctx), CollectionWrite(name=name)
        ).model_dump(mode="json")


@mcp.tool(annotations=ToolAnnotations(destructiveHint=False, idempotentHint=True))
def add_artwork_to_collection(
    collection_id: int, artwork_id: int, ctx: Context
) -> dict:
    """Add an explicitly chosen catalog artwork to the caller's collection. Duplicate adds are harmless."""
    with SessionLocal() as db:
        return service.add_artwork(
            db, actor(ctx), collection_id, artwork_id
        ).model_dump(mode="json")


mcp_app = AuthenticatedMCP(mcp.streamable_http_app())


def new_transport():
    """Each application lifespan owns a fresh SDK session manager."""
    server = FastMCP(
        "Artlog collections",
        stateless_http=True,
        json_response=True,
        streamable_http_path="/",
        transport_security=mcp.settings.transport_security,
    )
    server.add_tool(list_collections, annotations=ToolAnnotations(readOnlyHint=True))
    server.add_tool(search_artworks, annotations=ToolAnnotations(readOnlyHint=True))
    server.add_tool(
        create_collection, annotations=ToolAnnotations(destructiveHint=False)
    )
    server.add_tool(
        add_artwork_to_collection,
        annotations=ToolAnnotations(destructiveHint=False, idempotentHint=True),
    )
    mcp_app.app = server.streamable_http_app()
    return server
