#!/bin/bash
#
# acm console command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"

show_console_help() {
    cat <<'EOF'
Usage: ./acm console [config-file]

Attach to the running ac-worldserver console.

Press Ctrl+P then Ctrl+Q to detach (do NOT press Ctrl+C).
EOF
}

command_console() {
    local arg
    for arg in "${@}"; do
        case "${arg}" in
            -h|--help) show_console_help; exit 0 ;;
            *.conf) ;;
            *) log_error "Unknown argument: ${arg}"; show_console_help; exit 1 ;;
        esac
    done

    local CONFIG_FILE
    CONFIG_FILE="$(find_config_arg "${@}")"

    init_command_environment "${CONFIG_FILE}"

    if [ -z "$(container_ps_q ac-worldserver)" ]; then
        log_error "ac-worldserver is not running. Start the server first with: ./acm start"
        exit 1
    fi

    echo "Attaching to ac-worldserver console..."
    echo "Press Ctrl+P then Ctrl+Q to detach (do NOT press Ctrl+C)."
    exec ${CONTAINER_CMD} attach --detach-keys="ctrl-p,ctrl-q" ac-worldserver
}
