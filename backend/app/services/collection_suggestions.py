"""Docent chat offers to collect an artwork once the member shows interest.

Rules only (no model call), so the offer is predictable and never invents works:

- Interest: this is at least the ``MIN_QUESTIONS``-th question about the artwork
  in the conversation, and the docent actually answered (not refused).
- Once per conversation: only the first such answer offers. It is read from the
  stored conversation (already holding this exchange), so reloading or restoring
  the chat does not bring the offer back; resetting the chat starts over.
- If the artwork is in none of the member's collections, offer to put it in
  one. (Artist collections are no longer offered: collections follow moods.)

The offer is only a suggestion: nothing is saved until the member confirms it
through the regular collection REST calls.
"""

from sqlalchemy import select

from app.models import ChatMessage, ChatRole, Collection, CollectionItem
from app.repositories import chat_repository
from app.schemas.chat import ChatRequest, ChatResponse
from app.schemas.mypage import (
    CollectionChoice,
    CollectionSuggestion,
)
from app.services import catalog_service

MIN_QUESTIONS = 3  # the third question about one artwork counts as interest
MAX_CHOICES = 6


def first_interest(db, user_id: int, artwork_id: int) -> bool:
    """True only for the conversation's first answered question from the third on."""
    session_id = chat_repository.get_session_id(
        db, user_id=user_id, artwork_id=artwork_id
    )
    if session_id is None:
        return False
    refused = db.scalars(
        select(ChatMessage.refused)
        .where(
            ChatMessage.session_id == session_id,
            ChatMessage.role == ChatRole.ASSISTANT,
        )
        .order_by(ChatMessage.id)
    ).all()
    eligible = [i for i, r in enumerate(refused, 1) if i >= MIN_QUESTIONS and not r]
    return eligible[:1] == [len(refused)]


def suggest(
    db, user_id: int | None, artwork_id: int, body: ChatRequest, response: ChatResponse
) -> CollectionSuggestion | None:
    if (
        user_id is None
        or response.refused
        or not first_interest(db, user_id, artwork_id)
    ):
        return None
    art = catalog_service.get_artwork(db, artwork_id)
    collections = db.execute(
        select(Collection.id, Collection.name)
        .where(Collection.user_id == user_id)
        .order_by(Collection.updated_at.desc(), Collection.id.desc())
    ).all()
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
