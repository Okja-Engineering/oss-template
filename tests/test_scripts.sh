#!/usr/bin/env bash
# The workspace's scripts (decision 228): every tracked script outside
# foundation/ and tests/fixtures/, a file whose first line is a bash shebang,
# sets `set -o pipefail`, so no failure is lost at the head of a pipeline.
set -u
set -o pipefail
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
WS=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)

scripts=$(cd "$WS" && git ls-files -z -- . ':!foundation/' ':!tests/fixtures/' | tr '\0' '\n') || {
  assert_fail "the tracked files can be listed"
  assert_done
}
count=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ "$(head -n 1 "$WS/$f" 2>/dev/null)" = '#!/usr/bin/env bash' ] || continue
  count=$((count + 1))
  if grep -qx 'set -o pipefail' "$WS/$f"; then
    assert_pass "$f sets -o pipefail"
  else
    assert_fail "$f sets -o pipefail"
  fi
done <<EOF
$scripts
EOF
assert_eq "yes" "$([ "$count" -ge 10 ] && echo yes)" "the scripts are found: $count"

assert_done
