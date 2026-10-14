"""Account isolation, real collection SQL and the actual MCP wire protocol."""

from datetime import timedelta
from types import SimpleNamespace

import pytest
from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import DefaultClause, MetaData, create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.auth import get_current_user
from app.core.timeutil import local_date, utcnow
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
from app.rag import collection_mcp
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


def test_profile_roundtrip_birthdate_style_and_account_isolation(client):
    defaults = client.get("/api/me/profile")
    assert defaults.headers["Cache-Control"] == "private, no-store"
    assert defaults.json()["onboarding_completed"] is False
    assert "explanation_priorities" not in defaults.json()
    body = {
        "birth_date": "2001-02-03",
        "conversation_style": "professional",
    }
    saved = client.put("/api/me/profile", json=body).json()
    assert saved["onboarding_completed"] is True
    assert all(saved[k] == v for k, v in body.items())
    assert "explanation_priorities" not in saved
    assert (
        client.get("/api/me/profile", headers={"Authorization": "Bearer b"}).json()[
            "birth_date"
        ]
        is None
    )
    client.put("/api/me/profile", json={})
    assert client.get("/api/me/profile").json()["birth_date"] is None


def test_nickname_change_is_optional_own_and_shown_in_feed(client):
    assert client.get("/api/me/profile").json()["nickname"] == "감상가1"
    saved = client.put("/api/me/profile", json={"nickname": "  새벽산책  "}).json()
    assert saved["nickname"] == "새벽산책"
    # 닉네임을 보내지 않는 기존 화면의 저장은 이름을 바꾸지 않는다
    client.put("/api/me/profile", json={"conversation_style": "professional"})
    assert client.get("/api/me/profile").json()["nickname"] == "새벽산책"
    other = client.get("/api/me/profile", headers={"Authorization": "Bearer b"})
    assert other.json()["nickname"] == "감상가2"

    day = client.post(
        "/api/me/diary",
        json={"entry_date": "2026-10-01", "content": "공개 감상", "is_public": True},
    )
    assert day.status_code == 201, day.text
    feed = client.get("/api/diary/feed").json()["items"]
    assert [item["author_name"] for item in feed] == ["새벽산책"]
    assert "private-1@example.com" not in str(feed)


@pytest.mark.parametrize(
    "body",
    [
        {"nickname": "가"},
        {"nickname": "   "},
        {"nickname": "가" * 21},
        {"birth_date": "2099-01-01"},
        {"birth_date": "2026-02-30"},
        {"birth_date": "1899-01-01"},
        {"explanation_priorities": ["background", "technique", "artist_life"]},
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
    client.post(
        "/api/me/diary",
        json={"entry_date": "2026-10-14", "content": "비공개 비평", "artwork_id": 1},
    )
    client.post(
        "/api/me/diary",
        headers={"Authorization": "Bearer b"},
        json={
            "entry_date": "2026-10-13",
            "content": "다른 이용자의 비평",
            "artwork_id": 2,
        },
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
        "list_auto_collections",
        "create_collection_from_views",
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


def view(c, user_id, artwork_id, days_ago=0, count=1):
    """Record a view directly so the order of views is exact."""
    db = app.dependency_overrides[get_db]()
    at = utcnow() - timedelta(days=days_ago)
    db.add(
        ArtworkView(
            user_id=user_id,
            artwork_id=artwork_id,
            viewed_on=local_date(at),
            view_count=count,
            first_viewed_at=at,
            last_viewed_at=at,
        )
    )
    db.commit()


def test_auto_collections_follow_own_view_history_only(client):
    assert client.get("/api/me/collections/auto").json() == []
    view(client, 1, 3, days_ago=2)
    view(client, 1, 7, days_ago=1, count=3)
    view(client, 1, 5, days_ago=0)
    view(client, 2, 9)  # another member's history never shows up
    autos = {c["key"]: c for c in client.get("/api/me/collections/auto").json()}
    month = local_date(utcnow()).strftime("%Y-%m")
    assert set(autos) >= {"recent", "frequent", "artist-1"}
    assert autos["recent"]["cover"]["id"] == 5 and autos["recent"]["artwork_count"] == 3
    assert autos["frequent"]["artwork_count"] == 1  # only works viewed twice or more
    assert autos["artist-1"]["name"] == "김작가 모음"
    recent = client.get("/api/me/collections/auto/recent")
    assert recent.headers["Cache-Control"] == "private, no-store"
    assert [a["id"] for a in recent.json()["items"]] == [5, 7, 3]
    this_month = client.get(f"/api/me/collections/auto/month-{month}").json()
    assert {a["id"] for a in this_month["items"]} <= {3, 5, 7}
    for bad in ("nope", "month-2026-13", "artist-999"):
        assert client.get(f"/api/me/collections/auto/{bad}").status_code == 404
    client.headers["Authorization"] = "Bearer b"
    other = client.get("/api/me/collections/auto/recent").json()
    assert [a["id"] for a in other["items"]] == [9]


def test_create_with_artworks_keeps_order_and_first_is_cover(client):
    made = client.post(
        "/api/me/collections", json={"name": "순서 전시", "artwork_ids": [5, 2, 9, 2]}
    )
    assert made.status_code == 201, made.text
    assert made.json()["artwork_count"] == 3
    assert [a["id"] for a in made.json()["previews"]] == [5, 2, 9]
    client.put(f"/api/me/collections/{made.json()['id']}/items/1")
    listed = client.get("/api/me/collections").json()[0]
    assert listed["previews"][0]["id"] == 5  # a later add never replaces the cover
    missing = client.post(
        "/api/me/collections", json={"name": "없는 작품", "artwork_ids": [1, 999]}
    )
    assert missing.status_code == 404
    assert [c["name"] for c in client.get("/api/me/collections").json()] == ["순서 전시"]


def test_chat_from_views_proposes_viewed_works_and_writes_nothing(client, monkeypatch):
    view(client, 1, 4, days_ago=1)
    view(client, 1, 8, days_ago=0)

    def intent(**kw):
        monkeypatch.setattr(ai, "generate", lambda *args: ai.Intent(action="from_views", **kw))
        return client.post("/api/me/collections/chat", json={"message": "모아줘"}).json()

    reply = intent(basis="recent")
    assert reply["proposal"]["name"] == "최근 본 작품"
    assert reply["proposal"]["artwork_ids"] == [8, 4]
    assert [a["id"] for a in reply["artworks"]] == [8, 4]
    assert client.get("/api/me/collections").json() == []
    assert intent(basis="artist", artist_query="김작가")["proposal"]["name"] == "김작가 모음"
    assert intent(basis="artist", artist_query="없는화가")["proposal"] is None
    assert intent(basis="frequent")["proposal"] is None  # nothing viewed twice yet
    assert intent(basis="month")["proposal"] is None  # month is required
    p = reply["proposal"]
    created = client.post(
        "/api/me/collections", json={"name": p["name"], "artwork_ids": p["artwork_ids"]}
    ).json()
    assert created["previews"][0]["id"] == 8
    assert intent(basis="recent")["proposal"] is None  # same name already exists


def test_mcp_creates_collection_from_own_views(client):
    view(client, 1, 6, days_ago=1)
    view(client, 1, 2, days_ago=0)
    autos = rpc(client, "tools/call", {"name": "list_auto_collections", "arguments": {}})
    assert not autos.json()["result"].get("isError")
    made = rpc(
        client,
        "tools/call",
        {"name": "create_collection_from_views", "arguments": {"basis": "recent"}},
    ).json()["result"]
    assert not made.get("isError"), made
    saved = client.get("/api/me/collections").json()[0]
    assert saved["name"] == "최근 본 작품"
    assert [a["id"] for a in saved["previews"]] == [2, 6]
    empty = rpc(
        client,
        "tools/call",
        {"name": "create_collection_from_views", "arguments": {"basis": "recent"}},
        actor="b",
    ).json()["result"]
    assert empty["isError"]  # member b has no view history


def test_docent_offers_collection_only_after_repeated_questions(client):
    from app.schemas.chat import ChatRequest, ChatResponse, ChatTurn
    from app.services import collection_suggestions as offers

    db = app.dependency_overrides[get_db]()
    answered = ChatResponse(answer="답", refused=False, sources=[])

    def ask(questions, response=answered, user=1, artwork=1):
        history = [
            ChatTurn(role=role, content="질문" if role == "user" else "답")
            for _ in range(questions - 1)
            for role in ("user", "assistant")
        ]
        body = ChatRequest(question="또 질문", history=history)
        return offers.suggest(db, user, artwork, body, response)

    assert ask(2) is None  # not yet interested
    assert ask(3, ChatResponse(answer="모름", refused=True, sources=[])) is None
    assert ask(3, user=None) is None  # guests get no offer
    offer = ask(3)
    assert offer.kind == "add_artwork" and offer.collections == []
    cid = group(client, "담을 곳")
    assert [c.id for c in ask(3).collections] == [cid]
    client.put(f"/api/me/collections/{cid}/items/1")
    assert ask(3) is None  # already collected
    for art in (2, 3, 4):
        view(client, 1, art)
    artist = ask(3)
    assert artist.kind == "create_from_views"
    assert artist.proposal.name == "김작가 모음"
    assert sorted(artist.proposal.artwork_ids) == [2, 3, 4]
    assert client.get("/api/me/collections").json()[0]["artwork_count"] == 1  # nothing saved
    group(client, "김작가 모음")
    assert ask(3) is None  # artist collection exists and artwork 1 is collected
