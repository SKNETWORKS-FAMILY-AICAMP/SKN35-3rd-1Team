"""영어 원문(lang=en)을 한국어로 번역해 data/raw/<작가>/<원본 이름>.ko.md 로 저장한다.

번역은 한 번만 하고 결과 파일을 저장소에 둔다. 전처리(preprocess.py)는 번역본이 있으면
영어 원문 대신 번역본을 문서로 내보낸다. 같은 내용이 한국어·영어로 두 번 들어가 검색 결과가
겹치는 것을 막기 위해서다.

sources.json 항목에 번역 기록(translation)을 남긴다. 원문이 바뀌면 source_sha256 이 달라지므로
전처리가 경고하고, 이 스크립트를 다시 돌리면 그 문서만 새로 번역한다.

실행 (backend/ 에서):
    uv run python -m scripts.translate --artists rembrandt caravaggio
    uv run python -m scripts.translate --artists rembrandt --files the-jewish-bride.en.md   # 한 건만
"""

import argparse
import json
import re
import sys
import time
from datetime import UTC, datetime

import requests
from dotenv import dotenv_values

from scripts.preprocess import RAW, ROOT, clean_wiki, content_hash, write_atomic

MODEL = "gpt-5.4-mini"
MAX_CHARS = 4000  # 요청 하나에 넣을 원문 길이. 섹션 경계에서 자른다

# 이미 연표·카드에서 쓰는 표기. 번역본도 같은 이름을 써야 검색과 답변에서 표기가 흔들리지 않는다.
GLOSSARY = """\
Rembrandt Harmenszoon van Rijn = 렘브란트 하르먼손 판 레인 / Rembrandt = 렘브란트
Saskia van Uylenburgh = 사스키아 판 아윌렌뷔르흐 / Hendrick van Uylenburgh = 헨드릭 판 아윌렌뷔르흐
Hendrickje Stoffels = 헨드리케 스토펠스 / Titus van Rijn = 티투스 판 레인 / Cornelia = 코르넬리아
Geertje Dircx = 헤이르처 디르크스 / Magdalena van Loo = 막달레나 판 로 / Titia = 티티아
Pieter Lastman = 피터르 라스트만 / Jan Lievens = 얀 리번스 / Constantijn Huygens = 콘스탄테인 하위헌스
Nicolaes Tulp = 니콜라스 튈프 / Frans Banninck Cocq = 프란스 바닝 코크
Leiden = 레이던 / Amsterdam = 암스테르담 / Jodenbreestraat = 요덴브레이스트라트 / Westerkerk = 베스테르케르크
Rijksmuseum = 암스테르담 국립미술관 / Mauritshuis = 마우리츠하위스 미술관 / Hermitage Museum = 에르미타주 미술관
The Night Watch = 야경 / The Anatomy Lesson of Dr. Nicolaes Tulp = 니콜라스 튈프 박사의 해부학 수업
The Jewish Bride = 유대인 신부 / The Return of the Prodigal Son = 돌아온 탕자
Self-Portrait with Beret and Turned-Up Collar = 베레모와 세운 옷깃의 자화상
Michelangelo Merisi da Caravaggio = 미켈란젤로 메리시 다 카라바조 / Caravaggio = 카라바조
Simone Peterzano = 시모네 페테르차노 / Francesco Maria del Monte = 프란체스코 마리아 델 몬테
Ranuccio Tomassoni = 라누치오 토마소니 / Fillide Melandroni = 필리데 멜란드로니 / Mario Minniti = 마리오 민니티
Ciriaco Mattei = 치리아코 마테이 / Vincenzo Giustiniani = 빈첸초 주스티니아니 / Scipione Borghese = 시피오네 보르게세
Costanza Colonna = 코스탄차 콜론나 / Alof de Wignacourt = 알로프 드 비냐쿠르 / Knights of Malta = 몰타 기사단
San Luigi dei Francesi = 산 루이지 데이 프란체시 성당 / Contarelli Chapel = 콘타렐리 예배당 / Porto Ercole = 포르토 에르콜레
The Calling of Saint Matthew = 성 마태오를 부르심 / Supper at Emmaus = 엠마오의 만찬
David with the Head of Goliath = 골리앗의 머리를 든 다윗 / Judith Beheading Holofernes = 홀로페르네스의 목을 베는 유디트
The Incredulity of Saint Thomas = 의심하는 성 토마스 / Caravaggisti = 카라바조 화파
chiaroscuro = 키아로스쿠로 / tenebrism = 테네브리즘 / Baroque = 바로크
"""

SYSTEM = f"""너는 미술사 문서를 한국어로 옮기는 번역가다. 위키백과 영어 원문을 한국어로 번역한다.
규칙:
- 내용을 빼거나 보태지 말고, 요약하지 말고, 문장 단위로 충실하게 옮긴다.
- 사실, 연도, 숫자, 인용은 원문 그대로 유지한다. 확실하지 않은 표현(possibly, likely 등)의 정도도 그대로 살린다.
- '## 제목', '### 제목' 같은 마크다운 제목 줄은 '#' 개수를 유지하고 제목만 번역한다. 문단 구분도 유지한다.
- 아래 용어집의 표기를 반드시 따른다. 용어집에 없는 고유명사는 국립국어원 외래어 표기법을 따르고, 처음 나올 때만 괄호 안에 원어를 적는다.
- 작품 제목은 『』로 감싼다.
- 번역문만 출력한다. 설명이나 머리말을 붙이지 않는다.

용어집:
{GLOSSARY}"""


def split_sections(text: str, limit: int = MAX_CHARS) -> list[str]:
    """제목 줄과 문단 경계에서 잘라 요청 하나가 limit 를 넘지 않게 한다."""
    blocks = re.split(r"\n(?=#{2,4} )|\n\n", text)
    parts, cur = [], ""
    for b in blocks:
        b = b.strip()
        if not b:
            continue
        if cur and len(cur) + len(b) + 2 > limit:
            parts.append(cur)
            cur = b
        else:
            cur = f"{cur}\n\n{b}" if cur else b
    if cur:
        parts.append(cur)
    return parts


def translate(session: requests.Session, text: str) -> str:
    for attempt in range(6):
        r = session.post(
            "https://api.openai.com/v1/chat/completions",
            json={"model": MODEL, "messages": [{"role": "system", "content": SYSTEM},
                                               {"role": "user", "content": text}]},
            timeout=300,
        )
        if r.status_code in (429, 500, 502, 503):
            time.sleep(5 * (attempt + 1))
            continue
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"].strip()
    raise RuntimeError("번역 요청이 계속 실패했습니다")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="영어 원문을 한국어로 번역")
    parser.add_argument("--artists", nargs="+", required=True, help="작가 slug (data/raw 폴더 이름)")
    parser.add_argument("--files", nargs="+", help="이 파일만 번역 (기본: lang=en 인 md 전부)")
    parser.add_argument("--force", action="store_true", help="원문이 그대로여도 다시 번역")
    args = parser.parse_args(argv)

    key = dotenv_values(ROOT / ".env").get("OPENAI_API_KEY")
    if not key:
        print("[오류] .env 에 OPENAI_API_KEY 가 없습니다.")
        return 1
    session = requests.Session()
    session.headers["Authorization"] = f"Bearer {key}"

    for artist in args.artists:
        folder = RAW / artist
        src_path = folder / "sources.json"
        sources = json.loads(src_path.read_text(encoding="utf-8"))
        for fname, s in sources.items():
            if not fname.endswith(".md") or s.get("lang") != "en":
                continue
            if args.files and fname not in args.files:
                continue
            original = clean_wiki((folder / fname).read_text(encoding="utf-8"))
            digest = content_hash(original)
            done = s.get("translation")
            out = folder / f"{fname.removesuffix('.md')}.ko.md"
            if done and done["source_sha256"] == digest and out.exists() and not args.force:
                print(f"건너뜀 (이미 번역됨): {artist}/{fname}")
                continue
            parts = split_sections(original)
            print(f"번역: {artist}/{fname} ({len(original):,}자, {len(parts)}개 요청)", flush=True)
            translated = "\n\n".join(translate(session, p) for p in parts)
            out.write_text(translated + "\n", encoding="utf-8")
            s["translation"] = {
                "file": out.name, "model": MODEL, "translated_on": datetime.now(UTC).astimezone().date().isoformat(),
                "source_sha256": digest,
            }
            # 문서 하나 끝날 때마다 기록해 두면 중간에 멈춰도 다음 실행 때 이어서 한다
            write_atomic(src_path, (json.dumps(sources, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
            print(f"  → {out.name} ({len(translated):,}자)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
