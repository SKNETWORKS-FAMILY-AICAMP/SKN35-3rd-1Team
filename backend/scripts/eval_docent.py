"""Capture real docent answers for the 30 general and 9 accuracy review cases.

Run from backend/ with configured TiDB, Chroma, embeddings, and OpenAI access::

    python -m scripts.eval_docent --out ../docs/eval-runs/2026-10-14

The script records evidence and automatic contract checks. A human must judge
each answer against pass_conditions and failure_signals before reporting a
quality pass rate.
"""

import argparse
import hashlib
import json
import subprocess
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import select

from app.core.config import get_settings
from app.docent import service as docent_service
from app.models import Artwork
from app.rag.prompts import PROMPT_VERSION
from app.rag.retriever import COMPARISON_K, OWN_K, TOP_K
from app.schemas.chat import ChatRequest

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parent
GENERAL = ROOT / "tests/questions/rag-eval.json"
ACCURACY = ROOT / "tests/questions/prompt-accuracy.json"
DATA_SUCCESS = PROJECT / "data/processed/_SUCCESS.json"


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _cases(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))["cases"]


def _topics(keys: set[str]) -> set[str]:
    return {key.removesuffix(".en") for key in keys}


def evaluate(session, cases: list[dict]) -> list[dict]:
    slugs = {case["artwork_slug"] for case in cases}
    artwork_ids = dict(
        session.execute(select(Artwork.slug, Artwork.id).where(Artwork.slug.in_(slugs))).all()
    )
    rows = []
    for case in cases:
        row = {
            "case_id": case["id"],
            "category": case["category"],
            "artwork_slug": case["artwork_slug"],
            "question": case["question"],
            "history": case.get("history", []),
            "expected": case.get("expected", {"refused": case.get("expected_refused")}),
            "pass_conditions": case.get("pass_conditions", []),
            "failure_signals": case.get("failure_signals", []),
            "retrieved": [],
            "model_input": None,
            "model_output": None,
            "response": None,
            "automatic": {},
            "human_review": None,
        }
        artwork_id = artwork_ids.get(case["artwork_slug"])
        if artwork_id is None:
            row["setup_error"] = "작품 slug를 DB에서 찾지 못했습니다."
            rows.append(row)
            continue
        original_retrieve = docent_service.retrieve
        original_generate = docent_service.generate

        def capture_retrieve(*args, _original=original_retrieve, _row=row, **kwargs):
            docs = _original(*args, **kwargs)
            _row["retrieved"] = [
                {"metadata": doc.metadata, "text": doc.page_content} for doc in docs
            ]
            return docs

        def capture_generate(schema, instruction, data, _original=original_generate, _row=row):
            _row["model_input"] = {"system": instruction, "data": data}
            draft = _original(schema, instruction, data)
            _row["model_output"] = draft.model_dump(mode="json")
            return draft

        docent_service.retrieve = capture_retrieve
        docent_service.generate = capture_generate
        try:
            response = docent_service.answer(
                session, artwork_id, ChatRequest.model_validate(case)
            )
            row["response"] = response.model_dump(mode="json")
            expected_refused = row["expected"]["refused"]
            retrieved_ids = {
                doc["metadata"]["document_id"] for doc in row["retrieved"]
            }
            returned_ids = {source.document_id for source in response.sources}
            target_keys = set(
                case.get("target_doc_keys")
                or row["expected"].get("target_doc_keys")
                or []
            )
            retrieved_keys = {
                doc["metadata"].get("doc_key") for doc in row["retrieved"]
                if doc["metadata"].get("doc_key")
            }
            delivered_text = "\n".join(
                source["text"] for source in (row["model_input"] or {}).get("data", {}).get("sources", [])
            )
            required_context = case.get("required_context") or []
            row["automatic"] = {
                "refused_matches": response.refused == expected_refused,
                "source_ids_in_retrieval": returned_ids <= retrieved_ids,
                "source_required_satisfied": bool(returned_ids)
                if row["expected"].get("source_required")
                else True,
                "target_evidence_retrieved": bool(_topics(target_keys) & _topics(retrieved_keys))
                if target_keys
                else None,
                "required_context_delivered": all(
                    phrase in delivered_text for phrase in required_context
                ) if required_context else None,
            }
        except Exception as exc:  # noqa: BLE001 - retain the remaining evaluation cases
            row["execution_error"] = type(exc).__name__
            session.rollback()
        finally:
            docent_service.retrieve = original_retrieve
            docent_service.generate = original_generate
        rows.append(row)
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    settings = get_settings()
    if settings.openai_api_key is None:
        parser.error("OPENAI_API_KEY가 없어 실제 도슨트 평가를 실행할 수 없습니다.")

    from app.db.session import SessionLocal

    cases = _cases(GENERAL) + _cases(ACCURACY)
    with SessionLocal() as session:
        rows = evaluate(session, cases)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "cases.jsonl").write_text(
        "".join(json.dumps(row, ensure_ascii=False, default=str) + "\n" for row in rows),
        encoding="utf-8",
    )
    instruction = docent_service.instructions(None, None)
    (args.out / "system-prompt.txt").write_text(instruction, encoding="utf-8")
    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=PROJECT, capture_output=True, text=True, check=False
    )
    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=PROJECT, capture_output=True, text=True, check=False
    )
    manifest = {
        "ran_at_utc": datetime.now(UTC).isoformat(),
        "git_commit": commit.stdout.strip() if commit.returncode == 0 else None,
        "working_tree_dirty": bool(status.stdout.strip()) if status.returncode == 0 else None,
        "prompt_version": PROMPT_VERSION,
        "prompt_sha256": hashlib.sha256(instruction.encode()).hexdigest(),
        "model": settings.assistant_model,
        "generation_temperature": 0.3,
        "embedding_model": settings.embedding_model,
        "chroma_chunks_collection": settings.chroma_chunks_collection,
        "retrieval": {"top_k": TOP_K, "own_k": OWN_K, "comparison_k": COMPARISON_K},
        "data_success_sha256": _digest(DATA_SUCCESS) if DATA_SUCCESS.exists() else None,
        "question_sha256": {"general": _digest(GENERAL), "accuracy": _digest(ACCURACY)},
        "case_count": len(rows),
        "execution_errors": sum("execution_error" in row or "setup_error" in row for row in rows),
        "human_review_status": "pending",
    }
    (args.out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{len(rows)}개 사례 기록: {args.out}")
    print("자동 계약 검사만 기록했습니다. 의미·출처·원문 복제 여부는 사람의 검토가 필요합니다.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
