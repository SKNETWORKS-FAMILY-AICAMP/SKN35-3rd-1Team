"""Recommendation items: the usual card plus an optional human-readable reason.

Flat (not wrapped) so clients can read them exactly like ordinary cards.
"""

from app.schemas.catalog import ArtistCard, ArtworkCard


class RecommendedArtwork(ArtworkCard):
    # e.g. "『별이 빛나는 밤』을 좋아해서"; None for curated fallbacks.
    reason: str | None


class RecommendedArtist(ArtistCard):
    reason: str | None
