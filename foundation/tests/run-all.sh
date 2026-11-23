#!/usr/bin/env bash
# Run every suite in this directory, or in the directory given.
# usage: tests/run-all.sh [DIRECTORY]
set -u
export LC_ALL=C
here=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/runner.sh
. "$here/lib/runner.sh"
runner_main "${1:-$here}"
