#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="${PROJECT_DIR}"
export SCRIPT_DIR

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

source "${PROJECT_DIR}/lib/utils/logging.sh"
source "${PROJECT_DIR}/lib/utils/run.sh"
source "${PROJECT_DIR}/tests/lib/assert.sh"

# Strip colors for deterministic assertions.
log_info() { echo "[INFO] ${1}"; }

OUTPUT="$(print_backup_summary "/tmp/backups" "/tmp/backups/db_backup_playerbots_20260801_120000.sql.gz" "/tmp/backups/config_backup_playerbots_20260801_120000.tar.gz")"
assert_eq $'[INFO] Backups saved to /tmp/backups/\n[INFO]   Database: db_backup_playerbots_20260801_120000.sql.gz\n[INFO]   Config:   config_backup_playerbots_20260801_120000.tar.gz' "${OUTPUT}" "print_backup_summary output"

# wait_for_authserver resolves the container via container_ps_q and inspects that ID
FAKE_CONTAINER_CMD="$(mktemp)"
cat > "${FAKE_CONTAINER_CMD}" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${FAKE_CONTAINER_CMD_ARGS:-/tmp/fake_container_cmd_args}"
if [ "$1" = "inspect" ] && [ "$2" = "--format" ] && [ "$3" = "{{.State.Health.Status}}" ]; then
    echo "healthy"
fi
EOF
chmod +x "${FAKE_CONTAINER_CMD}"

FAKE_CONTAINER_CMD_ARGS="$(mktemp)"
export FAKE_CONTAINER_CMD_ARGS

CONTAINER_CMD="${FAKE_CONTAINER_CMD}"
export CONTAINER_CMD

CONTAINER_COMPOSE_CALLS=""
container_compose() {
    CONTAINER_COMPOSE_CALLS="${CONTAINER_COMPOSE_CALLS} $*"
}

container_ps_q() {
    echo "test-authserver-id"
}

wait_for_authserver "$(date +%s)" >/dev/null

INSPECT_TARGET="$(sed -n '4p' "${FAKE_CONTAINER_CMD_ARGS}")"
assert_eq "test-authserver-id" "${INSPECT_TARGET}" "wait_for_authserver inspects the container ID returned by container_ps_q"

# wait_for_authserver fails if the authserver container is not found
container_ps_q() { :; }
CONTAINER_COMPOSE_LOG="$(mktemp)"
container_compose() {
    echo "$*" >> "${CONTAINER_COMPOSE_LOG}"
}
if (wait_for_authserver "$(date +%s)" >/dev/null 2>&1); then
    fail "wait_for_authserver should fail when authserver container is not found"
fi
assert_eq "down" "$(cat "${CONTAINER_COMPOSE_LOG}")" "wait_for_authserver shuts down stack when authserver container is not found"

rm -f "${FAKE_CONTAINER_CMD}" "${FAKE_CONTAINER_CMD_ARGS}" "${CONTAINER_COMPOSE_LOG}"

# launch_game executes LAUNCH_GAME without eval
GAME_LAUNCH_MARKER="${TMP_DIR}/game_launched"
FAKE_GAME_CMD="${TMP_DIR}/fake_game"
cat > "${FAKE_GAME_CMD}" <<EOF
#!/usr/bin/env bash
touch "${GAME_LAUNCH_MARKER}"
EOF
chmod +x "${FAKE_GAME_CMD}"

read_config_value() {
    if [ "$1" = "LAUNCH_GAME" ]; then
        echo "${FAKE_GAME_CMD} arg1 arg2"
    fi
}

CONFIG_FILE="${PROJECT_DIR}/conf/wowserver.conf"
export CONFIG_FILE

launch_game false
sleep 0.5
[ -f "${GAME_LAUNCH_MARKER}" ] || fail "launch_game should execute LAUNCH_GAME"

# launch_game is skipped when SKIP_GAME is true
rm -f "${GAME_LAUNCH_MARKER}"
launch_game true
[ ! -f "${GAME_LAUNCH_MARKER}" ] || fail "launch_game should be skipped when SKIP_GAME is true"

rm -f "${FAKE_GAME_CMD}" "${GAME_LAUNCH_MARKER}"

echo "PASS: run_test"
