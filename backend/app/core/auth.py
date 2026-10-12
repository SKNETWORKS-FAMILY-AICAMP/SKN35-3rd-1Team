"""Who is calling. Routes take ``user: CurrentUser`` (login required) or
``user: OptionalUser`` (anonymous allowed, ``None`` when no token).

Clients send ``Authorization: Bearer <Firebase ID token>``. Only this module
changes when Firebase login is added: verify the token, then call
``get_or_create_by_firebase_uid`` with the verified uid. Never read a uid from
the request body, path or query.

``AUTH_MODE=dev`` (until Firebase is wired): any bearer token is accepted and
maps to one fixed development user, so protected routes still reject requests
without a token, exactly as they will in production.
"""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import get_settings
from app.db.session import DbSession
from app.models import User
from app.repositories import user_repository

# auto_error=False: this module decides between 401 and anonymous.
bearer_scheme = HTTPBearer(auto_error=False, description="Firebase ID 토큰")
BearerToken = Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)]


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
    # TODO(Firebase 담당): firebase_admin.auth.verify_id_token(token.credentials)
    # 실패하면 _unauthorized(), 성공하면 uid·email·name으로 get_or_create_by_firebase_uid.
    raise _unauthorized()


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
