# shellcheck shell=bash
# The suite runner, given a directory: run every `test_*.sh` directly in it
# and fail if any fails, if none ran, or if git tracks a suite there that did
# not run. Fixtures live in subdirectories, so they are not picked up.
#
# usage: . runner.sh; runner_main DIR
# A caller (a run-all.sh) exports LC_ALL=C first.

runner_main() {
  local dir=$1 suite tracked ran=0 failed=0 failed_names="" missing=""

  if [ ! -d "$dir" ]; then
    printf 'run-all: not a directory: %s\n' "$dir" >&2
    return 1
  fi

  for suite in "$dir"/test_*.sh; do
    [ -f "$suite" ] || continue
    ran=$((ran + 1))
    printf '\n=== %s\n' "$suite"
    if bash "$suite"; then
      printf 'PASS %s\n' "$suite"
    else
      printf 'FAIL %s\n' "$suite"
      failed=$((failed + 1))
      failed_names="$failed_names $suite"
    fi
  done
  printf '\n'

  if [ "$ran" -eq 0 ]; then
    printf 'run-all: no test suites found in %s\n' "$dir" >&2
    return 1
  fi

  # Every suite git tracks here has to have run: a suite that disappeared
  # from the checkout must not read as a smaller pass. A committed deletion
  # is not caught, since git then tracks nothing either.
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for tracked in $(git -C "$dir" ls-files -- 'test_*.sh' 2>/dev/null); do
      case "$tracked" in */*) continue ;; esac
      [ -f "$dir/$tracked" ] || missing="$missing $tracked"
    done
  else
    printf 'run-all: %s is not in a git work tree, so the suite list was not cross-checked\n' "$dir"
  fi

  if [ -n "$missing" ]; then
    printf 'run-all: git tracks suites in %s that did not run:%s\n' "$dir" "$missing" >&2
    printf 'run-all: %d suites ran; a missing suite is a failure, not a smaller pass\n' "$ran" >&2
    return 1
  fi

  if [ "$failed" -ne 0 ]; then
    printf 'run-all: %d of %d suites failed:%s\n' "$failed" "$ran" "$failed_names" >&2
    return 1
  fi

  printf 'run-all: %d suites passed\n' "$ran"
  return 0
}
