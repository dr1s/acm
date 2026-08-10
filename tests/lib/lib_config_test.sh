#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="/project"
export SCRIPT_DIR
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

TMP=$(mktemp)
cat > "${TMP}" <<'EOF'
NAME=playerbots
MAIN_REPO=https://github.com/example/repo.git@main
LAUNCH_GAME=/usr/bin/game
SPACED='value with spaces'
QUOTED='single quoted value'
EMPTY=
#COMMENTED=ignored
TRAILING_SPACES='has trailing spaces   '
EOF
cat >> "${TMP}" <<'EOF'
MULTI=first
MULTI=second
MULTI=third
EOF

assert_eq "playerbots" "$(read_config_value NAME "${TMP}")" "read_config_value NAME"
assert_eq "/usr/bin/game" "$(read_config_value LAUNCH_GAME "${TMP}")" "read_config_value LAUNCH_GAME"
assert_eq "https://github.com/example/repo.git@main" "$(read_config_value MAIN_REPO "${TMP}")" "read_config_value MAIN_REPO"
assert_eq "" "$(read_config_value MISSING "${TMP}")" "read_config_value missing key"
assert_eq "value with spaces" "$(read_config_value SPACED "${TMP}")" "read_config_value value with spaces"
assert_eq "single quoted value" "$(read_config_value QUOTED "${TMP}")" "read_config_value removes single quotes"
assert_eq "" "$(read_config_value EMPTY "${TMP}")" "read_config_value empty value"
assert_eq "" "$(read_config_value COMMENTED "${TMP}")" "read_config_value ignores comments"
assert_eq "has trailing spaces" "$(read_config_value TRAILING_SPACES "${TMP}")" "read_config_value trims trailing spaces"

MULTI_VALUES=$(read_config_values MULTI "${TMP}")
assert_eq "first second third" "$(echo "${MULTI_VALUES}" | tr '\n' ' ' | sed 's/ $//')" "read_config_values returns multiple values"

assert_eq "/project/conf/wowserver.conf" "$(resolve_config_path "conf/wowserver.conf")" "resolve_config_path relative"
assert_eq "/abs/path.conf" "$(resolve_config_path "/abs/path.conf")" "resolve_config_path absolute"

rm -f "${TMP}"
echo "PASS: config_test"
