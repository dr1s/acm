#!/bin/bash
set -euo pipefail
SCRIPT_DIR="/project"
export SCRIPT_DIR
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/args.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

has_flag --clean --clean --skip-build || fail "has_flag finds first flag"
has_flag --clean --skip-build --clean || fail "has_flag finds later flag"
! has_flag --clean --skip-build || fail "has_flag absent"
! has_flag --clean || fail "has_flag empty args"

assert_eq "/project/conf/wowserver.conf" "$(find_config_arg)" "default config path"
assert_eq "/project/./conf/solo.conf" "$(find_config_arg --clean ./conf/solo.conf)" "relative config"
assert_eq "/etc/wow.conf" "$(find_config_arg /etc/wow.conf)" "absolute config"
assert_eq "/project/./conf/last.conf" "$(find_config_arg ./conf/first.conf --clean ./conf/last.conf)" "last config wins"
assert_eq "/project/./conf/second.conf" "$(find_config_arg ./conf/first.conf ./conf/second.conf --skip-build)" "last config wins with multiple"
assert_eq "/project/./conf/middle.conf" "$(find_config_arg --clean ./conf/middle.conf --skip-build)" "config in middle"

assert_eq "mydb" "$(get_arg_value --database --database mydb --skip-git)" "get_arg_value finds first value"
assert_eq "mydb" "$(get_arg_value --database --skip-git --database mydb)" "get_arg_value finds later value"
! get_arg_value --database --skip-git 2>/dev/null || fail "get_arg_value absent"

exit_code=0
get_arg_value --database --database --skip-git 2>/dev/null || exit_code=$?
[ "${exit_code}" -eq 2 ] || fail "get_arg_value missing value is flag"

exit_code=0
get_arg_value --database --skip-git --database 2>/dev/null || exit_code=$?
[ "${exit_code}" -eq 2 ] || fail "get_arg_value trailing flag missing value"

assert_eq "value" "$(get_arg_value --flag --flag value)" "get_arg_value simple flag value"
! get_arg_value --flag --flag -value 2>/dev/null || fail "get_arg_value treats dash-prefixed as missing"

echo "PASS: args_test"
