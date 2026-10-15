"""국립중앙박물관·메트로폴리탄 미술관 원본 이미지를 줄인 사본으로 만들어 프론트 정적 파일로 둔다.

``backend/`` 에서 실행 (Pillow 는 이 작업에만 쓰므로 프로젝트 의존성에 넣지 않는다)::

    uv run --with pillow python -m scripts.build_local_images            # 사본과 매핑 갱신
    uv run --with pillow python -m scripts.build_local_images --dry-run  # 대상만 출력
    uv run --with pillow python -m scripts.build_local_images --force    # 이미 있는 사본도 다시 만듦

museum.go.kr·images.metmuseum.org 이미지는 장당 2~10MB 원본뿐이고 썸네일 주소와 CORS 헤더가 없다.
museum.go.kr 은 서버 응답도 자주 수십 초씩 멈춘다. 그래서 작품 목록이 회색 칸으로 남는다. 긴 변 1280px JPEG 사본을
``frontend/web/images/artworks/{slug}.jpg`` 에 두면 Vercel 이 같은 도메인에서 내보낸다.
원천 데이터(data/raw)는 그대로 두고, 전처리가 ``data/mappings/local_images.json`` 으로
image_url 만 ``/images/artworks/{slug}.jpg`` 로 바꾼다. 출처 페이지(image_source_url)는 그대로다.
공공누리 '변경금지' 유형은 크기도 바꾸지 않고 원본 주소를 그대로 둔다.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
import time

import httpx
from PIL import Image

from app.core import timeutil
from scripts.check_images import USER_AGENT
from scripts.preprocess import ROOT, load_processed

MAPPING = ROOT / "data" / "mappings" / "local_images.json"
OUT_DIR = ROOT / "frontend" / "web" / "images" / "artworks"
PUBLIC_PREFIX = "/images/artworks/"
HOSTS = ("www.museum.go.kr", "museum.go.kr", "images.metmuseum.org")
LONG_SIDE = 1280
QUALITY = 82
RETRIES = 4
TIMEOUT = httpx.Timeout(120, connect=30)


def load_mapping() -> dict:
    if not MAPPING.exists():
        return {}
    return json.loads(MAPPING.read_text(encoding="utf-8")).get("artworks", {})


def targets() -> dict[str, str]:
    """slug → 원래 이미지 주소. 이미 매핑이 적용된 행은 매핑에 적힌 원래 주소를 쓴다."""
    previous = load_mapping()
    found = {}
    for w in load_processed("artworks.jsonl"):
        url = w.get("image_url") or ""
        if url.startswith(PUBLIC_PREFIX) and w["slug"] in previous:
            url = previous[w["slug"]]["source"]
        if "변경금지" in (w.get("image_license") or ""):
            continue
        if any(f"//{h}/" in url for h in HOSTS):
            found[w["slug"]] = url
    return found


def download(client: httpx.Client, url: str) -> bytes:
    for attempt in range(RETRIES + 1):
        try:
            resp = client.get(url)
            resp.raise_for_status()
            return resp.content
        except (httpx.HTTPError, httpx.StreamError) as e:
            if attempt == RETRIES:
                raise
            wait = 5 * (attempt + 1)
            print(f"    다시 시도 {attempt + 1}/{RETRIES} ({type(e).__name__}), {wait}초 뒤")
            time.sleep(wait)
    raise AssertionError("unreachable")


def shrink(data: bytes) -> bytes:
    with Image.open(io.BytesIO(data)) as im:
        im = im.convert("RGB")
        im.thumbnail((LONG_SIDE, LONG_SIDE), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        im.save(out, "JPEG", quality=QUALITY, optimize=True, progressive=True)
        return out.getvalue()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="대상만 출력")
    parser.add_argument("--force", action="store_true", help="이미 있는 사본도 다시 만듦")
    args = parser.parse_args(argv)

    todo = targets()
    print(f"대상 {len(todo)}점")
    if args.dry_run:
        for slug, url in sorted(todo.items()):
            print(f"  {slug}  {url}")
        return 0

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    mapping, failed = {}, []
    headers = {"User-Agent": USER_AGENT}
    with httpx.Client(headers=headers, timeout=TIMEOUT, follow_redirects=True) as client:
        for i, (slug, url) in enumerate(sorted(todo.items()), 1):
            path = OUT_DIR / f"{slug}.jpg"
            if path.exists() and not args.force:
                print(f"[{i}/{len(todo)}] {slug}: 사본 있음")
            else:
                try:
                    original = download(client, url)
                    small = shrink(original)
                except Exception as e:  # noqa: BLE001 - 한 장 실패로 나머지를 멈추지 않는다
                    print(f"[{i}/{len(todo)}] {slug}: 실패 {type(e).__name__}: {e}")
                    failed.append(slug)
                    continue
                path.write_bytes(small)
                print(f"[{i}/{len(todo)}] {slug}: {len(original) / 1e6:.1f}MB → {len(small) / 1e3:.0f}KB")
            mapping[slug] = {"source": url, "thumb": f"{PUBLIC_PREFIX}{slug}.jpg"}

    MAPPING.write_text(json.dumps({
        "_note": "scripts/build_local_images.py 가 만든다. 원천 이미지 주소(source)가 그대로일 때만 "
                 "전처리가 프론트 정적 사본(thumb)으로 바꾼다.",
        "long_side": LONG_SIDE,
        "generated": timeutil.utcnow().date().isoformat(),
        "artworks": dict(sorted(mapping.items())),
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"매핑 {len(mapping)}점 저장: {MAPPING.relative_to(ROOT)}")
    if failed:
        print("실패해서 원본 주소를 유지: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
