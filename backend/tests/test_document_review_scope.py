"""Review transitions using real SQL queries against an isolated SQLite DB."""

import pytest
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import Session

from app.repositories import document_repository as repo
from scripts.build_chunks import load


@pytest.fixture
def db():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def functions(connection, _):
        connection.create_function("substring_index", 3, lambda s, sep, n: s.split(sep)[0])

    schema = [
        "CREATE TABLE artworks (id INTEGER PRIMARY KEY, artist_id INTEGER)",
        "CREATE TABLE documents (id INTEGER PRIMARY KEY, doc_key TEXT, title TEXT, content TEXT, artwork_id INTEGER, needs_review BOOLEAN)",
        "CREATE TABLE document_artists (document_id INTEGER, artist_id INTEGER)",
        "CREATE TABLE document_artworks (document_id INTEGER, artwork_id INTEGER)",
        "CREATE TABLE document_chunks (id INTEGER PRIMARY KEY, document_id INTEGER, chunk_index INTEGER, content TEXT, embedding_model TEXT)",
    ]
    with engine.begin() as connection:
        for ddl in schema:
            connection.exec_driver_sql(ddl)
        connection.exec_driver_sql("INSERT INTO artworks VALUES (10, 1)")
        for i in range(1, 9):
            pending = i % 2 == 0
            body = "검수 전 인물 카사트" if pending else "승인된 본문"
            connection.execute(text("INSERT INTO documents VALUES (:id, :key, '해설', :body, :art, :pending)"),
                               {"id": i, "key": f"artist/{i}", "body": body,
                                "art": 10 if i in (1, 2, 7, 8) else None, "pending": pending})
            chunk = "해설 > 답변 시 주의\n\n" + body if i in (7, 8) else body
            connection.execute(text("INSERT INTO document_chunks VALUES (:id, :doc, 0, :body, 'test')"),
                               {"id": i * 10, "doc": i, "body": chunk})
        for i in (3, 4, 5, 6):
            connection.exec_driver_sql("INSERT INTO document_artists VALUES (?, 1)", (i,))
        for i in (5, 6):
            connection.exec_driver_sql("INSERT INTO document_artworks VALUES (?, 10)", (i,))
    with Session(engine) as session:
        yield session
    engine.dispose()


def test_unreviewed_commentary_bio_and_pins_are_excluded(db):
    scope = repo.scope_document_ids(db, 10)
    assert scope == [1, 3, 5, 7]
    assert repo.pinned_chunk_ids(db, 10, scope) == [50, 70]
    assert not repo.name_in_scope(db, scope, "카사트")
    db.execute(text("UPDATE documents SET needs_review = 0 WHERE id = 2"))
    assert 2 in repo.scope_document_ids(db, 10)
    assert repo.name_in_scope(db, repo.scope_document_ids(db, 10), "카사트")


def test_chunk_build_load_excludes_pending_documents(db):
    docs, _ = load(db)
    assert {d["id"] for d in docs} == {1, 3, 5, 7}
    db.execute(text("UPDATE documents SET needs_review = 0 WHERE id = 4"))
    docs, _ = load(db)
    assert {d["id"] for d in docs} == {1, 3, 4, 5, 7}
