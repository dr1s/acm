#!/bin/bash
#
# acm create-account command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"

show_create_account_help() {
    cat <<'EOF'
Usage: ./acm create-account <username> <password> [config-file]

Create a new WoW account with GM level 3 on the running ac-worldserver.
EOF
}

check_expect_installed() {
    if ! command -v expect >/dev/null 2>&1; then
        log_error "This command requires 'expect' but it is not installed."
        log_error "Install it with your package manager, e.g.:"
        log_error "  sudo pacman -S expect        # Arch"
        log_error "  sudo apt install expect        # Debian / Ubuntu"
        log_error "  sudo dnf install expect        # Fedora"
        return 1
    fi
}

run_expect_create_account() {
    local USERNAME="${1}"
    local PASSWORD="${2}"

    expect <<EOF
set timeout 30
spawn ${CONTAINER_CMD} attach --detach-keys="ctrl-p,ctrl-q" ac-worldserver
expect "AC>"
send "account create ${USERNAME} ${PASSWORD}\r"
expect "AC>"
send "account set gmlevel ${USERNAME} 3 -1\r"
expect "AC>"
sleep 1
send "\x10\x11"
expect eof
EOF
}

command_create_account() {
    local USERNAME=""
    local PASSWORD=""

    local arg
    for arg in "${@}"; do
        case "${arg}" in
            -h|--help) show_create_account_help; exit 0 ;;
            *.conf) ;;
            *)
                if [ -z "${USERNAME}" ]; then
                    USERNAME="${arg}"
                elif [ -z "${PASSWORD}" ]; then
                    PASSWORD="${arg}"
                else
                    log_error "Unknown argument: ${arg}"
                    show_create_account_help
                    exit 1
                fi
                ;;
        esac
    done

    if [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]; then
        log_error "Username and password are required."
        show_create_account_help
        exit 1
    fi

    local CONFIG_FILE
    CONFIG_FILE="$(find_config_arg "${SCRIPT_DIR}" "${@}")"

    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Config file '${CONFIG_FILE}' not found."
        exit 1
    fi

    init_environment "${CONFIG_FILE}"

    if [ -z "$(container_ps_q ac-worldserver)" ]; then
        log_error "ac-worldserver is not running. Start the server first with: ./acm start"
        exit 1
    fi

    if ! check_expect_installed; then
        exit 1
    fi

    log_info "Creating account '${USERNAME}' with GM level 3..."
    if run_expect_create_account "${USERNAME}" "${PASSWORD}"; then
        log_info "Account '${USERNAME}' created successfully."
    else
        log_error "Failed to create account '${USERNAME}'."
        exit 1
    fi
}
