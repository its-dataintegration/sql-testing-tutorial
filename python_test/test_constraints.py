"""Runs every statement in sql/must_fail/*.sql.

Each statement breaks a schema rule, so SQLite must reject it with a
constraint error (sqlite3.IntegrityError). A syntax error or a typo in a
table name raises a different error and fails the test.

They run against a temporary copy of the database, so the real file is never written to.
"""

import sqlite3

import pytest

from sql_cases import MUST_FAIL_DIR, load_cases

CASES = load_cases(MUST_FAIL_DIR)


@pytest.mark.parametrize("case", CASES, ids=[c.id for c in CASES])
def test_statement_is_rejected(scratch_db, case):
    with pytest.raises(sqlite3.IntegrityError):
        scratch_db.execute(case.sql)
