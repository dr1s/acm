#!/usr/bin/env bash
#
# Config file reading and path resolution.
#

# _read_config_raw KEY FILE
# Echoes the raw value portion (after KEY=) for every matching, non-comment line.
_read_config_raw() {
    local KEY="${1}"
    local FILE="${2}"
    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
            \#*|"") continue ;;
            "${KEY}"=*) echo "${line#"${KEY}"=}" ;;
        esac
    done < "${FILE}"
}

# _strip_config_value VALUE
# Removes matching outer single or double quotes, then trims surrounding whitespace.
_strip_config_value() {
    local VALUE="${1}"
    # Remove matching outer quotes
    case "${VALUE}" in
        \"*\") VALUE="${VALUE#\"}"; VALUE="${VALUE%\"}" ;;
        \'*\') VALUE="${VALUE#\'}"; VALUE="${VALUE%\'}" ;;
    esac
    # Trim leading whitespace
    VALUE="${VALUE#"${VALUE%%[![:space:]]*}"}"
    # Trim trailing whitespace
    VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"
    echo "${VALUE}"
}

read_config_value() {
    local KEY="${1}"
    local FILE="${2}"
    local RAW
    RAW="$(_read_config_raw "${KEY}" "${FILE}" | head -1)"
    _strip_config_value "${RAW}"
}

read_config_values() {
    local KEY="${1}"
    local FILE="${2}"
    local RAW
    while IFS= read -r RAW || [ -n "${RAW}" ]; do
        [ -z "${RAW}" ] && continue
        _strip_config_value "${RAW}"
    done < <(_read_config_raw "${KEY}" "${FILE}")
}

resolve_config_path() {
    local CONFIG_FILE="${1}"
    case "${CONFIG_FILE}" in
        /*) echo "${CONFIG_FILE}" ;;
        *) echo "${SCRIPT_DIR}/${CONFIG_FILE}" ;;
    esac
}
