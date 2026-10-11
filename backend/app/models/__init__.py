"""Import every model so Alembic sees the complete metadata graph."""

from app.models.activity import ArtistFollow, ArtworkLike, ArtworkView
from app.models.base import EMBEDDING_DIMENSION, Base
from app.models.catalog import Artist, ArtMovement, Artwork
from app.models.document import (
    Document,
    DocumentArtist,
    DocumentArtwork,
    DocumentChunk,
    DocumentType,
)
from app.models.embedding import ArtworkEmbedding
from app.models.user import User

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
    "Document",
    "DocumentArtist",
    "DocumentArtwork",
    "DocumentChunk",
    "DocumentType",
    "User",
]
