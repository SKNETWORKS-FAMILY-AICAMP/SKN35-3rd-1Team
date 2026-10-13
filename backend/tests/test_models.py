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
    "chat_sessions",
    "chat_messages",
    "social_accounts",
    "user_preferences",
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


def test_one_chat_session_per_user_and_artwork() -> None:
    unique_columns = {
        tuple(column.name for column in constraint.columns)
        for constraint in Base.metadata.tables["chat_sessions"].constraints
        if constraint.__class__.__name__ == "UniqueConstraint"
    }
    assert ("user_id", "artwork_id") in unique_columns


def test_users_are_keyed_by_firebase_uid() -> None:
    users = Base.metadata.tables["users"]
    assert users.c.firebase_uid.unique
    assert "password_hash" not in users.c


def test_social_accounts_have_provider_identity_unique_constraint() -> None:
    social_accounts = Base.metadata.tables["social_accounts"]
    unique_columns = {
        tuple(column.name for column in constraint.columns)
        for constraint in social_accounts.constraints
        if constraint.__class__.__name__ == "UniqueConstraint"
    }
    assert ("provider", "provider_user_id") in unique_columns


def test_user_preferences_are_one_to_one_with_users() -> None:
    user_preferences = Base.metadata.tables["user_preferences"]
    assert [column.name for column in user_preferences.primary_key] == ["user_id"]
    assert user_preferences.c.birth_year.nullable
    assert user_preferences.c.gender.nullable


def test_every_foreign_key_has_an_on_delete_policy() -> None:
    foreign_keys = {
        foreign_key
        for table in Base.metadata.tables.values()
        for foreign_key in table.foreign_keys
    }
    assert foreign_keys
    assert all(foreign_key.ondelete for foreign_key in foreign_keys)
