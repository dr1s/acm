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

Backup retention can be configured in the config file. See README.md for details.
EOF
}

command_run() {
    parse_command_args show_run_help "--skip-game" "$@"
    init_command_environment "${PARSED_CONFIG_FILE}"

    local BACKUP_DIR
    BACKUP_DIR="$(resolve_backup_dir)"

    local DB_ROOT_PASSWORD
    DB_ROOT_PASSWORD="$(get_db_password)"

    local SKIP_GAME="${PARSED_FLAGS[--skip-game]:-false}"
    local UP_ARGS=("${PARSED_POSITIONAL_ARGS[@]}")

    run_full_session "${BACKUP_DIR}" "${DB_ROOT_PASSWORD}" "${CONFIG_NAME}" "${SKIP_GAME}" "${UP_ARGS[@]}"
}
