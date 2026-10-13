"""Account isolation, real collection SQL and the actual MCP wire protocol."""

from types import SimpleNamespace

import pytest
from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import DefaultClause, MetaData, create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app import collection_mcp
from app.core.auth import get_current_user
from app.db.session import get_db
from app.main import app
from app.models import (
    Artist,
    ArtMovement,
    Artwork,
    ArtworkLike,
    ArtworkView,
    Collection,
    CollectionItem,
    DiaryEntry,
    User,
    UserPreference,
)
from app.services import collection_assistant as ai


@pytest.fixture
def client(monkeypatch):
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    metadata = MetaData()
    for model in (
        User,
        ArtMovement,
        Artist,
        Artwork,
        UserPreference,
        Collection,
        CollectionItem,
        DiaryEntry,
        ArtworkLike,
        ArtworkView,
    ):
        t = model.__table__.to_metadata(metadata)
        for c in t.columns:
            if c.server_default is not None and "ON UPDATE" in str(
                c.server_default.arg
            ):
                c.server_default = DefaultClause(text("CURRENT_TIMESTAMP"))
    metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as db:
        db.add_all(
            [
                User(
                    id=i,
                    firebase_uid=str(i),
                    email=f"private-{i}@example.com",
                    nickname=f"감상가{i}",
                )
                for i in (1, 2)
            ]
        )
        db.add(ArtMovement(id=1, slug="test", name="사조"))
        db.add(Artist(id=1, slug="artist", name="김작가", movement_id=1))
        db.flush()
        db.add_all(
            [
                Artwork(
                    id=i,
                    slug=f"work-{i}",
                    title=f"그림{i}",
                    artist_id=1,
                    is_featured=False,
                )
                for i in range(1, 17)
            ]
        )
        db.commit()

        def actor(request: Request):
            token = request.headers.get("Authorization")
            if token not in ("Bearer a", "Bearer b"):
                raise HTTPException(401, "로그인 필요")
            return db.get(User, 1 if token == "Bearer a" else 2)

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = actor
        monkeypatch.setattr(
            collection_mcp, "authenticate", lambda request: actor(request).id
        )
        monkeypatch.setattr(
            collection_mcp,
            "SessionLocal",
            lambda: Session(engine, expire_on_commit=False),
        )
        collection_mcp.mcp.settings.transport_security.allowed_hosts.append(
            "testserver"
        )
        with TestClient(app) as http:
            http.headers["Authorization"] = "Bearer a"
            yield http
        app.dependency_overrides.clear()
    engine.dispose()


def group(c, name="나의 전시"):
    response = c.post("/api/me/collections", json={"name": name})
    assert response.status_code == 201, response.text
    return response.json()["id"]


def test_profile_roundtrip_order_birthdate_and_account_isolation(client):
    defaults = client.get("/api/me/profile")
    assert defaults.headers["Cache-Control"] == "private, no-store"
    assert defaults.json()["onboarding_completed"] is False
    body = {
        "birth_date": "2001-02-03",
        "explanation_priorities": ["artist_life", "technique", "background"],
        "conversation_style": "professional",
    }
    saved = client.put("/api/me/profile", json=body).json()
    assert saved["onboarding_completed"] is True
    assert all(saved[k] == v for k, v in body.items())
    assert (
        client.get("/api/me/profile", headers={"Authorization": "Bearer b"}).json()[
            "birth_date"
        ]
        is None
    )
    client.put("/api/me/profile", json={})
    assert client.get("/api/me/profile").json()["birth_date"] is None


@pytest.mark.parametrize(
    "body",
    [
        {"birth_date": "2099-01-01"},
        {"birth_date": "2026-02-30"},
        {"birth_date": "1899-01-01"},
        {"explanation_priorities": ["technique"] * 3},
        {"explanation_priorities": ["background", "artist_life"]},
        {"conversation_style": "invented"},
        {"user_id": 2},
    ],
)
def test_settings_validation(client, body):
    assert client.put("/api/me/profile", json=body).status_code == 422


def test_collections_crud_deduplicate_and_page(client):
    cid = group(client)
    assert (
        client.post("/api/me/collections", json={"name": "나의 전시"}).status_code
        == 409
    )
    for art in range(1, 17):
        assert client.put(f"/api/me/collections/{cid}/items/{art}").status_code == 200
    duplicate = client.put(f"/api/me/collections/{cid}/items/1").json()
    assert duplicate["artwork_count"] == 16
    assert len(duplicate["previews"]) == 3
    one = client.get(f"/api/me/collections/{cid}/items?limit=12").json()
    two = client.get(
        f"/api/me/collections/{cid}/items?before_id={one['next_cursor']}"
    ).json()
    assert len(one["items"]) == 12 and len(two["items"]) == 4
    assert len({a["id"] for a in one["items"] + two["items"]}) == 16
    assert client.put(f"/api/me/collections/{cid}/items/999").status_code == 404
    assert (
        client.put(
            f"/api/me/collections/{cid}",
            json={"name": "새 제목", "description": "소개"},
        ).json()["description"]
        == "소개"
    )
    client.delete(f"/api/me/collections/{cid}/items/1")
    assert client.get("/api/me/collections").json()[0]["artwork_count"] == 15
    client.delete(f"/api/me/collections/{cid}")
    assert client.get("/api/me/collections").json() == []


def test_no_other_owner_can_read_or_mutate_collection(client):
    cid = group(client)
    client.headers["Authorization"] = "Bearer b"
    assert client.get("/api/me/collections").json() == []
    for method, path, body in [
        ("GET", f"{cid}/items", None),
        ("PUT", str(cid), {"name": "도용"}),
        ("DELETE", str(cid), None),
        ("PUT", f"{cid}/items/1", None),
        ("DELETE", f"{cid}/items/1", None),
    ]:
        assert (
            client.request(method, f"/api/me/collections/{path}", json=body).status_code
            == 404
        )
    assert (
        client.post(
            "/api/me/collections/chat", json={"message": "담아줘", "collection_id": cid}
        ).status_code
        == 404
    )


def test_own_critiques_activity_and_taste_never_read_other_user(client, monkeypatch):
    client.put(
        "/api/me/diary/2026-10-14", json={"content": "비공개 비평", "artwork_id": 1}
    )
    client.put(
        "/api/me/diary/2026-10-13",
        headers={"Authorization": "Bearer b"},
        json={"content": "다른 이용자의 비평", "artwork_id": 2},
    )
    cid = group(client)
    client.put(f"/api/me/collections/{cid}/items/1")
    observed = {}

    def generate(schema, instruction, data):
        observed.update(data)
        return ai.TasteDraft(summary="그림1에 관심을 두고 계시네요.")

    monkeypatch.setattr(ai, "generate", generate)
    client.put("/api/me/profile", json={"birth_date": "2000-01-01"})
    taste = client.post("/api/me/taste").json()
    assert taste["summary"] and [e["id"] for e in taste["evidence"]] == [1]
    assert observed == {"works": [{"title": "그림1", "artist": "김작가", "year": None}]}
    assert not client.get("/api/me/taste").json()["stale"]
    client.put(f"/api/me/collections/{cid}/items/3")
    assert client.get("/api/me/taste").json()["stale"]
    own = client.get("/api/me/critiques").json()["items"]
    assert len(own) == 1 and own[0]["content"] == "비공개 비평"
    activity = client.get("/api/me/activity").json()
    assert {a["kind"] for a in activity} == {"diary", "collection"}
    assert "다른 이용자의 비평" not in str(activity)
    assert (
        client.get("/api/me/taste", headers={"Authorization": "Bearer b"}).json()[
            "summary"
        ]
        is None
    )


def test_chat_proposes_and_never_writes_until_confirmed(client, monkeypatch):
    cid = group(client)
    monkeypatch.setattr(
        ai,
        "generate",
        lambda *args: ai.Intent(
            action="add", collection_name="나의 전시", artwork_query="그림1"
        ),
    )
    reply = client.post(
        "/api/me/collections/chat", json={"message": "그림1 담아줘"}
    ).json()
    assert reply["proposal"]["collection_id"] == cid
    assert client.get("/api/me/collections").json()[0]["artwork_count"] == 0
    client.put(f"/api/me/collections/{cid}/items/{reply['proposal']['artwork_id']}")
    assert client.get("/api/me/collections").json()[0]["artwork_count"] == 1
    monkeypatch.setattr(
        ai,
        "generate",
        lambda *args: ai.Intent(
            action="add", collection_name="나의 전시", artwork_query="김작가"
        ),
    )
    assert (
        client.post(
            "/api/me/collections/chat", json={"message": "김작가 담아줘"}
        ).json()["proposal"]
        is None
    )


def test_ai_unavailable_has_safe_error_and_empty_taste_needs_art(client, monkeypatch):
    monkeypatch.setattr(
        ai, "get_settings", lambda: SimpleNamespace(openai_api_key=None)
    )
    assert client.post("/api/me/taste").status_code == 409
    assert (
        client.post(
            "/api/me/collections/chat", json={"message": "전시 만들어줘"}
        ).status_code
        == 503
    )


def rpc(c, method, params=None, actor="a"):
    return c.post(
        "/mcp/",
        headers={
            "Authorization": f"Bearer {actor}",
            "Accept": "application/json, text/event-stream",
        },
        json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}},
    )


def test_actual_mcp_initialize_tools_and_cross_account_guard(client):
    init = rpc(
        client,
        "initialize",
        {
            "protocolVersion": "2025-11-25",
            "capabilities": {},
            "clientInfo": {"name": "test", "version": "1"},
        },
    )
    assert init.status_code == 200, init.text
    tools = rpc(client, "tools/list").json()["result"]["tools"]
    assert {t["name"] for t in tools} == {
        "list_collections",
        "search_artworks",
        "create_collection",
        "add_artwork_to_collection",
    }
    assert all("user_id" not in t["inputSchema"]["properties"] for t in tools)
    created = rpc(
        client,
        "tools/call",
        {"name": "create_collection", "arguments": {"name": "MCP 전시"}},
    ).json()["result"]
    assert not created.get("isError"), created
    cid = client.get("/api/me/collections").json()[0]["id"]
    args = {
        "name": "add_artwork_to_collection",
        "arguments": {"collection_id": cid, "artwork_id": 1},
    }
    denied = rpc(client, "tools/call", args, actor="b").json()["result"]
    assert denied["isError"]
    assert not rpc(client, "tools/call", args).json()["result"].get("isError")
    assert client.get("/api/me/collections").json()[0]["artwork_count"] == 1
    assert (
        client.post(
            "/mcp/",
            headers={
                "Authorization": "",
                "Accept": "application/json, text/event-stream",
            },
            json={},
        ).status_code
        == 401
    )
    assert rpc(client, "tools/list").headers["cache-control"] == "private, no-store"
