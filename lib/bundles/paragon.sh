#!/usr/bin/env bash
#
# Paragon bundle command implementation.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"
source "${SCRIPT_DIR}/lib/utils/database.sh"
source "${SCRIPT_DIR}/lib/utils/dependencies.sh"

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
    local LUA_SCRIPTS_DIR="${SERVER_DIR}/lua_scripts"
    local TARGET="${LUA_SCRIPTS_DIR}/paragon"

    if [ -d "${TARGET}" ]; then
        log_info "Removing ${TARGET}..."
        rm -rf "${TARGET}"
    else
        log_info "No synced Lua scripts found at ${TARGET}."
    fi
}


show_paragon_help() {
    cat <<'EOF'
Usage: ./acm bundle paragon <subcommand> [options]

Subcommands:
  install       Install Paragon Anniversary SQL schema and sync Lua scripts
  uninstall     Drop Paragon databases and remove synced Lua scripts

Run './acm bundle paragon <subcommand> --help' for subcommand-specific options.
EOF
}

show_paragon_install_help() {
    cat <<'EOF'
Usage: ./acm bundle paragon install [OPTIONS] [config-file]

Install Paragon Anniversary SQL schema and sync Lua scripts.

Options:
  --skip-git      Skip cloning/updating the paragon repository
  --database      Use a custom database name (default: acore_ale)
  -h, --help      Show this help message
EOF
}

show_paragon_uninstall_help() {
    cat <<'EOF'
Usage: ./acm bundle paragon uninstall [OPTIONS] [config-file]

Drop Paragon databases and remove synced Lua scripts.

Options:
  --database      Use a custom database name (default: acore_ale)
  -h, --help      Show this help message
EOF
}

clone_paragon_repo() {
    mkdir -p "${SCRIPT_DIR}/setup-cache"

    if [ -d "${PARAGON_DIR}/.git" ]; then
        log_info "Updating existing paragon repository..."
        git -C "${PARAGON_DIR}" pull
    else
        log_info "Cloning paragon repository to ${PARAGON_DIR}..."
        git clone --depth 1 "${PARAGON_REPO}" "${PARAGON_DIR}"
    fi
}

apply_sql_files() {
    local REPO_DIR="${1}"
    local DB_NAME="${2}"
    local REWRITE="${3}"
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d /tmp/paragon_sql_XXXXXX)
    trap 'rm -rf "${TEMP_DIR}"' EXIT

    log_info "Preparing SQL files..."
    if [ "${REWRITE}" = true ]; then
        log_info "Rewriting acore_ale -> ${DB_NAME}..."
    fi

    local SQL_FILES=(
        "sql/01_create_database.sql"
        "sql/02_create_config_tables.sql"
        "sql/03_create_experience_tables.sql"
        "sql/04_create_paragon_tables.sql"
        "sql/05_create_triggers.sql"
        "sql/06_insert_default_config.sql"
        "sql/11-13-2026_Example_Data.sql"
    )

    local sql_file
    for sql_file in "${SQL_FILES[@]}"; do
        if [ ! -f "${REPO_DIR}/${sql_file}" ]; then
            log_error "SQL file '${sql_file}' not found in repository."
            return 1
        fi

        if [ "${REWRITE}" = true ]; then
            # shellcheck disable=SC2016
            sed 's/`acore_ale`/`'"${DB_NAME}"'`/g' "${REPO_DIR}/${sql_file}" > "${TEMP_DIR}/$(basename "${sql_file}")"
        else
            cp "${REPO_DIR}/${sql_file}" "${TEMP_DIR}/$(basename "${sql_file}")"
        fi
    done

    log_info "Applying SQL files in order..."

    for sql_file in "${SQL_FILES[@]}"; do
        local BASENAME
        BASENAME=$(basename "${sql_file}")

        log_info "Applying ${sql_file}..."
        if ! container_exec_database_mysql "${DB_ROOT_PASSWORD}" < "${TEMP_DIR}/${BASENAME}"; then
            log_error "Failed to apply ${sql_file}."
            return 1
        fi
    done

    trap - EXIT
}

sync_lua_scripts() {
    local LUA_SCRIPTS_DIR="${SERVER_DIR}/lua_scripts"
    local SRC_DIR="${PARAGON_DIR}/serverside/paragon"

    if [ ! -d "${SRC_DIR}" ]; then
        log_error "Source directory '${SRC_DIR}' not found in repository."
        return 1
    fi

    mkdir -p "${LUA_SCRIPTS_DIR}"

    log_info "Syncing serverside/paragon to ${LUA_SCRIPTS_DIR}/paragon..."
    rsync -av --delete "${SRC_DIR}/" "${LUA_SCRIPTS_DIR}/paragon/"
}

update_lua_config() {
    local DB_NAME="${1}"
    local LUA_SCRIPTS_DIR="${SERVER_DIR}/lua_scripts"
    local CONSTANT_FILE="${LUA_SCRIPTS_DIR}/paragon/paragon_constant.lua"

    if [ ! -f "${CONSTANT_FILE}" ]; then
        log_warn "No paragon_constant.lua found at '${CONSTANT_FILE}'. Skipping DB_NAME update."
        return 0
    fi

    log_info "Updating DB_NAME in '${CONSTANT_FILE}'..."

    if grep -q "DB_NAME" "${CONSTANT_FILE}"; then
        sed -i "s/DB_NAME.*=.*/DB_NAME = \"${DB_NAME}\";/" "${CONSTANT_FILE}"
    else
        echo "DB_NAME = \"${DB_NAME}\"" >> "${CONSTANT_FILE}"
    fi
}

verify_installation() {
    local DB_NAME="${1}"

    log_info "Verifying installation..."

    local TABLE_COUNT
    TABLE_COUNT=$(container_exec_database_mysql "${DB_ROOT_PASSWORD}" -N \
        -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${DB_NAME}';" 2>/dev/null || echo "0")

    if [ "${TABLE_COUNT}" -ge 10 ] 2>/dev/null; then
        log_info "Found ${TABLE_COUNT} tables in '${DB_NAME}'."
    else
        log_warn "Expected at least 10 tables, found ${TABLE_COUNT}."
    fi

    local CONFIG_COUNT
    CONFIG_COUNT=$(container_exec_database_mysql "${DB_ROOT_PASSWORD}" -N \
        -e "SELECT COUNT(*) FROM \`${DB_NAME}\`.paragon_config;" 2>/dev/null || echo "0")

    if [ "${CONFIG_COUNT}" -ge 17 ] 2>/dev/null; then
        log_info "Found ${CONFIG_COUNT} rows in paragon_config."
    else
        log_warn "Expected at least 17 rows in paragon_config, found ${CONFIG_COUNT}."
    fi
}

bundle_paragon_install() {
    parse_command_args show_paragon_install_help "--skip-git --database=" "$@"
    reject_positional_args show_paragon_install_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    local SKIP_GIT="${PARSED_FLAGS[--skip-git]:-false}"
    local DATABASE_NAME="${PARSED_FLAGS[--database]:-acore_ale}"
    local DATABASE_NAME_PROVIDED=false
    if [ -n "${PARSED_FLAGS[--database]+x}" ]; then
        DATABASE_NAME_PROVIDED=true
    fi

    check_container_runtime
    if [ "${SKIP_GIT}" = false ]; then
        check_host_commands git || exit 1
    fi
    check_host_commands rsync sed mktemp || exit 1

    local DB_ROOT_PASSWORD
    DB_ROOT_PASSWORD="$(get_db_password)"

    if [ "${SKIP_GIT}" = false ]; then
        clone_paragon_repo
    fi

    ensure_database_running
    wait_for_container_database "${DB_ROOT_PASSWORD}"
    paragon_drop_existing_databases "${DB_ROOT_PASSWORD}" "${DATABASE_NAME}"

    local REWRITE=false
    if [ "${DATABASE_NAME_PROVIDED}" = true ]; then
        REWRITE=true
    fi

    if apply_sql_files "${PARAGON_DIR}" "${DATABASE_NAME}" "${REWRITE}"; then
        sync_lua_scripts
        if [ "${DATABASE_NAME_PROVIDED}" = true ]; then
            update_lua_config "${DATABASE_NAME}"
        fi
        verify_installation "${DATABASE_NAME}"
        log_info "Paragon database installation complete."
        log_info "Database name: ${DATABASE_NAME}"
        log_info "Start/restart worldserver and run '.reload eluna' to activate."
    else
        log_error "Paragon database installation failed."
        exit 1
    fi

    log_info "Repository available at: ${PARAGON_DIR}"
}

bundle_paragon_uninstall() {
    parse_command_args show_paragon_uninstall_help "--database=" "$@"
    reject_positional_args show_paragon_uninstall_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    local DATABASE_NAME="${PARSED_FLAGS[--database]:-acore_ale}"

    check_container_runtime

    local DB_ROOT_PASSWORD
    DB_ROOT_PASSWORD="$(get_db_password)"

    ensure_database_running
    wait_for_container_database "${DB_ROOT_PASSWORD}"
    paragon_drop_existing_databases "${DB_ROOT_PASSWORD}" "${DATABASE_NAME}"
    paragon_remove_lua_scripts

    log_info "Paragon uninstalled."
}

bundle_paragon() {
    if [ $# -eq 0 ]; then
        show_paragon_help
        exit 1
    fi

    local SUBCOMMAND="${1}"
    shift

    case "${SUBCOMMAND}" in
        install) bundle_paragon_install "$@" ;;
        uninstall) bundle_paragon_uninstall "$@" ;;
        help|-h|--help) show_paragon_help; exit 0 ;;
        *) log_error "Unknown paragon subcommand: ${SUBCOMMAND}"; show_paragon_help; exit 1 ;;
    esac
}
