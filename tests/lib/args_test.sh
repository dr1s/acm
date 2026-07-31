#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/args.sh"

fail() { echo "FAIL: ${1}"; exit 1; }

has_flag --clean --clean --skip-build || fail "has_flag finds first flag"
has_flag --clean --skip-build --clean || fail "has_flag finds later flag"
! has_flag --clean --skip-build || fail "has_flag absent"
! has_flag --clean || fail "has_flag empty args"

[ "$(find_config_arg /project)" = "/project/conf/wowserver.conf" ] || fail "default config path"
[ "$(find_config_arg /project --clean ./conf/solo.conf)" = "/project/./conf/solo.conf" ] || fail "relative config"
[ "$(find_config_arg /project /etc/wow.conf)" = "/etc/wow.conf" ] || fail "absolute config"

[ "$(get_arg_value --database --database mydb --skip-git)" = "mydb" ] || fail "get_arg_value finds first value"
[ "$(get_arg_value --database --skip-git --database mydb)" = "mydb" ] || fail "get_arg_value finds later value"
! get_arg_value --database --skip-git 2>/dev/null || fail "get_arg_value absent"
get_arg_value --database --database --skip-git 2>/dev/null
[ $? -eq 2 ] || fail "get_arg_value missing value is flag"
get_arg_value --database --skip-git --database 2>/dev/null
[ $? -eq 2 ] || fail "get_arg_value trailing flag missing value"

echo "PASS: args_test"
