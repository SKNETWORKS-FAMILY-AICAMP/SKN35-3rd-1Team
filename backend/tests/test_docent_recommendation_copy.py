"""Approved recommendation wording follows the correct recommendation source."""

from types import SimpleNamespace

from app.schemas.chat import ChatRequest
from app.services import docent_service as docent


def _setup(monkeypatch, route_kind, similar=(), personal=()):
    monkeypatch.setattr(
        docent.catalog_service,
        "get_artwork",
        lambda *args: SimpleNamespace(title="현재 작품", artist_name="작가"),
    )
    monkeypatch.setattr(
        docent, "classify_artwork", lambda *args: SimpleNamespace(kind=route_kind)
    )
    monkeypatch.setattr(docent.docent_scope, "is_artwork_request", lambda *args: True)
    monkeypatch.setattr(
        docent.recommendation_service,
        "similar",
        lambda *args, **kwargs: list(similar),
    )
    monkeypatch.setattr(
        docent.recommendation_service,
        "recommend_artworks",
        lambda *args, **kwargs: list(personal),
    )


def test_similar_recommendation_and_no_result(monkeypatch):
    _setup(
        monkeypatch,
        "recommend_similar",
        similar=[SimpleNamespace(title="닮은 작품")],
    )
    response = docent.answer(None, 1, ChatRequest(question="비슷한 작품 추천해 줘"))
    assert response.answer == "이 작품과 비슷한 결을 가진 작품을 더 둘러보세요. 『닮은 작품』"
    assert not response.refused and response.sources == []

    _setup(monkeypatch, "recommend_similar")
    response = docent.answer(None, 1, ChatRequest(question="비슷한 작품 추천해 줘"))
    assert response.answer == "현재 이 작품과 유사한 작품 정보가 아직 준비되지 않았어요."


def test_personal_recommendation_includes_only_available_reasons(monkeypatch):
    _setup(
        monkeypatch,
        "recommend_personal",
        personal=[
            SimpleNamespace(title="작품 A", reason="최근 본 작품과 비슷해서"),
            SimpleNamespace(title="작품 B", reason=None),
        ],
    )
    response = docent.answer(None, 1, ChatRequest(question="내 취향에 맞는 작품"), user_id=4)
    assert response.answer == (
        "이런 작품은 어떠신가요? 『작품 A』 — 최근 본 작품과 비슷해서 · 『작품 B』"
    )

    _setup(monkeypatch, "recommend_personal")
    empty = docent.answer(None, 1, ChatRequest(question="내 취향에 맞는 작품"), user_id=4)
    assert empty.answer == "아직 충분한 취향 데이터가 쌓이지 않았어요."


def test_anonymous_personal_request_uses_current_artwork_similarity(monkeypatch):
    _setup(
        monkeypatch,
        "recommend_personal",
        similar=[SimpleNamespace(title="비슷한 작품")],
    )
    response = docent.answer(None, 1, ChatRequest(question="내 취향에 맞는 작품"))
    assert response.answer == (
        "로그인 후 감상 기록이 쌓이면 더 정교한 추천을 받아볼 수 있어요. "
        "현재 작품과 비슷한 작품을 먼저 만나보세요. 『비슷한 작품』"
    )

    _setup(monkeypatch, "recommend_personal")
    empty = docent.answer(None, 1, ChatRequest(question="내 취향에 맞는 작품"))
    assert empty.answer == (
        "로그인 후 감상 기록이 쌓이면 더 정교한 추천을 받아볼 수 있어요. "
        "현재 이 작품과 유사한 작품 정보가 아직 준비되지 않았어요."
    )
