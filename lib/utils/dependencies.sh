#!/usr/bin/env bash
#
# Shared dependency checks for acm commands.
#

source "${SCRIPT_DIR}/lib/utils/logging.sh"

# __dependency_hint CMD
# Returns a package-manager hint for the given command.
__dependency_hint() {
    local cmd="${1}"
    case "${cmd}" in
        git)      echo "Install git (e.g. sudo pacman -S git, sudo apt install git)." ;;
        envsubst) echo "Install gettext (e.g. sudo pacman -S gettext, sudo apt install gettext)." ;;
        rsync)    echo "Install rsync (e.g. sudo pacman -S rsync, sudo apt install rsync)." ;;
        patch)    echo "Install patch (e.g. sudo pacman -S patch, sudo apt install patch)." ;;
        tar)      echo "Install tar (e.g. sudo pacman -S tar, sudo apt install tar)." ;;
        gzip)     echo "Install gzip (e.g. sudo pacman -S gzip, sudo apt install gzip)." ;;
        expect)   echo "Install expect (e.g. sudo pacman -S expect, sudo apt install expect)." ;;
        zcat)     echo "Install gzip (e.g. sudo pacman -S gzip, sudo apt install gzip)." ;;
        mktemp)   echo "Install coreutils (e.g. sudo pacman -S coreutils, sudo apt install coreutils)." ;;
        sed)      echo "Install sed (e.g. sudo pacman -S sed, sudo apt install sed)." ;;
        *)        echo "Install ${cmd} with your package manager." ;;
    esac
}

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
# Returns 0 if all commands are installed, 1 otherwise.
check_host_commands() {
    local cmd
    local MISSING=0
    for cmd in "$@"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log_error "Required command '${cmd}' is not installed."
            log_error "$(__dependency_hint "${cmd}")"
            MISSING=1
        fi
    done
    return "${MISSING}"
}
