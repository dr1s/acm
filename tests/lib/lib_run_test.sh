#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="${PROJECT_DIR}"
export SCRIPT_DIR

source "${PROJECT_DIR}/lib/utils/logging.sh"
source "${PROJECT_DIR}/lib/utils/run.sh"
source "${PROJECT_DIR}/tests/lib/assert.sh"

# Strip colors for deterministic assertions.
log_info() { echo "[INFO] ${1}"; }

OUTPUT="$(print_backup_summary "/tmp/backups" "/tmp/backups/db_backup_playerbots_20260801_120000.sql.gz" "/tmp/backups/config_backup_playerbots_20260801_120000.tar.gz")"
assert_eq $'[INFO] Backups saved to /tmp/backups/\n[INFO]   Database: db_backup_playerbots_20260801_120000.sql.gz\n[INFO]   Config:   config_backup_playerbots_20260801_120000.tar.gz' "${OUTPUT}" "print_backup_summary output"

echo "PASS: run_test"
