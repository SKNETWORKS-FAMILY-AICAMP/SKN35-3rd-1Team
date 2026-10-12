#!/usr/bin/env python3
"""Inspect public Wikimedia source coverage for the docent raw-data task."""

import json
import sys
import urllib.parse
import urllib.request

HEADERS = {"User-Agent": "DocentResearch/0.1 (local research; https://www.wikidata.org/)"}


def api(host, params):
    url = f"https://{host}/w/api.php?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=40) as response:
        return json.load(response)


def extract(title):
    data = api("en.wikipedia.org", {
        "action": "query", "format": "json", "titles": title,
        "prop": "extracts|pageprops", "explaintext": "1", "redirects": "1",
    })
    return next(iter(data["query"]["pages"].values()))


def wikitext(title):
    data = api("en.wikipedia.org", {
        "action": "query", "format": "json", "titles": title,
        "prop": "revisions", "rvprop": "content", "rvslots": "main",
        "redirects": "1",
    })
    page = next(iter(data["query"]["pages"].values()))
    return page["revisions"][0]["slots"]["main"]["*"], page


def category(title):
    data = api("en.wikipedia.org", {
        "action": "query", "format": "json", "list": "categorymembers",
        "cmtitle": title, "cmnamespace": "0", "cmlimit": "500",
    })
    return [entry["title"] for entry in data["query"]["categorymembers"]]


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "schiele":
        page = extract("Egon Schiele")
        body = page["extract"]
        start = body.find("== Gallery ==")
        print("length", len(body), "gallery", start)
        print(body[start : start + 8000] if start >= 0 else body[:8000])
    elif mode == "klimt":
        for title in category("Category:Paintings by Gustav Klimt"):
            page = extract(title)
            print(title, len(page.get("extract", "")), page.get("pageprops", {}).get("wikibase_item"))
    elif mode == "schiele-wiki":
        body, _ = wikitext("Egon Schiele")
        start = body.find("==Self-portraits==")
        print("length", len(body), "gallery", start)
        print(body[start : start + 11000] if start >= 0 else body[-11000:])
