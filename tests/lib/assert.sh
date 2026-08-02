#!/bin/bash
#
# Shared assertion helpers for unit tests.
#

# fail LABEL
# Prints a failure message and exits with status 1.
fail() {
    echo "FAIL: ${1}"
    exit 1
}

# assert_eq EXPECTED ACTUAL LABEL
# Exits with status 1 if ACTUAL does not equal EXPECTED.
assert_eq() {
    local expected="${1}"
    local actual="${2}"
    local label="${3}"
    if [ "${actual}" != "${expected}" ]; then
        echo "FAIL: ${label}: expected '${expected}', got '${actual}'"
        exit 1
    fi
}

# assert_ne UNEXPECTED ACTUAL LABEL
# Exits with status 1 if ACTUAL equals UNEXPECTED.
assert_ne() {
    local unexpected="${1}"
    local actual="${2}"
    local label="${3}"
    if [ "${actual}" = "${unexpected}" ]; then
        echo "FAIL: ${label}: expected not '${unexpected}', got '${actual}'"
        exit 1
    fi
}

# assert_empty VALUE LABEL
# Exits with status 1 if VALUE is not empty.
assert_empty() {
    local value="${1}"
    local label="${2}"
    if [ -n "${value}" ]; then
        echo "FAIL: ${label}: expected empty, got '${value}'"
        exit 1
    fi
}

# assert_not_empty VALUE LABEL
# Exits with status 1 if VALUE is empty.
assert_not_empty() {
    local value="${1}"
    local label="${2}"
    if [ -z "${value}" ]; then
        echo "FAIL: ${label}: expected non-empty value"
        exit 1
    fi
}
