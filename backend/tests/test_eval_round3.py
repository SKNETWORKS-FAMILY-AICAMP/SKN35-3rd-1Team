from scripts.eval_round3 import retrieval_metrics


def test_retrieval_metrics_rewards_early_and_complete_hits():
    relevant = {("doc", 1), ("doc", 2)}
    result = retrieval_metrics([("doc", 1), ("other", 0), ("doc", 2)], relevant)

    assert result["recall_at_5"] == 1.0
    assert result["reciprocal_rank"] == 1.0
    assert 0 < result["ndcg_at_5"] < 1.0


def test_retrieval_metrics_is_zero_without_a_hit():
    result = retrieval_metrics([("other", 0)], {("doc", 1)})

    assert result == {"recall_at_5": 0.0, "reciprocal_rank": 0.0, "ndcg_at_5": 0.0}
