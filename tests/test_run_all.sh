#!/usr/bin/env bash
# The workspace's runner is a thin caller of the product's runner library,
# given the workspace's tests/ directory: it runs those suites and no others,
# and fails when one of them fails.
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
ROOT=$(cd "$TEST_DIR/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$ROOT/foundation/tests/lib/assert.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# write_suite FILE NAME: a suite with one passing assertion. The runner
# gives a suite no arguments, so it finds the assertion library through
# ASSERT_LIB, never through a path pasted into its source.
export ASSERT_LIB="$ROOT/foundation/tests/lib/assert.sh"
write_suite() {
  # shellcheck disable=SC2016 # expanded by the generated suite, not here
  printf '%s\n' '#!/usr/bin/env bash' 'set -u' '. "$ASSERT_LIB"' "assert_eq a a '$2'" 'assert_done' >"$1"
}

# A copy of the workspace layout: tests/run-all.sh beside the product library.
W="$SCRATCH/ws"
mkdir -p "$W/tests" "$W/foundation/tests/lib"
cp "$TEST_DIR/run-all.sh" "$W/tests/run-all.sh" 2>/dev/null
cp "$ROOT/foundation/tests/lib/runner.sh" "$ROOT/foundation/tests/lib/assert.sh" \
  "$W/foundation/tests/lib/" 2>/dev/null
write_suite "$W/tests/test_workspace.sh" workspace
write_suite "$W/foundation/tests/test_product.sh" product

out=$(cd "$SCRATCH" && bash "$W/tests/run-all.sh" 2>&1)
status=$?
assert_status 0 "$status" "tests/run-all.sh with no argument passes on tests/"
assert_contains "$out" "$W/tests/test_workspace.sh" "it ran the workspace suite"
assert_not_contains "$out" "test_product.sh" "it did not run a product suite"
assert_contains "$out" "1 suites passed" "it counted one suite"

out=$(bash "$TEST_DIR/run-all.sh" "$ROOT/foundation/tests/fixtures/runner/failing" 2>&1)
status=$?
assert_status 1 "$status" "tests/run-all.sh fails on the failing fixture"

assert_done
