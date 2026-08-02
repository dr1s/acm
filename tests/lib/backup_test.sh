#!/bin/bash
ORIGINAL_BACKUP_DIR="${BACKUP_DIR:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/backup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

unset BACKUP_DIR
assert_eq "${SCRIPT_DIR}/backups" "$(resolve_backup_dir)" "resolve_backup_dir default"

BACKUP_DIR="./backups"
assert_eq "${SCRIPT_DIR}/./backups" "$(resolve_backup_dir)" "resolve_backup_dir relative"

BACKUP_DIR="/mnt/backups"
assert_eq "/mnt/backups" "$(resolve_backup_dir)" "resolve_backup_dir absolute"

BACKUP_DIR="${ORIGINAL_BACKUP_DIR}"
echo "PASS: backup_test"
