#!/usr/bin/env bash
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

Backup retention can be configured in the config file. See README.md for details.
EOF
}

command_backup() {
    parse_command_args show_backup_help "--skip-stop" "$@"
    reject_positional_args show_backup_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    local SKIP_STOP="${PARSED_FLAGS[--skip-stop]:-false}"

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
        local START_TIME
        START_TIME=$(date +%s)
        wait_for_authserver "${START_TIME}"
    fi

    log_info "Backup complete."
}
