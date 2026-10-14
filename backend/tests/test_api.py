"""API contract tests that run without TiDB.

These tests pin the contract: routing, auth requirements, request validation,
error format and the generated OpenAPI. The DB session and the services are
replaced with stubs, so nothing here reads or writes TiDB. Routes that are not
use mocked model responses so these tests never call paid AI services.
"""

from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, get_optional_user
from app.core.exceptions import NotFoundError
from app.db.session import get_db
from app.main import app
from app.schemas.catalog import ArtistDetail, ArtworkDetail
from app.schemas.chat import ChatResponse
from app.services import (
    catalog_service,
    chat_service,
    docent_service,
    follow_service,
    library_service,
    like_service,
    recommendation_service,
)

client = TestClient(app)

PUBLIC = [
    ("GET", "/api/movements"),
    ("GET", "/api/artists"),
    ("GET", "/api/artists/1"),
    ("GET", "/api/artworks"),
    ("GET", "/api/artworks/1"),
    ("GET", "/api/artworks/1/similar"),
]

PROTECTED = [
    ("GET", "/api/artworks/1/chat/messages"),
    ("DELETE", "/api/artworks/1/chat"),
    ("GET", "/api/me/chats"),
    ("PUT", "/api/artworks/1/like"),
    ("DELETE", "/api/artworks/1/like"),
    ("GET", "/api/me/likes"),
    ("PUT", "/api/artists/1/follow"),
    ("DELETE", "/api/artists/1/follow"),
    ("GET", "/api/me/follows"),
    ("POST", "/api/artworks/1/views"),
    ("GET", "/api/me/library/calendar?month=2026-10"),
    ("GET", "/api/me/library/days/2026-10-12"),
    ("GET", "/api/me/recommendations/artworks"),
    ("GET", "/api/me/recommendations/artists"),
]

NO_CONTENT = [
    ("PUT", "/api/artworks/{artwork_id}/like"),
    ("DELETE", "/api/artworks/{artwork_id}/like"),
    ("PUT", "/api/artists/{artist_id}/follow"),
    ("DELETE", "/api/artists/{artist_id}/follow"),
    ("POST", "/api/artworks/{artwork_id}/views"),
    ("DELETE", "/api/artworks/{artwork_id}/chat"),
]

VALID_CHAT = {"question": "이 작품은 언제 그렸나요?", "history": []}

# Implemented routes answer 200/204 with stubbed services.
ROUTED = {200, 204}

ARTIST = ArtistDetail(
    id=1,
    slug="rembrandt",
    name="렘브란트 판 레인",
    name_en="Rembrandt van Rijn",
    movement_id=1,
    birth_year=1606,
    death_year=1669,
    summary=None,
    portrait_url=None,
    nationality="네덜란드",
)
ARTWORK = ArtworkDetail(
    id=1,
    slug="night-watch",
    title="야경",
    title_en="The Night Watch",
    artist_id=1,
    artist_name="렘브란트 판 레인",
    movement_id=1,
    year_label="1642",
    image_url=None,
    is_featured=True,
    medium=None,
    dimensions=None,
    collection=None,
    description=None,
    image_source_url=None,
    image_license=None,
)


@pytest.fixture(autouse=True)
def stub_services(monkeypatch):
    """No DB: a dummy session and canned service results."""

    app.dependency_overrides[get_db] = lambda: None
    nothing = lambda *args, **kwargs: None
    empty = lambda *args, **kwargs: []
    for module, name, fake in [
        (
            docent_service,
            "answer",
            lambda *a, **k: ChatResponse(
                answer="테스트 답변", refused=False, sources=[]
            ),
        ),
        (chat_service, "save_exchange", nothing),
        (catalog_service, "list_movements", empty),
        (catalog_service, "list_artists", empty),
        (catalog_service, "get_artist", lambda *a, **k: ARTIST),
        (catalog_service, "list_artworks", empty),
        (catalog_service, "get_artwork", lambda *a, **k: ARTWORK),
        (like_service, "like", nothing),
        (like_service, "unlike", nothing),
        (like_service, "list_liked", empty),
        (follow_service, "follow", nothing),
        (follow_service, "unfollow", nothing),
        (follow_service, "list_followed", empty),
        (library_service, "record_view", nothing),
        (library_service, "calendar", empty),
        (library_service, "viewed_on_day", empty),
        (chat_service, "list_messages", empty),
        (chat_service, "reset", nothing),
        (chat_service, "list_chats", empty),
        (recommendation_service, "similar", empty),
        (recommendation_service, "recommend_artworks", empty),
        (recommendation_service, "recommend_artists", empty),
    ]:
        monkeypatch.setattr(module, name, fake)
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def logged_in():
    """Act as a logged-in user without touching the database."""

    fake_user = SimpleNamespace(id=1, firebase_uid="test-user")
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[get_optional_user] = lambda: fake_user
    yield fake_user
    app.dependency_overrides.pop(get_current_user)
    app.dependency_overrides.pop(get_optional_user)


@pytest.fixture(scope="module")
def openapi() -> dict:
    return app.openapi()


def json_schema(openapi: dict, method: str, path: str, status: str = "200") -> dict:
    operation = openapi["paths"][path][method.lower()]
    return operation["responses"][status]["content"]["application/json"]["schema"]


def test_health() -> None:
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


# --- routing and auth -------------------------------------------------------


@pytest.mark.parametrize(("method", "path"), PUBLIC)
def test_public_endpoints_need_no_token(method: str, path: str) -> None:
    assert client.request(method, path).status_code in ROUTED


@pytest.mark.parametrize(("method", "path"), PROTECTED)
def test_protected_endpoints_reject_missing_token(method: str, path: str) -> None:
    response = client.request(method, path)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize(("method", "path"), PROTECTED)
def test_protected_endpoints_route_when_logged_in(
    method: str, path: str, logged_in
) -> None:
    assert client.request(method, path).status_code in ROUTED


def test_chat_allows_anonymous_questions() -> None:
    assert client.post("/api/artworks/1/chat", json=VALID_CHAT).status_code == 200


def test_chat_accepts_logged_in_questions(logged_in) -> None:
    assert client.post("/api/artworks/1/chat", json=VALID_CHAT).status_code == 200


@pytest.mark.parametrize(
    ("path", "service", "name"),
    [
        ("/api/artworks/999", catalog_service, "get_artwork"),
        ("/api/artists/999", catalog_service, "get_artist"),
    ],
)
def test_missing_resource_is_404_with_detail(monkeypatch, path, service, name) -> None:
    def missing(*args, **kwargs):
        raise NotFoundError("없음")

    monkeypatch.setattr(service, name, missing)
    response = client.get(path)
    assert response.status_code == 404
    assert response.json() == {"detail": "없음"}


def test_like_missing_artwork_is_404(monkeypatch, logged_in) -> None:
    def missing(*args, **kwargs):
        raise NotFoundError("작품을 찾을 수 없습니다.")

    monkeypatch.setattr(like_service, "like", missing)
    assert client.put("/api/artworks/999/like").status_code == 404


def test_user_id_comes_from_token(monkeypatch, logged_in) -> None:
    seen = {}
    monkeypatch.setattr(
        like_service,
        "list_liked",
        lambda db, *, user_id: seen.setdefault("id", user_id) and [],
    )
    client.get("/api/me/likes?user_id=999")
    assert seen == {"id": logged_in.id}


def test_detail_returns_service_model() -> None:
    body = client.get("/api/artworks/1").json()
    assert body["artist_name"] == "렘브란트 판 레인"
    assert "image_license" in body


# --- request validation -----------------------------------------------------


@pytest.mark.parametrize(
    "body",
    [
        None,
        {},
        {"question": ""},
        {"question": "가" * 501},
        {"question": "질문", "history": [{"role": "system", "content": "x"}]},
        {"question": "질문", "history": [{"role": "user", "content": ""}]},
        {"question": "질문", "history": [{"role": "user", "content": "x"}] * 13},
    ],
    ids=[
        "no-body",
        "empty",
        "blank-question",
        "long-question",
        "bad-role",
        "blank-turn",
        "13-turns",
    ],
)
def test_chat_rejects_invalid_body(body) -> None:
    assert client.post("/api/artworks/1/chat", json=body).status_code == 422


def test_chat_history_is_optional() -> None:
    assert (
        client.post("/api/artworks/1/chat", json={"question": "질문"}).status_code
        == 200
    )


@pytest.mark.parametrize("month", ["2026-1", "2026-13", "202610", "2026-00"])
def test_calendar_month_must_be_yyyy_mm(month: str, logged_in) -> None:
    assert client.get(f"/api/me/library/calendar?month={month}").status_code == 422


def test_library_day_must_be_a_date(logged_in) -> None:
    assert client.get("/api/me/library/days/2026-13-40").status_code == 422


# --- OpenAPI contract -------------------------------------------------------


def test_chat_contract(openapi: dict) -> None:
    operation = openapi["paths"]["/api/artworks/{artwork_id}/chat"]["post"]
    request = operation["requestBody"]["content"]["application/json"]["schema"]
    assert request == {"$ref": "#/components/schemas/ChatRequest"}
    assert json_schema(openapi, "POST", "/api/artworks/{artwork_id}/chat") == {
        "$ref": "#/components/schemas/ChatResponse"
    }
    schemas = openapi["components"]["schemas"]
    assert set(schemas["ChatRequest"]["required"]) == {"question"}
    assert set(schemas["ChatResponse"]["required"]) == {"answer", "refused", "sources"}
    assert set(schemas["Source"]["properties"]) == {
        "document_id",
        "title",
        "doc_type",
        "source_name",
        "source_url",
        "license",
        "basis_sources",
    }
    assert "basis_sources" not in schemas["Source"].get("required", [])
    assert set(schemas["BasisSource"]["properties"]) == {
        "source_name",
        "source_url",
    }


@pytest.mark.parametrize(
    ("path", "item"),
    [
        ("/api/movements", "Movement"),
        ("/api/artists", "ArtistCard"),
        ("/api/artworks", "ArtworkCard"),
        ("/api/artworks/{artwork_id}/similar", "ArtworkCard"),
        ("/api/artworks/{artwork_id}/chat/messages", "ChatMessageOut"),
        ("/api/me/chats", "ChatSummary"),
        ("/api/me/likes", "ArtworkCard"),
        ("/api/me/follows", "ArtistCard"),
        ("/api/me/library/calendar", "CalendarDay"),
        ("/api/me/library/days/{day}", "ViewedArtwork"),
        ("/api/me/recommendations/artworks", "RecommendedArtwork"),
        ("/api/me/recommendations/artists", "RecommendedArtist"),
    ],
)
def test_lists_are_plain_json_arrays(openapi: dict, path: str, item: str) -> None:
    schema = json_schema(openapi, "GET", path)
    assert schema["type"] == "array"
    assert schema["items"] == {"$ref": f"#/components/schemas/{item}"}


@pytest.mark.parametrize(
    ("path", "model"),
    [
        ("/api/artists/{artist_id}", "ArtistDetail"),
        ("/api/artworks/{artwork_id}", "ArtworkDetail"),
    ],
)
def test_details_return_detail_models(openapi: dict, path: str, model: str) -> None:
    assert json_schema(openapi, "GET", path) == {
        "$ref": f"#/components/schemas/{model}"
    }


@pytest.mark.parametrize(("method", "path"), NO_CONTENT)
def test_no_content_endpoints_have_no_body(
    openapi: dict, method: str, path: str
) -> None:
    responses = openapi["paths"][path][method.lower()]["responses"]
    assert "200" not in responses
    assert "content" not in responses["204"]


def test_security_marks_only_authenticated_operations(openapi: dict) -> None:
    secured = {
        (method.upper(), path)
        for path, operations in openapi["paths"].items()
        for method, operation in operations.items()
        if operation.get("security")
    }
    assert ("GET", "/api/me/likes") in secured
    assert ("PUT", "/api/artworks/{artwork_id}/like") in secured
    # Optional bearer: shown as secured, but anonymous calls are allowed.
    assert ("POST", "/api/artworks/{artwork_id}/chat") in secured
    for public in [
        ("GET", "/api/health"),
        ("GET", "/api/movements"),
        ("GET", "/api/artists"),
        ("GET", "/api/artists/{artist_id}"),
        ("GET", "/api/artworks"),
        ("GET", "/api/artworks/{artwork_id}"),
        ("GET", "/api/artworks/{artwork_id}/similar"),
    ]:
        assert public not in secured


def test_responses_never_expose_private_columns(openapi: dict) -> None:
    for name, schema in openapi["components"]["schemas"].items():
        properties = set(schema.get("properties", {}))
        assert not properties & {"firebase_uid", "embedding", "password_hash"}, name


def test_route_methods_are_registered_once():
    keys = [(route.path, frozenset(route.methods)) for route in app.routes
            if hasattr(route, "methods") and route.path.startswith("/api/")]
    assert len(keys) == len(set(keys))
