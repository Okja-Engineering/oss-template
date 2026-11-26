#!/usr/bin/env bash
# Run every workspace suite in this directory, or in the directory given, at
# most RUN_ALL_JOBS at a time (decision 233), and report through the
# product's runner library.
#
# RUN_ALL_JOBS, a whole number above 0, its leading zeros dropped, defaults
# to the CPU count: getconf's, else sysctl's, else 2. Each suite's output,
# its standard output and error together, is kept in one private directory
# and printed whole, in the suites' order, once every suite has ended: the
# output is a serial run's, but for its timing. A suite passes when it exits 0 having printed its plan,
# assert_done's "# N assertions, 0 failed"; one that cannot be started fails.
# An interrupt ends the suites and removes the private directory.
# usage: tests/run-all.sh [DIRECTORY]
set -u
set -o pipefail
export LC_ALL=C
here=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/runner.sh
. "$here/../foundation/tests/lib/runner.sh"

dir=${1:-$here}
runner_dir "$dir" || exit 1

whole() { case "$1" in '' | *[!0-9]* | 0*) return 1 ;; esac; }
cpus() {
  local c
  c=$(getconf _NPROCESSORS_ONLN 2>/dev/null) && whole "$c" && { printf '%s\n' "$c"; return; }
  c=$(sysctl -n hw.ncpu 2>/dev/null) && whole "$c" && { printf '%s\n' "$c"; return; }
  printf '2\n'
}
if [ -n "${RUN_ALL_JOBS+set}" ]; then
  # Leading zeros dropped, so 01 is 1 and 00 is nothing, refused.
  jobs=${RUN_ALL_JOBS#"${RUN_ALL_JOBS%%[!0]*}"}
  whole "$jobs" || {
    printf 'run-all: RUN_ALL_JOBS must be a whole number above 0, not "%s"\n' "$RUN_ALL_JOBS" >&2
    exit 1
  }
else
  jobs=$(cpus)
fi

suites=()
for suite in "$dir"/test_*.sh; do
  [ -f "$suite" ] && suites+=("$suite")
done
if [ "${#suites[@]}" -eq 0 ]; then
  printf '\n'
  runner_finish "$dir" 0 0 ""
  exit
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/run-all.XXXXXX") || {
  printf 'run-all: cannot make a private directory for the suites'"'"' output\n' >&2
  exit 1
}
pids=""
trap 'rm -rf "$tmp"' EXIT
# stop STATUS: end each worker's process group, its suites with it.
stop() {
  local p
  trap '' INT TERM HUP
  for p in $pids; do
    kill -TERM -- "-$p" 2>/dev/null
  done
  wait
  exit "$1"
}
trap 'stop 129' HUP
trap 'stop 130' INT
trap 'stop 143' TERM

# A worker runs, one after another, each suite it claims first, so each
# suite runs once, by whichever worker is free. The claim is a file the
# shell itself creates exclusively, noclobber opening an absent file with
# O_EXCL: mkdir(1) need not refuse the second of two racing callers, and
# Ubuntu 26.04's, uutils coreutils 0.10, lets both succeed most times.
work() {
  local i=0 s
  for s in "${suites[@]}"; do
    i=$((i + 1))
    (set -C && : >"$tmp/claim.$i") 2>/dev/null || continue
    { bash "$s" </dev/null; } >"$tmp/$i.out" 2>&1
    printf '%s\n' "$?" >"$tmp/$i.status"
  done
}
[ "$jobs" -le "${#suites[@]}" ] || jobs=${#suites[@]}
# Under job control each worker leads its own process group, which stop ends
# whole, and starts with SIGINT not ignored, so its suites can trap it. A
# worker's standard error is not the run's: on macOS a new worker may print
# "child setpgid (PID to PID): Operation not permitted" when the run has
# already made it its group's leader, about one fork in 1500, the group made
# either way; a worker writes nothing else there, its suites' output being
# kept in their own files.
set -m
k=0
while [ "$k" -lt "$jobs" ]; do
  work &
  pids="$pids $!"
  k=$((k + 1))
done 2>/dev/null
set +m
for p in $pids; do
  wait "$p"
done

ran=0 failed=0 failed_names=""
for suite in "${suites[@]}"; do
  ran=$((ran + 1))
  printf '\n=== %s\n' "$suite"
  cat "$tmp/$ran.out" 2>/dev/null
  if [ "$(cat "$tmp/$ran.status" 2>/dev/null)" = 0 ] &&
    grep -Eq '^# [0-9]+ assertions, 0 failed$' "$tmp/$ran.out"; then
    printf 'PASS %s\n' "$suite"
  else
    printf 'FAIL %s\n' "$suite"
    failed=$((failed + 1))
    failed_names="$failed_names $suite"
  fi
done
printf '\n'
runner_finish "$dir" "$ran" "$failed" "$failed_names"
