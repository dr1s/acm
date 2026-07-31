#!/bin/bash
#
# Shared command-line argument helpers.
#

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

# find_config_arg SCRIPT_DIR [args...]
# Echoes the resolved config file path, defaulting to SCRIPT_DIR/conf/wowserver.conf.
find_config_arg() {
    local SCRIPT_DIR="${1}"
    shift
    local CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    local arg
    for arg in "${@}"; do
        case "${arg}" in
            *.conf) CONFIG_FILE="$(resolve_config_path "${arg}" "${SCRIPT_DIR}")" ;;
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
