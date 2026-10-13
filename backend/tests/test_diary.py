"""Exercise actual diary SQL and HTTP against isolated SQLite, never shared TiDB."""

import pytest
from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import DefaultClause, MetaData, create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.auth import get_current_user
from app.db.session import get_db
from app.main import app
from app.models import Artist, ArtMovement, Artwork, DiaryEntry, User


@pytest.fixture
def client():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    metadata = MetaData()
    for model in (User, ArtMovement, Artist, Artwork, DiaryEntry):
        table = model.__table__.to_metadata(metadata)
        for column in table.columns:
            if column.server_default is not None and "ON UPDATE" in str(
                column.server_default.arg
            ):
                column.server_default = DefaultClause(text("CURRENT_TIMESTAMP"))
    metadata.create_all(engine)
    with Session(engine) as db:
        db.add_all(
            [
                User(
                    id=1,
                    firebase_uid="a",
                    email="private-a@example.com",
                    nickname="첫 감상가",
                ),
                User(
                    id=2,
                    firebase_uid="b",
                    email="private-b@example.com",
                    nickname="두 번째 감상가",
                ),
                ArtMovement(id=1, slug="test", name="사조"),
                Artist(id=1, slug="artist", name="작가", movement_id=1),
            ]
        )
        db.flush()
        db.add_all(
            [
                Artwork(
                    id=i,
                    slug=f"work-{i}",
                    title=f"작품 {i}",
                    artist_id=1,
                    is_featured=False,
                )
                for i in (1, 2)
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
        with TestClient(app) as http:
            yield http
        app.dependency_overrides.clear()
    engine.dispose()


def put(client, day="2026-10-13", *, token="a", **body):
    return client.put(
        f"/api/me/diary/{day}",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": "감상", **body},
    )


def test_private_default_and_public_to_private_transition(client):
    private = put(client)
    assert private.status_code == 200
    assert not private.json()["is_public"]
    assert client.get("/api/diary/feed").json()["items"] == []
    public = put(client, content="  빛이 따뜻해요  ", is_public=True, artwork_id=1)
    assert public.json()["id"] == private.json()["id"]
    feed = client.get("/api/diary/feed")
    assert feed.headers["cache-control"] == "no-store"
    item = feed.json()["items"][0]
    assert item["content"] == "빛이 따뜻해요"
    assert item["author_name"] == "첫 감상가"
    assert item["artwork"]["id"] == 1
    assert not {"email", "firebase_uid", "user_id"}.intersection(item)
    assert "private-a@example.com" not in feed.text
    put(client, is_public=False)
    assert client.get("/api/diary/feed").json()["items"] == []


def test_users_cannot_read_edit_or_delete_other_diaries(client):
    first = put(client, content="A의 비공개 기록").json()
    assert (
        client.get(
            "/api/me/diary/2026-10-13", headers={"Authorization": "Bearer b"}
        ).json()
        is None
    )
    second = put(client, token="b", content="B의 기록").json()
    assert second["id"] != first["id"]
    client.delete("/api/me/diary/2026-10-13", headers={"Authorization": "Bearer b"})
    own = client.get("/api/me/diary/2026-10-13", headers={"Authorization": "Bearer a"})
    assert own.json()["content"] == first["content"]
    assert own.headers["cache-control"] == "private, no-store"


def test_public_feed_cursor_and_artwork_filter(client):
    for day in range(1, 7):
        put(client, f"2026-10-{day:02}", is_public=day != 5, artwork_id=day % 2 + 1)
    one = client.get("/api/diary/feed?limit=2").json()
    two = client.get(f"/api/diary/feed?limit=2&before_id={one['next_cursor']}").json()
    assert [e["entry_date"] for e in one["items"] + two["items"]] == [
        "2026-10-06",
        "2026-10-04",
        "2026-10-03",
        "2026-10-02",
    ]
    filtered = client.get("/api/diary/feed?artwork_id=2").json()["items"]
    assert all(e["artwork"]["id"] == 2 for e in filtered)
    assert client.get("/api/diary/feed?limit=31").status_code == 422


def test_diary_only_day_month_boundaries_and_delete(client):
    put(client, "2026-09-30")
    put(client, "2026-10-01", is_public=True)
    put(client, "2026-10-31")
    put(client, "2026-11-01")
    month = client.get(
        "/api/me/diary?month=2026-10", headers={"Authorization": "Bearer a"}
    ).json()
    assert [d["entry_date"] for d in month] == ["2026-10-31", "2026-10-01"]
    assert (
        client.delete(
            "/api/me/diary/2026-10-01", headers={"Authorization": "Bearer a"}
        ).status_code
        == 204
    )
    assert client.get("/api/diary/feed").json()["items"] == []


@pytest.mark.parametrize(
    "body",
    [{"content": "  "}, {"content": "x" * 2001}, {"user_id": 2}, {"artwork_id": -1}],
)
def test_invalid_body_cannot_write(client, body):
    assert put(client, **body).status_code == 422


def test_auth_validation_and_missing_artwork_preserves_existing(client):
    assert client.get("/api/me/diary?month=2026-10").status_code == 401
    assert (
        client.put("/api/me/diary/2026-10-13", json={"content": "내용"}).status_code
        == 401
    )
    assert client.delete("/api/me/diary/2026-10-13").status_code == 401
    put(client)
    assert put(client, artwork_id=999).status_code == 404
    own = client.get(
        "/api/me/diary/2026-10-13", headers={"Authorization": "Bearer a"}
    ).json()
    assert own["content"] == "감상"
    assert put(client, "2026-02-30").status_code == 422
