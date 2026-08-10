#!/bin/bash
#
# acm restore command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"
source "${SCRIPT_DIR}/lib/utils/database.sh"

show_restore_help() {
    cat <<'EOF'
Usage: ./acm restore [config-file] <backup-file.sql.gz>

Stop the stack, remove the database volume, and restore from a compressed backup.
EOF
}

resolve_backup_path() {
    if [ -z "${BACKUP_ARG}" ]; then
        log_error "Usage: ./acm restore [config-file] <backup-file.sql.gz>"
        exit 1
    fi
    BACKUP_FILE="$(cd "$(dirname "${BACKUP_ARG}")" && pwd)/$(basename "${BACKUP_ARG}")"
}

stop_and_remove_database() {
    log_info "Stopping the full stack..."
    container_compose down --remove-orphans 2>/dev/null || true

    if [ -n "$(container_ps_q ac-database)" ]; then
        container_rm ac-database
    fi
}

remove_existing_volume() {
    log_info "Checking for existing database volume..."
    local PROJECT_NAME
    PROJECT_NAME=$(basename "$(pwd)")
    local DOCKER_VOL_DB="${DOCKER_VOL_DB:-${PROJECT_NAME}_ac-database}"

    if container_volume_inspect "${DOCKER_VOL_DB}" >/dev/null 2>&1; then
        log_info "Removing existing volume '${DOCKER_VOL_DB}'..."
        container_volume_rm "${DOCKER_VOL_DB}"
    else
        log_info "No existing volume found, proceeding with fresh volume."
    fi
}

start_database() {
    log_info "Starting database container..."
    container_compose up -d ac-database
}

restore_backup() {
    log_info "Restoring backup from ${BACKUP_FILE}..."

    local TEMP_SQL
    TEMP_SQL=$(mktemp /tmp/restore_XXXXXX.sql)
    trap 'rm -f "${TEMP_SQL}"' EXIT

    zcat "${BACKUP_FILE}" > "${TEMP_SQL}"

    if ! container_compose exec -T ac-database \
        env MYSQL_PWD="${DB_ROOT_PASSWORD}" mysql -u root \
        < "${TEMP_SQL}"; then
        log_error "Database restore failed."
        exit 1
    fi

    trap - EXIT
}

stop_database() {
    log_info "Stopping database container..."
    container_compose down
}

command_restore() {
    parse_command_args show_restore_help "" "$@"
    init_command_environment "${PARSED_CONFIG_FILE}"

    if [ ${#PARSED_POSITIONAL_ARGS[@]} -eq 0 ]; then
        log_error "Usage: ./acm restore [config-file] <backup-file.sql.gz>"
        show_restore_help
        exit 1
    fi

    local BACKUP_ARG="${PARSED_POSITIONAL_ARGS[0]}"
    local BACKUP_FILE
    resolve_backup_path

    if [ ! -f "${BACKUP_FILE}" ]; then
        log_error "Backup file '${BACKUP_FILE}' not found."
        exit 1
    fi

    local DB_ROOT_PASSWORD
    DB_ROOT_PASSWORD="$(get_db_password)"

    stop_and_remove_database
    remove_existing_volume
    start_database
    wait_for_container_database "${DB_ROOT_PASSWORD}"
    restore_backup
    stop_database

    log_info "Restore complete."
    log_info "Start the full stack with: ./acm start"
}
