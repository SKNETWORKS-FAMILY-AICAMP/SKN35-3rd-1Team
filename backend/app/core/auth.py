"""Who is calling. Routes take ``user: CurrentUser`` (login required) or
``user: OptionalUser`` (anonymous allowed, ``None`` when no token).

Clients send ``Authorization: Bearer <Firebase ID token>``. In Firebase mode
the Admin SDK verifies the signature, expiration, issuer and project before
``get_or_create_by_firebase_uid`` is called. Never read a uid from the request
body, path or query.

``AUTH_MODE=dev`` explicitly accepts any bearer token and maps to one fixed
development user. Use ``AUTH_MODE=firebase`` for real account separation.
"""

import json
from threading import Lock
from typing import Annotated

import firebase_admin
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials
from firebase_admin.exceptions import FirebaseError
from google.auth.exceptions import GoogleAuthError

from app.core.config import get_settings
from app.db.session import DbSession
from app.models import User
from app.repositories import user_repository

# auto_error=False: this module decides between 401 and anonymous.
bearer_scheme = HTTPBearer(auto_error=False, description="Firebase ID 토큰")
BearerToken = Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)]
_firebase_app_lock = Lock()
_firebase_app_name = "artlog-auth"


def _get_firebase_app() -> firebase_admin.App:
    """Initialize once, including when concurrent first requests arrive."""

    settings = get_settings()
    with _firebase_app_lock:
        try:
            app = firebase_admin.get_app(_firebase_app_name)
        except ValueError:
            credential = None
            if settings.firebase_service_account_json is not None:
                credential = credentials.Certificate(
                    json.loads(
                        settings.firebase_service_account_json.get_secret_value()
                    )
                )
            elif settings.google_application_credentials:
                credential = credentials.Certificate(
                    settings.google_application_credentials
                )
            app = firebase_admin.initialize_app(
                credential,
                options={"projectId": settings.firebase_project_id},
                name=_firebase_app_name,
            )
        if app.project_id != settings.firebase_project_id:
            raise ValueError("Firebase project configuration mismatch")
        return app


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="로그인이 필요합니다.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def _resolve_user(db: DbSession, token: HTTPAuthorizationCredentials) -> User:
    settings = get_settings()
    if settings.auth_mode == "dev":
        return user_repository.get_or_create_by_firebase_uid(
            db,
            firebase_uid=settings.dev_user_uid,
            email=f"{settings.dev_user_uid}@artlog.local",
            nickname="개발용 사용자",
        )
    if settings.auth_mode != "firebase":
        raise _unauthorized()
    try:
        claims = firebase_auth.verify_id_token(
            token.credentials, app=_get_firebase_app()
        )
    except (FirebaseError, GoogleAuthError, ValueError):
        # Do not log the bearer token or include SDK/credential errors in HTTP.
        raise _unauthorized() from None

    uid, email = claims.get("uid"), claims.get("email")
    if (
        not isinstance(uid, str)
        or not uid.strip()
        or len(uid) > 128
        or not isinstance(email, str)
        or not email.strip()
        or len(email) > 255
    ):
        raise _unauthorized()
    name = claims.get("name")
    nickname = (
        name.strip()
        if isinstance(name, str) and name.strip()
        else email.split("@", 1)[0]
    )
    return user_repository.get_or_create_by_firebase_uid(
        db, firebase_uid=uid, email=email, nickname=nickname[:50]
    )


def get_current_user(db: DbSession, token: BearerToken) -> User:
    if token is None:
        raise _unauthorized()
    return _resolve_user(db, token)


def get_optional_user(db: DbSession, token: BearerToken) -> User | None:
    """Anonymous when there is no token; a token that fails verification is still 401."""

    if token is None:
        return None
    return _resolve_user(db, token)


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]
