"""Declarative base and shared TiDB table options."""

from sqlalchemy import MetaData
from sqlalchemy.dialects.mysql.base import ischema_names
from sqlalchemy.orm import DeclarativeBase
from tidb_vector.sqlalchemy import VectorType

# SQLAlchemy's stock MySQL dialect does not know TiDB's VECTOR(D) type when
# reflecting existing tables. Register it so Alembic autogenerate/check and
# Inspector can parse VECTOR columns instead of producing NullType.
ischema_names.setdefault("vector", VectorType)

NAMING_CONVENTION = {
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

TABLE_OPTIONS = {
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_general_ci",
}

EMBEDDING_DIMENSION = 1536


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)
