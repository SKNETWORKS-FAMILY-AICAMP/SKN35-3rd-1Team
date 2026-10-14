"""문서를 검색용 청크로 자른다.

규칙 (docs/rag-handoff.md 3절)
- 본문이 WHOLE_DOC_MAX 이하인 문서는 자르지 않는다. 연표 사건, 고흐·고갱 팀 작성 해설(덧붙인 절 제외 최대 1,103자),
  모네·세잔 주제 문서가 여기에 들어가며, 이야기 하나가 청크 하나에 온전히 남는다.
- 원문 뒤에 덧붙인 절(ANNOTATION_SECTIONS: `## 감상 포인트` 편집 보충문, `## 답변 시 주의` 보정문)은
  문서 길이와 관계없이 항상 따로 청크로 만들고 머리말에 절 제목을 남긴다. LLM 이 원문과 구분하고,
  출처 표시에서 편집 근거를 함께 보여 줄 청크를 골라낼 수 있어야 하기 때문이다 (annotation_section).
- 긴 문서는 `## 제목` 섹션 단위로 먼저 나누고, TARGET_CHARS 를 넘는 섹션만 줄 경계에서 다시 자른다.
  위키 원문은 줄 하나가 문단 하나다. 한 줄이 HARD_MAX_CHARS 를 넘으면 문장 경계에서 자른다.
- MIN_CHARS 미만인 조각은 옆 조각과 합친다. 제목만 바뀌는 짧은 섹션이 따로 청크가 되면 검색 품질이 떨어진다.
- 청크 앞에 `문서 제목 > 섹션 > 하위 섹션` 머리말을 붙인다. 섹션 제목 줄(`## …`)은 본문에서 빼고
  머리말로만 쓰되, 합쳐진 조각의 하위 섹션 이름은 본문 안에 `[섹션 이름]` 줄로 남긴다.

청크는 문서 하나만 보고 만든다. 문서가 추가되면 그 문서만 잘라 임베딩하면 되고,
아래 상수나 규칙을 바꾸면 전체를 다시 만들어야 한다.
"""

import re
from collections.abc import Iterable
from dataclasses import dataclass
from itertools import groupby

WHOLE_DOC_MAX = 1200  # 덧붙인 절을 뺀 본문 기준. 고흐·고갱 팀 작성 해설을 자르지 않는 길이
TARGET_CHARS = 500
HARD_MAX_CHARS = 800
MIN_CHARS = 150

ANNOTATION_SECTIONS = ("감상 포인트", "답변 시 주의")

HEADING = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
SENTENCE_END = re.compile(r"(?<=[.!?。])\s+")

Path = tuple[str, ...]  # 섹션 제목 경로. 첫 섹션 앞 도입부는 ()


@dataclass(frozen=True)
class Chunk:
    doc_key: str
    chunk_index: int
    heading: str  # "문서 제목 > 섹션 > 하위 섹션"
    body: str

    @property
    def content(self) -> str:
        """임베딩하고 DB `document_chunks.content` 에 저장하는 글. 머리말을 함께 넣어야 짧은 조각도 맥락이 남는다."""
        return f"{self.heading}\n\n{self.body}"


@dataclass
class _Piece:
    """청크가 되기 전의 조각. 합쳐질 수 있어서 (섹션 경로, 글) 묶음을 여러 개 가진다."""

    parts: list[tuple[Path, str]]

    @property
    def size(self) -> int:
        """청크 본문이 됐을 때의 글자 수 (줄바꿈과 `[섹션 이름]` 표시 포함)."""
        return len(_render("", self)[1])


def chunk_document(doc: dict) -> list[Chunk]:
    """processed 문서 한 건(documents.jsonl 의 한 줄)을 청크 리스트로 만든다."""
    pieces: list[_Piece] = []
    # 본문과 덧붙인 절을 따로 다룬다. 덧붙인 절끼리는 섞이지 않고, 본문 조각과도 합치지 않는다.
    for annotation, group in groupby(_parse_sections(doc["content"]), key=lambda s: _annotation(s[0])):
        sections = list(group)
        whole = _Piece([(path, "\n".join(lines)) for path, lines in sections])
        if annotation is None and whole.size <= WHOLE_DOC_MAX:
            pieces.append(whole)
        else:
            pieces += _merge_small([p for path, lines in sections for p in _split_section(path, lines)])
    return [
        Chunk(doc["doc_key"], i, *_render(doc["title"], piece))
        for i, piece in enumerate(pieces)
        if piece.parts
    ]


def chunk_documents(docs: Iterable[dict]) -> list[Chunk]:
    return [c for doc in docs for c in chunk_document(doc)]


def annotation_section(content: str) -> str | None:
    """청크 content(머리말 포함)가 덧붙인 절에서 나왔으면 그 절 제목을 돌려준다. 검색·출처 표시에서 쓴다."""
    path = content.split("\n", 1)[0].split(" > ")[1:]
    return _annotation(tuple(path))


def _annotation(path: Path) -> str | None:
    return next((title for title in path if title in ANNOTATION_SECTIONS), None)


def _parse_sections(content: str) -> list[tuple[Path, list[str]]]:
    """본문을 (섹션 경로, 줄 목록) 으로 나눈다. 본문이 없는 섹션(하위 섹션만 거느린 제목)은 빠진다."""
    sections: list[tuple[Path, list[str]]] = []
    stack: list[tuple[int, str]] = []
    lines: list[str] = []

    def flush() -> None:
        if lines:
            sections.append((tuple(title for _, title in stack), lines.copy()))
            lines.clear()

    for raw in content.splitlines():
        line = raw.strip()
        m = HEADING.match(line)
        if not m:
            if line:
                lines.append(line)
            continue
        flush()
        level = len(m.group(1))
        if level == 1:
            # 모네·세잔 주제 문서의 `# 제목` 은 문서 제목과 같은 말이라 버린다.
            # 문서 중간에 나오면 새 글이 시작된 것이므로 앞 섹션 경로를 이어받지 않는다.
            stack.clear()
            continue
        while stack and stack[-1][0] >= level:
            stack.pop()
        stack.append((level, m.group(2)))
    flush()
    return sections


def _split_section(path: Path, lines: list[str]) -> list[_Piece]:
    """섹션 하나를 TARGET_CHARS 안팎의 조각으로 나눈다. 줄을 중간에서 자르지 않는다."""
    units = [u for line in lines for u in _split_long(line)]
    pieces: list[list[str]] = []
    current: list[str] = []
    for unit in units:
        if current and len("\n".join(current + [unit])) > TARGET_CHARS:
            pieces.append(current)
            current = []
        current.append(unit)
    if current:
        pieces.append(current)
    return [_Piece([(path, "\n".join(p))]) for p in pieces]


def _split_long(line: str) -> list[str]:
    """HARD_MAX_CHARS 를 넘는 줄을 문장 단위로 묶어 자른다. 문장 하나가 그보다 길면 글자 수로 자른다."""
    if len(line) <= HARD_MAX_CHARS:
        return [line]
    out: list[str] = []
    current = ""
    for sentence in SENTENCE_END.split(line):
        while len(sentence) > HARD_MAX_CHARS:
            if current:
                out.append(current)
                current = ""
            out.append(sentence[:HARD_MAX_CHARS])
            sentence = sentence[HARD_MAX_CHARS:]
        if current and len(current) + 1 + len(sentence) > TARGET_CHARS:
            out.append(current)
            current = ""
        current = f"{current} {sentence}".strip()
    if current:
        out.append(current)
    return out


def _merge_small(pieces: list[_Piece]) -> list[_Piece]:
    """MIN_CHARS 미만 조각을 다음 조각(마지막이면 앞 조각)에 붙인다. 합친 청크 본문이 HARD_MAX_CHARS 를 넘으면 그대로 둔다."""
    out: list[_Piece] = []
    carry: _Piece | None = None
    for piece in pieces:
        if carry is not None:
            # 합친 결과로 잰다. 섹션이 다르면 `[섹션 이름]` 줄과 줄바꿈이 더해진다.
            merged = _Piece(carry.parts + piece.parts)
            if merged.size <= HARD_MAX_CHARS:
                piece = merged
            else:
                out.append(carry)
            carry = None
        if piece.size < MIN_CHARS:
            carry = piece
        else:
            out.append(piece)
    if carry is not None:
        merged = _Piece(out[-1].parts + carry.parts) if out else None
        if merged is not None and merged.size <= HARD_MAX_CHARS:
            out[-1] = merged
        else:
            out.append(carry)
    return out


def _render(title: str, piece: _Piece) -> tuple[str, str]:
    """(머리말, 본문). 머리말에는 조각들이 공통으로 속한 섹션까지 쓰고, 그 아래 섹션 이름은 본문에 남긴다."""
    paths = [path for path, _ in piece.parts]
    common = list(paths[0])
    for path in paths[1:]:
        n = 0
        while n < min(len(common), len(path)) and common[n] == path[n]:
            n += 1
        common = common[:n]

    body: list[str] = []
    shown: Path = tuple(common)
    for path, text in piece.parts:
        if path != shown and len(path) > len(common):
            body.append(f"[{' > '.join(path[len(common):])}]")
        shown = path
        body.append(text)
    return " > ".join([title, *common]), "\n".join(body)


if __name__ == "__main__":
    # backend/ 에서 실행: uv run python -m app.rag.chunking
    from statistics import median

    from scripts.preprocess import load_processed

    docs = load_processed("documents.jsonl")
    chunks = chunk_documents(docs)
    sizes = [len(c.body) for c in chunks]
    print(f"문서 {len(docs)}건 → 청크 {len(chunks)}개")
    print(f"본문 길이 최소 {min(sizes)} / 중앙값 {median(sizes):.0f} / 최대 {max(sizes)}자")
    print(f"{MIN_CHARS}자 미만 {sum(s < MIN_CHARS for s in sizes)}개, {HARD_MAX_CHARS}자 초과 {sum(s > HARD_MAX_CHARS for s in sizes)}개")
