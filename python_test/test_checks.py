"""Runs every check in sql/checks/*.sql.

A check is a query that returns the rows breaking a rule, so it passes when
it returns no rows.
"""

import pytest

from sql_cases import CHECKS_DIR, format_rows, load_cases

CASES = load_cases(CHECKS_DIR)


@pytest.mark.parametrize("case", CASES, ids=[c.id for c in CASES])
def test_check(db, case):
    cursor = db.execute(case.sql)
    rows = cursor.fetchall()
    assert not rows, (
        f"{case.file.name}:{case.line} '{case.name}' found {len(rows)} bad row(s):\n"
        + format_rows(cursor.description, rows)
    )
