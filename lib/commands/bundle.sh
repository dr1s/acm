#!/bin/bash
#
# acm bundle command.
#

source "${SCRIPT_DIR}/lib/bundles/paragon.sh"

show_bundle_help() {
    cat <<'EOF'
Usage: ./acm bundle <bundle-name> <subcommand> [options]

Bundles:
  paragon         Paragon Anniversary install/uninstall

Run './acm bundle <bundle-name> --help' for bundle-specific options.
EOF
}

command_bundle() {
    if [ $# -eq 0 ]; then
        show_bundle_help
        exit 1
    fi

    local BUNDLE="${1}"
    shift

    case "${BUNDLE}" in
        paragon) bundle_paragon "$@" ;;
        help|-h|--help) show_bundle_help; exit 0 ;;
        *) log_error "Unknown bundle: ${BUNDLE}"; show_bundle_help; exit 1 ;;
    esac
}
