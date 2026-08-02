#!/bin/bash
#
# acm stop command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"

show_stop_help() {
    cat <<'EOF'
Usage: ./acm stop [config-file]

Stop the running compose stack.
EOF
}

command_stop() {
    local arg
    for arg in "${@}"; do
        case "${arg}" in
            -h|--help) show_stop_help; exit 0 ;;
            *.conf) ;;
            *) log_error "Unknown argument: ${arg}"; show_stop_help; exit 1 ;;
        esac
    done

    local CONFIG_FILE
    CONFIG_FILE="$(find_config_arg "${SCRIPT_DIR}" "${@}")"

    init_command_environment "${CONFIG_FILE}"

    log_info "Stopping compose stack..."
    container_down
    log_info "Compose stack has been stopped."
}
