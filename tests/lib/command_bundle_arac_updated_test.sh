#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="${PROJECT_DIR}"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/bundles/arac-updated.sh"

# Mock dependencies defined by the bundle file's libraries
init_command_environment() {
    CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    CONFIG_NAME="test"
    export CONFIG_FILE CONFIG_NAME
}

log_info() { :; }
log_warn() { :; }
log_error() { :; }

GIT_CLONE_ARGS=()
git_clone_or_pull() { GIT_CLONE_ARGS+=("${1}" "${2}"); }

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT
SERVER_DIR="${TMP_DIR}/server"
mkdir -p "${SERVER_DIR}/data/dbc"
DBC_FILES_COPIED=""
cp() { DBC_FILES_COPIED="yes"; }

# --help exits 0
if ! (bundle_arac_updated --help) >/dev/null 2>&1; then
    fail "arac-updated --help should exit 0"
fi

# Unknown subcommand fails
if (bundle_arac_updated unknown) >/dev/null 2>&1; then
    fail "arac-updated with unknown subcommand should fail"
fi

# Install clones repo and copies dbc files
GIT_CLONE_ARGS=()
DBC_FILES_COPIED=""
# Use a fresh SCRIPT_DIR so the cache check does not find a pre-existing clone
SCRIPT_DIR="${TMP_DIR}"
export SCRIPT_DIR
bundle_arac_updated install >/dev/null 2>&1 || fail "arac-updated install should succeed"
[ "${#GIT_CLONE_ARGS[@]}" -ge 2 ] || fail "arac-updated install should clone repo"
[ "${DBC_FILES_COPIED}" = "yes" ] || fail "arac-updated install should copy dbc files"

# Uninstall removes dbc files
# Note: bundle_arac_updated_uninstall uses rm -v, so mock rm
REMOVED_FILES=()
rm() { REMOVED_FILES+=("$@"); }
bundle_arac_updated uninstall >/dev/null 2>&1 || fail "arac-updated uninstall should succeed"
[ "${#REMOVED_FILES[@]}" -ge 6 ] || fail "arac-updated uninstall should remove dbc files"

echo "PASS: command_arac_updated_test"
