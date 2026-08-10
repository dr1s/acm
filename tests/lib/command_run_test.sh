#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

init_command_environment() {
    CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    CONFIG_NAME="test"
    export CONFIG_FILE CONFIG_NAME
}

log_info() { :; }
log_warn() { :; }
log_error() { :; }

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/run.sh"

# Stub dependency checks; we are not testing the runtime here.
check_container_runtime() { :; }
check_host_commands() { :; }

# Mock run_full_session to capture invocation
CAPTURED_ARGS=()
run_full_session() {
    CAPTURED_ARGS=("$@")
}

# --help exits 0
if ! (command_run --help) >/dev/null 2>&1; then
    fail "run --help should exit 0"
fi

# Default: SKIP_GAME is false and UP_ARGS are forwarded
CAPTURED_ARGS=()
command_run --build
[ "${#CAPTURED_ARGS[@]}" -ge 4 ] || fail "run_full_session should receive expected arguments"
[ "${CAPTURED_ARGS[2]}" = "test" ] || fail "run_full_session should receive CONFIG_NAME"
[ "${CAPTURED_ARGS[3]}" = "false" ] || fail "run_full_session should receive SKIP_GAME=false by default"
[ "${CAPTURED_ARGS[4]}" = "--build" ] || fail "run_full_session should receive forwarded up-args"

# --skip-game sets SKIP_GAME to true
CAPTURED_ARGS=()
command_run --skip-game
[ "${CAPTURED_ARGS[3]}" = "true" ] || fail "run --skip-game should pass SKIP_GAME=true"

# Config file is extracted and other args are forwarded
CAPTURED_ARGS=()
command_run ./conf/custom.conf --build
[ "${CAPTURED_ARGS[4]}" = "--build" ] || fail "run should forward up-args after config file"

echo "PASS: command_run_test"
