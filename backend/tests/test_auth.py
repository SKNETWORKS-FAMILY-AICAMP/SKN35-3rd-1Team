"""Firebase verification failures and verified-UID account isolation."""

from types import SimpleNamespace
from unittest.mock import Mock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from firebase_admin import auth as firebase_auth
from google.auth.exceptions import DefaultCredentialsError
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core import auth
from app.db.session import get_db
from app.repositories import user_repository


@pytest.fixture
def firebase_mode(monkeypatch):
    settings = SimpleNamespace(
        auth_mode="firebase",
        firebase_project_id="skn35-3rd-1team",
        firebase_service_account_json=None,
        google_application_credentials=None,
        dev_user_uid="dev-user",
    )
    monkeypatch.setattr(auth, "get_settings", lambda: settings)
    monkeypatch.setattr(auth, "_get_firebase_app", lambda: "test-app")
    return settings


@pytest.fixture
def client(firebase_mode):
    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    # SQLite-compatible users table; the production ORM and repository are used
    # unchanged, including the UNIQUE firebase_uid constraint and commits.
    with engine.begin() as connection:
        connection.execute(
            text("""
            CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                firebase_uid VARCHAR(128) NOT NULL UNIQUE,
                email VARCHAR(255) NOT NULL UNIQUE,
                nickname VARCHAR(50) NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)
        )
    app = FastAPI()

    @app.get("/required")
    def required(user: auth.CurrentUser):
        return {"id": user.id, "nickname": user.nickname}

    @app.get("/optional")
    def optional(user: auth.OptionalUser):
        return {"id": user.id if user else None}

    def database():
        with Session(engine) as session:
            yield session

    app.dependency_overrides[get_db] = database
    with TestClient(app) as test_client:
        yield test_client
    engine.dispose()


def test_verified_uid_creates_distinct_users_and_reuses_existing_user(
    client, monkeypatch
):
    def verify(token, *, app):
        assert app == "test-app"
        return {
            "uid": token,
            "email": f"{token}@example.invalid",
            "name": f"사용자 {token}",
        }

    verifier = Mock(side_effect=verify)
    monkeypatch.setattr(auth.firebase_auth, "verify_id_token", verifier)
    a = client.get("/required?user_id=999", headers={"Authorization": "Bearer uid-a"})
    b = client.get("/required", headers={"Authorization": "Bearer uid-b"})
    again = client.get("/required", headers={"Authorization": "Bearer uid-a"})
    assert a.status_code == b.status_code == again.status_code == 200
    assert a.json()["id"] != b.json()["id"]
    assert a.json() == again.json()
    assert a.json()["nickname"] == "사용자 uid-a"
    assert verifier.call_count == 3


@pytest.mark.parametrize("name", [None, "", "   "])
def test_missing_display_name_uses_email_prefix(client, monkeypatch, name):
    monkeypatch.setattr(
        auth.firebase_auth,
        "verify_id_token",
        lambda *a, **k: {"uid": "uid", "email": "reader@example.invalid", "name": name},
    )
    response = client.get("/required", headers={"Authorization": "Bearer token"})
    assert response.status_code == 200
    assert response.json()["nickname"] == "reader"


def test_display_name_fits_database_column(client, monkeypatch):
    monkeypatch.setattr(
        auth.firebase_auth,
        "verify_id_token",
        lambda *a, **k: {
            "uid": "uid",
            "email": "reader@example.invalid",
            "name": "가" * 80,
        },
    )
    response = client.get("/required", headers={"Authorization": "Bearer token"})
    assert response.status_code == 200
    assert response.json()["nickname"] == "가" * 50


@pytest.mark.parametrize(
    "error",
    [
        firebase_auth.InvalidIdTokenError("bad signature / project"),
        firebase_auth.ExpiredIdTokenError("expired", None),
        firebase_auth.CertificateFetchError("unavailable", None),
        DefaultCredentialsError("missing server credentials"),
        ValueError("invalid token"),
    ],
)
@pytest.mark.parametrize("path", ["/required", "/optional"])
def test_verification_failure_is_401_and_never_touches_users(
    client, monkeypatch, error, path
):
    monkeypatch.setattr(auth.firebase_auth, "verify_id_token", Mock(side_effect=error))
    repository = Mock()
    monkeypatch.setattr(user_repository, "get_or_create_by_firebase_uid", repository)
    response = client.get(
        path, headers={"Authorization": "Bearer sensitive-test-token"}
    )
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json() == {"detail": "로그인이 필요합니다."}
    assert "sensitive-test-token" not in response.text
    repository.assert_not_called()


@pytest.mark.parametrize(
    "claims",
    [
        {},
        {"uid": "uid"},
        {"uid": "", "email": "a@example.invalid"},
        {"uid": "x" * 129, "email": "a@example.invalid"},
        {"uid": "uid", "email": None},
        {"uid": "uid", "email": " "},
        {"uid": "uid", "email": "x" * 256},
    ],
)
def test_incomplete_identity_is_rejected_before_database_write(
    client, monkeypatch, claims
):
    monkeypatch.setattr(auth.firebase_auth, "verify_id_token", lambda *a, **k: claims)
    repository = Mock()
    monkeypatch.setattr(user_repository, "get_or_create_by_firebase_uid", repository)
    assert (
        client.get("/required", headers={"Authorization": "Bearer token"}).status_code
        == 401
    )
    repository.assert_not_called()


def test_missing_token_is_required_or_anonymous(client, monkeypatch):
    verifier = Mock()
    monkeypatch.setattr(auth.firebase_auth, "verify_id_token", verifier)
    assert client.get("/required").status_code == 401
    assert client.get("/optional").json() == {"id": None}
    verifier.assert_not_called()


def test_dev_mode_is_explicit_and_unknown_mode_does_not_fall_back(
    client, firebase_mode, monkeypatch
):
    firebase_mode.auth_mode = "dev"
    verifier = Mock()
    monkeypatch.setattr(auth.firebase_auth, "verify_id_token", verifier)
    a = client.get("/required", headers={"Authorization": "Bearer a"})
    b = client.get("/required", headers={"Authorization": "Bearer b"})
    assert a.status_code == b.status_code == 200
    assert a.json()["id"] == b.json()["id"]
    verifier.assert_not_called()
    firebase_mode.auth_mode = "typo"
    assert (
        client.get("/required", headers={"Authorization": "Bearer a"}).status_code
        == 401
    )


def test_initialization_reuses_named_app_and_pins_project(monkeypatch):
    settings = SimpleNamespace(
        firebase_project_id="skn35-3rd-1team",
        firebase_service_account_json=None,
        google_application_credentials=None,
    )
    monkeypatch.setattr(auth, "get_settings", lambda: settings)
    app = SimpleNamespace(project_id=settings.firebase_project_id)
    monkeypatch.setattr(
        auth.firebase_admin, "get_app", Mock(side_effect=[ValueError(), app])
    )
    initialize = Mock(return_value=app)
    monkeypatch.setattr(auth.firebase_admin, "initialize_app", initialize)
    assert auth._get_firebase_app() is app
    assert auth._get_firebase_app() is app
    initialize.assert_called_once_with(
        None, options={"projectId": settings.firebase_project_id}, name="artlog-auth"
    )


def test_initialization_rejects_different_project(monkeypatch):
    monkeypatch.setattr(
        auth,
        "get_settings",
        lambda: SimpleNamespace(firebase_project_id="skn35-3rd-1team"),
    )
    monkeypatch.setattr(
        auth.firebase_admin,
        "get_app",
        lambda *a: SimpleNamespace(project_id="other-project"),
    )
    with pytest.raises(ValueError, match="project configuration mismatch"):
        auth._get_firebase_app()


def test_initialization_reads_local_credential_path(monkeypatch):
    settings = SimpleNamespace(
        firebase_project_id="skn35-3rd-1team",
        firebase_service_account_json=None,
        google_application_credentials="/private/test-server-credential.json",
    )
    monkeypatch.setattr(auth, "get_settings", lambda: settings)
    monkeypatch.setattr(auth.firebase_admin, "get_app", Mock(side_effect=ValueError()))
    certificate = Mock(return_value="server-credential")
    monkeypatch.setattr(auth.credentials, "Certificate", certificate)
    initialize = Mock(
        return_value=SimpleNamespace(project_id=settings.firebase_project_id)
    )
    monkeypatch.setattr(auth.firebase_admin, "initialize_app", initialize)
    auth._get_firebase_app()
    certificate.assert_called_once_with(settings.google_application_credentials)
    initialize.assert_called_once_with(
        "server-credential",
        options={"projectId": settings.firebase_project_id},
        name="artlog-auth",
    )
