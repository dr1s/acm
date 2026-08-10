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

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/create-account.sh"

# Mock dependencies
EXPECT_CHECKED=""
check_expect_installed() { EXPECT_CHECKED="yes"; return 0; }

WORLD_RUNNING="yes"
container_ps_q() { echo "${WORLD_RUNNING}"; }

ACCOUNT_CREATED=""
run_expect_create_account() { ACCOUNT_CREATED="${1}:${2}"; return 0; }

# --help exits 0
if ! (command_create_account --help) >/dev/null 2>&1; then
    fail "create-account --help should exit 0"
fi

# Missing username/password fails
if (command_create_account) >/dev/null 2>&1; then
    fail "create-account without credentials should fail"
fi

if (command_create_account myuser) >/dev/null 2>&1; then
    fail "create-account without password should fail"
fi

# Unknown argument fails
if (command_create_account myuser mypass --unknown) >/dev/null 2>&1; then
    fail "create-account with unknown arg should fail"
fi

# Successful account creation
EXPECT_CHECKED=""
ACCOUNT_CREATED=""
command_create_account myuser mypass
[ "${EXPECT_CHECKED}" = "yes" ] || fail "create-account should check for expect"
[ "${ACCOUNT_CREATED}" = "myuser:mypass" ] || fail "create-account should run expect with username and password"

# Fails if worldserver is not running
WORLD_RUNNING=""
if (command_create_account myuser mypass) >/dev/null 2>&1; then
    fail "create-account should fail when worldserver is not running"
fi

echo "PASS: command_create_account_test"
