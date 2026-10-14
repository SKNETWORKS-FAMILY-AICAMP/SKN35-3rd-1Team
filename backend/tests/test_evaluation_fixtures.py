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


def test_prompt_accuracy_cases_are_distinct_and_grounded_in_local_fixtures() -> None:
    fixture = load_json("questions/prompt-accuracy.json")
    cases = fixture["cases"]
    rag_ids = {case["id"] for case in load_json("questions/rag-eval.json")["cases"]}
    document_lines = (ROOT.parents[1] / "data/processed/documents.jsonl").read_text(
        encoding="utf-8"
    ).splitlines()
    documents = {
        document["doc_key"]: document
        for document in (json.loads(line) for line in document_lines)
    }

    assert fixture["version"] == 1
    assert len(cases) == 9
    assert {case["id"] for case in cases} == {
        f"prompt-{number:03d}" for number in range(1, 10)
    }
    assert not ({case["id"] for case in cases} & rag_ids)
    assert {case["category"] for case in cases} == {
        "insufficient_evidence",
        "partial_evidence",
        "variant_identity",
        "correction_priority",
        "editorial_attribution",
        "source_integrity",
        "copy_limit",
        "multi_turn_correction",
    }

    required_fields = {
        "id",
        "category",
        "artwork_slug",
        "question",
        "history",
        "target_doc_keys",
        "required_context",
        "expected_refused",
        "pass_conditions",
        "failure_signals",
    }
    for case in cases:
        assert set(case) == required_fields
        assert case["artwork_slug"] and case["question"]
        assert type(case["expected_refused"]) is bool
        assert case["target_doc_keys"] and case["required_context"]
        assert case["pass_conditions"] and case["failure_signals"]
        assert all(
            isinstance(item, str) and item.strip()
            for field in ("required_context", "pass_conditions", "failure_signals")
            for item in case[field]
        )
        assert isinstance(case["history"], list)
        assert all(
            set(turn) == {"role", "content"}
            and turn["role"] in {"user", "assistant"}
            and isinstance(turn["content"], str)
            and turn["content"].strip()
            for turn in case["history"]
        )
        assert bool(case["history"]) == (case["category"] == "multi_turn_correction")
        assert all(doc_key in documents for doc_key in case["target_doc_keys"])
        target_documents = [documents[key] for key in case["target_doc_keys"]]
        assert all(
            document["artwork_slug"] == case["artwork_slug"]
            and document["needs_review"] is False
            for document in target_documents
        )
        reference_text = "\n".join(document["content"] for document in target_documents)
        assert all(fragment in reference_text for fragment in case["required_context"])


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
        "license",
        "basis_sources",
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
