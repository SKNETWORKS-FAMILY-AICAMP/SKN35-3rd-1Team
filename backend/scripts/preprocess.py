"""data/raw → data/processed 전처리.

원본은 작가마다 형식이 달라서, 형식별로 읽는 함수를 두고 결과를 한 가지 형태로 모은다.
    - dataset.json            (고흐, 고갱)     작가·작품·문서가 이미 구조화됨
    - *.md + sources.json     (모네, 세잔, 렘브란트, 카라바조)  위키백과 원문
    - timeline.json           연표. 사건 하나 = 문서 하나
    - _comparisons/           비교 문서
원본에 없는 값(모네·세잔 작품 정보, 사조)은 data/mappings/catalog.json 에서 채운다.

실행 (backend/ 에서):  uv run python -m scripts.preprocess
결과: data/processed/{movements,artists,artworks,documents,artist_aliases}.jsonl + _SUCCESS.json

검수 (data/mappings/reviews.json 에 기록):
    uv run python -m scripts.preprocess review --list
    uv run python -m scripts.preprocess review --approve "rembrandt/timeline-*" --reviewer 홍길동
    검수할 때의 본문 해시를 함께 저장한다. 그 뒤 본문이 바뀌면 다시 검토 필요(needs_review=true)로 돌아간다.

출력 규칙
    - 5개 파일을 data/processed/.staging/ 에 모두 만든 뒤 한꺼번에 교체한다.
    - 성공하면 _SUCCESS.json(파일별 sha256, 줄 수)을 마지막에 쓴다. 적재 스크립트는
      load_processed() 로 읽는다. _SUCCESS.json 이 없거나 해시가 다르면 읽지 않는다.
    - 실패하면 기존 결과와 _SUCCESS.json 은 그대로 두고 _FAILED.json 에 이유를 남긴다.
"""

import argparse
import fnmatch
import hashlib
import json
import os
import re
import shutil
import sys
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "processed"
STAGING = OUT / ".staging"
SUCCESS = OUT / "_SUCCESS.json"
FAILED = OUT / "_FAILED.json"
MAPPING = ROOT / "data" / "mappings" / "catalog.json"
REVIEWS = ROOT / "data" / "mappings" / "reviews.json"
SUPPLEMENTS = ROOT / "data" / "mappings" / "document_supplements.json"
CORRECTIONS = ROOT / "data" / "mappings" / "document_corrections.json"
ALIASES = ROOT / "data" / "mappings" / "artist_aliases.json"
OUTPUT_FILES = ("movements.jsonl", "artists.jsonl", "artworks.jsonl", "documents.jsonl", "artist_aliases.jsonl")

MIN_CONTENT = 200  # 이보다 짧은 문서는 경고
MIN_ARTWORKS = 3  # 기획서 기준: 작가당 대표작 5점, 최소 3점
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DOC_TYPES = {"artist_bio", "artwork_commentary", "artist_comparison"}
# dataset.json 의 review_status 가 이 값일 때만 검수 완료로 본다. 그 밖의 값은 모두 needs_review=true
REVIEWED = {"검수 완료", "reviewed", "approved"}

# 위키백과 문서에서 통째로 버리는 섹션 (본문이 아닌 목록·링크)
DROP_SECTIONS = {
    "같이 보기", "각주", "내용주", "참고 문헌", "참고문헌", "참고 자료", "외부 링크", "갤러리", "읽을거리", "출처",
    "See also", "References", "Notes", "External links", "Further reading", "Gallery", "Sources",
    "Bibliography", "Citations", "Footnotes", "In popular culture", "Works about Rembrandt",
    "Literary works (e.g. poetry and fiction)", "Music", "Films", "Exhibitions", "Museum collections",
    "Selected works", "Paintings", "Drawings and etchings", "Other major paintings",
}
HEADING = re.compile(r"^(={2,4})\s*(.+?)\s*\1\s*$", re.MULTILINE)
# 백과사전·박물관 원문(마크다운 제목)에서 버리는 섹션. 번역본의 '## 출처'(소장 이력)는 본문이므로 위 목록을 쓰지 않는다
MD_DROP_SECTIONS = {"참고문헌", "참고 문헌", "참고 자료", "주석"}
MD_HEADING = re.compile(r"^(#{2,4}) (.+)$", re.MULTILINE)
NOTE_MARK = re.compile(r"(?<=[^\s\d])주\d{1,2}(?!\d)")  # 백과사전 본문의 주석 번호: 방고(倣古)주1 행위
# 박물관 사이트가 EUC-KR 밖의 한자를 '?'로 내보낸 곳. 원문 파일은 수집 해시가 있어 고치지 않고 여기서 복원한다
LOST_HANJA = {"준법(?法)": "준법(皴法)", "사천(?川)": "사천(槎川)", "수직준(垂直?)": "수직준(垂直皴)",
              "화보식(?譜式)": "화보식(畫譜式)", "학창의(鶴?衣)": "학창의(鶴氅衣)"}
# 한국어·로마자 문서에 섞이면 안 되는 문자 (기계 번역이 단어 일부를 다른 언어로 내놓는 경우)
FOREIGN_SCRIPT = re.compile(r"[֐-׿؀-ۿЀ-ӿऀ-ॿ฀-๿぀-ヿ]")
FOOTNOTE = re.compile(r"\[(?:\*|\d{1,3}|편집|출처 필요)\]")  # 위키 각주 표식
# 화면용 짧은 글(카드 설명, 작가 소개)에서 지우는 것: 원어 병기 괄호, 발음 기호
LANG_PAREN = re.compile(
    r"\s*\((?:[^()]*?(?:어|문화어):[^()]*"  # (프랑스어: …), (문화어: …)
    r"|[A-Za-z][^()가-힣]*(?:[^()]*)"        # (Michelangelo Merisi …) 처럼 로마자로 시작하는 원명
    r"|[一-鿿,\s]+)\)"               # (夜間巡察) 한자 병기
)
IPA = re.compile(r"\s*\[[^\]]*[ˈˌːɛɔəɲʒʃθðŋ̃][^\]]*\]")

ARTIST_FIELDS = ("slug", "name", "name_en", "movement_slug", "birth_year", "death_year", "nationality",
                 "summary", "portrait_url")
ARTWORK_FIELDS = ("slug", "artist_slug", "movement_slug", "title", "title_en", "year_label", "year_start", "medium",
                  "dimensions", "collection", "description", "image_url", "image_source_url", "image_license",
                  "is_featured")

warnings: list[str] = []


# ---------------------------------------------------------------- 정제
def clean_markdown(text: str) -> str:
    """마크다운 제목 원문에서 참고문헌·주석 섹션과 본문의 주석 번호를 지우고, '?'로 깨진 한자를 복원한다.

    머리말과 똑같은 문장만 담은 섹션(백과사전의 '정의')도 지운다. 같은 문장이 두 청크에 들어가지 않게 하려는 것.
    """
    text = NOTE_MARK.sub("", text)  # 주석 섹션을 빼고 수집한 원문에도 번호가 남아 있다
    for lost, hanja in LOST_HANJA.items():
        text = text.replace(lost, hanja)
    parts = MD_HEADING.split(text)  # [앞부분, #, 제목, 본문, #, 제목, 본문, ...]
    if len(parts) == 1:
        return text
    out, seen, skip_level = [parts[0]], {parts[0].strip()}, None
    for i in range(1, len(parts), 3):
        level, title, body = len(parts[i]), parts[i + 1].strip(), parts[i + 2]
        if skip_level is not None and level > skip_level:
            continue
        skip_level = None
        if title in MD_DROP_SECTIONS:
            skip_level = level
            continue
        if body.strip() and body.strip() in seen:
            continue
        seen.add(body.strip())
        out.append(f"{parts[i]} {parts[i + 1]}{body}")
    return "".join(out)


def clean_wiki(text: str) -> str:
    """위키 문법 제목을 마크다운 제목으로 바꾸고, 목록·링크 섹션과 빈 섹션을 지운다. 본문은 고치지 않는다."""
    text = clean_markdown(text)
    parts = HEADING.split(text)  # [앞부분, 등호, 제목, 본문, 등호, 제목, 본문, ...]
    sections = []  # (level, title, body)
    skip_level = None
    for i in range(1, len(parts), 3):
        level, title, body = len(parts[i]), parts[i + 1], parts[i + 2].strip()
        if skip_level is not None and level > skip_level:
            continue  # 버린 섹션의 하위 섹션
        skip_level = None
        if title in DROP_SECTIONS:
            skip_level = level
            continue
        sections.append((level, title, body))
    # 본문이 없는 제목은 지우되, 본문이 있는 하위 섹션을 거느린 상위 제목은 남긴다 (청크 머리말에 필요)
    keep = [False] * len(sections)
    for i in range(len(sections) - 1, -1, -1):
        level, _, body = sections[i]
        if body:
            keep[i] = True
            continue
        for j in range(i + 1, len(sections)):
            if sections[j][0] <= level:
                break
            if keep[j]:
                keep[i] = True
                break
    out = [parts[0].strip()]
    out += [f"{'#' * lv} {t}\n{b}".rstrip() for (lv, t, b), k in zip(sections, keep, strict=True) if k]
    text = "\n\n".join(p for p in out if p)
    text = FOOTNOTE.sub("", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def card_text(text: str | None) -> str | None:
    """카드 설명·작가 소개처럼 화면에 짧게 보이는 글에서 원어 병기, 발음 기호, 위키 표식을 지운다.

    문서 본문(content)에는 쓰지 않는다. 본문은 답변 근거라 원문을 그대로 둔다.
    """
    if not text:
        return text
    text = FOOTNOTE.sub("", IPA.sub("", LANG_PAREN.sub("", text)))
    text = re.sub(r"다!(?=\s|$)", "다.", text)
    return re.sub(r"\s{2,}", " ", text).strip()


def first_sentences(text: str, n: int = 2) -> str | None:
    """카드용 짧은 설명. 첫 문단의 앞 n문장."""
    para = card_text(text.split("\n")[0].strip())
    sents = re.findall(r".+?(?:다\.|\.)(?=\s|$)", para)
    return " ".join(s.strip() for s in sents[:n]) or None


def strip_query(url: str | None) -> str | None:
    return url.split("?")[0] if url else url


def commons_page(image_url: str | None) -> str | None:
    """위키미디어 원본 파일 주소에서 파일 설명 페이지(이용 조건이 적힌 곳) 주소를 만든다."""
    m = re.match(r"https://upload\.wikimedia\.org/wikipedia/commons/(?:thumb/)?[0-9a-f]/[0-9a-f]{2}/([^/?]+)", image_url or "")
    return f"https://commons.wikimedia.org/wiki/File:{m.group(1)}" if m else None


def content_hash(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def lang_of(text: str) -> str:
    return "ko" if re.search("[가-힣]", text[:300]) else "en"


def needs_review_of(record_status: str | None, review_status: str | None) -> bool:
    """dataset.json 형식의 검수 상태. 초안(draft)이거나 검수 완료가 아니면 검토 필요."""
    if record_status and record_status.startswith("draft"):
        return True
    return review_status is not None and review_status not in REVIEWED


# ---------------------------------------------------------------- 형식별 읽기
def read_dataset(folder: Path, cat: dict) -> None:
    """고흐·고갱 형식. 필드가 processed와 거의 같으므로 이름만 맞춘다."""
    d = json.loads((folder / "dataset.json").read_text(encoding="utf-8"))
    a = d["artist"]
    cat["artists"][a["slug"]] = {k: a.get(k) for k in ARTIST_FIELDS}
    for w in d["artworks"]:
        cat["artworks"][w["slug"]] = {k: w.get(k) for k in ARTWORK_FIELDS}
    for x in d["documents"]:
        cat["documents"].append({
            "doc_key": f"{a['slug']}/{x['document_key']}",
            "doc_type": x["doc_type"], "title": x["title"], "content": x["content"].strip(),
            "artist_slugs": x.get("artist_slugs") or [], "artwork_slug": x.get("artwork_slug"),
            "source_url": x["source_url"], "source_name": x.get("source_name"),
            # 괄호 안 적용 범위(팀이 새로 쓴 해설문에만 적용)를 지우면 기관 원문의 라이선스로 오해된다
            "license": x.get("license") or None,
            "lang": "ko", "topic": None, "related_artwork_slugs": [],
            "needs_review": needs_review_of(d.get("record_status"), x.get("review_status")),
        })


def read_markdown(folder: Path, cat: dict, mapping: dict) -> None:
    """위키백과 원문 형식. sources.json 의 항목 하나가 md 파일 하나."""
    slug = folder.name
    sources = json.loads((folder / "sources.json").read_text(encoding="utf-8"))
    artist = {"slug": slug, "summary": None, "portrait_url": None}
    artist.update(mapping["artists"].get(slug, {}))
    for fname, s in sources.items():
        if not fname.endswith(".md"):
            continue
        content, lang, title, source_name, needs_review, tr = read_md_document(folder, fname, s)
        if "artist" in s:  # 렘브란트·카라바조: 수집할 때 작가 정보를 같이 적어 둠
            artist.update({k: v for k, v in s["artist"].items() if k in ARTIST_FIELDS})
        if s["doc_type"] == "artist_bio" and fname == "bio.md" and lang == "ko":
            artist["summary"] = first_sentences(content)
        if s["doc_type"] == "artwork_commentary":
            add_artwork(cat, slug, s, content, lang, mapping, translated=bool(tr))
        cat["documents"].append({
            "doc_key": f"{slug}/{fname.removesuffix('.md')}",
            "doc_type": s["doc_type"], "title": title, "content": content,
            "artist_slugs": s.get("artist_slugs") or [], "artwork_slug": s.get("artwork_slug"),
            "source_url": s["source_url"], "source_name": source_name, "license": s.get("license"),
            "lang": lang, "topic": s.get("topic"), "related_artwork_slugs": s.get("related_artwork_slugs") or [],
            "basis_external_sources": [
                {"source_name": "관련 작품 소장처 자료", "source_url": url}
                for url in s.get("related_source_urls", [])
            ],
            "needs_review": needs_review,
        })
    cat["artists"][slug] = {k: artist.get(k) for k in ARTIST_FIELDS}


def read_md_document(folder: Path, fname: str, s: dict) -> tuple:
    """md 문서 하나를 읽는다. 번역본(scripts/translate.py)이 있으면 영어 원문 대신 쓴다.

    돌려주는 값: (content, lang, title, source_name, needs_review, translation 기록 또는 None).
    doc_key 는 번역본이어도 원문과 같게 둔다 (검수 기록·재적재 키가 흔들리지 않게).
    """
    raw = (folder / fname).read_text(encoding="utf-8")
    content = clean_wiki(raw)
    lang = s.get("lang") or lang_of(raw)
    title, source_name, needs_review = s["title"], s.get("source_name"), bool(s.get("needs_review", False))
    tr = s.get("translation")
    if not (tr and (folder / tr["file"]).exists()):
        return content, lang, title, source_name, needs_review, None
    if tr["source_sha256"] != content_hash(content):
        warnings.append(f"{folder.name}/{fname}: 번역 후 원문이 바뀜. scripts.translate 를 다시 실행하세요")
    content = clean_wiki((folder / tr["file"]).read_text(encoding="utf-8"))
    title = title.replace(" (영문)", "") + " (영문 번역)"
    source_name = f"{source_name} · 한국어 번역 ({tr['model']})"
    return content, "ko", title, source_name, True, tr  # 기계 번역은 사람이 고유명사 표기 등을 확인해야 함


def add_artwork(
    cat: dict, artist_slug: str, s: dict, content: str, lang: str, mapping: dict, translated: bool = False
) -> None:
    """작품 해설 문서에서 작품 카드를 만든다. 한 작품에 한국어·영어 문서가 둘 다 있으면 한국어 값을 쓴다."""
    slug = s["artwork_slug"]
    w = cat["artworks"].get(slug) or {k: None for k in ARTWORK_FIELDS}
    w.update({"slug": slug, "artist_slug": artist_slug})
    w.update({k: v for k, v in (s.get("artwork") or {}).items() if k in ARTWORK_FIELDS and v is not None})
    manual = mapping["artworks"].get(slug, {})
    w.update(manual)
    w["image_url"] = w.get("image_url") or strip_query(s.get("image_url"))
    w["image_license"] = w.get("image_license") or s.get("image_license")
    # 카드 설명 우선순위: 사람이 쓴 설명 > 한국어 원문 > 번역본 (번역본은 비어 있을 때만)
    if lang == "ko" and "description" not in manual and (not translated or not w.get("description")):
        w["description"] = content.strip() if s.get("display_full_description") else first_sentences(content)
    w["is_featured"] = bool(w.get("is_featured"))
    cat["artworks"][slug] = w


def read_timeline(folder: Path, cat: dict) -> None:
    """연표의 사건 하나를 문서 하나로 만든다. 청크 하나에 이야기 하나가 온전히 들어가게 하려는 것."""
    path = folder / "timeline.json"
    if not path.exists():
        return
    t = json.loads(path.read_text(encoding="utf-8"))
    src_path = folder / "sources.json"
    sources = json.loads(src_path.read_text(encoding="utf-8")) if src_path.exists() else {}
    slug = t["artist_slug"]
    name = cat["artists"][slug]["name"]
    for i, e in enumerate(t["events"]):
        titles = [cat["artworks"][a]["title"] for a in e["related_artworks"] if a in cat["artworks"]]
        lines = [f"{e['year']} · {e['title']}", e["story"]]
        if e["people"]:
            lines.append("등장 인물: " + ", ".join(e["people"]))
        if titles:
            lines.append("관련 작품: " + ", ".join(f"『{x}』" for x in titles))
        # 출처: 사건에 source_url 을 직접 적었으면 그것을, 아니면 sources.json 에서 source_file 로 찾는다
        if e.get("source_url"):
            src = {"source_url": e["source_url"], "source_name": e.get("source_name")}
        else:
            src = sources[e["source_file"]]
        cat["documents"].append({
            "doc_key": f"{slug}/timeline-{i:02d}",
            "doc_type": "artist_bio", "title": f"{name} 연표: {e['year']} {e['title']}",
            "content": "\n".join(lines), "artist_slugs": [slug], "artwork_slug": None,
            "source_url": src["source_url"], "source_name": src["source_name"], "license": t["license"],
            "lang": "ko", "topic": "연표", "related_artwork_slugs": e["related_artworks"],
            "needs_review": bool(e.get("needs_review", t.get("needs_review", False))),
        })


def read_comparisons(folder: Path, cat: dict) -> None:
    for path in sorted(folder.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if "document" in data:  # 고흐·고갱 비교 문서 형식
            x = data["document"]
            cat["documents"].append({
                "doc_key": f"_comparisons/{x['document_key']}",
                "doc_type": x["doc_type"], "title": x["title"], "content": x["content"].strip(),
                "artist_slugs": x["artist_slugs"], "artwork_slug": None,
                "source_url": x["source_url"], "source_name": x.get("source_name"), "license": x.get("license"),
                "lang": "ko", "topic": None, "related_artwork_slugs": [],
                "needs_review": needs_review_of(data.get("record_status"), x.get("review_status")),
            })
        elif path.name.startswith("sources.") and path.name != "sources.json":  # md 비교 자료의 출처 목록
            for fname, s in data.items():
                content, lang, title, source_name, needs_review, _ = read_md_document(folder, fname, s)
                cat["documents"].append({
                    "doc_key": f"_comparisons/{fname.removesuffix('.md')}",
                    "doc_type": s["doc_type"], "title": title, "content": content,
                    "artist_slugs": s["artist_slugs"], "artwork_slug": None,
                    "source_url": s["source_url"], "source_name": source_name, "license": s.get("license"),
                    "lang": lang, "topic": s.get("topic"), "related_artwork_slugs": [],
                    "needs_review": needs_review,
                })


# ---------------------------------------------------------------- 검증
def validate(cat: dict) -> list[str]:
    errors = []
    movements = {m["slug"] for m in cat["movements"]}
    artists, artworks = cat["artists"], cat["artworks"]
    for a in artists.values():
        if a.get("movement_slug") not in movements:
            errors.append(f"작가 {a['slug']}: 사조 '{a.get('movement_slug')}' 가 movements 에 없음")
        if not a.get("name"):
            errors.append(f"작가 {a['slug']}: name 없음 (data/mappings/catalog.json 에 추가)")
    for w in artworks.values():
        # 비어 있으면 작가의 사조로 채운 뒤, 채운 값까지 실제로 있는지 검사한다
        w["movement_slug"] = w.get("movement_slug") or artists.get(w["artist_slug"], {}).get("movement_slug")
        if w["movement_slug"] not in movements:
            errors.append(f"작품 {w['slug']}: 사조 '{w['movement_slug']}' 가 movements 에 없음")
        if not SLUG.match(w["slug"]) or len(w["slug"]) > 160:
            errors.append(f"작품 slug 형식 오류: {w['slug']}")
        if w["artist_slug"] not in artists:
            errors.append(f"작품 {w['slug']}: 작가 '{w['artist_slug']}' 없음")
        if not w.get("title"):
            errors.append(f"작품 {w['slug']}: title 없음 (data/mappings/catalog.json 에 추가)")
        if not w.get("description"):
            warnings.append(f"작품 {w['slug']}: 카드 설명 없음 (한국어 해설 문서가 없음)")
    keys = set()
    all_doc_keys = {d["doc_key"] for d in cat["documents"]}
    for d in cat["documents"]:
        k = d["doc_key"]
        if k in keys:
            errors.append(f"문서 키 중복: {k}")
        keys.add(k)
        if d["doc_type"] not in DOC_TYPES:
            errors.append(f"문서 {k}: 허용되지 않는 doc_type '{d['doc_type']}' (허용: {', '.join(sorted(DOC_TYPES))})")
            continue
        if not d.get("source_url"):
            errors.append(f"문서 {k}: source_url 없음")
        if len(d["title"]) > 255:
            errors.append(f"문서 {k}: 제목이 255자 초과")
        if d["doc_type"] == "artwork_commentary" and d["artwork_slug"] not in artworks:
            errors.append(f"문서 {k}: 작품 '{d['artwork_slug']}' 없음")
        if d["doc_type"] == "artist_bio" and len(d["artist_slugs"]) != 1:
            errors.append(f"문서 {k}: 생애 문서는 작가 1명이어야 함")
        if d["doc_type"] == "artist_comparison" and len(d["artist_slugs"]) < 2:
            errors.append(f"문서 {k}: 비교 문서는 작가 2명 이상이어야 함")
        for s in d["artist_slugs"]:
            if s not in artists:
                errors.append(f"문서 {k}: 작가 '{s}' 없음")
        for s in d["related_artwork_slugs"]:
            if s not in artworks:
                errors.append(f"문서 {k}: 관련 작품 '{s}' 없음")
        for basis in d.get("basis_doc_keys", []):
            if basis not in all_doc_keys:
                errors.append(f"문서 {k}: 편집 근거 문서 '{basis}' 없음")
        for source in d.get("basis_external_sources", []):
            if not source.get("source_name") or not source.get("source_url"):
                errors.append(f"문서 {k}: 외부 편집 근거의 source_name/source_url 없음")
        if m := FOREIGN_SCRIPT.search(d["content"]):
            around = d["content"][max(0, m.start() - 10):m.end() + 10].replace("\n", " ")
            warnings.append(f"문서 {k}: 본문에 다른 언어 문자가 섞임 '…{around}…'")
        if len(d["content"]) < MIN_CONTENT and d["topic"] != "연표":  # 연표 사건은 일부러 짧게 씀
            warnings.append(f"문서 {k}: 본문 {len(d['content'])}자로 짧음")
    for slug in artists:
        n_works = sum(1 for w in artworks.values() if w["artist_slug"] == slug)
        n_bio = sum(1 for d in cat["documents"] if d["doc_type"] == "artist_bio" and slug in d["artist_slugs"])
        if n_bio == 0:
            errors.append(f"작가 {slug}: 생애 문서 없음")
        if n_works < MIN_ARTWORKS:
            errors.append(f"작가 {slug}: 작품 {n_works}점 (최소 {MIN_ARTWORKS}점)")
    # 별칭: 수집된 작가는 반드시 있어야 하고, 같은 별칭이 두 작가에 겹치면 안 된다 (챗봇이 작가를 헷갈림)
    owner: dict[str, str] = {}
    for slug, a in cat["aliases"].items():
        for alias in a["aliases"]:
            key = alias.casefold()
            if key in owner and owner[key] != slug:
                errors.append(f"별칭 '{alias}' 가 {owner[key]}, {slug} 두 작가에 겹침")
            owner[key] = slug
    for slug in artists:
        if slug not in cat["aliases"]:
            errors.append(f"작가 {slug}: 별칭 없음 (data/mappings/artist_aliases.json 에 추가)")
    return errors


# ---------------------------------------------------------------- 출력
def jsonl_bytes(rows: list[dict]) -> bytes:
    return "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows).encode("utf-8")


def write_atomic(path: Path, data: bytes) -> None:
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def publish(outputs: dict[str, list[dict]]) -> dict:
    """5개 파일을 .staging 에 모두 만든 뒤 교체하고, 마지막에 _SUCCESS.json 을 쓴다.

    교체 도중에 멈추면 _SUCCESS.json 이 없는 상태로 남으므로, load_processed() 는 그 결과를 읽지 않는다.
    """
    shutil.rmtree(STAGING, ignore_errors=True)
    STAGING.mkdir(parents=True)
    manifest = {"files": {}}
    for name in OUTPUT_FILES:
        data = jsonl_bytes(outputs[name])
        (STAGING / name).write_bytes(data)
        manifest["files"][name] = {"sha256": hashlib.sha256(data).hexdigest(), "rows": len(outputs[name])}
    manifest["needs_review_documents"] = sum(d["needs_review"] for d in outputs["documents.jsonl"])

    SUCCESS.unlink(missing_ok=True)  # 여기부터 _SUCCESS.json 을 다시 쓸 때까지는 '불완전'으로 취급된다
    for name in OUTPUT_FILES:
        os.replace(STAGING / name, OUT / name)
    write_atomic(SUCCESS, (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    FAILED.unlink(missing_ok=True)
    STAGING.rmdir()
    return manifest


def mark_failed(errors: list[str]) -> None:
    """기존 결과와 _SUCCESS.json 은 건드리지 않고, 이번 실행이 실패했다는 기록만 남긴다."""
    shutil.rmtree(STAGING, ignore_errors=True)
    OUT.mkdir(parents=True, exist_ok=True)
    record = {"failed_at": datetime.now(UTC).isoformat(timespec="seconds"), "errors": errors}
    write_atomic(FAILED, (json.dumps(record, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def load_processed(name: str) -> list[dict]:
    """적재 스크립트용. 마지막으로 성공한 결과만 돌려준다.

    _SUCCESS.json 이 없거나 파일 해시가 다르면(교체 도중 중단 등) 예외를 낸다.
    """
    if not SUCCESS.exists():
        raise RuntimeError("data/processed/_SUCCESS.json 이 없습니다. 전처리를 다시 실행하세요.")
    expected = json.loads(SUCCESS.read_text(encoding="utf-8"))["files"][name]["sha256"]
    # git 이 줄바꿈을 CRLF 로 바꿔 받아도 같은 내용으로 본다 (전처리는 항상 LF 로 쓴다)
    data = (OUT / name).read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(data).hexdigest() != expected:
        raise RuntimeError(f"{name} 이 _SUCCESS.json 과 다릅니다. 전처리를 다시 실행하세요.")
    return [json.loads(line) for line in data.decode("utf-8").splitlines()]


# ---------------------------------------------------------------- 실행
def build() -> dict:
    mapping = json.loads(MAPPING.read_text(encoding="utf-8"))
    cat = {"movements": mapping["movements"], "artists": {}, "artworks": {}, "documents": []}
    folders = sorted(p for p in RAW.iterdir() if p.is_dir() and not p.name.startswith("_") and p.name != "schemas")
    for folder in folders:
        if (folder / "dataset.json").exists():
            read_dataset(folder, cat)
        elif (folder / "sources.json").exists():
            read_markdown(folder, cat, mapping)
        else:
            warnings.append(f"{folder.name}: 읽을 수 있는 형식이 아님 (건너뜀)")
            continue
        read_timeline(folder, cat)
    read_comparisons(RAW / "_comparisons", cat)
    initialize_editorial_metadata(cat)
    apply_overrides(cat, mapping)
    apply_document_supplements(cat, read_document_supplements())
    apply_document_corrections(cat, read_document_corrections())
    apply_reviews(cat, read_reviews())
    cat["aliases"] = json.loads(ALIASES.read_text(encoding="utf-8"))["artists"]
    normalize_artist_slugs(cat)
    return cat


def normalize_artist_slugs(cat: dict) -> None:
    """artist_slugs 에 별칭(예: "monet", "모네")이 섞여 들어오면 작가 slug 로 바꾸고 중복을 지운다.

    수집 담당이 별칭을 적어 넣는 일이 실제로 있었다. 멈추지 않고 고친 뒤 경고만 남긴다.
    별칭 목록에도 없는 값은 그대로 두어 검증에서 오류로 잡히게 한다.
    """
    by_alias = {alias.casefold(): slug for slug, a in cat["aliases"].items() for alias in [slug, *a["aliases"]]}
    for d in cat["documents"]:
        fixed = []
        for s in d["artist_slugs"]:
            slug = s if s in cat["artists"] else by_alias.get(s.casefold(), s)
            if slug not in fixed:
                fixed.append(slug)
        if fixed != d["artist_slugs"]:
            warnings.append(f"문서 {d['doc_key']}: artist_slugs {d['artist_slugs']} 를 {fixed} 로 고침 (별칭은 artist_aliases.json 에)")
            d["artist_slugs"] = fixed


def alias_rows(cat: dict) -> list[dict]:
    """Only artists with reviewed material are available to the classifier."""
    available = set()
    for doc in cat["documents"]:
        if doc["needs_review"]:
            continue
        available.update(doc["artist_slugs"])
        work = cat["artworks"].get(doc.get("artwork_slug"))
        if work:
            available.add(work["artist_slug"])
    return [{"slug": slug, "name": a["name"],
             "status": "collected" if slug in available else
                       "pending_review" if slug in cat["artists"] else "planned",
             "aliases": a["aliases"], "confusable": a.get("confusable", [])}
            for slug, a in sorted(cat["aliases"].items())]


def apply_overrides(cat: dict, mapping: dict) -> None:
    """매핑 파일 값을 원본 형식과 관계없이 덮어쓴다 (dataset.json 형식 작가·작품 포함)."""
    for a in cat["artists"].values():
        a["summary"] = card_text(a.get("summary"))
    for w in cat["artworks"].values():
        w["description"] = card_text(w.get("description"))
    for slug, values in mapping["artists"].items():
        if slug in cat["artists"]:
            cat["artists"][slug].update({k: v for k, v in values.items() if k in ARTIST_FIELDS})
    for slug, values in mapping["artworks"].items():
        if slug in cat["artworks"]:
            cat["artworks"][slug].update({k: v for k, v in values.items() if k in ARTWORK_FIELDS})
    for w in cat["artworks"].values():
        w["image_source_url"] = w.get("image_source_url") or commons_page(w.get("image_url"))


def read_reviews() -> dict:
    if not REVIEWS.exists():
        return {}
    return json.loads(REVIEWS.read_text(encoding="utf-8"))["reviews"]


def read_document_supplements() -> dict:
    """원문을 손대지 않고 짧은 문서에 덧붙일, 출처 기반의 편집 보충문을 읽는다."""
    if not SUPPLEMENTS.exists():
        return {}
    return json.loads(SUPPLEMENTS.read_text(encoding="utf-8"))["documents"]


def read_document_corrections() -> dict:
    """원문을 보존하면서 RAG 답변에 반영할 최신 정보·해석상 주의사항을 읽는다."""
    if not CORRECTIONS.exists():
        return {}
    return json.loads(CORRECTIONS.read_text(encoding="utf-8"))["documents"]


def initialize_editorial_metadata(cat: dict) -> None:
    """편집 보강이 없는 문서도 같은 출력 스키마를 갖게 한다."""
    for d in cat["documents"]:
        d.setdefault("basis_doc_keys", [])
        d.setdefault("basis_external_sources", [])


def merge_editorial_basis(d: dict, entry: dict) -> None:
    """보충·보정 근거를 중복 없이 최종 문서 메타데이터에 합친다."""
    d.setdefault("basis_doc_keys", [])
    d.setdefault("basis_external_sources", [])
    for key in entry.get("basis_doc_keys", []):
        if key not in d["basis_doc_keys"]:
            d["basis_doc_keys"].append(key)
    for source in entry.get("basis_external_sources", []):
        if source not in d["basis_external_sources"]:
            d["basis_external_sources"].append(source)


def apply_document_supplements(cat: dict, supplements: dict) -> None:
    """작품별 보충문을 '감상 포인트' 절로 붙인다. 검수 해시는 합쳐진 최종 본문을 기준으로 계산한다."""
    docs = {d["doc_key"]: d for d in cat["documents"]}
    for key, supplement in supplements.items():
        d = docs.get(key)
        if d is None:
            warnings.append(f"보충문 대상 문서 '{key}' 가 없음")
            continue
        missing_basis = [basis for basis in supplement.get("basis_doc_keys", []) if basis not in docs]
        if missing_basis:
            warnings.append(f"문서 {key}: 보충문 근거 문서가 없음 ({', '.join(missing_basis)})")
        content = clean_wiki(supplement.get("content", ""))
        if not content:
            warnings.append(f"문서 {key}: 보충문 내용이 비어 있음")
            continue
        merge_editorial_basis(d, supplement)
        d["content"] = f"{d['content'].rstrip()}\n\n## 감상 포인트\n{content}"


def apply_document_corrections(cat: dict, corrections: dict) -> None:
    """수집 원문을 고치지 않고 최신 사실·불확실성·절단 주의를 RAG 본문 뒤에 붙인다."""
    docs = {d["doc_key"]: d for d in cat["documents"]}
    for key, correction in corrections.items():
        d = docs.get(key)
        if d is None:
            warnings.append(f"보정문 대상 문서 '{key}' 가 없음")
            continue
        missing_basis = [basis for basis in correction.get("basis_doc_keys", []) if basis not in docs]
        if missing_basis:
            warnings.append(f"문서 {key}: 보정문 근거 문서가 없음 ({', '.join(missing_basis)})")
        content = clean_wiki(correction.get("content", ""))
        if not content:
            warnings.append(f"문서 {key}: 보정문 내용이 비어 있음")
            continue
        merge_editorial_basis(d, correction)
        d["content"] = f"{d['content'].rstrip()}\n\n## 답변 시 주의\n{content}"


def apply_reviews(cat: dict, reviews: dict) -> None:
    """검수 장부에 있고 본문 해시가 같으면 검토 완료로 본다. 본문이 바뀌었으면 다시 검토 필요."""
    docs = {d["doc_key"]: d for d in cat["documents"]}
    for key, r in reviews.items():
        d = docs.get(key)
        if d is None:
            warnings.append(f"검수 장부의 문서 '{key}' 가 없음 (원본에서 지워졌거나 이름이 바뀜)")
        elif r["content_sha256"] != content_hash(d["content"]):
            d["needs_review"] = True
            warnings.append(f"문서 {key}: {r['reviewed_on']} 검수 후 본문이 바뀌어 다시 검토가 필요함")
        else:
            d["needs_review"] = False


def review(args: argparse.Namespace) -> int:
    """검수 장부 보기·기록. 기록만 하고 data/processed 는 바꾸지 않는다 (다음 전처리 실행 때 반영)."""
    warnings.clear()
    cat = build()
    pending = sorted(d["doc_key"] for d in cat["documents"] if d["needs_review"])
    if not args.approve:
        for key in pending:
            print(key)
        print(f"검토 필요 {len(pending)}건")
        return 0
    if not args.reviewer:
        print("[오류] --reviewer 로 검수한 사람을 적어 주세요.")
        return 1
    docs = {d["doc_key"]: d for d in cat["documents"]}
    keys = sorted({k for pattern in args.approve for k in docs if fnmatch.fnmatchcase(k, pattern)})
    if not keys:
        print("[오류] 맞는 문서가 없습니다:", ", ".join(args.approve))
        return 1
    reviews = read_reviews()
    today = datetime.now(UTC).astimezone().date().isoformat()
    for k in keys:
        reviews[k] = {"reviewer": args.reviewer, "reviewed_on": today, "content_sha256": content_hash(docs[k]["content"])}
    data = {"_comment": "검수를 마친 문서. 본문 해시가 달라지면 다시 검토 필요로 돌아간다. "
                        "uv run python -m scripts.preprocess review --approve ... 로 기록한다.",
            "reviews": dict(sorted(reviews.items()))}
    write_atomic(REVIEWS, (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    for k in keys:
        print("검수 기록:", k)
    print(f"{len(keys)}건 기록. 전처리를 다시 실행하면 data/processed 에 반영됩니다.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="data/raw → data/processed 전처리")
    sub = parser.add_subparsers(dest="command")
    r = sub.add_parser("review", help="검수 장부 보기·기록")
    r.add_argument("--list", action="store_true", help="검토가 필요한 문서 목록 (기본)")
    r.add_argument("--approve", nargs="+", metavar="DOC_KEY", help="검수 완료로 기록할 doc_key (* 패턴 가능)")
    r.add_argument("--reviewer", help="검수한 사람")
    args = parser.parse_args(argv if argv is not None else [])
    if args.command == "review":
        return review(args)
    return run()


def run() -> int:
    warnings.clear()  # 같은 프로세스에서 다시 실행해도 이전 경고가 남지 않게
    try:
        cat = build()
        errors = validate(cat)
    except (OSError, KeyError, ValueError, TypeError) as exc:  # 원본 파일·형식 오류: 기존 결과는 그대로 두고 실패만 기록
        mark_failed([f"{type(exc).__name__}: {exc}"])
        print(f"[오류] {type(exc).__name__}: {exc}")
        print("data/processed 는 바꾸지 않았습니다. 실패 기록: data/processed/_FAILED.json")
        return 1
    for w in warnings:
        print("[경고]", w)
    if errors:
        mark_failed(errors)
        for e in errors:
            print("[오류]", e)
        print(f"오류 {len(errors)}건. data/processed 는 바꾸지 않았습니다. 실패 기록: data/processed/_FAILED.json")
        return 1

    manifest = publish({
        "movements.jsonl": sorted(cat["movements"], key=lambda r: r["slug"]),
        "artists.jsonl": sorted(cat["artists"].values(), key=lambda r: r["slug"]),
        "artworks.jsonl": sorted(cat["artworks"].values(), key=lambda r: r["slug"]),
        "documents.jsonl": sorted(cat["documents"], key=lambda r: r["doc_key"]),
        "artist_aliases.jsonl": alias_rows(cat),
    })

    print(f"사조 {len(cat['movements'])} · 작가 {len(cat['artists'])} · 작품 {len(cat['artworks'])} · "
          f"문서 {len(cat['documents'])} (검토 필요 {manifest['needs_review_documents']})")
    for slug in sorted(cat["artists"]):
        docs = [d for d in cat["documents"]
                if slug in d["artist_slugs"] or cat["artworks"].get(d["artwork_slug"] or "", {}).get("artist_slug") == slug]
        print(f"  {slug:<18} 작품 {sum(w['artist_slug'] == slug for w in cat['artworks'].values())}점 · "
              f"문서 {len(docs)}건 · 본문 {sum(len(d['content']) for d in docs):,}자")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
