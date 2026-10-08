"""Load SQL test cases from .sql files.

A file holds any number of cases. Each case starts with a marker line

    -- @test <name>

and runs until the next marker. Lines before the first marker (file header
comments) are ignored.
"""

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_DB = ROOT.parent / "school.sqlite3"
CHECKS_DIR = ROOT / "sql" / "checks"
MUST_FAIL_DIR = ROOT / "sql" / "must_fail"

_MARKER = re.compile(r"^--\s*@test\s+(?P<name>.+?)\s*$")


@dataclass(frozen=True)
class SqlCase:
    file: Path
    line: int
    name: str
    sql: str

    @property
    def id(self) -> str:
        return f"{self.file.stem}: {self.name}"


def load_cases(directory: Path) -> list[SqlCase]:
    cases = []
    for path in sorted(directory.glob("*.sql")):
        cases.extend(_parse_file(path))
    return cases


def _parse_file(path: Path) -> list[SqlCase]:
    cases, seen = [], set()
    name, start, body = None, 0, []

    def finish():
        sql = "\n".join(body).strip()
        if not _has_code(sql):
            raise ValueError(f"{path}:{start}: test '{name}' has no SQL")
        cases.append(SqlCase(path, start, name, sql))

    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        match = _MARKER.match(line)
        if match:
            if name is not None:
                finish()
            name, start, body = match["name"], lineno, []
            if name in seen:
                raise ValueError(f"{path}:{lineno}: duplicate test name '{name}'")
            seen.add(name)
        elif name is not None:
            body.append(line)
    if name is not None:
        finish()
    return cases


def _has_code(sql: str) -> bool:
    return any(line.strip() and not line.strip().startswith("--") for line in sql.splitlines())


def format_rows(cursor_description, rows, limit: int = 20) -> str:
    """Render query results as a small text table for failure messages."""
    headers = [col[0] for col in cursor_description]
    shown = [["NULL" if v is None else str(v) for v in row] for row in rows[:limit]]
    widths = [max(len(h), *(len(r[i]) for r in shown)) for i, h in enumerate(headers)]
    lines = [
        "  ".join(h.ljust(w) for h, w in zip(headers, widths)),
        "  ".join("-" * w for w in widths),
        *("  ".join(v.ljust(w) for v, w in zip(r, widths)) for r in shown),
    ]
    if len(rows) > limit:
        lines.append(f"... and {len(rows) - limit} more rows")
    return "\n".join(lines)
