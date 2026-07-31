#!/bin/bash
#
# Git helpers for repository and module management.
#

# parse_module_repo LINE
# Parses a MODULE_REPO line and sets five global variables:
#   PARSED_REPO_URL    - The git URL (before #, without @branch)
#   PARSED_REPO_NAME   - The repo name from URL (for cache key)
#   PARSED_MODULE_NAME - The directory name for modules/
#   PARSED_SUBFOLDER   - The subfolder path after # (empty if none)
#   PARSED_BRANCH      - The branch name after @ (empty if none)
parse_module_repo() {
    local LINE="${1}"
    local URL_PART="${LINE%%#*}"
    local SUBFOLDER_PART=""
    if [[ "${LINE}" == *"#"* ]]; then
        SUBFOLDER_PART="${LINE#*#}"
    fi

    PARSED_BRANCH=""
    if [[ "${URL_PART}" == *"@"* ]]; then
        local AFTER_PROTOCOL="${URL_PART#*://}"
        if [[ "${AFTER_PROTOCOL}" == *"@"* ]]; then
            PARSED_BRANCH="${AFTER_PROTOCOL##*@}"
            URL_PART="${URL_PART%@${PARSED_BRANCH}}"
        fi
    fi

    PARSED_REPO_URL="${URL_PART}"
    PARSED_REPO_NAME="$(basename "${PARSED_REPO_URL}" .git)"
    PARSED_SUBFOLDER="${SUBFOLDER_PART}"
    if [[ -n "${PARSED_SUBFOLDER}" ]]; then
        PARSED_MODULE_NAME="$(basename "${PARSED_SUBFOLDER}")"
    else
        PARSED_MODULE_NAME="${PARSED_REPO_NAME}"
    fi
}

# handle_pull_output EXIT_CODE OUTPUT [DIR]
handle_pull_output() {
    local EXIT_CODE="${1}"
    local PULL_OUTPUT="${2}"
    local DIR="${3:-.}"

    echo "${PULL_OUTPUT}"
    if [ "${EXIT_CODE}" -ne 0 ]; then
        log_error "Failed to update repository in '${DIR}'."
        exit 1
    fi
    if ! echo "${PULL_OUTPUT}" | grep -q "Already up to date"; then
        echo ""
        git -C "${DIR}" --no-pager log --oneline -5
        echo ""
    fi
}

# git_clone_or_pull URL DIR [BRANCH]
git_clone_or_pull() {
    local URL="${1}"
    local DIR="${2}"
    local BRANCH="${3:-}"

    if [ -d "${DIR}/.git" ]; then
        log_info "Updating $(basename "${DIR}")..."
        local PULL_OUTPUT EXIT_CODE=0
        PULL_OUTPUT="$(git -C "${DIR}" pull 2>&1)" || EXIT_CODE=$?
        handle_pull_output "${EXIT_CODE}" "${PULL_OUTPUT}" "${DIR}"
    else
        log_info "Cloning $(basename "${DIR}")..."
        if [ -n "${BRANCH}" ]; then
            git clone -b "${BRANCH}" "${URL}" "${DIR}"
        else
            git clone "${URL}" "${DIR}"
        fi
    fi

    if [ -n "${BRANCH}" ]; then
        git -C "${DIR}" checkout "${BRANCH}"
    fi
}
