#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${SCRIPT_DIR}"

FAILED=0
while IFS= read -r -d '' file; do
    echo "Checking ${file}..."
    if ! bash -n "${file}"; then
        echo "  SYNTAX ERROR"
        FAILED=1
    fi
done < <(find . -type f \( -name '*.sh' -o -name 'acm' \) -print0)

if [ "${FAILED}" -ne 0 ]; then
    exit 1
fi

echo "All shell files pass syntax check."
