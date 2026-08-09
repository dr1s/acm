#!/bin/bash
set -euo pipefail
ORIGINAL_PASSWORD="${DOCKER_DB_ROOT_PASSWORD:-}"
# shellcheck disable=SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/database.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

unset DOCKER_DB_ROOT_PASSWORD
assert_eq "password" "$(get_db_password)" "get_db_password default"

DOCKER_DB_ROOT_PASSWORD="secret123"
assert_eq "secret123" "$(get_db_password)" "get_db_password custom"

DOCKER_DB_ROOT_PASSWORD="${ORIGINAL_PASSWORD}"
echo "PASS: database_test"
