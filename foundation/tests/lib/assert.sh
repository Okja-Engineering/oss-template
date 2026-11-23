# shellcheck shell=bash
# Assertions for the shell suites. Source this, then call one assert per fact,
# and end every suite with `assert_done`.
#
# One assertion, one result: a compound assert reports one line for several
# facts, and when it fails you cannot tell which fact broke.
#
# Output is TAP-like: `ok N - description` or `not ok N - description`, with
# failure detail on `#` lines.

ASSERT_COUNT=0
ASSERT_FAILED=0

assert_pass() {
  ASSERT_COUNT=$((ASSERT_COUNT + 1))
  printf 'ok %d - %s\n' "$ASSERT_COUNT" "$1"
}

assert_fail() {
  ASSERT_COUNT=$((ASSERT_COUNT + 1))
  ASSERT_FAILED=$((ASSERT_FAILED + 1))
  printf 'not ok %d - %s\n' "$ASSERT_COUNT" "$1"
  shift
  while [ "$#" -gt 0 ]; do
    printf '#   %s\n' "$1"
    shift
  done
}

# assert_eq EXPECTED ACTUAL DESCRIPTION
assert_eq() {
  if [ "$1" = "$2" ]; then
    assert_pass "$3"
  else
    assert_fail "$3" "expected: $1" "actual:   $2"
  fi
}

# assert_status EXPECTED_EXIT ACTUAL_EXIT DESCRIPTION
assert_status() {
  if [ "$1" = "$2" ]; then
    assert_pass "$3"
  else
    assert_fail "$3" "expected exit: $1" "actual exit:   $2"
  fi
}

# assert_contains HAYSTACK NEEDLE DESCRIPTION
assert_contains() {
  case "$1" in
    *"$2"*) assert_pass "$3" ;;
    *) assert_fail "$3" "looked for: $2" "in:         $(printf '%s' "$1" | tr '\n' '~')" ;;
  esac
}

# assert_not_contains HAYSTACK NEEDLE DESCRIPTION
assert_not_contains() {
  case "$1" in
    *"$2"*) assert_fail "$3" "must not contain: $2" "in:               $(printf '%s' "$1" | tr '\n' '~')" ;;
    *) assert_pass "$3" ;;
  esac
}

# assert_file_exists PATH DESCRIPTION
assert_file_exists() {
  if [ -f "$1" ]; then
    assert_pass "$2"
  else
    assert_fail "$2" "no such file: $1"
  fi
}

# Print the summary and exit: non-zero if any assertion failed or none ran, so
# a suite cannot report success while carrying a failure.
assert_done() {
  printf '# %d assertions, %d failed\n' "$ASSERT_COUNT" "$ASSERT_FAILED"
  if [ "$ASSERT_COUNT" -eq 0 ]; then
    printf '# no assertions ran, which counts as a failure\n'
    exit 1
  fi
  [ "$ASSERT_FAILED" -eq 0 ] || exit 1
  exit 0
}
