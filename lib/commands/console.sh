#!/usr/bin/env bash
#
# acm console command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"
source "${SCRIPT_DIR}/lib/utils/dependencies.sh"

show_console_help() {
    cat <<'EOF'
Usage: ./acm console [config-file]

Attach to the running ac-worldserver console.

Press Ctrl+P then Ctrl+Q to detach (do NOT press Ctrl+C).
EOF
}

command_console() {
    parse_command_args show_console_help "" "$@"
    reject_positional_args show_console_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    check_container_runtime

    local CONTAINER_ID
    CONTAINER_ID=$(container_ps_q ac-worldserver)
    if [ -z "${CONTAINER_ID}" ]; then
        log_error "ac-worldserver is not running. Start the server first with: ./acm start"
        exit 1
    fi

    echo "Attaching to ac-worldserver console..."
    echo "Press Ctrl+P then Ctrl+Q to detach (do NOT press Ctrl+C)."
    exec "${CONTAINER_CMD}" attach --detach-keys="ctrl-p,ctrl-q" "${CONTAINER_ID}"
}
