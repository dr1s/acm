#!/bin/bash
#
# Environment initialization. Source this first in every command path.
#

set -euo pipefail

source "${SCRIPT_DIR}/lib/utils/logging.sh"
source "${SCRIPT_DIR}/lib/utils/config.sh"
source "${SCRIPT_DIR}/lib/utils/args.sh"

init_environment() {
    CONFIG_FILE="${1:-}"
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

        CONTAINER_CMD="$(read_config_value CONTAINER_CMD "${CONFIG_FILE}")"
        BACKUP_DIR="$(read_config_value BACKUP_DIR "${CONFIG_FILE}")"
    fi

    CONFIG_NAME="${CONFIG_NAME:-server}"
    DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-master}"
    COMPOSE_PROJECT="${COMPOSE_PROJECT:-${CONFIG_NAME}}"
    CONTAINER_CMD="${CONTAINER_CMD:-podman}"
    BACKUP_DIR="${BACKUP_DIR:-./backups}"
    export CONFIG_FILE
    export CONFIG_NAME
    export DOCKER_IMAGE_TAG
    export COMPOSE_PROJECT
    export CONTAINER_CMD
    export BACKUP_DIR
    WORK_DIR="server/${CONFIG_NAME}"
    SERVER_DIR="${SCRIPT_DIR}/${WORK_DIR}"
    export SERVER_DIR

    mkdir -p "${SERVER_DIR}"
    cd "${SERVER_DIR}"
}

# init_command_environment [args...]
# Finds the config file argument, validates it exists, and initializes the environment.
init_command_environment() {
    local CONFIG_FILE_ARG
    CONFIG_FILE_ARG="$(find_config_arg "$@")"

    if [ ! -f "${CONFIG_FILE_ARG}" ]; then
        log_error "Config file '${CONFIG_FILE_ARG}' not found."
        exit 1
    fi

    init_environment "${CONFIG_FILE_ARG}"
}
