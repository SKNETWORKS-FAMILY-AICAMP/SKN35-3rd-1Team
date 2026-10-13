"""전처리 파이프라인 테스트. 실제 data/raw 를 읽고, 출력은 임시 폴더에 쓴다."""

import json
import os
import re
from collections import Counter

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
    # 데이터가 늘어도 깨지지 않게 고정 건수 대신 '기록된 줄 수 = 실제 파일 줄 수'와 하한을 본다
    for name, f in manifest["files"].items():
        assert f["rows"] == len(pp.load_processed(name)), name
    assert manifest["files"]["artists.jsonl"]["rows"] >= 6
    assert manifest["files"]["artworks.jsonl"]["rows"] >= 6 * pp.MIN_ARTWORKS
    docs = pp.load_processed("documents.jsonl")
    assert len({d["doc_key"] for d in docs}) == len(docs)
    keys = {d["doc_key"] for d in docs}
    assert all(set(d["basis_doc_keys"]) <= keys for d in docs)
    assert all(isinstance(d["basis_external_sources"], list) for d in docs)
    works = pp.load_processed("artworks.jsonl")
    assert len({w["slug"] for w in works}) == len(works)
    assert not (out / ".staging").exists()


def test_rerun_is_deterministic_and_warnings_reset(out):
    assert pp.main() == 0
    first = snapshot(out)
    n_warnings = len(pp.warnings)
    assert pp.main() == 0  # 같은 프로세스에서 다시 실행
    assert snapshot(out) == first
    assert len(pp.warnings) == n_warnings


def test_needs_review_is_preserved(out, reviews):
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
    fan = works["jeongyangsa-deoksu-2292"]
    assert fan["image_url"] == "https://www.museum.go.kr/files/zin/curator_15_1.jpg"
    assert fan["image_license"] == "공공누리 제3유형 (출처표시+변경금지)"
    europa = works["the-abduction-of-europa"]
    civilis = works["the-conspiracy-of-claudius-civilis"]
    assert europa["image_url"].endswith("1280px-Rembrandt_-_The_Abduction_of_Europa_-_Google_Art_Project.jpg")
    assert civilis["image_url"].endswith("Nationalmuseum_-_17581.jpg")
    assert europa["image_license"] == civilis["image_license"] == "Public domain"

    artists = {a["slug"]: a for a in pp.load_processed("artists.jsonl")}
    # Portraits are nullable; preserve supplied portraits without inventing images
    # for newly collected drafts that have no approved portrait URL.
    mapping = json.loads(pp.MAPPING.read_text(encoding="utf-8"))
    supplied = {slug for slug, values in mapping["artists"].items() if values.get("portrait_url")}
    assert supplied
    assert all(artists[slug]["portrait_url"] for slug in supplied)
    assert all(len(artist["summary"]) >= 200 for artist in artists.values())
    assert all(artist["summary"].count(".") >= 3 for artist in artists.values())
    assert "빛을 단순한 효과가 아니라" in artists["rembrandt"]["summary"]
    assert "에칭" in artists["rembrandt"]["summary"]
    assert "사진처럼" in artists["jeong-seon"]["summary"]
    assert "풍속화" in artists["kim-hong-do"]["summary"]
    assert "식민주의적 왜곡" in artists["paul-gauguin"]["summary"]
    assert artists["egon-schiele"]["portrait_url"] is None
    assert artists["gustav-klimt"]["portrait_url"] is None


@pytest.mark.parametrize("artist_slug", ["vincent-van-gogh", "paul-gauguin"])
def test_gogh_and_gauguin_commentary_length_and_rights_scope(artist_slug):
    """두 작가의 직접 작성 해설은 1,000자 이상이고 출처 저작권과 구분되어야 한다."""
    path = pp.RAW / artist_slug / "dataset.json"
    dataset = json.loads(path.read_text(encoding="utf-8"))
    docs = [d for d in dataset["documents"] if d["doc_type"] == "artwork_commentary"]

    assert len(docs) == 25
    assert all("새로 작성한 해설문에만 적용" in d["license"] for d in docs)
    assert all("출처 기관의 웹페이지 해설문" in d["copyright_notice"] for d in docs)

    met_docs = [d for d in docs if d["source_name"] == "The Metropolitan Museum of Art"]
    assert met_docs
    assert all("기본 데이터" in d["source_rights_note"] for d in met_docs)
    assert all("웹페이지의 큐레이터 해설문은 CC0 대상으로 간주하지 않았" in d["source_rights_note"] for d in met_docs)


def test_dataset_license_scope_survives_preprocess(out):
    """CC BY 4.0의 적용 범위 단서가 processed까지 남아야 기관 원문의 라이선스로 오해되지 않는다."""
    assert pp.main() == 0
    docs = [d for d in pp.load_processed("documents.jsonl")
            if d["doc_key"].startswith(("vincent-van-gogh/commentary-", "paul-gauguin/commentary-"))]
    assert len(docs) == 50
    assert all("새로 작성한 해설문에만 적용" in d["license"] for d in docs)
    assert all(len(d["license"]) <= 100 for d in docs)  # documents.license String(100)


def test_gogh_and_gauguin_commentary_depth_without_boilerplate(out):
    """보충문을 합친 최종 해설은 1,000자 이상이고, 여러 문서에 같은 문장을 붙여 분량을 채우지 않는다."""
    assert pp.main() == 0
    docs = [d for d in pp.load_processed("documents.jsonl")
            if d["doc_key"].startswith(("vincent-van-gogh/commentary-", "paul-gauguin/commentary-"))]
    assert min(len(d["content"]) for d in docs) >= 1000
    sentences = Counter(s.strip() for d in docs for s in re.split(r"(?<=다\.)\s+", d["content"]) if len(s) > 30)
    assert not [s for s, c in sentences.items() if c >= 5]


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


def test_translation_replaces_english_original(out, reviews):
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


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("카라바조(Michelangelo Merisi da Caravaggio [karaˈvadd͡ʒo][*], 1571년~1610년)는 화가다.", "카라바조는 화가다."),
        ("《인상, 해돋이》(프랑스어: Impression, soleil levant)는 유화이다!", "《인상, 해돋이》는 유화이다."),
        ("《야경》(夜警, 네덜란드어: De Nachtwacht) 또는 《야간순찰》(夜間巡察)은 작품이다.", "《야경》 또는 《야간순찰》은 작품이다."),
        ("모네 (1840년~1926년)가 그린 연작이다.", "모네 (1840년~1926년)가 그린 연작이다."),  # 한국어 괄호는 남김
    ],
)
def test_card_text_removes_original_language_notes(raw, expected):
    assert pp.card_text(raw) == expected


def test_clean_wiki_keeps_parent_heading_and_drops_footnotes():
    text = "앞\n\n=== 망명 ===\n\n==== 몰타 ====\n본문[2] 끝[*]\n\n=== 빈 섹션 ===\n\n== 각주 ==\n목록"
    assert pp.clean_wiki(text) == "앞\n\n### 망명\n\n#### 몰타\n본문 끝"


def test_clean_markdown_drops_notes_references_and_repeated_definition():
    """백과사전 원문: 머리말과 같은 '정의', 참고문헌·주석 섹션, 본문의 주석 번호를 지우고 깨진 한자를 복원한다.
    번역본의 '출처'는 남긴다."""
    text = ("진경산수화.\n\n## 정의\n\n진경산수화.\n\n## 내용\n\n방고(倣古)주1 행위와 이백주2의 시. 학창의(鶴?衣)\n\n"
            "## 출처\n\n소장 이력\n\n## 참고문헌\n\n- 책\n\n## 주석\n\n주1\n\n: 풀이")
    assert pp.clean_wiki(text) == ("진경산수화.\n\n## 내용\n\n방고(倣古) 행위와 이백의 시. 학창의(鶴氅衣)\n\n"
                                   "## 출처\n\n소장 이력")


def test_apply_document_supplements_appends_section_and_warns_for_stale_key():
    cat = {"documents": [{"doc_key": "artist/work", "content": "기관 원문"}]}
    pp.warnings.clear()
    pp.apply_document_supplements(cat, {
        "artist/work": {"basis_doc_keys": ["artist/work"], "content": "보충 해설"},
        "artist/missing": {"content": "사라진 문서"},
    })
    assert cat["documents"][0]["content"] == "기관 원문\n\n## 감상 포인트\n보충 해설"
    assert cat["documents"][0]["basis_doc_keys"] == ["artist/work"]
    assert cat["documents"][0]["basis_external_sources"] == []
    assert pp.warnings == ["보충문 대상 문서 'artist/missing' 가 없음"]


def test_apply_document_corrections_preserves_source_and_adds_provenance():
    cat = {"documents": [
        {"doc_key": "artist/work", "content": "수집 원문"},
        {"doc_key": "artist/basis", "content": "근거 원문"},
    ]}
    pp.initialize_editorial_metadata(cat)
    pp.warnings.clear()
    pp.apply_document_corrections(cat, {
        "artist/work": {
            "basis_doc_keys": ["artist/basis"],
            "basis_external_sources": [{"source_name": "공식 자료", "source_url": "https://example.org/source"}],
            "content": "최신 정보로 답한다.",
        },
    })
    doc = cat["documents"][0]
    assert doc["content"] == "수집 원문\n\n## 답변 시 주의\n최신 정보로 답한다."
    assert doc["basis_doc_keys"] == ["artist/basis"]
    assert doc["basis_external_sources"] == [
        {"source_name": "공식 자료", "source_url": "https://example.org/source"}
    ]


def test_joseon_corrections_are_visible_to_rag():
    cat = pp.build()
    docs = {d["doc_key"]: d for d in cat["documents"]}
    assert "현재 국립중앙박물관" in docs["jeong-seon/bio"]["content"]
    assert "1725년은 영조 1년" in docs["jeong-seon/yuksangmyodo"]["content"]
    assert "추정해 완성하지 말고" in docs["kim-hong-do/chuseongbudo-inscription"]["content"]
    assert docs["jeong-seon/yuksangmyodo"]["basis_external_sources"][0]["source_name"] == (
        "국사편찬위원회 우리역사넷"
    )


def test_fix_korean_year_notation():
    from scripts.translate import fix_korean

    assert fix_korean("c. 1893년에 제작") == "1893년경에 제작"
    assert fix_korean("(c. 1600–1601)은") == "(1600–1601년경)은"


def test_artist_aliases_cover_collected_artists(out):
    assert pp.main() == 0
    rows = {r["slug"]: r for r in pp.load_processed("artist_aliases.jsonl")}
    collected = {a["slug"] for a in pp.load_processed("artists.jsonl")}
    pending = {s for s, r in rows.items() if r["status"] == "pending_review"}
    assert pending == set()
    assert {s for s, r in rows.items() if r["status"] == "collected"} == collected - pending
    assert all(r["aliases"] for r in rows.values())


def test_duplicate_alias_is_an_error(out, monkeypatch):
    def dup(cat):
        cat["aliases"]["paul-gauguin"]["aliases"].append("모네")

    assert pp.main() == 0
    before = snapshot(out)
    build_with(monkeypatch, dup)
    assert pp.main() == 1
    after = snapshot(out)
    failed = json.loads(after.pop("_FAILED.json"))
    assert after == before
    assert any("겹침" in e for e in failed["errors"])


def test_aliases_in_artist_slugs_are_fixed(out, monkeypatch):
    """수집 담당이 artist_slugs 에 별칭을 넣어도 멈추지 않고 작가 slug 로 고친다."""
    real_build = pp.build

    def build_with_alias():
        cat = real_build()
        bio = next(d for d in cat["documents"] if d["doc_key"] == "claude-monet/bio")
        bio["artist_slugs"] = ["claude-monet", "monet", "모네"]
        pp.normalize_artist_slugs(cat)
        return cat

    monkeypatch.setattr(pp, "build", build_with_alias)
    assert pp.main() == 0
    docs = {d["doc_key"]: d for d in pp.load_processed("documents.jsonl")}
    assert docs["claude-monet/bio"]["artist_slugs"] == ["claude-monet"]
    assert any("고침" in w for w in pp.warnings)


def test_crlf_checkout_is_still_accepted(out):
    """Windows 에서 git 이 줄바꿈을 CRLF 로 바꿔 받아도 load_processed() 가 거부하지 않는다."""
    assert pp.main() == 0
    path = out / "artists.jsonl"
    path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
    assert len(pp.load_processed("artists.jsonl")) >= 6


def test_approved_artist_documents_and_images(out):
    """승인 기록과 재생성 산출물에서 신규 작가 문서와 이미지 NULL 상태를 유지한다."""
    assert pp.main() == 0
    new_slugs = {"gustav-klimt", "egon-schiele"}
    docs = [d for d in pp.load_processed("documents.jsonl")
            if d["doc_key"].split("/", 1)[0] in new_slugs]
    assert len(docs) == 68
    assert all(not d["needs_review"] for d in docs)
    works = [w for w in pp.load_processed("artworks.jsonl") if w["artist_slug"] in new_slugs]
    assert len(works) == 60
    assert sum(w["image_url"] is None for w in works) == 53
    assert {m["slug"] for m in pp.load_processed("movements.jsonl")} >= {
        "expressionism", "vienna-secession",
    }
