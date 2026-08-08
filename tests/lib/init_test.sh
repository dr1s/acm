#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="${PROJECT_DIR}"
export SCRIPT_DIR

source "${PROJECT_DIR}/lib/utils/logging.sh"
source "${PROJECT_DIR}/lib/utils/config.sh"
source "${PROJECT_DIR}/lib/utils/init.sh"
source "${PROJECT_DIR}/tests/lib/assert.sh"

ORIGINAL_DIR="$(pwd)"
TMP_DIR=$(mktemp -d)
trap 'cd "${ORIGINAL_DIR}" && rm -rf "${TMP_DIR}"' EXIT

cd "${TMP_DIR}"
SCRIPT_DIR="${TMP_DIR}"
export SCRIPT_DIR

# Default init_environment (no config file)
unset CONFIG_NAME DOCKER_IMAGE_TAG COMPOSE_PROJECT
init_environment
assert_eq "server" "${CONFIG_NAME}" "init_environment default CONFIG_NAME"
assert_eq "master" "${DOCKER_IMAGE_TAG}" "init_environment default DOCKER_IMAGE_TAG"
assert_eq "server" "${COMPOSE_PROJECT}" "init_environment default COMPOSE_PROJECT"
assert_eq "server/server" "${WORK_DIR}" "init_environment default WORK_DIR"
[ -d "${TMP_DIR}/server/server" ] || fail "init_environment creates default work dir"

# init_environment with custom NAME
unset CONFIG_NAME DOCKER_IMAGE_TAG COMPOSE_PROJECT
mkdir -p "${TMP_DIR}/conf"
cat > "${TMP_DIR}/conf/custom.conf" <<'EOF'
NAME=playerbots
EOF
init_environment "${TMP_DIR}/conf/custom.conf"
assert_eq "playerbots" "${CONFIG_NAME}" "init_environment custom CONFIG_NAME"
assert_eq "playerbots" "${DOCKER_IMAGE_TAG}" "init_environment custom DOCKER_IMAGE_TAG"
assert_eq "playerbots" "${COMPOSE_PROJECT}" "init_environment custom COMPOSE_PROJECT"
assert_eq "server/playerbots" "${WORK_DIR}" "init_environment custom WORK_DIR"

# init_command_environment with valid config file
unset CONFIG_NAME DOCKER_IMAGE_TAG COMPOSE_PROJECT
init_command_environment "${TMP_DIR}/conf/custom.conf"
assert_eq "playerbots" "${CONFIG_NAME}" "init_command_environment valid config"

# init_command_environment with missing config file should exit 1
if (init_command_environment "${TMP_DIR}/conf/missing.conf" &>/dev/null); then
    fail "init_command_environment should exit on missing config"
fi

echo "PASS: init_test"
