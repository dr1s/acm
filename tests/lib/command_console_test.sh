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

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/console.sh"

# Stub dependency checks; we are not testing the runtime here.
check_container_runtime() { :; }

WORLD_CONTAINER_ID="test-worldserver-id"
WORLD_RUNNING="yes"
container_ps_q() {
    if [ "${WORLD_RUNNING}" = "yes" ]; then
        echo "${WORLD_CONTAINER_ID}"
    fi
}

ATTACH_CONTAINER_ID=""
exec() { ATTACH_CONTAINER_ID="${4}"; }

# --help exits 0
if ! (command_console --help) >/dev/null 2>&1; then
    fail "console --help should exit 0"
fi

# Unknown argument fails
if (command_console --unknown) >/dev/null 2>&1; then
    fail "console with unknown arg should fail"
fi

# Successful attach
ATTACH_CONTAINER_ID=""
command_console >/dev/null 2>&1
[ "${ATTACH_CONTAINER_ID}" = "${WORLD_CONTAINER_ID}" ] || fail "console should exec attach using the resolved container ID"

# Fails if worldserver is not running
WORLD_RUNNING=""
if (command_console) >/dev/null 2>&1; then
    fail "console should fail when worldserver is not running"
fi

echo "PASS: command_console_test"
