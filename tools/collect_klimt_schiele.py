#!/usr/bin/env python3
"""Collect licensed Wikimedia source text into the team's raw-data layout."""

import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

from research_wiki import category, extract, wikitext

ROOT = Path(__file__).resolve().parents[1] / "data" / "raw"
DATE = "2026-10-12"
HEADERS = {"User-Agent": "DocentResearch/0.1 (local research; https://www.wikidata.org/)"}

# Each row is a distinct work; two Klimt pages about multi-work commissions are excluded.
KLIMT = {
    "Portrait of Adele Bloch-Bauer I": ("portrait-of-adele-bloch-bauer-i", "아델레 블로흐바우어의 초상 I", "Portrait of Adele Bloch-Bauer I"),
    "Apple Tree II": ("apple-tree-ii", "사과나무 II", "Apple Tree II"),
    "Auditorium of the Old Burgtheater": ("auditorium-of-the-old-burgtheater", "옛 부르크극장의 객석", "Auditorium of the Old Burgtheater"),
    "Beethoven Frieze": ("beethoven-frieze", "베토벤 프리즈", "Beethoven Frieze"),
    "Danaë (Klimt)": ("danae-klimt", "다나에", "Danaë"),
    "Death and Life": ("death-and-life", "죽음과 삶", "Death and Life"),
    "Hope I": ("hope-i", "희망 I", "Hope I"),
    "Hope II": ("hope-ii", "희망 II", "Hope II"),
    "Insel im Attersee": ("island-in-the-attersee", "아터제의 섬", "Insel im Attersee"),
    "Johanna Staude": ("portrait-of-johanna-staude", "요한나 슈타우데의 초상", "Johanna Staude"),
    "Judith I": ("judith-i", "유디트 I", "Judith I"),
    "The Kiss (Klimt)": ("the-kiss", "키스", "The Kiss"),
    "Lady with a Fan (Klimt)": ("lady-with-a-fan", "부채를 든 여인", "Lady with a Fan"),
    "The Maiden (Klimt)": ("the-maiden-klimt", "처녀", "The Maiden"),
    "Pallas Athena (Klimt)": ("pallas-athena-klimt", "팔라스 아테나", "Pallas Athena"),
    "The Park (Klimt)": ("the-park-klimt", "공원", "The Park"),
    "Pear Tree (Klimt)": ("pear-tree-klimt", "배나무", "Pear Tree"),
    "Portrait of a Lady (Klimt)": ("portrait-of-a-lady-klimt", "여인의 초상", "Portrait of a Lady"),
    "Portrait of Adele Bloch-Bauer II": ("portrait-of-adele-bloch-bauer-ii", "아델레 블로흐바우어의 초상 II", "Portrait of Adele Bloch-Bauer II"),
    "Portrait of Elisabeth Lederer": ("portrait-of-elisabeth-lederer", "엘리자베트 레더러의 초상", "Portrait of Elisabeth Lederer"),
    "Portrait of Emilie Flöge": ("portrait-of-emilie-floge", "에밀리 플뢰게의 초상", "Portrait of Emilie Flöge"),
    "Portrait of Fräulein Lieser": ("portrait-of-fraulein-lieser", "프롤라인 리저의 초상", "Portrait of Fräulein Lieser"),
    "Schloss by the Water": ("schloss-by-the-water", "물가의 성", "Schloss by the Water"),
    "Schubert at the Piano": ("schubert-at-the-piano", "피아노를 치는 슈베르트", "Schubert at the Piano"),
    "The Three Ages of Woman (Klimt)": ("the-three-ages-of-woman", "여인의 세 시기", "The Three Ages of Woman"),
    "The Tree of Life, Stoclet Frieze": ("the-tree-of-life-stoclet-frieze", "생명의 나무", "The Tree of Life, Stoclet Frieze"),
    "Water Serpents I": ("water-serpents-i", "물뱀 I", "Water Serpents I"),
    "Water Serpents II": ("water-serpents-ii", "물뱀 II", "Water Serpents II"),
    "Women Friends": ("women-friends-klimt", "여자 친구들", "Women Friends"),
}

SCHIELE_ARTICLES = {
    "Dämmernde Stadt": ("city-in-twilight", "황혼의 도시", "City in Twilight"),
    "Dead City III": ("dead-city-iii", "죽은 도시 III", "Dead City III"),
    "Death and the Maiden (Schiele)": ("death-and-the-maiden-schiele", "죽음과 소녀", "Death and the Maiden"),
    "The Family (Schiele)": ("the-family-schiele", "가족", "The Family"),
    "Portrait of Edith (the artist's wife)": ("portrait-of-edith-schiele", "에디트 실레의 초상", "Portrait of Edith (the artist's wife)"),
    "Portrait of Wally": ("portrait-of-wally", "발리의 초상", "Portrait of Wally"),
    "Seated Woman with Bent Knees": ("seated-woman-with-bent-knees", "무릎을 굽히고 앉은 여인", "Seated Woman with Bent Knees"),
}

# The short source text for these 23 works is an unaltered gallery caption from
# the English Wikipedia artist page. Review is required before chatbot use.
SCHIELE_GALLERY = [
    ("self-portrait-striped-shirt-1910", "줄무늬 셔츠를 입은 자화상", "Self-portrait with striped shirt", "Egon Schiele 075.jpg"),
    ("schiele-self-portrait-1910", "자화상 (1910)", "Self-portrait (1910)", "Egon Schiele - Selbstporträt (1910).jpg"),
    ("self-portrait-grimacing-1910", "일그러진 표정의 자화상", "Self-portrait grimacing", "Egon Schiele - Grimassierendes Aktselbstbildnis - 1910.jpeg"),
    ("self-portrait-black-clay-pot", "검은 항아리와 함께한 자화상", "Self-portrait with black clay pot", "Schiele - Selbstbildnis, 1911, 104207.jpg"),
    ("self-portrait-with-lowered-head", "고개를 숙인 자화상", "Self-portrait with lowered head", "Egon Schiele - Selbstporträt mit gesenktem Kopf, 1912.jpg"),
    ("self-portrait-in-jail-1912", "감옥에서 그린 자화상", "Self-portrait in jail", "Egon Schiele - Ich werde für die Kunst und meine Geliebten gerne ausharren - 25-4-1912.jpeg"),
    ("self-portrait-with-brown-background", "갈색 배경의 자화상", "Self-Portrait with Brown Background", "Self-Portrait with Brown Background.jpg"),
    ("lovers-self-portrait-with-wally", "발리와 함께한 연인 자화상", "Lovers – Self-Portrait with Wally", "EGON SCHIELE 1890 - 1918 LIEBESPAAR (SELBSTDARSTELLUNG MIT WALLY) (LOVERS - SELF-PORTRAIT WITH WALLY).jpg"),
    ("girl-with-black-hair-1910", "검은 머리 소녀", "Girl with black hair", "Egon Schiele - Schwarzhaariger Mädchenakt - 1910.jpeg"),
    ("reclining-nude-schiele-1910", "누워 있는 누드 (1910)", "Reclining nude", "Egon Schiele - Liegender weiblicher Akttorso - 1910.jpeg"),
    ("nude-with-red-garters", "붉은 가터를 한 누드", "Nude with Red Garters", "Egon Schiele - Akt mit roten Strumpfbändern.jpg"),
    ("semi-nude-reclining-1911", "누워 있는 반나체 인물", "Semi-nude Reclining", "Schiele - Mädchen mit übereinandergreschlagenen Beinen - 1911.jpg"),
    ("walburga-neuzil-in-black-stockings", "검은 스타킹을 신은 발부르가 노이칠", "Walburga Neuzil in black stockings", "Schiele - Frau mit schwarzen Strümpfen Valerie Neuzil - 1913.jpg"),
    ("friendship-schiele-1913", "우정", "Friendship", "Schiele - Freundschaft - 1913.jpg"),
    ("seated-female-nude-elbows-propped", "팔꿈치를 괴고 앉은 여성 누드", "Seated female nude with elbows propped", "Egon Schiele 085.jpg"),
    ("mother-with-two-children-ii", "두 아이와 어머니 II", "Mother with two children II", "Mother with two children II Egon Schiele 1915.jpg"),
    ("small-town-iii", "작은 도시 III", "Die kleine Stadt III", "Egon Schiele 015.jpg"),
    ("stein-an-der-donau-ii", "도나우강의 슈타인 II", "Stein an der Donau II", "Egon Schiele 088.jpg"),
    ("the-bridge-schiele-1913", "다리", "The Bridge", "Egon Schiele 013.jpg"),
    ("houses-on-the-river", "강가의 집들", "Houses on the River", "Egon Schiele - Häuser am Fluss.jpg"),
    ("house-with-shingle-roof", "널지붕을 얹은 집", "House with Shingle Roof (Old House II)", "House with Shingles Egon Schiele 1915.jpeg"),
    ("old-mill-schiele-1916", "오래된 방앗간", "Old Mill", "Egon Schiele 004.jpg"),
    ("four-trees-schiele-1917", "네 그루의 나무", "Four trees", "Egon Schiele 094.jpg"),
]


def api(host, params):
    url = f"https://{host}/w/api.php?" + urllib.parse.urlencode(params)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=45) as r:
                return json.load(r)
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)


def wiki_url(title, lang="en"):
    return f"https://{lang}.wikipedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_"), safe="()")


def wikipedia_record(title, lang="en"):
    if lang == "en":
        return extract(title)
    data = api(f"{lang}.wikipedia.org", {
        "action": "query", "format": "json", "titles": title,
        "prop": "extracts|pageprops", "explaintext": "1", "redirects": "1",
    })
    return next(iter(data["query"]["pages"].values()))


def wikidata(ids):
    result = {}
    for offset in range(0, len(ids), 45):
        data = api("www.wikidata.org", {
            "action": "wbgetentities", "format": "json", "ids": "|".join(ids[offset:offset + 45]),
            "props": "labels|claims", "languages": "en|ko",
        })
        result.update(data["entities"])
    return result


def claim_value(entity, property_name):
    for claim in entity.get("claims", {}).get(property_name, []):
        if claim.get("rank") == "deprecated":
            continue
        value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
        if value is not None:
            return value
    return None


def qid_label(entity, language="en"):
    return entity.get("labels", {}).get(language, {}).get("value")


def year_from_entity(entity):
    value = claim_value(entity, "P571")
    if isinstance(value, dict):
        match = re.match(r"[+-](\d{4})", value.get("time", ""))
        if match:
            return int(match.group(1))
    return None


def image_licenses(file_names):
    result = {}
    names = list(dict.fromkeys(name for name in file_names if name))
    for offset in range(0, len(names), 40):
        data = api("commons.wikimedia.org", {
            "action": "query", "format": "json",
            "titles": "|".join("File:" + n for n in names[offset:offset + 40]),
            "prop": "imageinfo", "iiprop": "extmetadata", "iilimit": "1",
        })
        for page in data["query"]["pages"].values():
            if not page.get("imageinfo"):
                continue
            license_name = page["imageinfo"][0].get("extmetadata", {}).get("LicenseShortName", {}).get("value")
            if license_name:
                result[page["title"].removeprefix("File:")] = license_name
    return result


def image_fields(name, licenses):
    if not name:
        return None, None, None
    license_name = licenses.get(name)
    if not license_name or not any(s in license_name.lower() for s in ("public domain", "cc0", "cc by", "pd")):
        return None, None, None
    encoded = urllib.parse.quote(name.replace(" ", "_"), safe="()")
    return (
        "https://commons.wikimedia.org/wiki/Special:FilePath/" + encoded,
        "https://commons.wikimedia.org/wiki/File:" + encoded,
        license_name,
    )


def write_doc(folder, filename, content):
    assert content.strip()
    (folder / filename).write_text(content.rstrip() + "\n", encoding="utf-8")


def base_source(doc_type, title, artist_slug, artwork_slug, source_url, lang="en"):
    return {
        "doc_type": doc_type,
        "title": title,
        "artist_slugs": [artist_slug] if doc_type == "artist_bio" else None,
        "artwork_slug": artwork_slug,
        "source_url": source_url,
        "source_name": "위키백과" if lang == "ko" else "Wikipedia (영문)",
        "license": "CC BY-SA 4.0",
        "collected_at": DATE,
        "lang": lang,
        "image_url": None,
        "image_license": None,
        "needs_review": False,
    }


def artwork_data(slug, artist_slug, ko_title, en_title, entity, licenses, year_override=None, image_override=None):
    year = year_override or year_from_entity(entity)
    image_name = image_override or claim_value(entity, "P18")
    image_url, image_source_url, image_license = image_fields(image_name, licenses)
    artwork = {
        "slug": slug,
        "artist_slug": artist_slug,
        "movement_slug": "vienna-secession" if artist_slug == "gustav-klimt" else "expressionism",
        "title": ko_title,
        "title_en": en_title,
        "year_label": str(year) if year else None,
        "year_start": year,
        "medium": None,
        "dimensions": None,
        "collection": None,
        "image_source_url": image_source_url,
        "wikidata": "https://www.wikidata.org/wiki/" + entity["id"] if entity.get("id", "").startswith("Q") else None,
        "is_featured": slug in {
            "the-kiss", "portrait-of-adele-bloch-bauer-i", "judith-i",
            "portrait-of-wally", "death-and-the-maiden-schiele", "the-family-schiele",
        },
    }
    return artwork, image_url, image_license


def enrich_metadata(sources, entities_by_title, gallery):
    """Fill only fields directly attested by Wikidata or a copied gallery caption."""
    referenced = set()
    for entity in entities_by_title.values():
        for property_name in ("P195", "P186"):
            for claim in entity.get("claims", {}).get(property_name, []):
                value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
                if isinstance(value, dict) and value.get("id"):
                    referenced.add(value["id"])
    labels = wikidata(sorted(referenced)) if referenced else {}

    for source in sources.values():
        if source["doc_type"] != "artwork_commentary":
            continue
        artwork = source["artwork"]
        slug = artwork["slug"]
        page_title = next(
            (title for title, record in {**KLIMT, **SCHIELE_ARTICLES}.items() if record[0] == slug),
            None,
        )
        entity = entities_by_title.get(page_title, {})
        collection = claim_value(entity, "P195")
        if isinstance(collection, dict) and collection.get("id") in labels:
            item = labels[collection["id"]]
            artwork["collection"] = qid_label(item, "ko") or qid_label(item, "en")
        materials = []
        for claim in entity.get("claims", {}).get("P186", []):
            value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
            if isinstance(value, dict) and value.get("id") in labels:
                item = labels[value["id"]]
                material = qid_label(item, "ko") or qid_label(item, "en")
                if material and material not in materials:
                    materials.append(material)
        if materials:
            artwork["medium"] = ", ".join(materials)[:255]
        h, w = claim_value(entity, "P2048"), claim_value(entity, "P2049")
        if isinstance(h, dict) and isinstance(w, dict) and h.get("unit") == w.get("unit"):
            unit = h["unit"].split("/")[-1]
            unit_text = {"Q174728": "cm", "Q218593": "mm", "Q11573": "m"}.get(unit)
            if unit_text:
                artwork["dimensions"] = f"{float(h['amount']):g} × {float(w['amount']):g} {unit_text}"
        if slug in gallery:
            caption, _ = gallery[slug]
            for wiki_name, ko_name in (
                ("Leopold Museum", "레오폴트 미술관"),
                ("Thyssen-Bornemisza Museum", "티센보르네미사 미술관"),
                ("Neue Galerie", "노이에 갤러리 뉴욕"),
                ("Österreichische Galerie Belvedere", "오스트리아 벨베데레 미술관"),
            ):
                if wiki_name in caption:
                    artwork["collection"] = ko_name
                    break
    # The rendered source openings give these ranges more precisely than P571.
    year_overrides = {
        "auditorium-of-the-old-burgtheater": ("1888–1889", 1888),
        "beethoven-frieze": ("1902", 1902),
        "death-and-life": ("1908–1915", 1908),
        "hope-ii": ("1907–1908", 1907),
        "island-in-the-attersee": ("1901–1902", 1901),
        "pallas-athena-klimt": ("1898", 1898),
        "portrait-of-a-lady-klimt": ("1916–1917", 1916),
        "portrait-of-adele-bloch-bauer-i": ("1903–1907", 1903),
        "portrait-of-elisabeth-lederer": ("1914–1916", 1914),
        "portrait-of-emilie-floge": ("1902–1908", 1902),
        "portrait-of-johanna-staude": ("1917–1918", 1917),
        "the-kiss": ("1907–1908", 1907),
        "the-park-klimt": ("1909–1910년경", 1909),
        "water-serpents-i": ("1904–1907", 1904),
        "water-serpents-ii": ("1904–1907", 1904),
        "women-friends-klimt": ("1916–1917", 1916),
        "city-in-twilight": ("1913", 1913),
        "small-town-iii": ("1912–1913", 1912),
        "lovers-self-portrait-with-wally": ("1914–1915년경", 1914),
    }
    for source in sources.values():
        if source["doc_type"] != "artwork_commentary":
            continue
        artwork = source["artwork"]
        if artwork["slug"] in year_overrides:
            artwork["year_label"], artwork["year_start"] = year_overrides[artwork["slug"]]


def collect_artist(slug, ko_name, en_name, ko_wiki_title, birth_year, death_year, artist_qid):
    folder = ROOT / slug
    folder.mkdir(parents=True, exist_ok=True)
    sources = {}
    ko = wikipedia_record(ko_wiki_title, "ko")
    en = wikipedia_record(en_name, "en")
    assert "missing" not in ko and len(ko.get("extract", "")) > 200
    assert "missing" not in en and len(en.get("extract", "")) > 200
    write_doc(folder, "bio.md", ko["extract"])
    bio = base_source("artist_bio", f"{ko_name}의 생애", slug, None, wiki_url(ko["title"], "ko"), "ko")
    bio["topic"] = "생애 전체"
    bio["artist"] = {
        "slug": slug, "name": ko_name, "name_en": en_name,
        "movement_slug": "vienna-secession" if slug == "gustav-klimt" else "expressionism",
        "birth_year": birth_year, "death_year": death_year,
        "nationality": "오스트리아", "wikidata": "https://www.wikidata.org/wiki/" + artist_qid,
    }
    sources["bio.md"] = bio
    write_doc(folder, "bio.en.md", en["extract"])
    en_bio = base_source("artist_bio", f"{ko_name}의 생애 (영문)", slug, None, wiki_url(en["title"]))
    en_bio["topic"] = "생애 전체"
    sources["bio.en.md"] = en_bio
    return folder, sources


def main():
    assert len(KLIMT) == 29 and len(SCHIELE_ARTICLES) == 7 and len(SCHIELE_GALLERY) == 23
    available = set(category("Category:Paintings by Gustav Klimt"))
    assert set(KLIMT).issubset(available)
    pages = {}
    for title in list(KLIMT) + list(SCHIELE_ARTICLES):
        page = extract(title)
        assert "missing" not in page, title
        assert len(page.get("extract", "")) > 200, title
        pages[title] = page
    entities_by_title = {}
    qids = [p.get("pageprops", {}).get("wikibase_item") for p in pages.values()]
    entities = wikidata([qid for qid in qids if qid])
    entities.update(wikidata(["Q28001663"]))
    for title, page in pages.items():
        qid = page.get("pageprops", {}).get("wikibase_item")
        entities_by_title[title] = entities.get(qid, {})
    entities_by_title["Fritza Riedler"] = entities["Q28001663"]

    schiele_raw, _ = wikitext("Egon Schiele")
    gallery_lines = [line.strip() for line in schiele_raw.splitlines() if ".jpg|" in line or ".jpeg|" in line]
    gallery = {}
    for slug, ko_title, en_title, filename in SCHIELE_GALLERY:
        matches = [line for line in gallery_lines if filename + "|" in line]
        assert len(matches) == 1, (slug, filename, matches)
        gallery[slug] = (matches[0].split("|", 1)[1], filename)

    all_images = [claim_value(e, "P18") for e in entities_by_title.values()]
    all_images += [entry[3] for entry in SCHIELE_GALLERY]
    licenses = image_licenses(all_images)

    klimt_folder, klimt_sources = collect_artist(
        "gustav-klimt", "구스타프 클림트", "Gustav Klimt", "구스타프 클림트", 1862, 1918, "Q34661"
    )
    for title, (slug, ko_title, en_title) in KLIMT.items():
        page = pages[title]
        filename = slug + ".en.md"
        write_doc(klimt_folder, filename, page["extract"])
        source = base_source("artwork_commentary", ko_title + " 해설 (영문)", "gustav-klimt", slug, wiki_url(page["title"]))
        artwork, source["image_url"], source["image_license"] = artwork_data(
            slug, "gustav-klimt", ko_title, en_title, entities_by_title[title], licenses
        )
        source["artwork"] = artwork
        klimt_sources[filename] = source

    # This single painting has a substantial CC BY-SA catalogue row but no
    # standalone English Wikipedia article. Keep the row's wikitext verbatim.
    fritza_text, _ = wikitext("List of paintings by Gustav Klimt")
    row_start = fritza_text.index("|''Portrait of Fritza Riedler''")
    row_end = fritza_text.index("\n|-", row_start)
    fritza_row = fritza_text[row_start:row_end]
    assert len(fritza_row) > 200
    fritza_slug = "portrait-of-fritza-riedler"
    fritza_filename = fritza_slug + ".en.md"
    write_doc(klimt_folder, fritza_filename, fritza_row)
    fritza_source = base_source(
        "artwork_commentary", "프리차 리들러의 초상 해설 (영문)", "gustav-klimt",
        fritza_slug, wiki_url("List of paintings by Gustav Klimt"),
    )
    artwork, fritza_source["image_url"], fritza_source["image_license"] = artwork_data(
        fritza_slug, "gustav-klimt", "프리차 리들러의 초상", "Portrait of Fritza Riedler",
        entities_by_title["Fritza Riedler"], licenses,
    )
    fritza_source["artwork"] = artwork
    fritza_source["needs_review"] = True
    klimt_sources[fritza_filename] = fritza_source

    schiele_folder, schiele_sources = collect_artist(
        "egon-schiele", "에곤 실레", "Egon Schiele", "에곤 실레", 1890, 1918, "Q44032"
    )
    for title, (slug, ko_title, en_title) in SCHIELE_ARTICLES.items():
        page = pages[title]
        filename = slug + ".en.md"
        write_doc(schiele_folder, filename, page["extract"])
        source = base_source("artwork_commentary", ko_title + " 해설 (영문)", "egon-schiele", slug, wiki_url(page["title"]))
        artwork, source["image_url"], source["image_license"] = artwork_data(
            slug, "egon-schiele", ko_title, en_title, entities_by_title[title], licenses
        )
        source["artwork"] = artwork
        schiele_sources[filename] = source

    for slug, ko_title, en_title, filename_on_commons in SCHIELE_GALLERY:
        caption, _ = gallery[slug]
        year_match = re.search(r"\b(18|19)\d{2}\b", caption)
        year = int(year_match.group(0)) if year_match else None
        filename = slug + ".en.md"
        write_doc(schiele_folder, filename, caption)
        source = base_source("artwork_commentary", ko_title + " 해설 (영문)", "egon-schiele", slug, wiki_url("Egon Schiele"))
        artwork, source["image_url"], source["image_license"] = artwork_data(
            slug, "egon-schiele", ko_title, en_title, {}, licenses,
            year_override=year, image_override=filename_on_commons,
        )
        source["artwork"] = artwork
        source["needs_review"] = True
        schiele_sources[filename] = source

    enrich_metadata(klimt_sources, entities_by_title, gallery)
    enrich_metadata(schiele_sources, entities_by_title, gallery)

    for folder, sources in ((klimt_folder, klimt_sources), (schiele_folder, schiele_sources)):
        (folder / "sources.json").write_text(
            json.dumps(dict(sorted(sources.items())), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        count = sum(record["doc_type"] == "artwork_commentary" for record in sources.values())
        short = sum(len((folder / name).read_text(encoding="utf-8")) < 200 for name, record in sources.items() if record["doc_type"] == "artwork_commentary")
        print(folder, "artworks", count, "short", short, "images", sum(bool(record.get("image_url")) for record in sources.values()))


if __name__ == "__main__":
    main()
