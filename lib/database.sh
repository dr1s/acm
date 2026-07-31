#!/bin/bash
#
# MySQL helpers for the ac-database container.
#

source "${SCRIPT_DIR}/lib/container.sh"

get_db_password() {
    echo "${DOCKER_DB_ROOT_PASSWORD:-password}"
}

container_exec_database_mysql() {
    local DB_ROOT_PASSWORD="${1}"
    shift
    container_compose exec -T ac-database \
        env MYSQL_PWD="${DB_ROOT_PASSWORD}" mysql -u root "$@"
}

ensure_database_running() {
    log_info "Ensuring database container is running..."
    container_compose up -d ac-database 2>/dev/null || true
}

wait_for_container_database() {
    local DB_ROOT_PASSWORD="${1}"
    log_info "Waiting for database to be healthy..."
    local MAX_RETRIES=60
    local RETRY_COUNT=0

    while ! container_compose exec -T ac-database \
        mysqladmin ping -u root -p"${DB_ROOT_PASSWORD}" --silent 2>/dev/null; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ "${RETRY_COUNT}" -ge "${MAX_RETRIES}" ]; then
            log_error "Database failed to become healthy after $((MAX_RETRIES * 2)) seconds."
            container_compose logs ac-database
            exit 1
        fi
        sleep 2
    done

    log_info "Waiting for MySQL socket..."
    while ! container_compose exec -T ac-database \
        test -S /var/run/mysqld/mysqld.sock 2>/dev/null; do
        sleep 1
    done

    sleep 2
}
