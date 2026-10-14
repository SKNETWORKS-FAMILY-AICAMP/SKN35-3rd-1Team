"""질문 분류(수퍼바이저) 테스트. DB·API 없이 data/processed 의 작가 별칭과 작품 목록만 쓴다."""

import json
from pathlib import Path

import pytest

from app.rag.classifier import Route, classify, refusal_message
from scripts.preprocess import load_processed

QUESTIONS = Path(__file__).parent / "questions" / "rag-eval.json"


@pytest.mark.parametrize(("artist", "question", "kind", "reason"), [
    # 거절: 다루지 않는 작가 · 미수집 작가 · 실시간/생활 정보
    ("rembrandt", "피카소의 대표작은?", "refuse", "unknown_artist"),
    ("rembrandt", "클림트의 키스는 언제 그렸어?", "other_artist", None),
    ("claude-monet", "에곤 쉴레는 어떤 화가야?", "other_artist", None),
    ("claude-monet", "마네의 대표작은?", "refuse", "unknown_artist"),  # 모네와 헷갈리는 다른 화가
    ("claude-monet", "오늘 서울 날씨 알려줘", "refuse", "off_topic"),
    ("rembrandt", "이 그림을 가장 싸게 살 수 있는 사이트 찾아줘", "refuse", "off_topic"),
    ("paul-gauguin", "이 작품의 오늘 기준 시장 가격은 얼마야?", "refuse", "off_topic"),
    # 다른 수집 작가만 물음 → 그 작가 작품에서 물어보라고 안내
    ("rembrandt", "고흐 자화상은 왜 귀가 없어?", "other_artist", None),
    ("rembrandt", "카라바조는 왜 로마에서 도망쳤어?", "other_artist", None),
    # 추천
    ("rembrandt", "비슷한 작품 추천해 줘", "recommend_similar", None),
    ("rembrandt", "이 작품과 비슷한 그림 보여줘", "recommend_similar", None),
    ("rembrandt", "이런 그림 더 보여줘", "recommend_similar", None),
    ("claude-monet", "내 취향에 맞는 작품 추천해 줘", "recommend_personal", None),
    ("claude-monet", "내가 좋아할 만한 그림 있어?", "recommend_personal", None),
    ("claude-monet", "나한테 맞는 작품 골라줘", "recommend_personal", None),
    ("claude-monet", "좋아요 누른 작품이랑 비슷한 거 추천해 줘", "recommend_personal", None),
])
def test_clear_cases(artist, question, kind, reason):
    route = classify(question, artist)
    assert (route.kind, route.reason) == (kind, reason)


@pytest.mark.parametrize(("artist", "question"), [
    ("caravaggio", "렘브란트와 카라바조의 명암 표현은 어떻게 달라?"),  # 고른 작가 포함
    ("rembrandt", "카라바조와 비교하면 명암이 어떻게 달라?"),  # 다른 작가지만 비교 → 비교 문서
    ("paul-cezanne", "피사로와는 어떤 관계였어?"),  # 범위 밖 작가지만 관계 → 세잔 생애에 있음
    ("claude-monet", "마네랑 모네는 어떻게 달라?"),
    ("caravaggio", "레오나르도 다 빈치의 영향을 받았어?"),
    ("rembrandt", "이 그림에 피카소가 영향을 받았어?"),  # 고른 작품을 가리킴
    ("caravaggio", "미켈란젤로 메리시가 누구야?"),  # 카라바조의 본명. 미켈란젤로 부오나로티가 아님
    ("rembrandt", "마네킹처럼 서 있는 사람은 누구야?"),  # '마네'가 낱말 일부
    ("vincent-van-gogh", "테오는 어떤 사람이었어?"),  # 동생. 화가 이름으로 잡지 않음
    ("jeong-seon", "겸재는 금강산을 몇 번 갔어?"),
    ("paul-cezanne", "이 그림은 경매에서 얼마에 팔렸어?"),  # 과거 거래 기록은 문서에 있을 수 있음
    ("rembrandt", "이 그림과 비슷한 시기에 그린 작품은?"),  # '비슷한 시기' 는 추천이 아님
    ("rembrandt", "그 작품에서 빛은 어디서 와?"),
    # 팀 확인 요청 (연주님): 애매한 질문은 rag 로
    ("rembrandt", "그 사람은?"),
    ("rembrandt", "이 작가의 다른 작품은?"),
    ("vincent-van-gogh", "렘브란트와 카라바조는 어떻게 달라?"),
])
def test_ambiguous_questions_go_to_rag(artist, question):
    """애매하면 거절하지 않고 RAG 로 보낸다. RAG 쪽 프롬프트가 근거 없으면 한 번 더 거절한다."""
    assert classify(question, artist).kind == "rag"


@pytest.mark.parametrize(("artist", "question", "kind", "expect"), [
    # 모네 ↔ 마네: 다른 화가. 마네만 물으면 범위 밖, 같이 나오면 비교로 rag
    ("claude-monet", "마네는 어떤 화가야?", "refuse", ()),
    ("claude-monet", "Manet painted what?", "refuse", ()),
    ("claude-monet", "모네가 마네랑 헷갈려", "rag", ("claude-monet",)),
    ("claude-monet", "Monet의 수련은 몇 점이야?", "rag", ("claude-monet",)),
    ("rembrandt", "모네의 수련은 몇 점이야?", "other_artist", ("claude-monet",)),
    ("rembrandt", "마네킹처럼 서 있는 사람은 누구야?", "rag", ()),
    # 정선 ↔ 강원도 정선 (지명)
    ("rembrandt", "정선의 대표작은?", "other_artist", ("jeong-seon",)),
    ("rembrandt", "강원도 정선은 어디야?", "rag", ()),
    ("rembrandt", "정선군에 가 볼 만한 곳은?", "rag", ()),
    # 카라바조 본명 미켈란젤로 메리시 ↔ 미켈란젤로 부오나로티
    ("rembrandt", "미켈란젤로 메리시가 누구야?", "other_artist", ("caravaggio",)),
    ("rembrandt", "미켈란젤로 부오나로티는 누구야?", "refuse", ()),
    # 단원 김홍도 ↔ 단원고·단원구 (지명)
    ("rembrandt", "단원 김홍도의 씨름은?", "other_artist", ("kim-hong-do",)),
    ("kim-hong-do", "단원고는 어디 있어?", "rag", ()),
    # 빈센트 반 고흐 ↔ 테오 반 고흐 (동생)
    ("rembrandt", "테오 반 고흐는 누구야?", "rag", ()),
    ("rembrandt", "반 고흐의 해바라기는?", "other_artist", ("vincent-van-gogh",)),
    # 표기 흔들림도 같은 작가로
    ("rembrandt", "세잔느의 사과는?", "other_artist", ("paul-cezanne",)),
    ("rembrandt", "에곤 쉴레는 어떤 화가야?", "other_artist", ("egon-schiele",)),
])
def test_confusable_names(artist, question, kind, expect):
    route = classify(question, artist)
    assert route.kind == kind, route
    assert route.artists == expect


def test_out_of_scope_name_found_in_scope_documents_goes_to_rag():
    """세잔 『현대의 올랭피아』에서 "마네의 올랭피아를 패러디한 거야?" — 범위 밖 작가지만 세잔 문서에 마네가 나온다."""
    question = "마네의 올랭피아를 패러디한 거야?"
    assert classify(question, "paul-cezanne").kind == "refuse"  # 문서 확인 없이 이름만 보면 거절
    route = classify(question, "paul-cezanne", named_in_scope=lambda name: name == "마네")
    assert route.kind == "rag" and route.names == ("마네",)
    assert classify("마네의 대표작은?", "rembrandt", named_in_scope=lambda name: False).kind == "refuse"
    assert classify("클림트의 키스는?", "rembrandt", named_in_scope=lambda name: False).kind == "other_artist"
def test_eval_set_never_refuses_answerable_questions():
    """E 평가셋 30문항: 답해야 할 질문은 하나도 막지 않고, 막은 질문은 모두 거절 기대 질문이어야 한다."""
    artist_of = {w["slug"]: w["artist_slug"] for w in load_processed("artworks.jsonl")}
    cases = json.loads(QUESTIONS.read_text(encoding="utf-8"))["cases"]
    for case in cases:
        route = classify(case["question"], artist_of[case["artwork_slug"]])
        if not case["expected"]["refused"]:
            assert route.kind == "rag", (case["id"], route)
        if route.kind == "refuse":
            assert case["expected"]["refused"], case["id"]
    blocked = {c["id"] for c in cases if classify(c["question"], artist_of[c["artwork_slug"]]).kind == "refuse"}
    assert {"scope-001", "scope-002", "scope-003", "evidence-003"} <= blocked


def test_refusal_messages_use_approved_copy():
    assert refusal_message(classify("클림트의 키스는?", "rembrandt")) == (
        "구스타프 클림트의 작품을 선택하면 해당 작가에 관해 대화할 수 있어요."
    )
    assert refusal_message(classify("피카소 대표작?", "rembrandt")) == (
        "현재 피카소의 자료는 검토 중에 있어요."
    )
    assert "작품을 선택하면" in refusal_message(classify("고흐는 왜 귀를 잘랐어?", "rembrandt"))
    assert refusal_message(classify("이 그림의 빛은?", "rembrandt")) == ""


def test_off_topic_uses_approved_message():
    assert refusal_message(classify("오늘 날씨 알려줘", "rembrandt")) == (
        "해당 작품과 작가에 대해서만 대화 할 수 있어요."
    )


def test_uncollected_artist_uses_approved_message():
    route = Route("refuse", "uncollected_artist", names=("새 작가",))
    assert refusal_message(route) == "새 작가에 관한 자료는 준비 중 입니다."


def test_pending_artist_message_explains_review(monkeypatch):
    # This branch must remain covered even after all current artists are approved.
    from app.rag import classifier

    pending = classifier._Artist(
        "gustav-klimt", "구스타프 클림트", False, ("클림트",), (), True
    )
    monkeypatch.setattr(classifier, "_artists", lambda: {pending.slug: pending})
    monkeypatch.setattr(classifier, "_alias_index", lambda: (("클림트", pending),))
    route = classify("클림트의 키스는 언제 그렸어?", "rembrandt")
    assert route.reason == "unreviewed_artist"
    assert refusal_message(route) == "현재 구스타프 클림트 작가의 자료는 검토 중에 있어요."


def test_approved_artist_is_routed_as_other_artist():
    route = classify("클림트의 키스는 언제 그렸어?", "rembrandt")
    assert route.kind == "other_artist"
    assert route.artists == ("gustav-klimt",)
    assert "작품을 선택하면" in refusal_message(route)


@pytest.mark.parametrize(("question", "covered", "kind"), [
    ("모네와 세잔은 자연을 표현하는 방식이 어떻게 달라?", False, "refuse"),  # 평가 compare-002
    ("모네와 세잔은 자연을 표현하는 방식이 어떻게 달라?", True, "rag"),  # 두 작가를 다룬 비교 문서가 있으면 답한다
    ("세잔과는 어떤 관계였어?", False, "rag"),  # 관계·영향은 고른 작가 생애 문서로 답할 수 있다
    ("이 그림의 빛은 어디서 와?", False, "rag"),
])
def test_comparison_needs_a_document_covering_the_other_artist(monkeypatch, question, covered, kind):
    from app.rag import classifier
    from app.repositories import document_repository as repo

    asked = []
    monkeypatch.setattr(repo, "artwork_artist_slug", lambda s, a: "claude-monet")
    monkeypatch.setattr(repo, "scope_document_ids", lambda s, a: [1, 2])
    monkeypatch.setattr(repo, "comparison_covers", lambda s, ids, slugs: asked.append(slugs) or covered)
    route = classifier.classify_artwork(None, 1, question)
    assert route.kind == kind
    if kind == "refuse":
        assert asked == [("paul-cezanne",)] and route.reason == "no_comparison_source"
        assert refusal_message(route) == (
            "검수된 자료로는 폴 세잔 작가와의 비교를 확인하기 어려워요. 지금 작품과 작가에 대해 물어봐 주세요."
        )
