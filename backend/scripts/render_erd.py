"""Render the SQLAlchemy schema as Mermaid and Graphviz ERD files.

Run from ``backend/`` with::

    uv run python -m scripts.render_erd
"""

from __future__ import annotations

import html
import shutil
import subprocess
from pathlib import Path

from sqlalchemy import UniqueConstraint

from app.models import Base

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIRECTORY = REPOSITORY_ROOT / "docs" / "db"

TABLE_GROUPS = {
    "Identity & Preferences": ("users", "social_accounts", "user_preferences"),
    "Catalog": ("art_movements", "artists", "artworks", "artwork_embeddings"),
    "User Activity": (
        "diary_entries",
        "collections",
        "collection_items",
        "artwork_likes",
        "artist_follows",
        "artwork_views",
        "chat_sessions",
        "chat_messages",
    ),
    "Documents & RAG": (
        "documents",
        "document_artists",
        "document_artworks",
        "document_basis_documents",
        "document_chunks",
    ),
}

GROUP_COLORS = {
    "Identity & Preferences": "#E8F2EC",
    "Catalog": "#EDF1F7",
    "User Activity": "#F8F0E5",
    "Documents & RAG": "#F2EDF7",
}

TYPE_NAMES = {
    "biginteger": "bigint",
    "smallinteger": "smallint",
    "integer": "int",
    "string": "varchar",
    "text": "text",
    "mediumtext": "mediumtext",
    "datetime": "datetime",
    "date": "date",
    "boolean": "tinyint",
    "json": "json",
    "vectortype": "vector",
}


def ordered_table_names() -> list[str]:
    grouped = [table for tables in TABLE_GROUPS.values() for table in tables]
    remaining = sorted(set(Base.metadata.tables) - set(grouped))
    return grouped + remaining


def type_name(column) -> str:
    return TYPE_NAMES.get(type(column.type).__name__.lower(), type(column.type).__name__.lower())


def key_labels(column) -> str:
    labels = []
    if column.primary_key:
        labels.append("PK")
    if column.foreign_keys:
        labels.append("FK")
    if column.unique:
        labels.append("UK")
    return ",".join(labels)


def sorted_foreign_keys(table) -> list:
    """foreign_key_constraints is a set; sort it so re-rendering gives identical files."""
    return sorted(
        table.foreign_key_constraints,
        key=lambda constraint: [column.name for column in constraint.columns],
    )


def is_one_to_one(foreign_key_constraint) -> bool:
    table = foreign_key_constraint.table
    columns = {column.name for column in foreign_key_constraint.columns}
    primary_key = {column.name for column in table.primary_key.columns}
    if columns == primary_key:
        return True
    return any(
        isinstance(constraint, UniqueConstraint)
        and columns == {column.name for column in constraint.columns}
        for constraint in table.constraints
    )


def mermaid_source() -> str:
    lines = ["erDiagram"]
    for table_name in ordered_table_names():
        table = Base.metadata.tables[table_name]
        for constraint in sorted_foreign_keys(table):
            parent = next(iter(constraint.elements)).column.table.name
            child_cardinality = "o|" if is_one_to_one(constraint) else "o{"
            label = ", ".join(column.name for column in constraint.columns)
            lines.append(f'    {parent} ||--{child_cardinality} {table_name} : "{label}"')

    lines.append("")
    for table_name in ordered_table_names():
        table = Base.metadata.tables[table_name]
        lines.append(f"    {table_name} {{")
        for column in table.columns:
            keys = key_labels(column)
            key_suffix = f" {keys}" if keys else ""
            lines.append(f"        {type_name(column)} {column.name}{key_suffix}")
        lines.append("    }")
    return "\n".join(lines) + "\n"


def graphviz_source() -> str:
    lines = [
        "digraph ERD {",
        '  graph [rankdir="LR", bgcolor="#FBFAF7", pad="0.35", nodesep="0.45", ranksep="1.0", splines="polyline"];',
        '  node [shape="plain", fontname="Malgun Gothic"];',
        '  edge [color="#718076", penwidth="1.2", arrowsize="0.7", fontname="Malgun Gothic", fontsize="9"];',
    ]

    for index, (group_name, table_names) in enumerate(TABLE_GROUPS.items()):
        lines.append(f"  subgraph cluster_{index} {{")
        lines.append(f'    label="{group_name}"; color="{GROUP_COLORS[group_name]}"; penwidth="2"; style="rounded";')
        for table_name in table_names:
            table = Base.metadata.tables[table_name]
            rows = []
            for column in table.columns:
                keys = html.escape(key_labels(column)) or "&#160;"
                nullable = "" if column.nullable or column.primary_key else "NOT NULL"
                nullable_label = html.escape(nullable) or "&#160;"
                rows.append(
                    "<TR>"
                    f'<TD ALIGN="LEFT"><FONT COLOR="#66736B">{html.escape(type_name(column))}</FONT></TD>'
                    f'<TD PORT="{html.escape(column.name)}" ALIGN="LEFT">{html.escape(column.name)}</TD>'
                    f'<TD ALIGN="CENTER"><B>{keys}</B></TD>'
                    f'<TD ALIGN="LEFT"><FONT COLOR="#8A928D">{nullable_label}</FONT></TD>'
                    "</TR>"
                )
            label = (
                '<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="5" COLOR="#ADB6B0">'
                f'<TR><TD COLSPAN="4" BGCOLOR="{GROUP_COLORS[group_name]}"><B>{table_name}</B></TD></TR>'
                + "".join(rows)
                + "</TABLE>>"
            )
            lines.append(f"    {table_name} [label={label}];")
        lines.append("  }")

    for table_name in ordered_table_names():
        table = Base.metadata.tables[table_name]
        for constraint in sorted_foreign_keys(table):
            element = next(iter(constraint.elements))
            parent = element.column.table.name
            parent_column = element.column.name
            child_column = element.parent.name
            cardinality = "1 : 0..1" if is_one_to_one(constraint) else "1 : N"
            lines.append(
                f'  {parent}:{parent_column} -> {table_name}:{child_column} '
                f'[label="{cardinality}", arrowhead="vee"];'
            )

    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> None:
    dot = shutil.which("dot")
    if dot is None:
        raise SystemExit("Graphviz 'dot' executable was not found.")

    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    (OUTPUT_DIRECTORY / "00_erd.mmd").write_text(mermaid_source(), encoding="utf-8")

    source = graphviz_source()
    for output_format in ("png", "svg"):
        output_path = OUTPUT_DIRECTORY / f"00_erd.{output_format}"
        subprocess.run(
            [dot, f"-T{output_format}", "-o", str(output_path)],
            input=source,
            text=True,
            encoding="utf-8",
            check=True,
        )

    print(f"rendered_tables={len(Base.metadata.tables)}")
    print(f"output={OUTPUT_DIRECTORY / '00_erd.png'}")


if __name__ == "__main__":
    main()
