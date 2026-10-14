"""Docent chat offers to collect an artwork once the member shows interest.

Rules only (no model call), so the offer is predictable and never invents works:

- Interest: this is at least the ``MIN_QUESTIONS``-th question about the artwork
  in the conversation, and the docent actually answered (not refused).
- If the member has viewed several works by the same artist and has no
  "{artist} 모음" collection yet, offer to create it from those views.
- Otherwise, if the artwork is in none of the member's collections, offer to
  put it in one.

The offer is only a suggestion: nothing is saved until the member confirms it
through the regular collection REST calls.
"""

from sqlalchemy import select

from app.models import Collection, CollectionItem
from app.schemas.chat import ChatRequest, ChatResponse
from app.schemas.mypage import (
    CollectionAction,
    CollectionChoice,
    CollectionSuggestion,
)
from app.services import auto_collections as auto
from app.services import catalog_service

MIN_QUESTIONS = 3  # the third question about one artwork counts as interest
MIN_ARTIST_VIEWS = 3  # distinct works by one artist before offering an artist collection
MAX_CHOICES = 6


def questions_asked(body: ChatRequest) -> int:
    return 1 + sum(1 for turn in body.history if turn.role == "user")


def suggest(
    db, user_id: int | None, artwork_id: int, body: ChatRequest, response: ChatResponse
) -> CollectionSuggestion | None:
    if user_id is None or response.refused or questions_asked(body) < MIN_QUESTIONS:
        return None
    art = catalog_service.get_artwork(db, artwork_id)
    collections = db.execute(
        select(Collection.id, Collection.name)
        .where(Collection.user_id == user_id)
        .order_by(Collection.updated_at.desc(), Collection.id.desc())
    ).all()
    names = {name.casefold() for _, name in collections}

    basis = auto.Basis("artist", artist_id=art.artist_id)
    collection_name = auto.name_for(basis, art.artist_name)
    if collection_name.casefold() not in names:
        works = auto.artworks(db, user_id, basis)
        if len(works) >= MIN_ARTIST_VIEWS:
            return CollectionSuggestion(
                kind="create_from_views",
                message=(
                    f"{art.artist_name}의 작품을 {len(works)}점 감상하셨네요. "
                    f"지금까지 본 작품으로 ‘{collection_name}’ 컬렉션을 만들어 드릴까요?"
                ),
                artwork_id=artwork_id,
                proposal=CollectionAction(
                    action="create",
                    name=collection_name,
                    artwork_ids=[w.id for w in works],
                ),
                artworks=works[:MAX_CHOICES],
            )

    ids = [cid for cid, _ in collections]
    already = ids and db.scalar(
        select(CollectionItem.artwork_id).where(
            CollectionItem.collection_id.in_(ids),
            CollectionItem.artwork_id == artwork_id,
        )
    )
    if already:
        return None
    return CollectionSuggestion(
        kind="add_artwork",
        message=f"『{art.title}』에 관심이 많으시네요. 컬렉션에 담아 드릴까요?",
        artwork_id=artwork_id,
        collections=[
            CollectionChoice(id=cid, name=name) for cid, name in collections[:MAX_CHOICES]
        ],
    )
