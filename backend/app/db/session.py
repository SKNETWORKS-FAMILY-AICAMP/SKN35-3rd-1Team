"""SQLAlchemy engine and session lifecycle for TiDB."""

from collections.abc import Generator
from typing import Annotated

from fastapi import Depends
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings

settings = get_settings()

engine = create_engine(
    settings.sqlalchemy_url,
    pool_pre_ping=True,
    pool_recycle=300,
    connect_args=settings.tidb_connect_args,
)

SessionLocal = sessionmaker(
    bind=engine,
    class_=Session,
    autoflush=False,
    expire_on_commit=False,
)


def get_db() -> Generator[Session, None, None]:
    """Yield one DB session per request.

    Commit and rollback belong to the service layer so transaction boundaries
    remain explicit.
    """

    with SessionLocal() as session:
        yield session


# Use as ``db: DbSession`` in route and dependency signatures.
DbSession = Annotated[Session, Depends(get_db)]
