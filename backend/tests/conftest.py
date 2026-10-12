"""Unit tests must not depend on or connect to the shared TiDB database."""

import os

# Individual tests replace DB sessions with stubs or an in-memory database.
# The engine can still be constructed during app imports without real secrets.
os.environ["TIDB_DATABASE_URL"] = "mysql+pymysql://test:test@127.0.0.1/artlog_unit"
