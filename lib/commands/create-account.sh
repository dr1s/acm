#!/usr/bin/env bash
#
# acm create-account command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"
source "${SCRIPT_DIR}/lib/utils/dependencies.sh"

show_create_account_help() {
    cat <<'EOF'
Usage: ./acm create-account <username> <password> [config-file]

Create a new WoW account with GM level 3 on the running ac-worldserver.
EOF
}

check_expect_installed() {
    check_host_commands expect
}

run_expect_create_account() {
    local USERNAME="${1}"
    local PASSWORD="${2}"
    local CONTAINER_ID="${3}"

    expect - -- "${USERNAME}" "${PASSWORD}" "${CONTAINER_ID}" <<'EOF'
set timeout 30
set username [lindex $argv 0]
set password [lindex $argv 1]
set container_id [lindex $argv 2]
spawn $env(CONTAINER_CMD) attach --detach-keys="ctrl-p,ctrl-q" $container_id
expect "AC>"
send "account create $username $password\r"
expect "AC>"
send "account set gmlevel $username 3 -1\r"
expect "AC>"
sleep 1
send "\x10\x11"
expect eof
EOF
}

command_create_account() {
    parse_command_args show_create_account_help "" "$@"
    init_command_environment "${PARSED_CONFIG_FILE}"

    if [ ${#PARSED_POSITIONAL_ARGS[@]} -lt 2 ]; then
        log_error "Username and password are required."
        show_create_account_help
        exit 1
    fi

    if [ ${#PARSED_POSITIONAL_ARGS[@]} -gt 2 ]; then
        log_error "Unknown argument: ${PARSED_POSITIONAL_ARGS[2]}"
        show_create_account_help
        exit 1
    fi

    local USERNAME="${PARSED_POSITIONAL_ARGS[0]}"
    local PASSWORD="${PARSED_POSITIONAL_ARGS[1]}"

    local CONTAINER_ID
    CONTAINER_ID=$(container_ps_q ac-worldserver)
    if [ -z "${CONTAINER_ID}" ]; then
        log_error "ac-worldserver is not running. Start the server first with: ./acm start"
        exit 1
    fi

    if ! check_expect_installed; then
        exit 1
    fi

    log_info "Creating account '${USERNAME}' with GM level 3..."
    if run_expect_create_account "${USERNAME}" "${PASSWORD}" "${CONTAINER_ID}"; then
        log_info "Account '${USERNAME}' created successfully."
    else
        log_error "Failed to create account '${USERNAME}'."
        exit 1
    fi
}
