"""Member profiles, member follows and follow-list visibility."""

import pytest
from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import DefaultClause, MetaData, create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.auth import get_current_user, get_optional_user
from app.db.session import get_db
from app.main import app
from app.models import (
    Artist,
    ArtMovement,
    Artwork,
    DiaryEntry,
    User,
    UserFollow,
    UserPreference,
)


@pytest.fixture
def client():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    metadata = MetaData()
    for model in (User, ArtMovement, Artist, Artwork, UserPreference, DiaryEntry, UserFollow):
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
                    firebase_uid=f"uid-{i}",
                    email=f"private-{i}@example.com",
                    nickname=f"감상가{i}",
                    public_id=f"pub{i}",
                )
                for i in (1, 2, 3)
            ]
        )
        db.add(ArtMovement(id=1, slug="test", name="사조"))
        db.add(Artist(id=1, slug="artist", name="김작가", movement_id=1))
        db.flush()
        db.add(Artwork(id=1, slug="work", title="그림", artist_id=1, is_featured=False))
        db.commit()

        def actor(request: Request):
            token = request.headers.get("Authorization", "")
            ids = {"Bearer a": 1, "Bearer b": 2, "Bearer c": 3}
            return db.get(User, ids[token]) if token in ids else None

        def required(request: Request):
            user = actor(request)
            if user is None:
                raise HTTPException(401, "로그인 필요")
            return user

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = required
        app.dependency_overrides[get_optional_user] = actor
        with TestClient(app) as http:
            yield http
        app.dependency_overrides.clear()
    engine.dispose()


A, B, C = ({"Authorization": f"Bearer {k}"} for k in "abc")


def test_follow_counts_lists_and_no_private_identifiers(client):
    assert client.put("/api/users/pub2/follow", headers=A).status_code == 204
    assert client.put("/api/users/pub2/follow", headers=A).status_code == 204
    assert client.put("/api/users/pub2/follow", headers=C).status_code == 204
    profile = client.get("/api/users/pub2", headers=A).json()
    assert profile["follower_count"] == 2 and profile["following_count"] == 0
    assert profile["is_following"] and not profile["is_me"]
    followers = client.get("/api/users/pub2/followers").json()
    assert {m["id"] for m in followers} == {"pub1", "pub3"}
    assert "private-" not in str(followers) and "uid-" not in str(profile)
    assert client.get("/api/users/pub1/following").json() == [
        {"id": "pub2", "nickname": "감상가2"}
    ]
    assert client.delete("/api/users/pub2/follow", headers=A).status_code == 204
    assert client.get("/api/users/pub2").json()["follower_count"] == 1


def test_self_follow_unknown_member_and_login_required(client):
    assert client.put("/api/users/pub1/follow", headers=A).status_code == 400
    assert client.put("/api/users/nobody/follow", headers=A).status_code == 404
    assert client.put("/api/users/pub2/follow").status_code == 401
    assert client.get("/api/users/nobody").status_code == 404


def test_hidden_follow_lists_only_visible_to_owner(client):
    client.put("/api/users/pub2/follow", headers=A)
    saved = client.put(
        "/api/me/social", headers=B, json={"follow_list_public": False}
    ).json()
    assert saved["follow_list_public"] is False and saved["follower_count"] == 1
    other = client.get("/api/users/pub2", headers=A).json()
    assert other["follower_count"] is None and other["following_count"] is None
    assert client.get("/api/users/pub2/followers", headers=A).status_code == 403
    assert client.get("/api/users/pub2/followers", headers=B).status_code == 200
    assert client.get("/api/me/social", headers=B).json()["is_me"] is True
    assert client.put(
        "/api/me/social", headers=B, json={"follow_list_public": True, "user_id": 1}
    ).status_code == 422


def test_member_diary_and_feed_expose_only_public_entries_with_author_id(client):
    client.post(
        "/api/me/diary",
        headers=B,
        json={
            "entry_date": "2026-10-01",
            "content": "공개 감상",
            "is_public": True,
            "artwork_id": 1,
        },
    )
    client.post(
        "/api/me/diary",
        headers=B,
        json={"entry_date": "2026-10-02", "content": "비공개"},
    )
    entries = client.get("/api/users/pub2/diary").json()["items"]
    assert [e["content"] for e in entries] == ["공개 감상"]
    feed = client.get("/api/diary/feed").json()["items"]
    assert feed[0]["author_id"] == "pub2"
    assert client.get("/api/users/pub1/diary").json()["items"] == []
