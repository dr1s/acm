#!/bin/bash
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

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/restore.sh"

# Mock the restore pipeline
BACKUP_RESOLVED=""
RESOLVE_CALLED=""
# shellcheck disable=SC2034
resolve_backup_path() { RESOLVE_CALLED="yes"; BACKUP_RESOLVED="${BACKUP_ARG}"; BACKUP_FILE="${BACKUP_ARG}"; }

STOP_AND_REMOVE_DB=""
stop_and_remove_database() { STOP_AND_REMOVE_DB="yes"; }

VOLUME_REMOVED=""
remove_existing_volume() { VOLUME_REMOVED="yes"; }

DB_STARTED=""
start_database() { DB_STARTED="yes"; }

DB_WAITED=""
wait_for_container_database() { DB_WAITED="yes"; }

RESTORED=""
restore_backup() { RESTORED="yes"; }

DB_STOPPED=""
stop_database() { DB_STOPPED="yes"; }

# --help exits 0
if ! (command_restore --help) >/dev/null 2>&1; then
    fail "restore --help should exit 0"
fi

# Missing backup file fails
if (command_restore) >/dev/null 2>&1; then
    fail "restore without backup file should fail"
fi

# Full restore flow
BACKUP_ARG="/tmp/db_backup_test_20260101_120000.sql.gz"
touch "${BACKUP_ARG}"
trap 'rm -f "${BACKUP_ARG}"' EXIT

RESOLVE_CALLED=""
STOP_AND_REMOVE_DB=""
VOLUME_REMOVED=""
DB_STARTED=""
DB_WAITED=""
RESTORED=""
DB_STOPPED=""
command_restore "${BACKUP_ARG}"
[ "${RESOLVE_CALLED}" = "yes" ] || fail "restore should resolve backup path"
[ "${STOP_AND_REMOVE_DB}" = "yes" ] || fail "restore should stop and remove database"
[ "${VOLUME_REMOVED}" = "yes" ] || fail "restore should remove existing volume"
[ "${DB_STARTED}" = "yes" ] || fail "restore should start database"
[ "${DB_WAITED}" = "yes" ] || fail "restore should wait for database"
[ "${RESTORED}" = "yes" ] || fail "restore should restore backup"
[ "${DB_STOPPED}" = "yes" ] || fail "restore should stop database"

echo "PASS: command_restore_test"
