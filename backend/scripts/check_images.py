"""data/processed 의 작품 이미지·작가 초상 URL이 실제로 열리는지 확인한다.

``backend/`` 에서 실행::

    uv run python -m scripts.check_images                 # 전체 확인
    uv run python -m scripts.check_images --artist rembrandt
    uv run python -m scripts.check_images --json out.json # 결과를 파일로도 남김

리다이렉트를 따라가 최종 응답의 상태 코드·형식·크기를 본다. 이미지가 아니거나,
2xx 가 아니거나, 너무 커서 화면에서 실패할 만한 URL을 문제로 보고 종료 코드 1을 낸다.
위키미디어는 요청이 몰리면 429 를 주므로 동시 요청을 적게 두고 Retry-After 만큼 기다린 뒤 다시 묻는다.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from urllib.parse import urlsplit

import httpx

from scripts.preprocess import ROOT, load_processed

USER_AGENT = "ArtLogImageCheck/1.0 (SKN35-3rd-1Team; image URL audit)"
MAX_BYTES = 20 * 1024 * 1024  # 이보다 크면 모바일·웹에서 로딩 실패 위험
RETRIES = 3
MAX_WAIT = 20  # Retry-After 가 길게 와도 이 이상은 기다리지 않음
WORKERS = 2


@dataclass
class Result:
    kind: str  # artwork | portrait
    artist: str
    slug: str
    title: str
    url: str
    status: int | None = None
    final_host: str = ""
    content_type: str = ""
    size: int | None = None
    problem: str = ""


def targets(artist: str | None) -> list[Result]:
    rows = []
    for a in load_processed("artists.jsonl"):
        if a.get("portrait_url") and artist in (None, a["slug"]):
            rows.append(Result("portrait", a["slug"], a["slug"], a["name"], a["portrait_url"]))
    for w in load_processed("artworks.jsonl"):
        if artist not in (None, w["artist_slug"]):
            continue
        rows.append(Result("artwork", w["artist_slug"], w["slug"], w["title"], w.get("image_url") or ""))
    return rows


def fetch(client: httpx.Client, url: str) -> httpx.Response:
    """HEAD 로 먼저 묻고, HEAD 를 받지 않는 서버면 본문을 읽지 않는 GET 으로 다시 묻는다."""
    resp = client.head(url)
    if resp.status_code in (403, 405, 501):
        with client.stream("GET", url) as streamed:
            return streamed
    return resp


def check(client: httpx.Client, r: Result) -> Result:
    if not r.url:
        r.problem = "URL 없음"
        return r
    if r.url.startswith("/"):
        # 프론트가 같은 도메인에서 내보내는 정적 사본 (scripts/build_local_images.py)
        path = ROOT / "frontend" / "web" / r.url.lstrip("/")
        r.final_host = "frontend/web"
        if not path.is_file():
            r.problem = "정적 사본 파일 없음"
        else:
            r.status, r.content_type, r.size = 200, "image/jpeg", path.stat().st_size
        return r
    for attempt in range(RETRIES + 1):
        try:
            resp = fetch(client, r.url)
        except httpx.HTTPError as e:
            r.problem = f"요청 실패: {type(e).__name__}"
            return r
        if resp.status_code != 429 or attempt == RETRIES:
            break
        header = resp.headers.get("retry-after", "")
        wait = float(header) if header.isdigit() else 2 ** (attempt + 1)
        if wait > MAX_WAIT:  # 몇 분짜리 차단이면 기다리지 않고 그대로 보고
            break
        time.sleep(wait)
    r.status = resp.status_code
    r.final_host = urlsplit(str(resp.url)).hostname or ""
    r.content_type = resp.headers.get("content-type", "").split(";")[0]
    length = resp.headers.get("content-length")
    r.size = int(length) if length and length.isdigit() else None
    if resp.status_code == 429:
        r.problem = f"HTTP 429 (요청 제한, {resp.headers.get('retry-after', '?')}초)"
    elif not 200 <= resp.status_code < 300:
        r.problem = f"HTTP {resp.status_code}"
    elif not r.content_type.startswith("image/"):
        r.problem = f"이미지 아님 ({r.content_type or '형식 없음'})"
    elif r.size and r.size > MAX_BYTES:
        r.problem = f"너무 큼 ({r.size / 1024 / 1024:.0f}MB)"
    print(".", end="", file=sys.stderr, flush=True)
    return r


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--artist", help="작가 slug 하나만 확인")
    parser.add_argument("--json", help="전체 결과를 저장할 JSON 경로")
    args = parser.parse_args(argv)

    rows = targets(args.artist)
    headers = {"User-Agent": USER_AGENT}
    with (
        httpx.Client(headers=headers, follow_redirects=True, timeout=30) as client,
        ThreadPoolExecutor(WORKERS) as pool,
    ):
        results = list(pool.map(lambda r: check(client, r), rows))

    hosts = Counter(urlsplit(r.url).hostname for r in results if r.url)
    problems = [r for r in results if r.problem]
    print(f"확인 {len(results)}건 · 정상 {len(results) - len(problems)} · 문제 {len(problems)}")
    print("원래 URL 호스트: " + ", ".join(f"{h} {n}" for h, n in hosts.most_common()))
    for r in problems:
        print(f"  [{r.kind}] {r.artist}/{r.slug} 《{r.title}》 {r.problem}\n      {r.url}")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump([asdict(r) for r in results], f, ensure_ascii=False, indent=2)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
