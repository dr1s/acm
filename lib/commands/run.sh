#!/bin/bash
#
# acm run command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/run.sh"

show_run_help() {
    cat <<'EOF'
Usage: ./acm run [OPTIONS] [config-file] [up-args...]

Start the server, wait for authserver, optionally launch the game, wait for
keypress, backup databases/configs, and shut down.

Options:
  --skip-game     Skip launching the game
  -h, --help      Show this help message
EOF
}

command_run() {
    SKIP_GAME=false
    local UP_ARGS=()

    local arg
    for arg in "${@}"; do
        case "${arg}" in
            --skip-game) SKIP_GAME=true ;;
            -h|--help) show_run_help; exit 0 ;;
            *.conf) ;;
            *) UP_ARGS+=("${arg}") ;;
        esac
    done

    local CONFIG_FILE
    CONFIG_FILE="$(find_config_arg "${SCRIPT_DIR}" "${@}")"

    init_command_environment "${CONFIG_FILE}"

    local BACKUP_DIR
    BACKUP_DIR="$(resolve_backup_dir)"

    local DB_ROOT_PASSWORD
    DB_ROOT_PASSWORD="$(get_db_password)"

    run_full_session "${CONFIG_FILE}" "${BACKUP_DIR}" "${DB_ROOT_PASSWORD}" "${CONFIG_NAME}" "${SKIP_GAME}" "${UP_ARGS[@]}"
}
