#!/usr/bin/env bash
#
# acm start command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/run.sh"
source "${SCRIPT_DIR}/lib/utils/dependencies.sh"

show_start_help() {
    cat <<'EOF'
Usage: ./acm start [OPTIONS] [config-file] [up-args...]

Start the compose stack and wait for the authserver to be ready.

Options:
  -h, --help      Show this help message
EOF
}

command_start() {
    parse_command_args show_start_help "" "$@"
    init_command_environment "${PARSED_CONFIG_FILE}"

    check_container_runtime

    local UP_ARGS=("${PARSED_POSITIONAL_ARGS[@]}")
    local START_TIME
    START_TIME=$(date +%s)
    # shellcheck disable=SC2119
    ensure_compose_containers_stopped
    start_stack "${UP_ARGS[@]}"
    wait_for_authserver "${START_TIME}"
    log_info "Compose stack is running."
}
