# shellcheck shell=bash
# The suite runner, given a directory: run every `test_*.sh` directly in it
# and fail if any fails, if none ran, or if git tracks a suite there that did
# not run. Fixtures live in subdirectories, so they are not picked up.
#
# usage: . runner.sh; runner_main DIR
# A caller (a run-all.sh) exports LC_ALL=C first. A caller that runs the
# suites itself checks DIR with runner_dir, then reports with runner_finish.
#
#   runner_dir DIR       exit 0 when DIR is a directory; else say so, exit 1
#   runner_finish DIR RAN FAILED NAMES
#                        after RAN suites ran, FAILED of them, NAMES, failed:
#                        exit 1 when none ran, when git tracks a suite in DIR
#                        that did not run, or when any failed; else exit 0

runner_dir() {
  [ -d "$1" ] && return 0
  printf 'run-all: not a directory: %s\n' "$1" >&2
  return 1
}

runner_main() {
  local dir=$1 suite ran=0 failed=0 failed_names=""

  runner_dir "$dir" || return 1

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
  runner_finish "$dir" "$ran" "$failed" "$failed_names"
}

runner_finish() {
  local dir=$1 ran=$2 failed=$3 failed_names=$4 suite tracked missing=""

  if [ "$ran" -eq 0 ]; then
    printf 'run-all: no test suites found in %s\n' "$dir" >&2
    return 1
  fi

  # Every suite git tracks here has to have run: a suite that disappeared
  # from the checkout must not read as a smaller pass. A committed deletion
  # is not caught, since git then tracks nothing either. Names are read
  # from git's NUL-delimited list, as they are, never split or quoted.
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tracked=$(
      set -o pipefail
      git -C "$dir" ls-files -z -- 'test_*.sh' | tr '\0' '\n'
    ) || {
      printf 'run-all: could not list the suites git tracks in %s\n' "$dir" >&2
      return 1
    }
    while IFS= read -r suite; do
      case "$suite" in '' | */*) continue ;; esac
      [ -f "$dir/$suite" ] || missing="$missing $suite"
    done <<EOF
$tracked
EOF
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
