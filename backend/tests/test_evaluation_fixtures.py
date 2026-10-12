import json
from pathlib import Path


ROOT = Path(__file__).parent


def load_json(relative_path: str) -> dict:
    return json.loads((ROOT / relative_path).read_text(encoding="utf-8"))


def test_rag_eval_set_has_30_well_formed_cases() -> None:
    cases = load_json("questions/rag-eval.json")["cases"]

    assert len(cases) == 30
    assert len({case["id"] for case in cases}) == len(cases)
    assert {case["category"] for case in cases} == {
        "factual",
        "detail_interpretation",
        "comparison",
        "out_of_scope",
        "insufficient_evidence",
        "multi_turn",
    }

    for case in cases:
        expected = case["expected"]
        assert case["artwork_slug"]
        assert case["question"]
        assert isinstance(case["history"], list)
        assert isinstance(expected["refused"], bool)
        assert isinstance(expected["required_keywords"], list)
        assert isinstance(expected["target_doc_keys"], list)
        assert isinstance(expected["source_required"], bool)
        assert isinstance(expected["forbidden_claims"], list)
        assert not expected["source_required"] or not expected["refused"]


def test_fake_chat_responses_follow_the_planned_contract() -> None:
    responses = load_json("fixtures/chat-responses.json")

    for response in responses.values():
        assert set(response) == {"answer", "refused", "sources"}
        assert response["answer"]
        assert isinstance(response["refused"], bool)
        assert isinstance(response["sources"], list)

    assert responses["supported"]["sources"]
    assert responses["refused"]["sources"] == []

    required_source_fields = {
        "document_id",
        "title",
        "doc_type",
        "source_name",
        "source_url",
    }
    assert all(
        set(source) == required_source_fields
        for source in responses["supported"]["sources"]
    )


def test_activity_contract_cases_are_unique_and_cover_all_features() -> None:
    cases = load_json("contracts/activity-cases.json")["cases"]

    assert len({case["id"] for case in cases}) == len(cases)
    assert {case["feature"] for case in cases} == {
        "like",
        "follow",
        "view",
        "authorization",
    }
    assert all(case["scenario"] and case["expected"] for case in cases)
