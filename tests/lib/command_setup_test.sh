#!/bin/bash
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

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/setup.sh"

# Track which setup phases run
PHASES=()
update_main_repo() { PHASES+=("update_main_repo"); }
update_modules() { PHASES+=("update_modules"); }
remove_stale_modules() { PHASES+=("remove_stale_modules"); }
sync_compose_override() { PHASES+=("sync_compose_override"); }
patch_compose_dependency() { PHASES+=("patch_compose_dependency"); }
remove_old_images() { PHASES+=("remove_old_images"); }
build_images() { PHASES+=("build_images"); }
prune_images() { PHASES+=("prune_images"); }
prune_build_cache() { PHASES+=("prune_build_cache"); }
ensure_module_configs() { PHASES+=("ensure_module_configs"); }

# --help exits 0
if ! (command_setup --help) >/dev/null 2>&1; then
    fail "setup --help should exit 0"
fi

# Unknown argument fails
if (command_setup --unknown) >/dev/null 2>&1; then
    fail "setup --unknown should fail"
fi

# Default run executes the full flow
PHASES=()
command_setup
[[ " ${PHASES[*]} " =~ " update_main_repo " ]] || fail "setup default should update main repo"
[[ " ${PHASES[*]} " =~ " update_modules " ]] || fail "setup default should update modules"
[[ " ${PHASES[*]} " =~ " remove_stale_modules " ]] || fail "setup default should remove stale modules"
[[ " ${PHASES[*]} " =~ " build_images " ]] || fail "setup default should build images"

# --skip-update skips git operations
PHASES=()
command_setup --skip-update
[[ ! " ${PHASES[*]} " =~ " update_main_repo " ]] || fail "setup --skip-update should not update main repo"
[[ ! " ${PHASES[*]} " =~ " update_modules " ]] || fail "setup --skip-update should not update modules"
[[ " ${PHASES[*]} " =~ " build_images " ]] || fail "setup --skip-update should still build images"

# --skip-stale skips stale module removal
PHASES=()
command_setup --skip-stale
[[ ! " ${PHASES[*]} " =~ " remove_stale_modules " ]] || fail "setup --skip-stale should not remove stale modules"

# --skip-build skips image build
PHASES=()
command_setup --skip-build
[[ ! " ${PHASES[*]} " =~ " build_images " ]] || fail "setup --skip-build should not build images"

# --clean triggers image removal
PHASES=()
command_setup --clean
[[ " ${PHASES[*]} " =~ " remove_old_images " ]] || fail "setup --clean should remove old images"

# --prune triggers pruning
PHASES=()
command_setup --prune
[[ " ${PHASES[*]} " =~ " prune_images " ]] || fail "setup --prune should prune images"
[[ " ${PHASES[*]} " =~ " prune_build_cache " ]] || fail "setup --prune should prune build cache"

echo "PASS: command_setup_test"
