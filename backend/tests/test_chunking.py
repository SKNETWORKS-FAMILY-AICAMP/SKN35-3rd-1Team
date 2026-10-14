"""청킹 규칙 테스트. 작은 가짜 문서로 규칙을 보고, 실제 data/processed 로 전체 결과의 범위를 본다."""

from collections import Counter

import pytest

from app.rag import chunking as ch
from scripts import preprocess as pp


def doc(content, title="문서", key="a/doc"):
    return {"doc_key": key, "title": title, "content": content}


def test_short_document_is_one_chunk_with_title_heading():
    chunks = ch.chunk_document(doc("1641–1642 · 사건\n이야기 두세 문장.", title="렘브란트 연표: 1641–1642 사건"))
    assert len(chunks) == 1
    assert chunks[0].heading == "렘브란트 연표: 1641–1642 사건"
    assert chunks[0].content == "렘브란트 연표: 1641–1642 사건\n\n1641–1642 · 사건\n이야기 두세 문장."


def test_short_document_keeps_section_names_in_body_and_drops_h1():
    chunks = ch.chunk_document(doc("# 문서\n\n도입.\n\n## 소장\n오르세 미술관.", title="문서"))
    assert len(chunks) == 1
    assert chunks[0].body == "도입.\n[소장]\n오르세 미술관."


def test_long_document_splits_by_section_with_heading_path():
    a, b = "가" * 450, "나" * 450
    content = f"도입 {'다' * 400}\n## 생애\n### 초기\n{a}\n## 작품\n{b}"
    chunks = ch.chunk_document(doc(content, title="생애"))
    assert [c.heading for c in chunks] == ["생애", "생애 > 생애 > 초기", "생애 > 작품"]
    assert [c.chunk_index for c in chunks] == [0, 1, 2]
    assert all("##" not in c.body for c in chunks)


def test_long_section_splits_on_line_boundaries_near_target():
    lines = [f"{i}" + "라" * 199 for i in range(8)]  # 200자 줄 8개
    chunks = ch.chunk_document(doc("## 섹션\n" + "\n".join(lines)))
    assert len(chunks) == 4
    assert all(len(c.body) <= ch.TARGET_CHARS for c in chunks)
    assert "\n".join(c.body for c in chunks) == "\n".join(lines)  # 글자를 빠뜨리거나 겹치지 않음


def test_overlong_line_splits_on_sentences():
    sentence = "마" * 99 + "."
    chunks = ch.chunk_document(doc(" ".join([sentence] * 12)))  # 줄 하나 1,211자
    assert len(chunks) > 1
    assert all(len(c.body) <= ch.HARD_MAX_CHARS for c in chunks)
    assert all(c.body.endswith(".") for c in chunks)


def test_small_section_merges_into_next_with_marker():
    content = f"## 배경\n짧다.\n## 본론\n{'바' * 650}\n## 결론\n{'사' * 650}"
    chunks = ch.chunk_document(doc(content, title="T"))
    assert chunks[0].heading == "T"
    assert chunks[0].body.startswith("[배경]\n짧다.\n[본론]\n")
    assert len(chunks) == 2


def test_merge_limit_counts_section_markers_and_newlines():
    """149자 + 650자는 799자지만 `[배경]`·`[본론]` 표시와 줄바꿈을 더하면 800자를 넘는다."""
    content = f"## 배경\n{'짧' * 149}\n## 본론\n{'바' * 650}\n## 결론\n{'사' * 650}"
    chunks = ch.chunk_document(doc(content, title="T"))
    assert all(len(c.body) <= ch.HARD_MAX_CHARS for c in chunks)
    assert [c.heading for c in chunks] == ["T > 배경", "T > 본론", "T > 결론"]


def test_trailing_small_piece_merge_also_counts_markers():
    content = f"## 본론\n{'바' * 650}\n## 결론\n{'사' * 650}\n## 덧말\n{'짧' * 149}"
    chunks = ch.chunk_document(doc(content, title="T"))
    assert all(len(c.body) <= ch.HARD_MAX_CHARS for c in chunks)
    assert chunks[-1].heading == "T > 덧말"


def test_h1_in_the_middle_resets_section_path():
    content = f"## 생애\n{'가' * 650}\n# 새로운 제목\n{'나' * 650}"
    chunks = ch.chunk_document(doc(content, title="T"))
    assert [c.heading for c in chunks] == ["T > 생애", "T"]
    assert "[생애]" not in chunks[1].body


def test_empty_parent_section_is_kept_only_in_heading():
    content = f"## 망명과 죽음\n### 몰타\n{'아' * 650}\n### 시칠리아\n{'자' * 650}"
    chunks = ch.chunk_document(doc(content, title="카라바조의 생애"))
    assert [c.heading for c in chunks] == ["카라바조의 생애 > 망명과 죽음 > 몰타", "카라바조의 생애 > 망명과 죽음 > 시칠리아"]


@pytest.mark.parametrize("section", ch.ANNOTATION_SECTIONS)
def test_annotation_section_is_always_its_own_chunk(section):
    """짧은 문서여도 덧붙인 절은 따로 떼고, 머리말에 절 제목을 남긴다. 아무리 짧아도 본문과 합치지 않는다."""
    chunks = ch.chunk_document(doc(f"[기본 정보] 원문.\n\n## {section}\n짧은 보충.", title="해설"))
    assert [c.heading for c in chunks] == ["해설", f"해설 > {section}"]
    assert [ch.annotation_section(c.content) for c in chunks] == [None, section]
    assert chunks[1].body == "짧은 보충."


def test_long_annotation_section_keeps_title_in_every_piece():
    content = "원문.\n## 답변 시 주의\n" + "\n".join("차" * 400 for _ in range(3))
    chunks = ch.chunk_document(doc(content, title="T"))
    assert [c.heading for c in chunks[1:]] == ["T > 답변 시 주의"] * 3


@pytest.fixture(scope="module")
def processed():
    return pp.load_processed("documents.jsonl")


def test_processed_documents_all_chunk_within_limits(processed):
    chunks = ch.chunk_documents(processed)
    keys = {d["doc_key"] for d in processed}
    assert {c.doc_key for c in chunks} == keys  # 모든 문서가 청크를 하나 이상 가짐
    assert len({(c.doc_key, c.chunk_index) for c in chunks}) == len(chunks)
    assert all(len(c.body) <= ch.WHOLE_DOC_MAX for c in chunks)
    # HARD_MAX_CHARS 를 넘는 청크는 자르지 않고 통째로 둔 본문뿐이다 (그 문서의 본문 청크가 하나)
    body_chunks = Counter(c.doc_key for c in chunks if ch.annotation_section(c.content) is None)
    assert all(body_chunks[c.doc_key] == 1 for c in chunks if len(c.body) > ch.HARD_MAX_CHARS)
    assert all(c.body.strip() and not c.body.startswith("#") for c in chunks)
    for t in ch.ANNOTATION_SECTIONS:  # 덧붙인 절 제목은 머리말에만 있고 본문 표시로 내려가지 않음
        assert not any(f"[{t}]" in c.body for c in chunks)


def test_timeline_documents_are_never_split(processed):
    timeline = [d for d in processed if d.get("topic") == "연표"]
    assert timeline
    for d in timeline:
        assert len(ch.chunk_document(d)) == 1
