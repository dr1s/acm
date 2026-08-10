#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SCRIPT_DIR
cd "${SCRIPT_DIR}"

FAILED=0
for test_file in tests/lib/*_test.sh; do
    [ -e "${test_file}" ] || continue
    echo "Running ${test_file}..."
    if bash "${test_file}"; then
        echo "  OK"
    else
        echo "  FAILED"
        FAILED=1
    fi
done

if [ "${FAILED}" -ne 0 ]; then
    echo "Some tests failed."
    exit 1
fi

echo "All tests passed."
