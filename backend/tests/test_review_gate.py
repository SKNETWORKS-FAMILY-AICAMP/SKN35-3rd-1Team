"""검수 승인 전후에 검색 범위와 벡터 동기화 대상이 바뀌는지 확인한다."""

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app.repositories.document_repository import scope_document_ids
from scripts.build_chunks import load as load_reviewed_chunks
from scripts.sync_chroma import chunk_ids


def test_pending_document_is_excluded_before_and_included_after_approval():
    engine = create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(text("CREATE TABLE artworks (id INTEGER PRIMARY KEY, artist_id INTEGER)"))
        connection.execute(text("CREATE TABLE documents (id INTEGER PRIMARY KEY, doc_key TEXT, title TEXT, content TEXT, artwork_id INTEGER, needs_review BOOLEAN)"))
        connection.execute(text("CREATE TABLE document_artists (document_id INTEGER, artist_id INTEGER)"))
        connection.execute(text("CREATE TABLE document_chunks (id INTEGER PRIMARY KEY, document_id INTEGER, chunk_index INTEGER, content TEXT, embedding_model TEXT)"))
        connection.execute(text("INSERT INTO artworks VALUES (1, 10)"))
        connection.execute(text("INSERT INTO documents VALUES (1, 'schiele/approved', '승인', '본문', 1, 0), (2, 'schiele/pending', '미승인', '본문', 1, 1), (3, 'schiele/bio', '생애', '본문', NULL, 1)"))
        connection.execute(text("INSERT INTO document_artists VALUES (3, 10)"))
        connection.execute(text("INSERT INTO document_chunks VALUES (101, 1, 0, '승인 청크', 'test'), (102, 2, 0, '옛 미승인 청크', 'test'), (103, 3, 0, '옛 미승인 생애 청크', 'test')"))

    with Session(engine) as session:
        assert scope_document_ids(session, 1) == [1]
        assert [row['id'] for row in load_reviewed_chunks(session)[0]] == [1]
        assert chunk_ids(session) == {101}

        session.execute(text("UPDATE documents SET needs_review = 0 WHERE id IN (2, 3)"))
        assert scope_document_ids(session, 1) == [1, 2, 3]
        assert [row['id'] for row in load_reviewed_chunks(session)[0]] == [1, 3, 2]
        assert chunk_ids(session) == {101, 102, 103}

        session.execute(text("UPDATE documents SET needs_review = 1 WHERE id = 1"))
        assert scope_document_ids(session, 1) == [2, 3]
        assert chunk_ids(session) == {102, 103}
