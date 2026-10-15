"""Read-only TiDB connectivity and schema check.

Run from ``backend/`` with::

    uv run python -m scripts.check_db
"""

from sqlalchemy import inspect, text

from app.db.session import engine
from app.models import Base


def main() -> None:
    expected_tables = set(Base.metadata.tables)

    with engine.connect() as connection:
        database = connection.execute(text("SELECT DATABASE()")).scalar_one()
        version = connection.execute(text("SELECT VERSION()")).scalar_one()
        actual_tables = set(inspect(connection).get_table_names())

    missing_tables = sorted(expected_tables - actual_tables)

    print("connection=OK")
    print(f"database={database}")
    print(f"version={version}")
    print(f"tables={len(actual_tables)}")
    print(f"missing={','.join(missing_tables) if missing_tables else '(none)'}")

    if missing_tables:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
