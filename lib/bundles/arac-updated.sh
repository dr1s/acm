#!/usr/bin/env bash
#
# All races all classes updated bundle implementation
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/logging.sh"
source "${SCRIPT_DIR}/lib/utils/git.sh"
source "${SCRIPT_DIR}/lib/utils/init.sh"
source "${SCRIPT_DIR}/lib/utils/dependencies.sh"


show_arac_updated_help() {
    cat <<'EOF'
Usage: ./acm bundle arac-updated [COMMAND]

Commands:
    install    Install the arac-updated bundle
    uninstall  Uninstall the arac-updated bundle
    help       Show this help message
EOF
}

bundle_arac_updated_install() {
    parse_command_args show_arac_updated_help "" "$@"
    reject_positional_args show_arac_updated_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    check_host_commands git || exit 1

    log_info "Installing arac-updated bundle..."
    if [ ! -d "${SCRIPT_DIR}/setup-cache/mod-arac-updated" ]; then
        log_info "Cloning arac-updated repository..."
        git_clone_or_pull "https://github.com/ChromWolf/mod-arac-updated.git" "${SCRIPT_DIR}/setup-cache/mod-arac-updated"
    fi

    if [ ! -d "${SERVER_DIR}/data/dbc" ]; then
        log_info "Creating dbc directory..."
        mkdir -p "${SERVER_DIR}/data/dbc"
    fi

    log_info "Installing arac-updated dbc files"
    if ! cp -v "${SCRIPT_DIR}/setup-cache/mod-arac-updated/patch-contents/DBFilesContent/"*.dbc "${SERVER_DIR}/data/dbc"; then
        log_error "Failed to install arac-updated dbc files"
        exit 1
    fi

    log_info "arac-updated bundle installed"
    log_info "Ensure the client patch is installed on your client and the module is enabled"
    log_info "Patch: https://github.com/ChromWolf/mod-arac-updated/raw/refs/heads/master/Patch-A.MPQ"
}

bundle_arac_updated_uninstall() {
    parse_command_args show_arac_updated_help "" "$@"
    reject_positional_args show_arac_updated_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    log_info "Uninstalling arac-updated bundle..."
    log_info "Removing arac-updated dbc files"
    rm -f -v \
        "${SERVER_DIR}/data/dbc/CharBaseInfo.dbc" \
        "${SERVER_DIR}/data/dbc/CharStartOutfit.dbc" \
        "${SERVER_DIR}/data/dbc/SkillLineAbility.dbc" \
        "${SERVER_DIR}/data/dbc/SkillRaceClassInfo.dbc" \
        "${SERVER_DIR}/data/dbc/Spell.dbc" \
        "${SERVER_DIR}/data/dbc/SpellCategory.dbc"

    log_info "arac-updated bundle uninstalled"
}

bundle_arac_updated() {
    if [ $# -eq 0 ]; then
        show_arac_updated_help
        exit 1
    fi

    local SUBCOMMAND="${1}"
    shift

    case "${SUBCOMMAND}" in
        install) bundle_arac_updated_install "$@" ;;
        uninstall) bundle_arac_updated_uninstall "$@" ;;
        help|-h|--help) show_arac_updated_help; exit 0 ;;
        *) log_error "Unknown arac-updated subcommand: ${SUBCOMMAND}"; show_arac_updated_help; exit 1 ;;
    esac
}
