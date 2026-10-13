"""검색 근거 적중률을 잰다 (docs/test-plan.md 의 첫 번째 지표). LLM 은 부르지 않고 retriever 만 평가한다.

backend/ 에서 실행::

    uv run python -m scripts.eval_retrieval                          # tests/questions/rag-eval.json
    uv run python -m scripts.eval_retrieval --out ../docs/eval/retrieval.json

- 적중: 기대 `target_doc_keys` 중 하나 이상이 검색 결과(거리 순위 + 항상 넣는 청크)에 있음.
- 전부 적중: 기대 문서가 모두 있음. 어떤 규칙으로 들어왔는지(`순위`/`고정`)도 기록한다.
  한국어 원문과 영문 번역본(`doc_key` 끝 `.en`)은 같은 근거로 센다. 둘 중 하나만 있어도 그 근거는 찾은 것이다.
- 거절 기대 질문(범위 밖·근거 부족)은 최상위 거리만 기록한다. 거절은 답변 단계(프롬프트)에서 판단한다.
- 멀티턴 질문도 마지막 질문만으로 검색한다 (retriever 규칙).
질문 1개마다 질문 임베딩 API 를 1번 부른다 (30문항 기준 1원 미만).
"""

import argparse
import json
from pathlib import Path

from sqlalchemy import select

from app.models import Artwork
from app.rag.retriever import TOP_K, retrieve

QUESTIONS = Path(__file__).resolve().parents[1] / "tests" / "questions" / "rag-eval.json"


def evaluate(session, cases: list[dict], k: int = TOP_K) -> list[dict]:
    slugs = {c["artwork_slug"] for c in cases}
    ids = dict(session.execute(select(Artwork.slug, Artwork.id).where(Artwork.slug.in_(slugs))).all())
    rows = []
    for case in cases:
        expected = case["expected"]
        docs = retrieve(session, ids[case["artwork_slug"]], case["question"], k)
        ranked = [d.metadata for d in docs if not d.metadata["pinned"]]
        found = {d.metadata["doc_key"]: ("고정" if d.metadata["pinned"] else "순위") for d in reversed(docs)}
        targets = expected.get("target_doc_keys") or []
        rows.append({
            "id": case["id"],
            "category": case["category"],
            "artwork_slug": case["artwork_slug"],
            "question": case["question"],
            "expect_refused": expected["refused"],
            "targets": targets,
            "matched": {t: found[t] for t in targets if t in found},
            "hit": bool(targets) and any(t in found for t in targets),
            "all_hit": bool(targets) and _topics(targets) <= _topics(found),
            "top_distance": ranked[0]["distance"] if ranked else None,
            "retrieved": [(d.metadata["doc_key"], d.metadata["distance"], d.metadata["pinned"]) for d in docs],
        })
    return rows


def _topics(doc_keys) -> set[str]:
    """원문과 번역본을 하나로 (`rembrandt/the-night-watch.en` → `rembrandt/the-night-watch`)."""
    return {k.removesuffix(".en") for k in doc_keys}


def summary(rows: list[dict]) -> dict:
    targeted = [r for r in rows if r["targets"]]
    answer = [r["top_distance"] for r in rows if not r["expect_refused"] and r["top_distance"] is not None]
    refuse = [r["top_distance"] for r in rows if r["expect_refused"] and r["top_distance"] is not None]
    return {
        "questions": len(rows),
        "targeted": len(targeted),
        "hit": sum(r["hit"] for r in targeted),
        "all_hit": sum(r["all_hit"] for r in targeted),
        "hit_rate": round(sum(r["hit"] for r in targeted) / len(targeted), 3) if targeted else None,
        "answer_top_distance": [min(answer), max(answer)] if answer else None,
        "refuse_top_distance": [min(refuse), max(refuse)] if refuse else None,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--questions", type=Path, default=QUESTIONS)
    parser.add_argument("--k", type=int, default=TOP_K)
    parser.add_argument("--out", type=Path, help="질문별 결과를 JSON 으로 저장")
    args = parser.parse_args(argv)

    # import 할 때 DB 엔진을 만들므로 여기서 가져옴
    from app.db.session import SessionLocal

    cases = json.loads(args.questions.read_text(encoding="utf-8"))["cases"]
    with SessionLocal() as session:
        rows = evaluate(session, cases, args.k)
    for r in rows:
        mark = "-" if not r["targets"] else ("O" if r["all_hit"] else "△" if r["hit"] else "X")
        print(f"{mark} {r['id']:<26} 거리 {r['top_distance']}  {r['matched'] or ''}")
    s = summary(rows)
    print(
        f"\n검색 근거 적중률 {s['hit']}/{s['targeted']} ({s['hit_rate']:.0%}) · 전부 적중 {s['all_hit']}"
        f"\n최상위 거리: 답할 질문 {s['answer_top_distance']} · 거절 기대 {s['refuse_top_distance']}"
    )
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps({"summary": s, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"저장: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
