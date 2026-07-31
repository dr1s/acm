#!/bin/bash
#
# Shared helpers for Paragon Anniversary installation/uninstallation.
#

source "${SCRIPT_DIR}/lib/container.sh"
source "${SCRIPT_DIR}/lib/database.sh"

PARAGON_REPO="https://github.com/dr1s/lua-paragon-anniversary.git"
PARAGON_DIR="${SCRIPT_DIR}/setup-cache/lua-paragon-anniversary"

paragon_drop_existing_databases() {
    local DB_ROOT_PASSWORD="${1}"
    local DB_NAME="${2}"
    log_info "Dropping existing paragon databases..."
    container_exec_database_mysql "${DB_ROOT_PASSWORD}" \
        -e "SET FOREIGN_KEY_CHECKS=0; DROP DATABASE IF EXISTS \`${DB_NAME}\`; DROP DATABASE IF EXISTS \`acore_ale\`; SET FOREIGN_KEY_CHECKS=1;"
}

paragon_remove_lua_scripts() {
    local SERVER_DIR="${SCRIPT_DIR}/${WORK_DIR}"
    local LUA_SCRIPTS_DIR="${SERVER_DIR}/lua_scripts"
    local TARGET="${LUA_SCRIPTS_DIR}/paragon"

    if [ -d "${TARGET}" ]; then
        log_info "Removing ${TARGET}..."
        rm -rf "${TARGET}"
    else
        log_info "No synced Lua scripts found at ${TARGET}."
    fi
}
