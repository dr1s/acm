#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

# Mock dependencies not redefined by the command file's libraries
init_command_environment() {
    CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    CONFIG_NAME="test"
    export CONFIG_FILE CONFIG_NAME
}

log_info() { :; }
log_warn() { :; }
log_error() { :; }

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/backup.sh"

# Mock dependencies defined by the command file's libraries
resolve_backup_dir() { echo "/tmp/backups"; }
get_db_password() { echo "password"; }
container_up() { :; }

STOPPED=""
stop_worldserver_and_authserver() { STOPPED="yes"; }

DB_BACKUP_RESULT="/tmp/backups/db_backup_test_20260101_120000.sql.gz"
CFG_BACKUP_RESULT="/tmp/backups/config_backup_test_20260101_120000.tar.gz"
backup_databases() { echo "${DB_BACKUP_RESULT}"; }
backup_configs() { echo "${CFG_BACKUP_RESULT}"; }
CLEANED=""
cleanup_backups() { CLEANED="yes"; }

STARTED=""
START_TIME_PASSED=""
wait_for_authserver() { STARTED="yes"; START_TIME_PASSED="${1}"; }

# --help exits 0 and prints usage
if ! (command_backup --help) >/dev/null 2>&1; then
    fail "backup --help should exit 0"
fi

# Unknown argument fails
if (command_backup --unknown) >/dev/null 2>&1; then
    fail "backup --unknown should fail"
fi

# Default behavior stops and restarts worldserver/authserver
STOPPED=""
STARTED=""
command_backup
[ "${STOPPED}" = "yes" ] || fail "backup should stop worldserver/authserver by default"
[ "${STARTED}" = "yes" ] || fail "backup should restart worldserver/authserver by default"
[ "${START_TIME_PASSED}" != "" ] || fail "backup should pass START_TIME to wait_for_authserver"

# --skip-stop avoids stop/restart
STOPPED=""
STARTED=""
command_backup --skip-stop
[ -z "${STOPPED}" ] || fail "backup --skip-stop should not stop worldserver/authserver"
[ -z "${STARTED}" ] || fail "backup --skip-stop should not restart worldserver/authserver"

# Backup pipeline is always invoked
[ "${CLEANED}" = "yes" ] || fail "backup should invoke cleanup_backups"

echo "PASS: command_backup_test"
