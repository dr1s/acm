#!/bin/bash
#
# Shared command-line argument helpers.
#

# resolve_config_path is defined in lib/utils/config.sh. Source it only if it
# has not already been loaded (e.g. in tests that set a fake SCRIPT_DIR).
if ! command -v resolve_config_path >/dev/null 2>&1; then
    source "${SCRIPT_DIR}/lib/utils/config.sh"
fi

# has_flag FLAG [args...]
# Returns 0 if FLAG is present in the remaining arguments.
has_flag() {
    local FLAG="${1}"
    shift
    local arg
    for arg in "${@}"; do
        if [ "${arg}" = "${FLAG}" ]; then
            return 0
        fi
    done
    return 1
}

# find_config_arg [args...]
# Echoes the resolved config file path, defaulting to SCRIPT_DIR/conf/wowserver.conf.
find_config_arg() {
    local CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    local arg
    for arg in "${@}"; do
        case "${arg}" in
            *.conf) CONFIG_FILE="$(resolve_config_path "${arg}")" ;;
        esac
    done
    echo "${CONFIG_FILE}"
}

# get_arg_value FLAG [args...]
# Echoes the value that follows FLAG.
# Returns 0 if a value is found, 1 if FLAG is not present,
# and 2 if FLAG is present but not followed by a value.
get_arg_value() {
    local FLAG="${1}"
    shift
    local arg
    local prev_arg=""
    for arg in "${@}"; do
        if [ "${prev_arg}" = "${FLAG}" ]; then
            case "${arg}" in
                -*) return 2 ;;
                *) echo "${arg}"; return 0 ;;
            esac
        fi
        prev_arg="${arg}"
    done
    if [ "${prev_arg}" = "${FLAG}" ]; then
        return 2
    fi
    return 1
}

# Global state populated by parse_command_args.
declare -A PARSED_FLAGS
declare -a PARSED_POSITIONAL_ARGS
PARSED_CONFIG_FILE=""

# parse_command_args HELP_FUNC SPEC [args...]
# Parses command-line arguments into shared global structures.
#
# HELP_FUNC: name of a function to call when -h/--help is encountered
# SPEC:      space-separated list of allowed flags. A trailing '=' means the
#            flag takes a value (e.g., "--database=").
#
# After calling:
#   - PARSED_FLAGS[--flag]="true" for boolean flags
#   - PARSED_FLAGS[--flag]="value" for value flags
#   - PARSED_CONFIG_FILE is the resolved config file path
#   - PARSED_POSITIONAL_ARGS contains remaining positional arguments
parse_command_args() {
    local HELP_FUNC="${1}"
    local SPEC="${2}"
    shift 2

    PARSED_FLAGS=()
    PARSED_POSITIONAL_ARGS=()
    PARSED_CONFIG_FILE=""

    local -A BOOL_FLAGS
    local -A VALUE_FLAGS
    local token
    for token in ${SPEC}; do
        case "${token}" in
            *=) VALUE_FLAGS["${token%=}"]=1 ;;
            *) BOOL_FLAGS["${token}"]=1 ;;
        esac
    done

    local i arg
    for ((i=1; i<=$#; i++)); do
        arg="${!i}"
        case "${arg}" in
            -h|--help)
                "${HELP_FUNC}"
                exit 0
                ;;
            *.conf)
                PARSED_CONFIG_FILE="${arg}"
                ;;
            *)
                if [ -n "${BOOL_FLAGS[${arg}]+x}" ]; then
                    PARSED_FLAGS["${arg}"]="true"
                elif [ -n "${VALUE_FLAGS[${arg}]+x}" ]; then
                    local next_idx=$((i + 1))
                    if [ "${next_idx}" -gt "$#" ]; then
                        log_error "${arg} requires a value"
                        "${HELP_FUNC}"
                        exit 1
                    fi
                    local next_arg="${!next_idx}"
                    case "${next_arg}" in
                        -*)
                            log_error "${arg} requires a value"
                            "${HELP_FUNC}"
                            exit 1
                            ;;
                    esac
                    # shellcheck disable=SC2034
                    PARSED_FLAGS["${arg}"]="${next_arg}"
                    i="${next_idx}"
                else
                    PARSED_POSITIONAL_ARGS+=("${arg}")
                fi
                ;;
        esac
    done

    if [ -z "${PARSED_CONFIG_FILE}" ]; then
        PARSED_CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    else
        PARSED_CONFIG_FILE="$(resolve_config_path "${PARSED_CONFIG_FILE}")"
    fi
}

# reject_positional_args HELP_FUNC
# Exits with an error if PARSED_POSITIONAL_ARGS is non-empty.
# Commands that do not accept positional arguments should call this after
# parse_command_args.
reject_positional_args() {
    local HELP_FUNC="${1}"
    if [ ${#PARSED_POSITIONAL_ARGS[@]} -gt 0 ]; then
        log_error "Unknown argument: ${PARSED_POSITIONAL_ARGS[0]}"
        "${HELP_FUNC}"
        exit 1
    fi
}
