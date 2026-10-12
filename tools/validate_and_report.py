#!/usr/bin/env python3
"""Validate the two raw folders and write a source-coverage table."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
ARTISTS = (("gustav-klimt", "구스타프 클림트"), ("egon-schiele", "에곤 실레"))
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def main():
    all_slugs = set()
    output = [
        "# 클림트·실레 작품별 원문 자료표",
        "",
        "수집일: 2026-10-12 · 팀 가이드의 `data/raw/<작가 slug>/` 형식",
        "",
        "- 작품 60점: 작가별 30점. 생애 원문은 작가별 한국어·영어 각 1건입니다.",
        "- 작품 원문은 모두 영어 위키백과의 공개 텍스트입니다. `*.en.md`는 팀의 번역 단계에서 한국어로 변환해야 합니다.",
        "- `개별 문서`는 해당 작품의 독립 문서, `작품 목록 항목`은 클림트 작품 목록의 표 항목, `작가 페이지 캡션`은 실레 문서 갤러리의 작품별 한 줄입니다. 목록 항목과 짧은 캡션은 검토 대상으로 표시했습니다.",
        "- 원문 글자 수에는 섹션 제목과 참고문헌이 포함됩니다. 공통 생애 문서의 길이는 개별 작품 길이에 더하지 않았습니다.",
        "- `sources.json`에 본문·이미지의 주소와 이용 조건, `artwork`에 위키데이터로 확인한 카드 값이 있습니다. 확인되지 않은 값은 `null`입니다.",
        "- 인용·출처 표시는 각 원문의 위키백과 페이지를 따릅니다. 이미지가 CC BY-SA인 경우 파일 설명 페이지의 저작자·표시 조건도 확인해 표기해야 합니다.",
        "",
    ]
    summary = []
    for artist_slug, artist_name in ARTISTS:
        folder = RAW / artist_slug
        sources = json.loads((folder / "sources.json").read_text(encoding="utf-8"))
        md_names = {path.name for path in folder.glob("*.md")}
        assert md_names == set(sources), (artist_slug, md_names ^ set(sources))
        assert not list(folder.glob("*.ko.md"))
        assert set(sources) >= {"bio.md", "bio.en.md"}
        artworks = []
        short = 0
        review = 0
        for name, record in sources.items():
            content = (folder / name).read_text(encoding="utf-8")
            assert content.strip() and record["source_url"].startswith("https://")
            assert record["license"] == "CC BY-SA 4.0"
            assert record["lang"] == ("en" if name.endswith(".en.md") else "ko")
            assert record["collected_at"] == "2026-10-12"
            if record["doc_type"] == "artist_bio":
                assert record["artist_slugs"] == [artist_slug] and record["artwork_slug"] is None
                continue
            assert record["doc_type"] == "artwork_commentary"
            assert record["artist_slugs"] is None
            assert name == record["artwork_slug"] + ".en.md"
            artwork = record["artwork"]
            slug = artwork["slug"]
            assert SLUG.fullmatch(slug) and slug not in all_slugs
            all_slugs.add(slug)
            assert artwork["artist_slug"] == artist_slug
            assert artwork["year_start"] is None or isinstance(artwork["year_start"], int)
            assert record["image_url"] and record["image_license"] and artwork["image_source_url"]
            chars = len(content.rstrip("\n"))
            short += chars < 200
            review += bool(record["needs_review"])
            artworks.append((artwork, name, record, chars))
        assert len(artworks) == 30, (artist_slug, len(artworks))
        artworks.sort(key=lambda item: (item[0]["year_start"] is None, item[0]["year_start"] or 0, item[0]["slug"]))
        summary.append((artist_slug, len(artworks), short, review))
        output.extend([
            f"## {artist_name} ({len(artworks)}점)",
            "",
            f"생애 원문: [한국어](data/raw/{artist_slug}/bio.md) {len((folder / 'bio.md').read_text(encoding='utf-8')):,}자 · "
            f"[영어](data/raw/{artist_slug}/bio.en.md) {len((folder / 'bio.en.md').read_text(encoding='utf-8')):,}자",
            "",
            "| 번호 | 작품 | 연도 | 개별 원문 | 글자 수 | 검토 | 원문 파일 | 출처 |",
            "| ---: | --- | --- | --- | ---: | --- | --- | --- |",
        ])
        for index, (artwork, name, record, chars) in enumerate(artworks, 1):
            source_kind = (
                "작가 페이지 캡션" if record["source_url"].endswith("/Egon_Schiele")
                else "작품 목록 항목" if record["source_url"].endswith("/List_of_paintings_by_Gustav_Klimt")
                else "개별 문서"
            )
            check = "필요" if record["needs_review"] else "-"
            source_url = record["source_url"].replace("|", "%7C")
            output.append(
                f"| {index} | {artwork['title']} (`{artwork['slug']}`) | {artwork['year_label'] or '-'} | "
                f"{source_kind} | {chars:,} | {check} | [열기](data/raw/{artist_slug}/{name}) | [원문]({source_url}) |"
            )
        output.append("")

    output.extend([
        "## 검수 요약",
        "",
        "| 작가 | 작품 | 200자 미만 | 검토 필요 |",
        "| --- | ---: | ---: | ---: |",
        *[f"| `{artist}` | {count} | {short} | {review} |" for artist, count, short, review in summary],
        "",
        "실레의 짧은 23건은 작품 식별·연도 중심의 캡션입니다. 도슨트 답변 근거로 사용하기 전에 개별 해설 원문을 추가해야 합니다. "
        "영어 원문은 팀의 번역·검수 단계가 끝나기 전까지 한국어 챗봇에 바로 적재할 수 없습니다.",
        "",
        "원본은 `data/raw/`에만 기록했습니다. `data/processed/`와 `data/mappings/`는 수정하지 않았습니다.",
        "",
    ])
    (ROOT / "SOURCE_COVERAGE.md").write_text("\n".join(output), encoding="utf-8")
    print("validated:", summary, "unique slugs:", len(all_slugs))


if __name__ == "__main__":
    main()
