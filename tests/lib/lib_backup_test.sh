#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/backup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

TMP_CONFIG=$(mktemp)
trap 'rm -f "${TMP_CONFIG}"' EXIT

CONFIG_FILE="${TMP_CONFIG}"
export CONFIG_FILE

# Default: no BACKUP_DIR in config
unset BACKUP_DIR
assert_eq "${SCRIPT_DIR}/./backups" "$(resolve_backup_dir)" "resolve_backup_dir default"

# Relative path from config
cat > "${TMP_CONFIG}" <<'EOF'
BACKUP_DIR=./backups
EOF
BACKUP_DIR="$(read_config_value BACKUP_DIR "${TMP_CONFIG}")"
assert_eq "${SCRIPT_DIR}/./backups" "$(resolve_backup_dir)" "resolve_backup_dir relative"

# Absolute path from config
cat > "${TMP_CONFIG}" <<'EOF'
BACKUP_DIR=/mnt/backups
EOF
BACKUP_DIR="$(read_config_value BACKUP_DIR "${TMP_CONFIG}")"
assert_eq "/mnt/backups" "$(resolve_backup_dir)" "resolve_backup_dir absolute"

# cleanup_backups tests
TMP_BACKUP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_BACKUP_DIR}" "${TMP_CONFIG}"' EXIT

TODAY=$(date +%Y%m%d)
OLD_DATE=$(date -d "${TODAY} - 10 days" +%Y%m%d 2>/dev/null || date -v-10d +%Y%m%d 2>/dev/null)

touch "${TMP_BACKUP_DIR}/db_backup_test_${TODAY}_120000.sql.gz"
touch "${TMP_BACKUP_DIR}/db_backup_test_${OLD_DATE}_120000.sql.gz"

cat > "${TMP_CONFIG}" <<'EOF'
KEEP_ALL_BACKUPS=true
EOF

cleanup_backups "${TMP_BACKUP_DIR}" "test"
[ -f "${TMP_BACKUP_DIR}/db_backup_test_${OLD_DATE}_120000.sql.gz" ] || fail "KEEP_ALL_BACKUPS should preserve old backup"

# Reset and verify default retention deletes backups beyond all windows
rm -f "${TMP_BACKUP_DIR}/db_backup_test_${OLD_DATE}_120000.sql.gz"
VERY_OLD_DATE=$(date -d "${TODAY} - 400 days" +%Y%m%d 2>/dev/null || date -v-400d +%Y%m%d 2>/dev/null)
touch "${TMP_BACKUP_DIR}/db_backup_test_${VERY_OLD_DATE}_120000.sql.gz"
: > "${TMP_CONFIG}"

cleanup_backups "${TMP_BACKUP_DIR}" "test"
[ ! -f "${TMP_BACKUP_DIR}/db_backup_test_${VERY_OLD_DATE}_120000.sql.gz" ] || fail "default retention should delete 400-day-old backup"

# Verify custom retention windows are read from config
YESTERDAY=$(date -d "${TODAY} - 1 day" +%Y%m%d 2>/dev/null || date -v-1d +%Y%m%d 2>/dev/null)
touch "${TMP_BACKUP_DIR}/db_backup_test_${YESTERDAY}_120000.sql.gz"

cat > "${TMP_CONFIG}" <<'EOF'
BACKUP_RETAIN_DAILY=1
EOF

cleanup_backups "${TMP_BACKUP_DIR}" "test"
[ ! -f "${TMP_BACKUP_DIR}/db_backup_test_${YESTERDAY}_120000.sql.gz" ] || fail "custom BACKUP_RETAIN_DAILY=1 should delete yesterday's backup"

echo "PASS: backup_test"
