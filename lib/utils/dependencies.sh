#!/usr/bin/env bash
#
# Shared dependency checks for acm commands.
#

source "${SCRIPT_DIR}/lib/utils/logging.sh"

# check_container_runtime
# Verifies that CONTAINER_CMD is set, installed, and has compose support.
check_container_runtime() {
    if [ -z "${CONTAINER_CMD:-}" ]; then
        log_error "CONTAINER_CMD is not set."
        exit 1
    fi

    if ! command -v "${CONTAINER_CMD}" >/dev/null 2>&1; then
        log_error "Container command '${CONTAINER_CMD}' is not installed."
        log_error "Install ${CONTAINER_CMD} or set CONTAINER_CMD in your config."
        exit 1
    fi

    if ! "${CONTAINER_CMD}" compose version >/dev/null 2>&1; then
        log_error "'${CONTAINER_CMD} compose' is not available."
        log_error "Install the Compose plugin for ${CONTAINER_CMD}."
        exit 1
    fi
}

# check_host_commands CMD [CMD ...]
# Verifies that each host command is available.
check_host_commands() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log_error "Required command '${cmd}' is not installed."
            exit 1
        fi
    done
}
