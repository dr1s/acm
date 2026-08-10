#!/usr/bin/env bash
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
    parse_command_args show_stop_help "" "$@"
    reject_positional_args show_stop_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    log_info "Stopping compose stack..."
    container_down
    log_info "Compose stack has been stopped."
}
