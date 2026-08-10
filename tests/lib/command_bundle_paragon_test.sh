#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

init_command_environment() {
    CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    CONFIG_NAME="test"
    export CONFIG_FILE CONFIG_NAME
}

log_info() { :; }
log_warn() { :; }
log_error() { :; }

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/bundles/paragon.sh"

# Mock the paragon pipeline
CLONE_CALLED=""
clone_paragon_repo() { CLONE_CALLED="yes"; }

DB_STARTED=""
# shellcheck disable=SC2034
ensure_database_running() { DB_STARTED="yes"; }

DB_WAITED=""
# shellcheck disable=SC2034
wait_for_container_database() { DB_WAITED="yes"; }

DROPPED_DB=""
paragon_drop_existing_databases() { DROPPED_DB="yes"; }

SQL_APPLIED=""
apply_sql_files() { SQL_APPLIED="yes"; return 0; }

LUA_SYNCED=""
sync_lua_scripts() { LUA_SYNCED="yes"; }

LUA_CONFIG_UPDATED=""
update_lua_config() { LUA_CONFIG_UPDATED="yes"; }

VERIFIED=""
verify_installation() { VERIFIED="yes"; }

LUA_REMOVED=""
paragon_remove_lua_scripts() { LUA_REMOVED="yes"; }

# --help exits 0 for install
if ! (bundle_paragon install --help) >/dev/null 2>&1; then
    fail "paragon install --help should exit 0"
fi

# --help exits 0 for uninstall
if ! (bundle_paragon uninstall --help) >/dev/null 2>&1; then
    fail "paragon uninstall --help should exit 0"
fi

# Unknown install argument fails
if (bundle_paragon install --unknown) >/dev/null 2>&1; then
    fail "paragon install with unknown arg should fail"
fi

# --skip-git skips clone
CLONE_CALLED=""
SQL_APPLIED=""
bundle_paragon install --skip-git
[ -z "${CLONE_CALLED}" ] || fail "paragon install --skip-git should not clone"
[ "${SQL_APPLIED}" = "yes" ] || fail "paragon install should apply SQL files"
[ "${LUA_SYNCED}" = "yes" ] || fail "paragon install should sync lua scripts"

# Full install flow
CLONE_CALLED=""
SQL_APPLIED=""
LUA_SYNCED=""
LUA_CONFIG_UPDATED=""
VERIFIED=""
bundle_paragon install
[ "${CLONE_CALLED}" = "yes" ] || fail "paragon install should clone repo by default"
[ "${SQL_APPLIED}" = "yes" ] || fail "paragon install should apply SQL files"
[ "${LUA_SYNCED}" = "yes" ] || fail "paragon install should sync lua scripts"
[ "${VERIFIED}" = "yes" ] || fail "paragon install should verify installation"

# --database triggers rewrite and lua config update
SQL_APPLIED=""
LUA_CONFIG_UPDATED=""
bundle_paragon install --database mydb
[ "${LUA_CONFIG_UPDATED}" = "yes" ] || fail "paragon install --database should update lua config"

# Uninstall flow
DROPPED_DB=""
LUA_REMOVED=""
bundle_paragon uninstall
[ "${DROPPED_DB}" = "yes" ] || fail "paragon uninstall should drop databases"
[ "${LUA_REMOVED}" = "yes" ] || fail "paragon uninstall should remove lua scripts"

echo "PASS: command_paragon_test"
