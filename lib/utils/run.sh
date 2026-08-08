#!/bin/bash
#
# Shared runtime helpers for starting and stopping the server stack.
# Used by the start, run, and stop commands.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"
source "${SCRIPT_DIR}/lib/utils/database.sh"
source "${SCRIPT_DIR}/lib/utils/backup.sh"

start_stack() {
    log_info "Starting compose stack..."
    container_up "$@"
}

wait_for_authserver() {
    local START_TIME="${1}"
    log_info "Services are running!"
    log_info "Waiting for authserver to be ready..."

    while true; do
        local HEALTH
        HEALTH=$(${CONTAINER_CMD} inspect --format "{{.State.Health.Status}}" "ac-authserver" 2>/dev/null || true)
        if [ "${HEALTH}" = "healthy" ]; then
            local ELAPSED=$(( $(date +%s) - START_TIME ))
            log_info "Authserver is up and running after ${ELAPSED}s."
            return 0
        fi

        local ELAPSED=$(( $(date +%s) - START_TIME ))
        if [ "${ELAPSED}" -ge 300 ]; then
            log_error "Authserver failed to become healthy after ${ELAPSED}s. Shutting down stack."
            container_compose down
            exit 1
        fi

        sleep 2
    done
}

launch_game() {
    local CONFIG_FILE="${1}"
    local SKIP_GAME="${2:-false}"

    if [ "${SKIP_GAME}" = true ]; then
        return
    fi

    local LAUNCH_GAME
    LAUNCH_GAME="$(read_config_value LAUNCH_GAME "${CONFIG_FILE}")"
    if [ -z "${LAUNCH_GAME}" ]; then
        return
    fi

    log_info "Launching game..."
    eval "${LAUNCH_GAME} &>/dev/null &"
    log_info "Game launched."
}

wait_for_game_exit() {
    local CONFIG_FILE="${1}"
    local SKIP_GAME="${2:-false}"

    if [ "${SKIP_GAME}" = true ]; then
        return
    fi

    local LAUNCH_GAME
    LAUNCH_GAME="$(read_config_value LAUNCH_GAME "${CONFIG_FILE}")"
    if [ -z "${LAUNCH_GAME}" ]; then
        return
    fi

    log_info "Waiting for game to start..."
    while ! pgrep -f "Wow.exe" >/dev/null 2>&1; do
        sleep 2
    done

    log_info "Waiting for game to exit..."
    while pgrep -f "Wow.exe" >/dev/null 2>&1; do
        sleep 2
    done
    log_info "Game exited."
}

wait_for_keypress() {
    log_info "Press any key to backup databases and shut down..."
    # Read the first byte. If the key sends an escape sequence (e.g. F9 from a
    # gamepad button), consume the rest of the sequence so it is not echoed.
    local key rest
    IFS= read -rs -n 1 key
    if [ "${key}" = $'\e' ]; then
        IFS= read -rs -t 0.2 -n 10 rest || true
        key="${key}${rest}"
    fi
    echo
}

stop_stack() {
    log_info "Stopping services..."
    container_down
}

print_backup_summary() {
    local BACKUP_DIR="${1}"
    local DB_BACKUP_FILE="${2}"
    local CFG_BACKUP_FILE="${3}"

    log_info "Backups saved to ${BACKUP_DIR}/"
    log_info "  Database: $(basename "${DB_BACKUP_FILE}")"
    log_info "  Config:   $(basename "${CFG_BACKUP_FILE}")"
}

run_full_session() {
    local CONFIG_FILE="${1}"
    local BACKUP_DIR="${2}"
    local DB_ROOT_PASSWORD="${3}"
    local CONFIG_NAME="${4}"
    local SKIP_GAME="${5}"
    shift 5
    local UP_ARGS=("$@")

    local START_TIME
    START_TIME=$(date +%s)
    # shellcheck disable=SC2119
    ensure_compose_containers_stopped
    start_stack "${UP_ARGS[@]}"
    wait_for_authserver "${START_TIME}"
    launch_game "${CONFIG_FILE}" "${SKIP_GAME}"
    wait_for_game_exit "${CONFIG_FILE}" "${SKIP_GAME}"
    wait_for_keypress

    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    stop_worldserver_and_authserver

    local DB_BACKUP_FILE CFG_BACKUP_FILE
    DB_BACKUP_FILE="$(backup_databases "${DB_ROOT_PASSWORD}" "${BACKUP_DIR}" "${CONFIG_NAME}" "${TIMESTAMP}")"
    CFG_BACKUP_FILE="$(backup_configs "${BACKUP_DIR}" "${CONFIG_NAME}" "${TIMESTAMP}")"
    cleanup_backups "${BACKUP_DIR}" "${CONFIG_NAME}" "${CONFIG_FILE}"
    print_backup_summary "${BACKUP_DIR}" "${DB_BACKUP_FILE}" "${CFG_BACKUP_FILE}"
    stop_database_container
    stop_stack
    log_info "Compose stack has been stopped."
}
