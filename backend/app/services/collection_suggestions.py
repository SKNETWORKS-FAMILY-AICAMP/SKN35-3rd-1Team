"""Docent chat offers to collect an artwork once the member shows interest.

Rules only (no model call), so the offer is predictable and never invents works:

- Interest: this is at least the ``MIN_QUESTIONS``-th substantive question
  about the artwork, and the docent actually answered (not refused).
  Wording corrections and unrelated chatter do not count as interest.
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
from app.services.docent_grounding import is_non_engagement_question

MIN_QUESTIONS = 3  # the third question about one artwork counts as interest
MAX_CHOICES = 6


def first_interest(db, user_id: int, artwork_id: int) -> bool:
    """Offer only on the first answered, substantive question from the third on.

    The saved conversation is authoritative: the client history can be missing
    or edited, and the current exchange has already been persisted by the route.
    """
    session_id = chat_repository.get_session_id(
        db, user_id=user_id, artwork_id=artwork_id
    )
    if session_id is None:
        return False
    messages = db.scalars(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.id)
    ).all()
    if not messages:
        return False
    questions = 0
    substantive = False
    for message in messages:
        if message.role == ChatRole.USER:
            substantive = not is_non_engagement_question(message.content)
            if substantive:
                questions += 1
        elif (
            message.role == ChatRole.ASSISTANT
            and substantive
            and questions >= MIN_QUESTIONS
            and not message.refused
        ):
            return message.id == messages[-1].id
    return False


def suggest(
    db, user_id: int | None, artwork_id: int, body: ChatRequest, response: ChatResponse
) -> CollectionSuggestion | None:
    if (
        user_id is None
        or response.refused
        or is_non_engagement_question(body.question)
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
