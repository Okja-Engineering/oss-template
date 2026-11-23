#!/usr/bin/env bash
# A suite that fails on purpose: the runner must report it, and CI must see
# the runner fail on it.
set -u
# shellcheck source-path=SCRIPTDIR source=../../../lib/assert.sh
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/assert.sh"
assert_eq "expected" "actual" "this suite fails on purpose"
assert_done
