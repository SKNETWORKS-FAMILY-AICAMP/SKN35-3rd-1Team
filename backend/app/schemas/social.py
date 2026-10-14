"""Public member profiles and member follows. Only opaque public ids leave the server."""

from pydantic import BaseModel, ConfigDict


class MemberCard(BaseModel):
    id: str
    nickname: str


class MemberProfile(MemberCard):
    # AI one-line introduction from the member's public impressions and likes.
    intro: str | None = None
    # None when the member hides follow lists from other users.
    follower_count: int | None = None
    following_count: int | None = None
    follow_list_public: bool
    is_following: bool = False
    is_me: bool = False


class SocialSettings(BaseModel):
    model_config = ConfigDict(extra="forbid")
    follow_list_public: bool
