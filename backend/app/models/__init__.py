"""Import every model so Alembic sees the complete metadata graph."""

from app.models.activity import ArtistFollow, ArtworkLike, ArtworkView, UserFollow
from app.models.base import EMBEDDING_DIMENSION, Base
from app.models.catalog import Artist, ArtMovement, Artwork
from app.models.chat import ChatMessage, ChatRole, ChatSession
from app.models.collection import Collection, CollectionItem
from app.models.diary import DiaryEntry
from app.models.document import (
    Document,
    DocumentArtist,
    DocumentArtwork,
    DocumentBasis,
    DocumentChunk,
    DocumentType,
)
from app.models.embedding import ArtworkEmbedding
from app.models.theme_collection import ThemeCollectionCache
from app.models.user import User
from app.models.user_profile import SocialAccount, UserPreference

__all__ = [
    "EMBEDDING_DIMENSION",
    "ArtMovement",
    "Artist",
    "ArtistFollow",
    "Artwork",
    "ArtworkEmbedding",
    "ArtworkLike",
    "ArtworkView",
    "Base",
    "ChatMessage",
    "ChatRole",
    "ChatSession",
    "Collection",
    "CollectionItem",
    "DiaryEntry",
    "Document",
    "DocumentArtist",
    "DocumentArtwork",
    "DocumentBasis",
    "DocumentChunk",
    "DocumentType",
    "SocialAccount",
    "ThemeCollectionCache",
    "User",
    "UserFollow",
    "UserPreference",
]
