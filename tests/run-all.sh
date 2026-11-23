#!/usr/bin/env bash
# Run every workspace suite in this directory, or in the directory given,
# through the product's runner library.
# usage: tests/run-all.sh [DIRECTORY]
set -u
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/runner.sh
. "$here/../foundation/tests/lib/runner.sh"
runner_main "${1:-$here}"
