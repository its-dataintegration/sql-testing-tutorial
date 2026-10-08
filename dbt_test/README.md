# Suite 3: SQL tests run with dbt

**You need:** SQL, and a terminal. You'll write a little YAML and a few lines of a templating language
(Jinja), but every example is given, so you only need to copy and adapt.

This suite checks the same database as the other two ([shell](../tests/README.md) and
[pytest](../python_test/README.md)), but with **dbt**, a tool built specifically for testing and
managing data. Compare how much less code the common checks need here.

## The ideas, in two minutes

**A test is a question with a yes/no answer about your data.** "Is any room booked twice at the same time?"
You write the question as a SQL query, and the test passes or fails depending on the answer.

**In dbt, a test is a query that returns the rows that break a rule.** If it returns nothing, the test passes.
If it returns rows, the test fails. dbt wraps your query, counts the rows, and reports.

**What is dbt?** "Data build tool". Teams normally use it to build and document tables in a data warehouse,
and it has a testing feature that is popular on its own. Here we use only the testing part, on a SQLite file.

**dbt gives you three ways to write a test**, from least to most work:

| Way | Where | When to use it |
|---|---|---|
| **Built-in tests** | One line of YAML in `models/sources.yml` | The common rules every table has: unique, not empty, allowed values, foreign keys |
| **Generic tests** | A reusable template in `tests/generic/`, then one line of YAML wherever you need it | A rule you want to apply to many columns or tables |
| **Singular tests** | A `.sql` file in `tests/singular/` | A one-off business rule that needs a real query |

**Words you'll see:**
- **source**: a table or view that already exists in the database. dbt doesn't create the tables here; `models/sources.yml` just lists them.
- **YAML**: a simple indented text format for settings. You'll copy the patterns shown below.
- **Jinja**: the `{{ ... }}` bits inside SQL. `{{ source('school', 'courses') }}` means "the courses table", and dbt replaces it with the real table name before running.

## Step 1: Build the database to test

From the project's top folder (the one containing `school_seed.sql`):

```sh
python3 load_seed.py --force
```

This creates `school.sqlite3`, the file the tests check.

## Step 2: Install dbt (once)

dbt needs **Python 3.13** here. (dbt itself supports Python 3.10 to 3.13, and 3.13 is the newest of those. Python 3.14 does not work yet.)
Check what you have:

```sh
python3.13 --version
```

If that says "command not found", install it first. Either:

- `brew install python@3.13` (Mac), **or**
- use the `uv` tool (`brew install uv`), which downloads Python for you.

Keep Python up to date: `brew upgrade python@3.13` installs the latest security fixes.

Then, from the `dbt_test` folder:

```sh
cd dbt_test

# If you have Python 3.13:
python3.13 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt

# Or, if you use uv:
uv venv --no-managed-python --python 3.13 .venv
uv pip install --python .venv/bin/python -r requirements.txt
```

This creates `.venv`, a private folder where dbt is installed, so nothing else on your computer is affected.
Check it worked:

```sh
.venv/bin/dbt --version
```

You should see `installed: 1.11.x` and `sqlite: 1.10.0 - Up to date!`.
It also says a newer dbt (1.12) exists. That is expected: the SQLite adapter doesn't support 1.12 yet, so 1.11 is the newest that works.

## Step 3: Run the tests

```sh
.venv/bin/dbt test
```

Run this from the `dbt_test` folder. You'll see:

```
Found 110 data tests, 13 sources, ...

1 of 110 START test advisors_match_student_major ......... [RUN]
1 of 110 PASS advisors_match_student_major ............... [PASS in 0.01s]
2 of 110 START test classes_not_over_capacity ............ [RUN]
...
Done. PASS=110 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=110
```

Every test gets a `START` line and then a `PASS` or `FAIL` line. The last line is the summary.

Like the other suites, dbt reports the result to other programs through its **exit code**
(0 means everything passed):

```sh
.venv/bin/dbt test > /dev/null; echo "exit code: $?"
```

## Step 4: Take a tour

Open these files, in this order.

**1. [models/sources.yml](models/sources.yml)** lists every table and the tests that apply to it. Find `students`:

```yaml
- name: students
  tests:
    - row_count_equals:
        arguments:
          expected: 15
  columns:
    - name: student_id
      tests: [unique, not_null]
    - name: advisor_id
      tests:
        - relationships:
            arguments:
              to: "source('school', 'instructors')"
              field: "instructor_id"
    - name: status
      tests:
        - accepted_values:
            arguments:
              values: [Active, On Leave, Graduated, Withdrawn]
```

Read it as plain English: the table has 15 rows; `student_id` is unique and never empty; every `advisor_id`
must exist in the instructors table (a foreign key); `status` must be one of these four values.
Each entry is a full test. In the other suites, each of these was a hand-written query.
A test that takes settings (like `expected: 15`) lists them under `arguments:`. Tests with no settings, like `unique`, are just a name.

**2. [tests/generic/row_count_equals.sql](tests/generic/row_count_equals.sql)** is a *custom* test of the kind used in the YAML above:

```sql
{% test row_count_equals(model, expected) %}
select count(*) as actual_rows, {{ expected }} as expected_rows
from {{ model }}
having count(*) <> {{ expected }}
{% endtest %}
```

It is a SQL query with blanks (`model`, `expected`) that the YAML fills in. It returns a row only when the count is wrong.

**3. [tests/singular/room_not_double_booked.sql](tests/singular/room_not_double_booked.sql)** is a one-off business rule.
It is a normal SQL query that returns clashing meetings. The only unusual part is
`{{ source('school', 'class_meetings') }}` in place of a table name.

**4. [profiles.yml](profiles.yml)** tells dbt where the database file is (`../school.sqlite3`).

## Step 5: Run just some tests

```sh
.venv/bin/dbt test --select room_not_double_booked     # one test, by name
.venv/bin/dbt test --select source:school.students     # every test on one table
.venv/bin/dbt test --select test_type:singular         # all the one-off business rules
.venv/bin/dbt test --select test_type:generic          # all the YAML-defined tests
```

## Step 6: Break the data and watch a test catch it

Make a copy of the database, damage it on purpose, and point dbt at it with `SCHOOL_DB`.
The real `school.sqlite3` is not touched.

```sh
cp ../school.sqlite3 /tmp/broken.sqlite3
sqlite3 /tmp/broken.sqlite3 "UPDATE enrollments SET grade = 'A' WHERE enrollment_id = 28;"
SCHOOL_DB=/tmp/broken.sqlite3 .venv/bin/dbt test
```

Enrollment 28 is a class the student is still taking, so it shouldn't have a grade yet:

```
4 of 110 FAIL 1 grades_match_enrollment_status ........ [FAIL 1 in 0.00s]
...
Failure in test grades_match_enrollment_status (tests/singular/grades_match_enrollment_status.sql)
  Got 1 result, configured to fail if != 0
  compiled code at target/compiled/school_tests/tests/singular/grades_match_enrollment_status.sql
Done. PASS=109 WARN=0 ERROR=1 SKIP=0 NO-OP=0 TOTAL=110
```

Note that dbt counts a failed test as `ERROR` in its summary line. `FAIL 1` means one bad row was found.
Take care with the `SCHOOL_DB` path: if it points to a file that doesn't exist, dbt creates an empty file there
and every test errors with `no such table`. If that happens, delete the stray file.

## Step 7: Find out which rows are bad

dbt tells you *how many* rows broke the rule but not which. To see them, run the test's compiled query yourself.
dbt saved it, with the `{{ source(...) }}` parts already replaced, at the path shown in the output:

```sh
sqlite3 -header -column /tmp/broken.sqlite3 < target/compiled/school_tests/tests/singular/grades_match_enrollment_status.sql
```

```
enrollment_id   status   grade
-------------  --------  -----
           28  Enrolled  A
```

Tests written in YAML (like `unique` and `not_null`) are compiled into `target/compiled/school_tests/models/sources.yml/`.

## Step 8: Add a built-in test (a few lines of YAML)

Open [models/sources.yml](models/sources.yml). Find the `courses` table and add a `credits` column under `columns:`:

```yaml
        columns:
          - name: course_id
            tests: [unique, not_null]
          - name: credits                # new
            tests:                       # new
              - not_null                 # new
              - accepted_values:         # new
                  arguments:             # new
                    values: [1, 2, 3, 4, 5, 6]   # new
                    quote: false         # new
```

(`quote: false` is for numbers. Leave it out for text values. Keep the `arguments:` line: dbt warns about
deprecated syntax without it.) Run the courses tests:

```sh
.venv/bin/dbt test --select source:school.courses
```

Your two new tests appear as `source_not_null_school_courses_credits` and
`source_accepted_values_school_courses_credits__False__1__2__3__4__5__6`, and both pass. (The other `credits` test in the output
is the `credits between 1 and 6` rule that was already there.)

## Step 9: Add a singular test (a SQL file)

Create `tests/singular/every_course_has_a_description.sql` with:

```sql
select course_id, title
from {{ source('school', 'courses') }}
where description is null or description = ''
```

The file name becomes the test name. Run it:

```sh
.venv/bin/dbt test --select every_course_has_a_description
```

It passes. To see it fail:

```sh
sqlite3 /tmp/broken.sqlite3 "UPDATE courses SET description = NULL WHERE course_id = 3;"
SCHOOL_DB=/tmp/broken.sqlite3 .venv/bin/dbt test --select every_course_has_a_description
```

The recipe: write a query that returns the **bad rows**, and put `{{ source('school', '<table>') }}` where you'd put the table name.
**Do not end the query with a semicolon**: dbt wraps your query inside another one.

## Step 10: Write a reusable (generic) test

When you'd write the same query for many columns, make it a template. Create `tests/generic/is_not_blank.sql`:

```sql
{% test is_not_blank(model, column_name) %}
select {{ column_name }}
from {{ model }}
where {{ column_name }} is null or trim({{ column_name }}) = ''
{% endtest %}
```

`model` is the table being tested and `column_name` is the column. dbt fills both in. Now use it anywhere in
`models/sources.yml` with one word:

```yaml
          - name: title
            tests: [is_not_blank]
```

Run `.venv/bin/dbt test --select source:school.courses`. Your test appears as
`source_is_not_blank_school_courses_title`. Add the same line under other text columns to test them too.

## If something goes wrong

| What you see | What it means |
|---|---|
| `command not found: python3.13` | Install Python 3.13 (Step 2). |
| `UnserializableField` or `mashumaro` errors when starting dbt | The `.venv` was made with Python 3.14, which dbt doesn't support yet. Delete `.venv` and redo Step 2 with Python 3.13. |
| `Invalid value for '--profiles-dir'` or `Not a dbt project` | You are not in the `dbt_test` folder. |
| Every test errors with `no such table: main.xxx` | The database path is wrong or the file is empty. Run `python3 load_seed.py --force` (Step 1), or check `SCHOOL_DB`. |
| `Compilation Error ... 'test_xxx' is undefined` | A test name in the YAML doesn't match a built-in test or a file in `tests/generic/`. Check the spelling. |
| `Compilation Error ... expected token` in a test file | A typo in the `{{ }}` or `{% %}` parts, such as a missing `}}`. |
| `Database Error ... near ";": syntax error` | The query ends with a semicolon. Remove it. Other `syntax error` messages are typos in the SQL. |

## What's in this folder

| Path | Purpose |
|---|---|
| `models/sources.yml` | The tables and the YAML tests on each |
| `tests/generic/*.sql` | Reusable test templates: `row_count_equals`, `unique_combination`, `expression_is_true`, `is_iso_date`, `is_hhmm_time`, `matches_like` |
| `tests/singular/*.sql` | One-off business-rule tests |
| `profiles.yml` | Where the database file is |
| `dbt_project.yml` | Project name and folder settings |
| `requirements.txt` | The dbt versions to install (minimum versions, so you get the latest) |
| `target/`, `logs/`, `dbt_packages/` | Files dbt creates when it runs. Safe to delete. |

The database is never modified: dbt only runs `select` queries against it.

## Why use dbt for this?

- The common checks are one line of YAML instead of a hand-written query.
- Your own rules become reusable templates with parameters, such as `row_count_equals` with `expected: 5`.
- Tests are named, selectable (`--select`) and reported in one consistent format.
- The YAML documents the schema and its rules in one place.
- The same tests work unchanged on a real data warehouse (Snowflake, BigQuery, Postgres, ...), with a current dbt version.

## Versions and keeping up to date

`requirements.txt` asks for at least the newest versions available when it was written (`dbt-core` 1.11.15 and `dbt-sqlite` 1.10.0),
so a fresh install gets the latest compatible releases. To update an existing install:

```sh
.venv/bin/pip install --upgrade pip
.venv/bin/pip install --upgrade -r requirements.txt
```

Two limits to know about:

- **dbt 1.12 is out, but this suite uses 1.11.** The SQLite adapter (`dbt-sqlite` 1.10.0) isn't compatible with 1.12 yet, so 1.11 is the newest that works.
  When the adapter catches up, raise the numbers in `requirements.txt`.
- **Python 3.13, not 3.14.** dbt 1.11 supports Python 3.10 to 3.13. On 3.14, one of its libraries (`mashumaro`) crashes at start-up.
  Use the newest patch release of 3.13.

Do not remove the minimum versions in `requirements.txt`. Without them pip can quietly install a very old `dbt-sqlite` (1.4.0) that only works with an old, unsupported dbt.
To check the installed packages for known security problems: `uvx pip-audit --path .venv/lib/python3.13/site-packages`.
