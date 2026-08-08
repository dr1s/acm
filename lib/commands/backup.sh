#!/bin/bash
#
# acm backup command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/run.sh"

show_backup_help() {
    cat <<'EOF'
Usage: ./acm backup [OPTIONS] [config-file]

Backup all MySQL databases and config files.

By default the worldserver and authserver are stopped before the backup and
started again afterward to ensure a consistent database dump. Use --skip-stop
to leave them running.

Options:
  --skip-stop     Do not stop worldserver/authserver before backing up
  -h, --help      Show this help message
EOF
}

command_backup() {
    local SKIP_STOP=false

    local arg
    for arg in "${@}"; do
        case "${arg}" in
            --skip-stop) SKIP_STOP=true ;;
            -h|--help) show_backup_help; exit 0 ;;
            *.conf) ;;
            *) log_error "Unknown argument: ${arg}"; show_backup_help; exit 1 ;;
        esac
    done

    local CONFIG_FILE
    CONFIG_FILE="$(find_config_arg "${SCRIPT_DIR}" "${@}")"

    init_command_environment "${CONFIG_FILE}"

    local BACKUP_DIR
    BACKUP_DIR="$(resolve_backup_dir)"

    local DB_ROOT_PASSWORD
    DB_ROOT_PASSWORD="$(get_db_password)"

    if [ "${SKIP_STOP}" = false ]; then
        stop_worldserver_and_authserver
    fi

    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    local DB_BACKUP_FILE CFG_BACKUP_FILE
    DB_BACKUP_FILE="$(backup_databases "${DB_ROOT_PASSWORD}" "${BACKUP_DIR}" "${CONFIG_NAME}" "${TIMESTAMP}")"
    CFG_BACKUP_FILE="$(backup_configs "${BACKUP_DIR}" "${CONFIG_NAME}" "${TIMESTAMP}")"
    cleanup_backups "${BACKUP_DIR}" "${CONFIG_NAME}"

    log_info "Database backup: $(basename "${DB_BACKUP_FILE}")"
    log_info "Config backup:   $(basename "${CFG_BACKUP_FILE}")"

    if [ "${SKIP_STOP}" = false ]; then
        log_info "Starting worldserver and authserver..."
        container_up ac-worldserver ac-authserver
        START_TIME=$(date +%s)
        wait_for_authserver
    fi

    log_info "Backup complete."
}
