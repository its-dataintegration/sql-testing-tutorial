# School database: sample data and three ways to test it

This project has two parts:

1. **A sample school database** (students, classes, instructors, rooms and schedules), built from one SQL script into a SQLite file.
2. **Three test suites** that check the database, each using a different tool. They test the same things, so you can compare the tools side by side.

If you know SQL but are new to testing data, start with the [shell suite](tests/README.md). It uses nothing but SQL and a short script, so the ideas are easy to see. The other two suites show how the same ideas look with more specialised tools.

## Quick start

From this folder:

```sh
python3 load_seed.py            # creates school.sqlite3 from school_seed.sql
sqlite3 school.sqlite3          # explore the data; try:  SELECT * FROM v_class_roster;
tests/run_tests.sh              # run the first test suite
```

`load_seed.py` needs only Python 3 and creates `school.sqlite3` in the current folder. To rebuild it later, add `--force`.
All three suites test that file, and none of them changes it.

## The database

`school_seed.sql` creates 11 tables and 2 views, and fills them with sample data for two terms (Spring 2026 and Fall 2026).

| Table | What it holds |
|---|---|
| `departments`, `instructors` | Five departments and their ten instructors |
| `students` | Fifteen students, with their major and advisor |
| `terms` | The two terms |
| `buildings`, `rooms` | Where classes happen, with capacity and type (lecture, lab, seminar) |
| `courses`, `course_prerequisites` | The course catalogue and which course must come before another |
| `classes` | A course offered in a term: a section, its instructor, and an enrollment limit |
| `class_meetings` | The weekly schedule: day, start and end time, and room |
| `enrollments` | Which student is in which class, with status and grade |

| View | What it shows |
|---|---|
| `v_class_roster` | Each class with its instructor and students |
| `v_student_schedule` | Each student's weekly timetable |

## The three test suites

All three ask the same kind of question about the data: "Is any room booked twice at the same time?", "Does every class have an instructor?", "Does the database refuse a grade of `A+`?"

| | Suite 1: Shell | Suite 2: pytest | Suite 3: dbt |
|---|---|---|---|
| **Folder** | [tests/](tests/README.md) | [python_test/](python_test/README.md) | [dbt_test/](dbt_test/README.md) |
| **Tool** | A bash script and `sqlite3` | pytest (a Python testing tool) | dbt (a data testing tool) |
| **Where the tests live** | `.sql` files | `.sql` files | YAML for common rules, `.sql` files for the rest |
| **What you write** | A query that prints `PASS` or `FAIL` | A query that returns the bad rows | One line of YAML, or a query that returns the bad rows |
| **Number of tests** | 80 | 69 | 110 |
| **Extra setup** | None | A Python virtual environment | Python 3.13 and a virtual environment |
| **Good for learning** | How a test works, with nothing hidden | How a framework finds, names and reports tests | How common checks can become one line each |

Each folder has its own step-by-step guide. They are written for people who know SQL but not testing, and
they all follow the same path: run the tests, read the output, break the data on purpose and watch a test catch it,
then write a test of your own.

## Two kinds of test

Every suite has both kinds:

- **Checks** ask "is the data in the database correct?" Each is a query that finds rule-breaking rows, and it passes when there are none.
  Examples: no room is double-booked, every class has an instructor, completed classes have a grade.
- **Must-fail tests** ask "does the database refuse bad data?" Each tries to insert something invalid, such as a room with zero capacity,
  and passes only if the database rejects it.

## Two deliberate failures

The shell suite and the pytest suite each contain one test that is **meant to fail**, so you can see what a failure looks like:
`tests/test_always_fails.sql` and `python_test/sql/checks/always_fails.sql`. So those two suites report one failure on a normal run
(`79 passed, 1 failed` and `68 passed, 1 failed`). Delete the file to get a clean run. The dbt suite has no such test and passes completely.

## Python and package versions

The setup steps install the latest versions, to avoid known security problems and deprecated features:

- **pytest suite:** the newest Python (3.14.8 when this was written) and the newest pytest.
- **dbt suite:** Python 3.13 and dbt 1.11, the newest versions that work together. dbt 1.12 and Python 3.14 exist, but the SQLite adapter and dbt 1.11
  don't support them yet. See the [dbt guide](dbt_test/README.md#versions-and-keeping-up-to-date).
- **Shell suite and `load_seed.py`:** no packages; they use only `sqlite3` and the Python standard library.

Both `requirements.txt` files ask for at least the newest version, so a new install gets the latest releases.
The packages in both environments were scanned with `pip-audit` and no known vulnerabilities were found.

## What's in this folder

| Path | Purpose |
|---|---|
| `school_seed.sql` | Creates the tables and views and fills them with sample data |
| `load_seed.py` | Builds `school.sqlite3` from `school_seed.sql`, safely: a failed load never damages an existing database |
| `school.sqlite3` | The database all three suites test. Created by `load_seed.py`; safe to delete and rebuild |
| `tests/` | Suite 1: SQL tests run with a shell script |
| `python_test/` | Suite 2: the same tests run with pytest |
| `dbt_test/` | Suite 3: tests written for dbt |

## Changing the data

If you edit `school_seed.sql`, rebuild the database and rerun the tests:

```sh
python3 load_seed.py --force
tests/run_tests.sh
```

If your change breaks a rule, the failing test names the rows involved. You may also need to update tests that expect exact values,
such as row counts or a particular student's timetable.
