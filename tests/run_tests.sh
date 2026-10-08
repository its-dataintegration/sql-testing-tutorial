#!/usr/bin/env bash
# Runs the SQL tests against the school.sqlite3 database built by load_seed.py.
#
# Usage:  tests/run_tests.sh                  (tests ../school.sqlite3, from anywhere)
#         tests/run_tests.sh -q               (quiet: print only failures and the summary)
#         tests/run_tests.sh [-q] path/to.db  (test a different database file)
#
# Every test prints one line: PASS or FAIL, followed by its name.
#
# The database is never modified: query tests open it read-only, and the
# must-fail statements in test_constraints.sql run against a temporary copy.
#
# Exit code is 0 only if every test passes.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
QUIET=0
if [ "${1:-}" = "-q" ]; then QUIET=1; shift; fi
DB="${1:-$TESTS_DIR/../school.sqlite3}"

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "sqlite3 not found on PATH" >&2
    exit 2
fi
if [ ! -f "$DB" ]; then
    echo "Database not found: $DB" >&2
    echo "Create it first with:  python3 load_seed.py" >&2
    exit 2
fi

WORK="$(mktemp -d)"
COPY="$WORK/school_copy.sqlite3"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

if [ -t 1 ]; then GREEN=$'\033[32m'; RED=$'\033[31m'; RESET=$'\033[0m'; else GREEN=""; RED=""; RESET=""; fi

pass() { PASS=$((PASS + 1)); [ "$QUIET" = 1 ] || printf '  %sPASS%s  %s\n' "$GREEN" "$RESET" "$1"; return 0; }
fail() { FAIL=$((FAIL + 1)); printf '  %sFAIL%s  %s\n' "$RED" "$RESET" "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; return 0; }

echo "== Testing $DB"
CHECKSUM_BEFORE="$(shasum "$DB" | cut -d' ' -f1)"

# --- Query tests: each row printed is "<name>|PASS" or "<name>|FAIL|<detail>" -
for file in "$TESTS_DIR"/test_*.sql; do
    name="$(basename "$file")"
    [ "$name" = "test_constraints.sql" ] && continue
    echo "== $name"

    if ! out="$( (echo 'PRAGMA foreign_keys = ON;'; cat "$file") | sqlite3 -readonly -bail -batch -separator '|' "$DB" 2>&1)"; then
        fail "$name ran without SQL errors" "$out"
        continue
    fi

    while IFS='|' read -r test result detail; do
        [ -z "$test" ] && continue
        case "$result" in
            PASS) pass "$test" ;;
            FAIL) fail "$test" "$detail" ;;
            *)    fail "$test" "unexpected output: $result $detail" ;;
        esac
    done <<EOF
$out
EOF
done

# --- Constraint tests: each block must be rejected with a constraint error ----
run_constraint() {
    local test="$1" sql="$2" out
    out="$(printf 'PRAGMA foreign_keys = ON;\nBEGIN;\n%s\nROLLBACK;\n' "$sql" | sqlite3 -bail -batch "$COPY" 2>&1)"
    if [ $? -eq 0 ]; then
        fail "$test" "statement was accepted"
    elif printf '%s' "$out" | grep -qi 'constraint failed'; then
        pass "$test"
    else
        fail "$test" "failed for the wrong reason: $out"
    fi
}

echo "== test_constraints.sql (on a temporary copy)"
cp "$DB" "$COPY"
current=""
block=""
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        "-- @test "*)
            [ -n "$current" ] && run_constraint "$current" "$block"
            current="${line#-- @test }"
            block="" ;;
        *)
            [ -n "$current" ] && block="$block$line"$'\n' ;;
    esac
done < "$TESTS_DIR/test_constraints.sql"
[ -n "$current" ] && run_constraint "$current" "$block"

# --- The database itself must be untouched -----------------------------------
if [ "$(shasum "$DB" | cut -d' ' -f1)" = "$CHECKSUM_BEFORE" ]; then
    pass "database file unchanged by tests"
else
    fail "database file unchanged by tests"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
