"""Docent chat request/response and saved chat history.

Context for the answer always comes from the request ``history`` (the client
keeps the conversation, anonymous or not). For a logged-in user the server
also stores each question and answer so the conversation can be restored.
"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.catalog import ArtworkCard
from app.schemas.mypage import CollectionSuggestion

ChatRoleName = Literal["user", "assistant"]
DocType = Literal["artist_bio", "artwork_commentary", "artist_comparison"]


class ChatTurn(BaseModel):
    role: ChatRoleName
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=500)
    # The client sends at most the last 12 messages.
    history: list[ChatTurn] = Field(default_factory=list, max_length=12)
    # Tab chosen above the chat. None keeps the account's saved preference.
    explanation_style: Literal["easy", "standard", "deep"] | None = None


class BasisSource(BaseModel):
    """Source used to support an appended editorial note or correction."""

    source_name: str | None = None
    source_url: str | None = None


class Source(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    document_id: int
    title: str
    doc_type: DocType
    source_name: str | None
    source_url: str | None
    license: str | None
    basis_sources: list[BasisSource] = Field(default_factory=list)


class ChatResponse(BaseModel):
    answer: str
    # True when the question is outside the documents for this artwork.
    refused: bool
    sources: list[Source]
    # Offer to collect the artwork once the member keeps asking about it. Not saved.
    suggestion: CollectionSuggestion | None = None


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    role: ChatRoleName
    content: str
    refused: bool
    # Empty for questions.
    sources: list[Source]
    created_at: datetime


class ChatSummary(BaseModel):
    artwork: ArtworkCard
    # Preview of the latest message.
    last_message: str
    updated_at: datetime
