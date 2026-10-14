"""위키미디어 원본 이미지 주소를 Commons API 의 고정 폭 썸네일 주소로 바꿀 매핑을 만든다.

``backend/`` 에서 실행::

    uv run python -m scripts.build_image_thumbnails            # data/mappings/image_thumbnails.json 갱신
    uv run python -m scripts.build_image_thumbnails --dry-run  # 바뀔 개수만 출력

원본 파일(수십~수백 MB)을 직접 링크하면 화면 로딩이 느리고 upload.wikimedia.org 가 429 로
막는다. 원천 데이터(data/raw)는 그대로 두고, 전처리가 이 매핑으로 image_url·portrait_url 만
바꾼다. 매핑에는 원래 주소를 함께 적어 두어, 원천 주소가 바뀌면 예전 썸네일이 적용되지 않게 한다.
Commons API 만 묶어서 부르고 이미지 파일 자체는 내려받지 않는다.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from datetime import date
from urllib.parse import unquote, urlsplit

import httpx

from scripts.check_images import USER_AGENT
from scripts.preprocess import OUT, ROOT, strip_query

THUMBNAILS = ROOT / "data" / "mappings" / "image_thumbnails.json"
API = "https://commons.wikimedia.org/w/api.php"
WIDTH = 1280
BATCH = 10  # iiurlwidth 는 한 번에 많이 물으면 일부 썸네일 주소를 빼고 돌려준다
ALLOWED_HOSTS = {"upload.wikimedia.org", "thumb.wikimedia.org"}
# 위키미디어가 미리 만들어 두는 표준 썸네일 폭. 원본이 WIDTH 보다 작으면 이 중 원본보다 작은 최대 폭을 쓴다.
STANDARD_WIDTHS = (250, 330, 500, 960, 1280)
PAUSE = 2  # 요청 사이 간격(초)
RETRIES = 4
MAX_WAIT = 120

FILE_PATTERNS = (
    re.compile(r"^https://commons\.wikimedia\.org/wiki/Special:(?:FilePath|Redirect/file)/([^?#]+)"),
    re.compile(r"^https://upload\.wikimedia\.org/wikipedia/commons/(?:thumb/)?[0-9a-f]/[0-9a-f]{2}/([^/?#]+)"),
)


def commons_file(url: str | None) -> str | None:
    """위키미디어 이미지 주소에서 Commons 파일 이름을 꺼낸다. 이미 썸네일 주소면 None."""
    if not url or urlsplit(url).hostname == "thumb.wikimedia.org":
        return None
    for pattern in FILE_PATTERNS:
        if m := pattern.match(url):
            return unquote(m.group(1)).replace("_", " ")
    return None


def processed_targets() -> dict[tuple[str, str], tuple[str, str]]:
    """(종류, slug) → (원래 주소, Commons 파일 이름). 산출물이 아닌 원래 주소가 필요하므로
    이미 매핑이 적용된 행은 매핑에 적힌 원래 주소를 쓴다."""
    previous = load_thumbnails()
    targets = {}
    for kind, name, field in (("artworks", "artworks.jsonl", "image_url"), ("artists", "artists.jsonl", "portrait_url")):
        for line in (OUT / name).read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            url = row.get(field)
            entry = previous.get(kind, {}).get(row["slug"])
            if entry and url == entry["thumb"]:
                url = entry["source"]
            if file := commons_file(url):
                targets[(kind, row["slug"])] = (url, file)
    return targets


def is_thumb(url: str) -> bool:
    return "/wikipedia/commons/thumb/" in url


def load_thumbnails() -> dict:
    if not THUMBNAILS.exists():
        return {}
    return json.loads(THUMBNAILS.read_text(encoding="utf-8"))


def query(client: httpx.Client, files: list[str], width: int = WIDTH) -> dict[str, dict]:
    """파일 이름 → imageinfo. 정규화·리다이렉트된 제목도 원래 이름으로 되돌려 붙인다."""
    params = {
        "action": "query", "format": "json", "formatversion": 2, "redirects": 1,
        "prop": "imageinfo", "iiprop": "url|size|mime", "iiurlwidth": width,
        "titles": "|".join(f"File:{f}" for f in files),
    }
    for attempt in range(RETRIES + 1):
        time.sleep(PAUSE)  # API 예절: 한 번에 하나씩, 간격을 두고 묻는다
        resp = client.get(API, params=params)
        if resp.status_code != 429 or attempt == RETRIES:
            break
        header = resp.headers.get("retry-after", "")
        wait = min(float(header) if header.isdigit() else 10 * (attempt + 1), MAX_WAIT)
        print(f"  429 — {wait:.0f}초 기다린 뒤 다시 묻습니다", file=sys.stderr, flush=True)
        time.sleep(wait)
    resp.raise_for_status()
    q = resp.json()["query"]
    back = {}
    for step in ("normalized", "redirects"):
        for x in q.get(step, []):
            back[x["to"]] = back.get(x["from"], x["from"])
    found = {}
    for page in q["pages"]:
        title = back.get(page["title"], page["title"])
        found[title.removeprefix("File:")] = page
    return found


def thumbnail(page: dict | None) -> tuple[str | None, str]:
    """썸네일 주소와, 쓸 수 없을 때의 이유."""
    if page is None or page.get("missing"):
        return None, "Commons 에 파일 없음"
    info = (page.get("imageinfo") or [{}])[0]
    thumb = strip_query(info.get("thumburl"))  # utm_* 추적 파라미터 제거
    if not thumb:
        return None, "썸네일 주소 없음"
    if not is_thumb(thumb):
        return None, f"썸네일이 아닌 원본 주소 (원본 폭 {info.get('width')}px)"
    if urlsplit(thumb).hostname not in ALLOWED_HOSTS:
        return None, f"예상 밖 호스트 {urlsplit(thumb).hostname}"
    if not (info.get("mime") or "").startswith("image/"):
        return None, f"이미지 아님 {info.get('mime')}"
    if (info.get("thumbwidth") or 0) > WIDTH:
        return None, f"폭 {info.get('thumbwidth')}px"
    return thumb, ""


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="파일을 쓰지 않고 개수만 출력")
    args = parser.parse_args(argv)

    targets = processed_targets()
    files = sorted({file for _, file in targets.values()})
    pages: dict[str, dict] = {}
    with httpx.Client(headers={"User-Agent": USER_AGENT}, timeout=30) as client:
        for i in range(0, len(files), BATCH):
            pages.update(query(client, files[i:i + BATCH]))
        # 원본이 WIDTH 보다 작으면 API 가 원본 주소를 준다. 원본 폭보다 작은 표준 폭으로 다시 묻는다.
        by_width: dict[int, list[str]] = {}
        for file, page in pages.items():
            info = (page.get("imageinfo") or [{}])[0]
            if info.get("thumburl") and not is_thumb(info["thumburl"]):
                steps = [s for s in STANDARD_WIDTHS if s < (info.get("width") or 0)]
                if steps:
                    by_width.setdefault(steps[-1], []).append(file)
        for width, group in sorted(by_width.items()):
            for i in range(0, len(group), BATCH):
                pages.update(query(client, group[i:i + BATCH], width))

    result: dict[str, dict] = {"artworks": {}, "artists": {}}
    failed, kept = [], []
    for (kind, slug), (source, file) in sorted(targets.items()):
        page = pages.get(file)
        width = ((page or {}).get("imageinfo") or [{}])[0].get("width") or 0
        if 0 < width <= STANDARD_WIDTHS[0]:  # 원본이 가장 작은 썸네일보다 작으면 원본이 곧 가벼운 파일
            kept.append(f"  {kind}/{slug}: 원본 {width}px 이라 그대로 둠")
            continue
        thumb, reason = thumbnail(page)
        if thumb is None:
            failed.append(f"  {kind}/{slug}: {reason} ({file})")
            continue
        result[kind][slug] = {"source": source, "thumb": thumb}

    total = sum(len(v) for v in result.values())
    print(f"대상 {len(targets)}건 · 썸네일 {total}건 · 원본 유지 {len(kept)}건 · 실패 {len(failed)}건")
    print("\n".join(kept))
    print("\n".join(failed))
    if failed:
        print("실패한 항목이 있어 매핑을 쓰지 않습니다.")
        return 1
    if not args.dry_run:
        THUMBNAILS.write_text(json.dumps({
            "_note": "scripts/build_image_thumbnails.py 가 만든다. 원천 이미지 주소(source)가 "
                     "그대로일 때만 전처리가 Commons API 썸네일(thumb)로 바꾼다.",
            "width": WIDTH,
            "generated": date.today().isoformat(),
            **result,
        }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"썼음: {THUMBNAILS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
