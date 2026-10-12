"""Model metadata tests that do not require a live TiDB connection."""

from sqlalchemy.orm import configure_mappers

from app.models import Base

EXPECTED_TABLES = {
    "users",
    "art_movements",
    "artists",
    "artworks",
    "artwork_embeddings",
    "documents",
    "document_artists",
    "document_artworks",
    "document_basis_documents",
    "document_chunks",
    "artwork_likes",
    "artist_follows",
    "artwork_views",
}


def test_all_erd_tables_are_registered() -> None:
    assert set(Base.metadata.tables) == EXPECTED_TABLES


def test_relationship_mappers_configure() -> None:
    configure_mappers()


def test_activity_primary_keys_match_the_erd() -> None:
    assert [
        column.name for column in Base.metadata.tables["artwork_likes"].primary_key
    ] == [
        "user_id",
        "artwork_id",
    ]
    assert [
        column.name for column in Base.metadata.tables["artist_follows"].primary_key
    ] == [
        "user_id",
        "artist_id",
    ]
    assert [
        column.name for column in Base.metadata.tables["artwork_views"].primary_key
    ] == [
        "user_id",
        "viewed_on",
        "artwork_id",
    ]


def test_every_foreign_key_has_an_on_delete_policy() -> None:
    foreign_keys = {
        foreign_key
        for table in Base.metadata.tables.values()
        for foreign_key in table.foreign_keys
    }
    assert foreign_keys
    assert all(foreign_key.ondelete for foreign_key in foreign_keys)
