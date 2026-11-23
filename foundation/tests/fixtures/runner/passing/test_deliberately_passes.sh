#!/usr/bin/env bash
# A suite that passes on purpose, the runner's control case.
set -u
# shellcheck source-path=SCRIPTDIR source=../../../lib/assert.sh
. "$(CDPATH='' cd -- "$(dirname "$0")/../../.." && pwd)/lib/assert.sh"
assert_eq "same" "same" "this suite passes on purpose"
assert_done
