#!/bin/bash
#
# Config file reading and path resolution.
#

read_config_value() {
    local KEY="${1}"
    local FILE="${2}"
    grep "^${KEY}=" "${FILE}" 2>/dev/null | sed "s/^${KEY}=//" | head -1 | sed "s/^'//;s/'$//" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

read_config_values() {
    local KEY="${1}"
    local FILE="${2}"
    grep "^${KEY}=" "${FILE}" 2>/dev/null | sed "s/^${KEY}=//" | sed "s/^'//;s/'$//" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

resolve_config_path() {
    local CONFIG_FILE="${1}"
    local SCRIPT_DIR="${2}"
    case "${CONFIG_FILE}" in
        /*) echo "${CONFIG_FILE}" ;;
        *) echo "${SCRIPT_DIR}/${CONFIG_FILE}" ;;
    esac
}
