#!/bin/bash
#
# acm bundle command.
#

show_bundle_help() {
    cat <<'EOF'
Usage: ./acm bundle <bundle-name> <subcommand> [options]

Bundles:
  arac-updated    All races all classes (updated) install/uninstall
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
        help|-h|--help) show_bundle_help; exit 0 ;;
        *)
            local BUNDLE_FILE="${SCRIPT_DIR}/lib/bundles/${BUNDLE}.sh"
            if [ ! -f "${BUNDLE_FILE}" ]; then
                log_error "Bundle implementation not found: ${BUNDLE_FILE}"
                show_bundle_help
                exit 1
            fi
            # shellcheck disable=SC1090
            source "${BUNDLE_FILE}"
            local BUNDLE_FUNCTION="bundle_${BUNDLE}"
            "${BUNDLE_FUNCTION}" "$@"
            ;;
    esac
}
