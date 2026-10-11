"""전처리 파이프라인 테스트. 실제 data/raw 를 읽고, 출력은 임시 폴더에 쓴다."""

import json
import os

import pytest

from scripts import preprocess as pp


@pytest.fixture
def out(tmp_path, monkeypatch):
    """출력 경로를 임시 폴더로 바꾼다. 실제 data/processed 는 건드리지 않는다."""
    monkeypatch.setattr(pp, "OUT", tmp_path)
    monkeypatch.setattr(pp, "STAGING", tmp_path / ".staging")
    monkeypatch.setattr(pp, "SUCCESS", tmp_path / "_SUCCESS.json")
    monkeypatch.setattr(pp, "FAILED", tmp_path / "_FAILED.json")
    return tmp_path


def snapshot(path):
    return {p.name: p.read_bytes() for p in sorted(path.iterdir()) if p.is_file()}


def build_with(monkeypatch, change):
    """원본을 읽은 결과(cat)를 change 로 고친 뒤 main() 이 쓰게 한다."""
    real_build = pp.build

    def patched():
        cat = real_build()
        change(cat)
        return cat

    monkeypatch.setattr(pp, "build", patched)


def test_counts_and_uniqueness(out):
    assert pp.main() == 0
    manifest = json.loads((out / "_SUCCESS.json").read_text(encoding="utf-8"))
    rows = {name: f["rows"] for name, f in manifest["files"].items()}
    assert rows == {"movements.jsonl": 3, "artists.jsonl": 6, "artworks.jsonl": 32, "documents.jsonl": 83}
    docs = pp.load_processed("documents.jsonl")
    assert len({d["doc_key"] for d in docs}) == len(docs)
    assert len({w["slug"] for w in pp.load_processed("artworks.jsonl")}) == 32
    assert not (out / ".staging").exists()


def test_rerun_is_deterministic_and_warnings_reset(out):
    assert pp.main() == 0
    first = snapshot(out)
    n_warnings = len(pp.warnings)
    assert pp.main() == 0  # 같은 프로세스에서 다시 실행
    assert snapshot(out) == first
    assert len(pp.warnings) == n_warnings


def test_needs_review_is_preserved(out):
    assert pp.main() == 0
    docs = {d["doc_key"]: d for d in pp.load_processed("documents.jsonl")}
    assert all(isinstance(d["needs_review"], bool) for d in docs.values())
    assert docs["rembrandt/timeline-00"]["needs_review"] is True  # timeline.json needs_review=true
    assert docs["rembrandt/bio"]["needs_review"] is False
    assert docs["vincent-van-gogh/bio-vincent-van-gogh"]["needs_review"] is True  # review_status='팀 검수 필요'


@pytest.mark.parametrize(
    ("change", "message"),
    [
        (lambda cat: cat["documents"][0].update(doc_type="artist_biography"), "허용되지 않는 doc_type"),
        (lambda cat: next(iter(cat["artworks"].values())).update(movement_slug="cubism"), "사조 'cubism'"),
    ],
)
def test_validation_failure_keeps_previous_result(out, monkeypatch, change, message):
    assert pp.main() == 0
    before = snapshot(out)
    build_with(monkeypatch, change)
    assert pp.main() == 1
    after = snapshot(out)
    failed = json.loads(after.pop("_FAILED.json"))
    assert after == before  # 기존 결과와 _SUCCESS.json 은 그대로
    assert any(message in e for e in failed["errors"])


def test_success_after_failure_clears_failed_marker(out, monkeypatch):
    real_build = pp.build
    build_with(monkeypatch, lambda cat: cat["documents"][0].update(doc_type="oops"))
    assert pp.main() == 1
    assert (out / "_FAILED.json").exists()
    monkeypatch.setattr(pp, "build", real_build)
    assert pp.main() == 0
    assert not (out / "_FAILED.json").exists()


def test_interrupted_swap_is_never_read(out, monkeypatch):
    """파일 교체 도중 멈추면 _SUCCESS.json 이 없으므로 load_processed() 가 거부한다."""
    assert pp.main() == 0
    real_replace = os.replace
    calls = {"n": 0}

    def flaky_replace(src, dst):
        calls["n"] += 1
        if calls["n"] == 2:
            raise OSError("디스크 오류 흉내")
        return real_replace(src, dst)

    monkeypatch.setattr(pp.os, "replace", flaky_replace)
    with pytest.raises(OSError):
        pp.publish({name: [] for name in pp.OUTPUT_FILES})
    monkeypatch.setattr(pp.os, "replace", real_replace)
    assert not (out / "_SUCCESS.json").exists()
    with pytest.raises(RuntimeError):
        pp.load_processed("artists.jsonl")


def test_tampered_file_is_rejected(out):
    assert pp.main() == 0
    (out / "artists.jsonl").write_text("{}\n", encoding="utf-8")
    with pytest.raises(RuntimeError):
        pp.load_processed("artists.jsonl")


@pytest.fixture
def reviews(out, tmp_path_factory, monkeypatch):
    """검수 장부도 임시 파일로 바꾼다."""
    path = tmp_path_factory.mktemp("mappings") / "reviews.json"
    monkeypatch.setattr(pp, "REVIEWS", path)
    return path


def test_mapping_overrides_apply_to_dataset_format(out):
    assert pp.main() == 0
    works = {w["slug"]: w for w in pp.load_processed("artworks.jsonl")}
    assert works["sunflowers-1887"]["image_url"].startswith("https://images.metmuseum.org/")
    assert works["impression-sunrise"]["image_source_url"].startswith("https://commons.wikimedia.org/wiki/File:")
    assert all(a["portrait_url"] for a in pp.load_processed("artists.jsonl"))


def test_review_approval_and_invalidation(out, reviews, monkeypatch):
    key = "rembrandt/timeline-00"
    assert pp.main(["review", "--approve", key, "--reviewer", "테스트"]) == 0
    assert json.loads(reviews.read_text(encoding="utf-8"))["reviews"][key]["reviewer"] == "테스트"
    assert pp.main() == 0
    docs = {d["doc_key"]: d for d in pp.load_processed("documents.jsonl")}
    assert docs[key]["needs_review"] is False

    # 검수 뒤 본문이 바뀌면 다시 검토 필요로 돌아간다
    def edit(cat):
        next(d for d in cat["documents"] if d["doc_key"] == key)["content"] += " (수정)"
        pp.apply_reviews(cat, pp.read_reviews())

    build_with(monkeypatch, edit)
    assert pp.main() == 0
    docs = {d["doc_key"]: d for d in pp.load_processed("documents.jsonl")}
    assert docs[key]["needs_review"] is True
    assert any("다시 검토" in w for w in pp.warnings)


def test_review_pattern_and_missing_reviewer(out, reviews):
    assert pp.main(["review", "--approve", "caravaggio/timeline-*"]) == 1  # 검수자 없음
    assert not reviews.exists()
    assert pp.main(["review", "--approve", "caravaggio/timeline-*", "--reviewer", "테스트"]) == 0
    assert len(json.loads(reviews.read_text(encoding="utf-8"))["reviews"]) == 14


def test_translation_replaces_english_original(out):
    """번역본이 있으면 영어 원문 대신 한국어 번역을 내보내고, doc_key 는 원문과 같다."""
    assert pp.main() == 0
    docs = {d["doc_key"]: d for d in pp.load_processed("documents.jsonl")}
    d = docs["rembrandt/the-jewish-bride.en"]
    assert d["lang"] == "ko"
    assert d["title"].endswith("(영문 번역)")
    assert d["needs_review"] is True
    assert "한국어 번역" in d["source_name"]
    # 한국어 원문이 있는 작품의 카드 설명은 번역본이 아니라 원문에서 온다
    works = {w["slug"]: w for w in pp.load_processed("artworks.jsonl")}
    assert works["the-jewish-bride"]["description"].startswith("《유대인 신부》")
