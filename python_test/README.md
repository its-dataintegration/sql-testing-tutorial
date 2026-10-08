# Suite 2: SQL tests run with Python and pytest

**You need:** SQL, and a terminal. You do **not** need to know Python: you'll write tests in `.sql` files,
and the Python code in this folder is already written.

This suite checks the same things as the [shell suite](../tests/README.md), but the tests run through
**pytest**, the most widely used testing tool in the Python world. The tests are still plain SQL in
`.sql` files. Python and pytest just find them, run them, and report the results.

## The ideas, in two minutes

**A test is a question with a yes/no answer about your data.** "Is any room booked twice at the same time?"
You write the question as a SQL query, and the test passes or fails depending on the answer.

**In this suite, a check is a query that returns the rows that break a rule.**
If the query returns nothing, there are no problems and the test passes. If it returns rows, the test fails,
and pytest prints those rows so you can see exactly what is wrong. This is a handy convention, because the same
query is both the test and the bug report.

**This suite has two kinds of test:**

| Kind | Folder | What it asks |
|---|---|---|
| **Checks** | `sql/checks/` | "Is the data that is *in* the database correct?" |
| **Must-fail tests** | `sql/must_fail/` | "Does the database *refuse* bad data?" Each one tries to insert something invalid and passes only if the database rejects it. |

**Why use a framework at all?** pytest gives you things the shell script had to build by hand: tests are
found automatically, each one has a name, you can run any subset, failures are explained clearly, and the
whole run produces a pass/fail result that automated systems (nightly builds, CI) understand.

**Words you'll see:**
- **pytest** runs the tests and prints the report.
- **virtual environment** (`.venv`) is a private folder where pytest is installed, so it doesn't affect anything else on your computer.
- **parametrized test**: one piece of Python (`test_checks.py`) that runs once for every `-- @test` block in your `.sql` files.

## Step 1: Build the database to test

From the project's top folder (the one containing `school_seed.sql`):

```sh
python3 load_seed.py --force
```

This creates `school.sqlite3`, the file the tests check, and lists how many rows each table has.

## Step 2: Install pytest (once)

Use a current Python 3 (this was tested on 3.14). Check yours:

```sh
python3 --version
```

If it is older than 3.10, install a newer one (on a Mac: `brew install python`). Then:

```sh
cd python_test
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
```

The first line moves into this folder. The second creates the private environment. The third and fourth update the
installer (`pip`) and install pytest into it.
The `.venv/bin/` prefix in later commands means "use the copy of pytest installed there".

To update later, run `.venv/bin/pip install --upgrade -r requirements.txt`. To check the installed packages for known
security problems, run `uvx pip-audit --path .venv/lib/python3.14/site-packages` (adjust `3.14` to your Python version).

## Step 3: Run the tests

```sh
.venv/bin/pytest
```

You'll see something like:

```
......................................................................  [100%]
=========================== FAILURES ===========================
...
FAILED test_checks.py::test_check[always_fails: this test always fails]
1 failed, 68 passed in 0.06s
```

Each dot is a passing test, and an `F` is a failing one. To see every test by name:

```sh
.venv/bin/pytest -v
```

```
test_checks.py::test_check[business_rules: no room is double-booked] PASSED
test_checks.py::test_check[business_rules: no instructor is double-booked] PASSED
...
```

## Step 4: Understand the one failure

One test is meant to fail. [sql/checks/always_fails.sql](sql/checks/always_fails.sql) exists so you can see
what a failure looks like. The report shows the file and line, the number of bad rows, and the rows themselves:

```
AssertionError: always_fails.sql:4 'this test always fails' found 1 bad row(s):
  reason              file
  ------------------  ---------------------------------------
  deliberate failure  python_test/sql/checks/always_fails.sql
```

pytest also reports failure to other programs through its **exit code** (0 means everything passed,
anything else means a failure):

```sh
.venv/bin/pytest -q > /dev/null; echo "exit code: $?"
```

This prints `exit code: 1`. To get a clean run, delete the file: `rm sql/checks/always_fails.sql`, then run
pytest again. You should see `68 passed`.

## Step 5: Read a test

Open [sql/checks/business_rules.sql](sql/checks/business_rules.sql). The first test is:

```sql
-- @test no room is double-booked
SELECT a.room_id, a.day_of_week, a.meeting_id, b.meeting_id AS clashes_with
FROM class_meetings a
JOIN class_meetings b ON b.meeting_id > a.meeting_id
                     AND b.room_id = a.room_id
                     AND b.day_of_week = a.day_of_week
...
WHERE a.start_time < b.end_time AND b.start_time < a.end_time;
```

- The `-- @test` line gives the test its name. It is just a SQL comment, so the file still runs in any SQL tool.
- The query joins the meetings table to itself and returns every pair of meetings that overlap in the same room.
- If there are no such pairs, no rows come back and the test passes.

You can copy that query into `sqlite3 ../school.sqlite3` and run it by hand. That is a good way to develop a new test.

## Step 6: Break the data and watch a test catch it

Make a copy of the database, damage it on purpose, and point pytest at it with `--db=<file>`.
The real `school.sqlite3` is not touched.

```sh
cp ../school.sqlite3 /tmp/broken.sqlite3
sqlite3 /tmp/broken.sqlite3 "UPDATE enrollments SET grade = 'A' WHERE enrollment_id = 28;"
.venv/bin/pytest --db=/tmp/broken.sqlite3
```

Enrollment 28 is a class the student is still taking, so it shouldn't have a grade yet. In the report you'll see:

```
AssertionError: business_rules.sql:84 'enrolled and waitlisted students have no grade yet' found 1 bad row(s):
  enrollment_id  status    grade
  -------------  --------  -----
  28             Enrolled  A
```

The columns your query selects are the columns in the report, so choose ones that help someone find the problem.

## Step 7: Write your own check

Add this to the end of [sql/checks/integrity.sql](sql/checks/integrity.sql):

```sql
-- @test every course has a description
SELECT course_id, title
FROM courses
WHERE description IS NULL OR description = '';
```

Run `.venv/bin/pytest -v -k description`. (`-k` runs only tests whose name contains that word. Spaces are not allowed inside
it: to combine words use `and`, as in `-k "zero and credits"`.) You'll see your test `PASSED`. To see it fail, run it on a damaged copy:

```sh
cp ../school.sqlite3 /tmp/broken.sqlite3
sqlite3 /tmp/broken.sqlite3 "UPDATE courses SET description = NULL WHERE course_id = 3;"
.venv/bin/pytest -k description --db=/tmp/broken.sqlite3
```

The recipe for any check:

1. Start with a `-- @test <name>` line. The name must be unique within the file.
2. Write **one** query that returns the **bad rows**.
3. End the query with `;`.

You can also create a new `.sql` file in `sql/checks/`. pytest finds every `.sql` file there automatically.

## Step 8: Write a must-fail test

Open [sql/must_fail/constraints.sql](sql/must_fail/constraints.sql). Each test has one statement that
*should be rejected*:

```sql
-- @test reject room with zero capacity
INSERT INTO rooms (building_id, room_number, capacity, room_type) VALUES (1, '999', 0, 'Lecture');
```

The test passes only if SQLite refuses the statement with a constraint error (`NOT NULL`, `UNIQUE`, `CHECK`
or `FOREIGN KEY`). A typo or a wrong table name is a different kind of error, so it fails the test rather than
passing by accident.

Add one of your own at the end of the file:

```sql
-- @test reject a course with zero credits
INSERT INTO courses (department_id, course_number, title, credits) VALUES (1, '777', 'Test', 0);
```

Run `.venv/bin/pytest -k "zero and credits" -v`. The test is `PASSED`, because the database refused the insert.
The statement runs on a temporary copy that is rolled back, so `school.sqlite3` is never changed.

## Everyday commands

```sh
.venv/bin/pytest                        # run everything
.venv/bin/pytest -v                     # list every test by name
.venv/bin/pytest -k rooms               # only tests whose name contains "rooms"
.venv/bin/pytest test_constraints.py    # only the must-fail tests
.venv/bin/pytest --db=path/to/other.db  # test a different database file (note the = sign)
```

## If something goes wrong

| What you see | What it means |
|---|---|
| `Database not found: ...` | Build the database first (Step 1). |
| `pytest: No such file` or `command not found` | Do Step 2, and run pytest as `.venv/bin/pytest` from inside `python_test`. |
| `ValueError: ... has no SQL` | A `-- @test` line has no query under it. |
| `ValueError: ... duplicate test name` | Two tests in the same file have the same name. Rename one. |
| `sqlite3.OperationalError: no such table/column` | A typo in your query. The message names the problem. |

## What's in this folder

| Path | Purpose |
|---|---|
| `sql/checks/*.sql` | Checks: queries that return rule-breaking rows (row counts, integrity, business rules, views) |
| `sql/must_fail/constraints.sql` | Statements the database must reject |
| `sql/checks/always_fails.sql` | A deliberate failure, to show what one looks like. Delete it for a clean run. |
| `test_checks.py`, `test_constraints.py` | Python that turns each `-- @test` block into a pytest test. You won't need to edit these. |
| `sql_cases.py`, `conftest.py` | Python that reads the `.sql` files and opens the database. You won't need to edit these. |
| `requirements.txt`, `pytest.ini` | Settings |

The database is never modified: checks open it read-only, and must-fail tests use a temporary copy.
