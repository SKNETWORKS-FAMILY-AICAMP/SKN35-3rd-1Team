"""질문을 검색 전에 분류한다 (수퍼바이저). LLM 을 부르지 않는 규칙 기반이라 빠르고 비용이 없다.

    route = classify_artwork(db, artwork_id, question)   # /chat 에서는 이것만 부르면 된다
    route.kind  →  "rag" | "other_artist" | "refuse" | "recommend_similar" | "recommend_personal"

| kind | 언제 | /chat 에서 할 일 |
| --- | --- | --- |
| rag | 기본값. 고른 작품·작가에 관한 질문 | retrieve() → 답변 체인 |
| other_artist | 데이터에 있는 **다른** 작가만 묻고, 고른 작가·비교·관계 표현이 없음 | 그 작가 작품을 골라 물어보라고 안내 (route.artists) |
| refuse | 검수 대기·미수집 작가, 다루지 않는 작가(피카소 등), 날씨·실시간 시세 같은 범위 밖 질문 | LLM 없이 refused=true |
| recommend_similar | "이 작품과 비슷한 작품 추천해 줘" | recommendation_service.similar() (고른 작품 기준) |
| recommend_personal | "내 취향에 맞는 작품 추천해 줘" | 로그인 사용자면 recommend_artworks(), 비로그인이면 similar() 로 대신 |

원칙: **잘못 거절하는 것이 더 나쁘다.** 확실할 때만 refuse/other_artist 로 보내고 애매하면 rag 로 둔다.
rag 로 간 질문도 답변 프롬프트의 "근거에 없으면 거절" 규칙이 한 번 더 거른다. 그래서
- 고른 작품을 가리키는 말("이 그림", "이 작품")이나 관계·영향·비교 표현이 있으면 다른 작가 이름이 나와도 rag
  (예: 세잔 작품에서 "피사로와는 어떤 관계였어?" → 세잔 문서에 답이 있음).
- 작가 이름은 artist_aliases.jsonl(전처리 결과)로 알아본다. 헷갈리는 이름(마네, 강원도 정선, 미켈란젤로 부오나로티 등)은
  우리 작가로 잡지 않는다.
- 범위 밖 작가 이름이 나와도 그 이름이 고른 작품의 범위 문서에 나오면 rag (classify_artwork 가 TiDB 로 확인).
  예: 세잔 『현대의 올랭피아』에서 "마네의 올랭피아를 패러디한 거야?" → 세잔 문서에 마네가 나옴.
"""

import re
from collections.abc import Callable
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Literal

Kind = Literal["rag", "other_artist", "refuse", "recommend_similar", "recommend_personal"]

# 데이터에 없는 유명 작가. 이 이름만 묻는 질문은 "다루지 않는 작가"로 거절한다.
OUT_OF_SCOPE_ARTISTS = (
    "피카소", "Picasso", "레오나르도 다 빈치", "다빈치", "다 빈치", "Leonardo da Vinci", "da Vinci",
    "미켈란젤로 부오나로티", "Michelangelo Buonarroti", "라파엘로", "Raphael", "마네", "Manet",
    "르누아르", "Renoir", "드가", "Degas", "뭉크", "Munch", "살바도르 달리", "달리", "Dalí", "Dali",
    "앤디 워홀", "워홀", "Warhol", "마티스", "Matisse", "샤갈", "Chagall", "칸딘스키", "Kandinsky",
    "몬드리안", "Mondrian", "페르메이르", "베르메르", "Vermeer", "벨라스케스", "Velázquez", "Velazquez",
    "고야", "Goya", "터너", "Turner", "쇠라", "Seurat", "시슬레", "Sisley", "피사로", "Pissarro",
    "로댕", "Rodin", "바스키아", "Basquiat", "호크니", "Hockney", "쿠사마 야요이", "Kusama",
    "신윤복", "혜원", "김정희", "추사", "이중섭", "박수근", "장승업", "김환기", "천경자",
)
# 고른 작품을 가리키는 말. 있으면 다른 작가 이름이 나와도 그 작품에 관한 질문으로 본다.
DEICTIC = ("이 그림", "이 작품", "이 화가", "이 작가", "그림에", "그림 속", "작품 속", "이번 그림")
# 작가 사이의 관계·영향·비교를 묻는 표현. 범위 안 생애·비교 문서에 답이 있을 수 있다.
RELATION = ("관계", "영향", "만났", "만난", "친구", "스승", "제자", "배웠", "함께", "같이", "교류", "비교", "차이",
            "달라", "다른 점", "다르게", "공통", "닮", "비슷한 점", "모방", "따라")
# 이 서비스가 답할 수 없는 실시간·생활 정보
OFF_TOPIC = re.compile(
    r"날씨|미세먼지|기온|환율|주가|주식|코인|맛집|교통|뉴스|로또|"
    r"(오늘|지금|현재|실시간)[^?]{0,12}(가격|시세|시가|값|얼마)|"
    r"(싸게|최저가|구매|구입|살 수 있는|파는|판매하는)[^?]{0,12}(사이트|곳|쇼핑몰|링크)|"
    r"(사이트|쇼핑몰)[^?]{0,8}(찾아|알려)"
)
# 로그인 사용자 취향 기준 추천. 일반 추천보다 먼저 본다.
RECOMMEND_PERSONAL = re.compile(
    r"취향|내가\s?좋아(할|하는|했던)|나(한테|에게)\s?(맞는|어울리는|맞춤)|맞춤\s?(추천|작품)|내\s?스타일|"
    r"좋아요\s?(한|누른)|내가\s?(본|봤던)\s?(작품|그림)"
)
RECOMMEND = re.compile(r"추천|비슷한\s?(작품|그림)|이런\s?(작품|그림)[을를]?\s?더|다른\s?작품[^?]{0,6}(보여|알려)")
# 이름 뒤에 붙어도 되는 조사 (마네킹·정선군처럼 다른 낱말의 일부는 이름으로 보지 않기 위해)
PARTICLES = ("의", "가", "이", "는", "은", "를", "을", "와", "과", "랑", "이랑", "하고", "에게", "한테", "께서",
             "도", "만", "처럼", "보다", "로", "으로", "에", "라는", "란", "씨", "가요", "는요", "요", "?", "!")
HANGUL = re.compile(r"[가-힣]")


@dataclass(frozen=True)
class Route:
    kind: Kind
    reason: str | None = None  # refuse: "unreviewed_artist" | "uncollected_artist" | "unknown_artist" | "off_topic" | "unknown_artwork"
    artists: tuple[str, ...] = ()  # 질문에 나온 데이터 안 작가 slug
    names: tuple[str, ...] = ()  # 질문에 나온 범위 밖 작가 이름 (안내 문구용)
    matched: tuple[str, ...] = field(default=(), compare=False)  # 디버깅용: 걸린 규칙


@dataclass(frozen=True)
class _Artist:
    slug: str
    name: str
    collected: bool
    aliases: tuple[str, ...]
    confusable: tuple[str, ...]
    pending_review: bool = False


def classify_artwork(session, artwork_id: int, question: str) -> Route:
    """/chat 용. 고른 작품의 작가를 찾고, 범위 밖 작가 이름이 그 작품의 범위 문서에 나오는지 TiDB 로 확인한다."""
    from app.repositories import document_repository as repo

    artist = repo.artwork_artist_slug(session, artwork_id)
    if artist is None:
        return Route("refuse", "unknown_artwork", matched=("unknown_artwork",))
    scope: list[int] | None = None

    def named_in_scope(name: str) -> bool:
        nonlocal scope
        scope = repo.scope_document_ids(session, artwork_id) if scope is None else scope
        return repo.name_in_scope(session, scope, name)

    return classify(question, artist, named_in_scope)


def classify(question: str, artist_slug: str, named_in_scope: Callable[[str], bool] | None = None) -> Route:
    """artist_slug: 고른 작품의 작가 slug (예: "rembrandt").

    named_in_scope: 이름이 고른 작품의 범위 문서에 나오는지 알려 주는 함수. 주면 범위 밖 작가로 거절하기 전에 확인한다.
    """
    text = question.strip()
    if OFF_TOPIC.search(text):
        return Route("refuse", "off_topic", matched=("off_topic",))
    if RECOMMEND_PERSONAL.search(text):
        return Route("recommend_personal", matched=("recommend_personal",))
    if RECOMMEND.search(text):
        return Route("recommend_similar", matched=("recommend_similar",))

    masked, collected, planned, planned_aliases = _find_artists(text)
    unknown = tuple(n for n in OUT_OF_SCOPE_ARTISTS if _mentions(masked, n))
    about_selected = artist_slug in collected or any(d in text for d in DEICTIC)
    relational = any(r in text for r in RELATION)
    others = tuple(s for s in collected if s != artist_slug)

    if about_selected or relational:
        return Route("rag", artists=collected, names=planned + unknown, matched=("selected_or_relation",))
    if others:
        return Route("other_artist", artists=others, matched=("other_collected",))
    if named_in_scope and any(named_in_scope(n) for n in planned_aliases + unknown):
        return Route("rag", names=planned + unknown, matched=("named_in_scope",))
    if planned:
        reason = "unreviewed_artist" if any(a.pending_review and a.name in planned for a in _artists().values()) else "uncollected_artist"
        return Route("refuse", reason, names=planned, matched=("planned",))
    if unknown:
        return Route("refuse", "unknown_artist", names=unknown[:1], matched=("unknown",))
    return Route("rag", matched=("default",))


def refusal_message(route: Route) -> str:
    """refuse·other_artist의 사용자 확정 안내를 서버에서 조립한다."""
    if route.kind == "refuse" and route.reason == "unreviewed_artist":
        return " ".join(
            f"현재 {name} 작가의 자료는 검토 중에 있어요." for name in route.names
        )
    if route.kind == "refuse" and route.reason == "uncollected_artist":
        names = _join(route.names)
        return f"{names}에 관한 자료는 준비 중 입니다."
    if route.kind == "refuse" and route.reason == "unknown_artist":
        return " ".join(
            f"현재 {name}의 자료는 검토 중에 있어요." for name in route.names
        )
    if route.kind == "refuse" and route.reason == "off_topic":
        return "해당 작품과 작가에 대해서만 대화 할 수 있어요."
    if route.kind == "refuse":
        return "이 도슨트는 작품과 작가에 관한 자료로만 답할 수 있어요. 작품에 대해 궁금한 점을 물어봐 주세요."
    if route.kind == "other_artist":
        names = [_artists()[s].name for s in route.artists if s in _artists()]
        return " ".join(
            f"{name}의 작품을 선택하면 해당 작가에 관해 대화할 수 있어요."
            for name in names
        )
    return ""


def _join(names) -> str:
    return ", ".join(names)


def _find_artists(text: str) -> tuple[str, tuple[str, ...], tuple[str, ...], tuple[str, ...]]:
    """질문에 나온 작가를 찾는다.

    돌려주는 값: (헷갈리는 이름·찾은 이름을 지운 글, 승인된 작가 slug, 수집 전·검수 대기 작가 이름, 해당 작가가 질문에 쓰인 모양).

    긴 별칭부터 찾고 찾은 자리는 지운다. 그래야 "미켈란젤로 메리시"(카라바조)가 "미켈란젤로"로,
    "반 고흐"의 "고흐"가 두 번 잡히지 않는다.
    """
    masked = text
    for phrase in _confusable_phrases():
        masked = masked.replace(phrase, " " * len(phrase))
    collected: list[str] = []
    planned: list[str] = []
    planned_aliases: list[str] = []
    for alias, artist in _alias_index():
        if not _mentions(masked, alias):
            continue
        masked = masked.replace(alias, " " * len(alias))
        target = collected if artist.collected else planned
        key = artist.slug if artist.collected else artist.name
        if key not in target:
            target.append(key)
        if not artist.collected:
            planned_aliases.append(alias)
    return masked, tuple(collected), tuple(planned), tuple(planned_aliases)


def _mentions(text: str, name: str) -> bool:
    """name 이 낱말로 나오는지. 한글 이름은 앞에 한글이 붙지 않고, 뒤에는 조사만 올 수 있다."""
    if not HANGUL.search(name):
        return re.search(rf"(?<![A-Za-z]){re.escape(name)}(?![A-Za-z])", text, re.IGNORECASE) is not None
    for m in re.finditer(re.escape(name), text):
        before = text[m.start() - 1] if m.start() else " "
        after = text[m.end():]
        if HANGUL.match(before):
            continue
        if not after or not HANGUL.match(after[0]) or after.startswith(PARTICLES):
            return True
    return False


@lru_cache
def _artists() -> dict[str, _Artist]:
    # 전처리 결과(data/processed)를 검증하며 읽는다
    from scripts.preprocess import load_processed

    return {
        a["slug"]: _Artist(
            a["slug"], a["name"], a["status"] == "collected", tuple(a["aliases"]), tuple(a.get("confusable") or ()), a["status"] == "pending_review"
        )
        for a in load_processed("artist_aliases.jsonl")
    }


@lru_cache
def _alias_index() -> tuple[tuple[str, _Artist], ...]:
    pairs = [(alias, a) for a in _artists().values() for alias in a.aliases]
    return tuple(sorted(pairs, key=lambda p: -len(p[0])))


@lru_cache
def _confusable_phrases() -> tuple[str, ...]:
    """작가 이름과 겹치는 지명·동명이인. 지우고 나서 작가 이름을 찾는다.

    별칭 파일의 confusable 중 지명·가족은 지운다. '마네'(다른 화가)는 지우지 않아 범위 밖 작가로 잡힌다.
    """
    phrases = {"강원도 정선", "정선군", "정선 아리랑", "단원고", "단원구", "테오 반 고흐"}
    for a in _artists().values():
        for c in a.confusable:
            head, _, note = c.partition(" (")
            if "지명" in note or "동생" in note:
                phrases.update(p.strip() for p in re.split(r"[·,]", head.replace(" 등 지명", "")) if p.strip())
    return tuple(sorted(phrases, key=len, reverse=True))
