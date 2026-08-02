#!/bin/bash
#
# acm start command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/run.sh"

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

    init_command_environment "${CONFIG_FILE}"

    START_TIME=$(date +%s)
    # shellcheck disable=SC2119
    ensure_compose_containers_stopped
    start_stack "${UP_ARGS[@]}"
    wait_for_authserver "${START_TIME}"
    log_info "Compose stack is running."
}
