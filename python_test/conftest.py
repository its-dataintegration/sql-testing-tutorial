import shutil
import sqlite3
from pathlib import Path

import pytest

from sql_cases import DEFAULT_DB


def pytest_addoption(parser):
    parser.addoption("--db", type=Path, default=DEFAULT_DB,
                     help=f"SQLite database file to test (default: {DEFAULT_DB})")


@pytest.fixture(scope="session")
def db_path(request) -> Path:
    path = request.config.getoption("--db").resolve()
    if not path.is_file():
        pytest.exit(f"Database not found: {path}\nCreate it first with:  python3 load_seed.py", returncode=2)
    return path


@pytest.fixture
def db(db_path):
    """Read-only connection to the database under test; it cannot be modified."""
    connection = sqlite3.connect(f"{db_path.as_uri()}?mode=ro", uri=True)
    connection.execute("PRAGMA foreign_keys = ON")
    try:
        yield connection
    finally:
        connection.close()


@pytest.fixture(scope="session")
def scratch_path(db_path, tmp_path_factory) -> Path:
    """A throwaway copy of the database, for tests that attempt writes."""
    copy = tmp_path_factory.mktemp("db") / db_path.name
    shutil.copyfile(db_path, copy)
    return copy


@pytest.fixture
def scratch_db(scratch_path):
    """Writable connection to the copy, with foreign keys on. Everything is rolled back."""
    connection = sqlite3.connect(scratch_path, isolation_level=None)
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("BEGIN")
    try:
        yield connection
    finally:
        connection.execute("ROLLBACK")
        connection.close()
