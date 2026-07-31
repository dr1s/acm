#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/config.sh"

TMP=$(mktemp)
cat > "${TMP}" <<'EOF'
NAME=playerbots
MAIN_REPO=https://github.com/example/repo.git@main
LAUNCH_GAME=/usr/bin/game
EOF

assert_eq() {
    local expected="${1}"
    local actual="${2}"
    local label="${3}"
    if [ "${actual}" != "${expected}" ]; then
        echo "FAIL: ${label}: expected '${expected}', got '${actual}'"
        exit 1
    fi
}

assert_eq "playerbots" "$(read_config_value NAME "${TMP}")" "read_config_value NAME"
assert_eq "/usr/bin/game" "$(read_config_value LAUNCH_GAME "${TMP}")" "read_config_value LAUNCH_GAME"
assert_eq "https://github.com/example/repo.git@main" "$(read_config_value MAIN_REPO "${TMP}")" "read_config_value MAIN_REPO"
assert_eq "" "$(read_config_value MISSING "${TMP}")" "read_config_value missing key"
assert_eq "/project/conf/wowserver.conf" "$(resolve_config_path "conf/wowserver.conf" "/project")" "resolve_config_path relative"
assert_eq "/abs/path.conf" "$(resolve_config_path "/abs/path.conf" "/project")" "resolve_config_path absolute"

rm -f "${TMP}"
echo "PASS: config_test"
