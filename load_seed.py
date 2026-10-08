#!/usr/bin/env python3
"""Create a SQLite database file from school_seed.sql.

Usage:
    python3 load_seed.py                       # creates ./school.sqlite3
    python3 load_seed.py data/school.sqlite3   # choose the output file
    python3 load_seed.py --force               # replace an existing file
    python3 load_seed.py --seed other_seed.sql

The database is built in a temporary file next to the output and only moved
into place once the seed has loaded and passed SQLite's integrity and
foreign key checks, so a failed load never leaves a half-built database or
damages an existing one.
"""

import argparse
import os
import sqlite3
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_SEED = HERE / "school_seed.sql"
DEFAULT_OUTPUT = Path("school.sqlite3")


class LoadError(Exception):
    pass


def load(seed_path: Path, db_path: Path) -> dict[str, int]:
    """Run the seed script against db_path and return the row count of each table."""
    conn = sqlite3.connect(db_path, isolation_level=None)
    try:
        try:
            conn.executescript(seed_path.read_text(encoding="utf-8"))
        except sqlite3.Error as exc:
            raise LoadError(f"seed script failed: {exc}") from exc

        conn.execute("PRAGMA foreign_keys = ON")
        problems = [row[0] for row in conn.execute("PRAGMA integrity_check") if row[0] != "ok"]
        if problems:
            raise LoadError("integrity check failed: " + "; ".join(problems))

        violations = conn.execute("PRAGMA foreign_key_check").fetchall()
        if violations:
            tables = sorted({row[0] for row in violations})
            raise LoadError(f"{len(violations)} foreign key violation(s) in: {', '.join(tables)}")

        tables = [name for (name,) in conn.execute(
            "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
        return {t: conn.execute(f'SELECT count(*) FROM "{t}"').fetchone()[0] for t in tables}
    finally:
        conn.close()


def build(seed_path: Path, output: Path, force: bool = False) -> dict[str, int]:
    """Build output from seed_path atomically. Returns row counts per table."""
    if not seed_path.is_file():
        raise LoadError(f"seed file not found: {seed_path}")
    if output.exists() and not force:
        raise LoadError(f"{output} already exists (use --force to replace it)")

    output.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{output.name}.", suffix=".tmp", dir=output.parent)
    os.close(fd)
    tmp_path = Path(tmp_name)
    try:
        counts = load(seed_path, tmp_path)
        # mkstemp creates the file as 0600; give it the permissions a normally created file would get.
        umask = os.umask(0)
        os.umask(umask)
        os.chmod(tmp_path, 0o666 & ~umask)
        os.replace(tmp_path, output)
        return counts
    finally:
        tmp_path.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Create a SQLite database from school_seed.sql.")
    parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT,
                        help=f"database file to create (default: {DEFAULT_OUTPUT})")
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED,
                        help="SQL seed script to load (default: school_seed.sql next to this script)")
    parser.add_argument("-f", "--force", action="store_true",
                        help="replace the output file if it already exists")
    args = parser.parse_args(argv)

    try:
        counts = build(args.seed, args.output, force=args.force)
    except LoadError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"Created {args.output} from {args.seed.name}")
    width = max(map(len, counts))
    for table, count in counts.items():
        print(f"  {table.ljust(width)}  {count:>4}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
