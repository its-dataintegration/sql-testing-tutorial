# Suite 1: SQL tests run with a shell script

**You need:** SQL, and a terminal. No programming and no extra tools beyond `sqlite3`.

This is the simplest way to test a database: write each test as a SQL query, and use a short shell
script to run them all and report the results. It shows the core idea behind every data-testing
tool, with nothing hidden behind a framework. The other two suites ([python_test](../python_test/README.md)
and [dbt_test](../dbt_test/README.md)) are the same idea with more tooling around it.

## The ideas, in two minutes

**A test is a question with a yes/no answer about your data.**
"Does every class have an instructor?" "Is any room booked twice at the same time?"
You write the question as a SQL query. The test passes if the answer is what you expect, and fails if not.

**Tests catch what a database schema can't.** The schema already stops some mistakes (a `NOT NULL`
column, a `CHECK` on grades). But it can't know that a room can't hold two classes at once, or that
a student can't be in two places at 10:00. Tests check rules like these, and they re-check them every time
the data changes.

**This suite has two kinds of test:**

| Kind | Files | What it asks |
|---|---|---|
| **Checks** | `test_row_counts.sql`, `test_integrity.sql`, `test_business_rules.sql`, `test_views.sql` | "Is the data that is *in* the database correct?" |
| **Must-fail tests** | `test_constraints.sql` | "Does the database *refuse* bad data?" Each one tries to insert something invalid and passes only if the database rejects it. |

**Every check prints one line:** `<test name>|PASS` or `<test name>|FAIL|<detail>`.
The script reads those lines and shows them as a report.

## Before you start

You need `sqlite3` and a terminal. Check with:

```sh
sqlite3 --version
```

All commands below are run from the project's top folder (the one containing `school_seed.sql`).

## Step 1: Build the database to test

The tests check a database file, `school.sqlite3`, so create it first:

```sh
python3 load_seed.py --force
```

You'll see a list of tables and how many rows each has. If you add `--force` when the file already
exists, it is replaced.

## Step 2: Run the tests

```sh
tests/run_tests.sh
```

You'll see output like this (shortened):

```
== Testing .../tests/../school.sqlite3
== test_always_fails.sql
  FAIL  this test always fails
        deliberate failure (tests/test_always_fails.sql)
== test_business_rules.sql
  PASS  no room double-booked
  PASS  no instructor double-booked
  ...
79 passed, 1 failed
```

Each `==` line is a test file, and each line under it is one test with its result.

## Step 3: Understand the one failure

One test is meant to fail. [test_always_fails.sql](test_always_fails.sql) exists so you can see what a
failure looks like. A failing test prints `FAIL`, its name, and a detail line to help you find the problem.

Check that the script reports failure to other programs too, through its **exit code**
(0 means everything passed, anything else means a failure):

```sh
tests/run_tests.sh > /dev/null; echo "exit code: $?"
```

This prints `exit code: 1`. Automated systems (such as a nightly build) use exactly this to decide whether to raise an alarm.

To get a clean run, delete the file: `rm tests/test_always_fails.sql`, then run the tests again.
You should see `79 passed, 0 failed`.

## Step 4: Read a test

Open [test_row_counts.sql](test_row_counts.sql). The simplest test in it is:

```sql
SELECT 'all schema objects exist',
       CASE WHEN count(*) = 13 THEN 'PASS'
            ELSE 'FAIL|found ' || count(*) || ' of 13 tables/views' END
FROM sqlite_schema
WHERE (type = 'table' AND name IN (...))
   OR (type = 'view'  AND name IN (...));
```

Every check has the same shape:

1. A name for the test (the first column).
2. A `CASE` expression that gives `'PASS'`, or `'FAIL|'` followed by a helpful detail.
3. A query that counts or collects the problems.

Now open [test_business_rules.sql](test_business_rules.sql) and read "no room double-booked".
It joins the meetings table to itself to find two meetings in the same room on the same day whose times
overlap. If it finds none, it prints `PASS`. If it finds some, it lists their IDs in the failure detail.

## Step 5: Break the data and watch a test catch it

You'll make a copy of the database, damage it on purpose, and see which test notices. The real
`school.sqlite3` is not touched.

```sh
cp school.sqlite3 /tmp/broken.sqlite3
sqlite3 /tmp/broken.sqlite3 "UPDATE enrollments SET grade = 'A' WHERE enrollment_id = 28;"
tests/run_tests.sh /tmp/broken.sqlite3
```

Enrollment 28 is a class the student is still taking, so it shouldn't have a grade yet. In the output you'll see:

```
  FAIL  enrolled and waitlisted have no grade yet
        enrollment_ids 28
```

The test named the exact row that is wrong. This is why the failure details matter: they turn
"something is wrong" into "look at enrollment 28".

Passing a path to the script is how you test any other database file.

## Step 6: Write your own check

Add this to the end of [test_integrity.sql](test_integrity.sql):

```sql
SELECT 'every course has a description',
       CASE WHEN count(*) = 0 THEN 'PASS'
            ELSE 'FAIL|course_ids ' || group_concat(course_id) END
FROM courses
WHERE description IS NULL OR description = '';
```

Run `tests/run_tests.sh` again. Your test appears in the `test_integrity.sql` section and passes.
To see it fail, run it on a damaged copy:

```sh
cp school.sqlite3 /tmp/broken.sqlite3
sqlite3 /tmp/broken.sqlite3 "UPDATE courses SET description = NULL WHERE course_id = 3;"
tests/run_tests.sh /tmp/broken.sqlite3
```

The recipe for any check:

1. Write a query that finds the **bad rows**.
2. Wrap it so it prints `PASS` when it finds none and `FAIL|<helpful detail>` when it finds some.
3. Put the test name first, and end the statement with `;`.

Keep each test's output to one row of two or three columns, or the script will not understand it.

## Step 7: Write a must-fail test

The other kind of test checks that the database rejects bad data. Open [test_constraints.sql](test_constraints.sql).
Each test starts with a `-- @test` line and has one statement that *should be rejected*:

```sql
-- @test reject room with zero capacity
INSERT INTO rooms (building_id, room_number, capacity, room_type) VALUES (1, '999', 0, 'Lecture');
```

The script runs the statement, and the test **passes only if SQLite refuses it with a constraint error**.
(A typo in your SQL counts as a failure, so a mistake can't pass by accident.)

Add one of your own at the end of the file:

```sql
-- @test reject a course with zero credits
INSERT INTO courses (department_id, course_number, title, credits) VALUES (1, '777', 'Test', 0);
```

Run the tests: `PASS  reject a course with zero credits` appears.

These tests run on a temporary copy of your database, so the bad inserts never touch `school.sqlite3`.

## Step 8: Other options

```sh
tests/run_tests.sh -q                 # quiet: only failures and the final count
tests/run_tests.sh path/to/other.db   # test a different database file
```

## If something goes wrong

| What you see | What it means |
|---|---|
| `Database not found: ...` | Build the database first (Step 1). |
| `sqlite3 not found on PATH` | SQLite isn't installed. On a Mac, run `brew install sqlite`. |
| A test shows `FAIL` with `unexpected output` | The test printed something other than `PASS` or `FAIL|...`, or returned more than one row. Check your query. |
| `FAIL  test_xxx.sql ran without SQL errors` | There is a syntax error in that file. The message shows SQLite's complaint. |

## What's in this folder

| File | Purpose |
|---|---|
| `run_tests.sh` | Runs every test file and prints the report |
| `test_row_counts.sql` | Each table has the expected number of rows; all tables and views exist |
| `test_integrity.sql` | No broken links between tables; valid formats; no missing pieces |
| `test_business_rules.sql` | No double-booking; capacity; grades match status; advisors; prerequisites |
| `test_views.sql` | The two views return the right rows |
| `test_constraints.sql` | Must-fail tests: the database rejects bad data |
| `test_always_fails.sql` | A deliberate failure, to show what one looks like. Delete it for a clean run. |

The database is never modified: checks open it read-only, and must-fail tests use a copy.
