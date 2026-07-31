#!/bin/bash
#
# acm start command.
#

source "${SCRIPT_DIR}/lib/args.sh"
source "${SCRIPT_DIR}/lib/run.sh"

show_start_help() {
    cat <<'EOF'
Usage: ./acm start [OPTIONS] [config-file] [up-args...]

Start the compose stack and wait for the authserver to be ready.

Options:
  -h, --help      Show this help message
EOF
}

command_start() {
    local UP_ARGS=()

    local arg
    for arg in "${@}"; do
        case "${arg}" in
            -h|--help) show_start_help; exit 0 ;;
            *.conf) ;;
            *) UP_ARGS+=("${arg}") ;;
        esac
    done

    local CONFIG_FILE
    CONFIG_FILE="$(find_config_arg "${SCRIPT_DIR}" "${@}")"

    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Config file '${CONFIG_FILE}' not found."
        exit 1
    fi

    init_environment "${CONFIG_FILE}"

    START_TIME=$(date +%s)
    ensure_compose_containers_stopped
    start_stack "${UP_ARGS[@]}"
    wait_for_authserver
    log_info "Compose stack is running."
}
