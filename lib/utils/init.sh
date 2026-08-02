#!/bin/bash
#
# Environment initialization. Source this first in every command path.
#

set -euo pipefail

source "${SCRIPT_DIR}/lib/utils/logging.sh"
source "${SCRIPT_DIR}/lib/utils/config.sh"

init_environment() {
    local CONFIG_FILE="${1:-}"
    if [ -z "${CONFIG_FILE}" ]; then
        CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    fi

    if [ -f "${CONFIG_FILE}" ]; then
        local NAME
        NAME="$(read_config_value NAME "${CONFIG_FILE}")"
        if [ -n "${NAME}" ]; then
            CONFIG_NAME="${NAME}"
            DOCKER_IMAGE_TAG="${NAME}"
        fi
    fi

    CONFIG_NAME="${CONFIG_NAME:-server}"
    DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-master}"
    COMPOSE_PROJECT="${COMPOSE_PROJECT:-${CONFIG_NAME}}"
    export CONFIG_NAME
    export DOCKER_IMAGE_TAG
    export COMPOSE_PROJECT
    WORK_DIR="server/${CONFIG_NAME}"

    mkdir -p "${SCRIPT_DIR}/${WORK_DIR}"
    cd "${SCRIPT_DIR}/${WORK_DIR}"
}

# init_command_environment CONFIG_FILE
# Validates the config file exists and initializes the environment.
init_command_environment() {
    local CONFIG_FILE="${1}"

    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Config file '${CONFIG_FILE}' not found."
        exit 1
    fi

    init_environment "${CONFIG_FILE}"
}
