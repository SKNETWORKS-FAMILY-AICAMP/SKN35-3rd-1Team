"""질문 분류(수퍼바이저) 테스트. DB·API 없이 data/processed 의 작가 별칭과 작품 목록만 쓴다."""

import json
from pathlib import Path

import pytest

from app.rag.classifier import classify, refusal_message
from scripts.preprocess import load_processed

QUESTIONS = Path(__file__).parent / "questions" / "rag-eval.json"


@pytest.mark.parametrize(("artist", "question", "kind", "reason"), [
    # 거절: 다루지 않는 작가 · 미수집 작가 · 실시간/생활 정보
    ("rembrandt", "피카소의 대표작은?", "refuse", "unknown_artist"),
    ("rembrandt", "클림트의 키스는 언제 그렸어?", "refuse", "uncollected_artist"),
    ("claude-monet", "에곤 쉴레는 어떤 화가야?", "refuse", "uncollected_artist"),
    ("claude-monet", "마네의 대표작은?", "refuse", "unknown_artist"),  # 모네와 헷갈리는 다른 화가
    ("claude-monet", "오늘 서울 날씨 알려줘", "refuse", "off_topic"),
    ("rembrandt", "이 그림을 가장 싸게 살 수 있는 사이트 찾아줘", "refuse", "off_topic"),
    ("paul-gauguin", "이 작품의 오늘 기준 시장 가격은 얼마야?", "refuse", "off_topic"),
    # 다른 수집 작가만 물음 → 그 작가 작품에서 물어보라고 안내
    ("rembrandt", "고흐 자화상은 왜 귀가 없어?", "other_artist", None),
    ("rembrandt", "카라바조는 왜 로마에서 도망쳤어?", "other_artist", None),
    # 추천
    ("rembrandt", "비슷한 작품 추천해 줘", "recommend", None),
    ("rembrandt", "이런 그림 더 보여줘", "recommend", None),
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
])
def test_ambiguous_questions_go_to_rag(artist, question):
    """애매하면 거절하지 않고 RAG 로 보낸다. RAG 쪽 프롬프트가 근거 없으면 한 번 더 거절한다."""
    assert classify(question, artist).kind == "rag"


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


def test_refusal_messages_use_natural_particles():
    assert refusal_message(classify("클림트의 키스는?", "rembrandt")).startswith("구스타프 클림트는 아직")
    assert refusal_message(classify("피카소 대표작?", "rembrandt")).startswith("피카소는 이 미술관")
    assert "작품을 고른 뒤" in refusal_message(classify("고흐는 왜 귀를 잘랐어?", "rembrandt"))
    assert refusal_message(classify("이 그림의 빛은?", "rembrandt")) == ""
