#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

log_info() { :; }
log_warn() { :; }
log_error() { :; }

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/bundle.sh"

# No arguments shows help and fails
if (command_bundle) >/dev/null 2>&1; then
    fail "bundle with no args should fail"
fi

# --help exits 0
if ! (command_bundle --help) >/dev/null 2>&1; then
    fail "bundle --help should exit 0"
fi

# Unknown bundle fails
if (command_bundle unknown-bundle install) >/dev/null 2>&1; then
    fail "bundle with unknown bundle should fail"
fi

echo "PASS: command_bundle_test"
