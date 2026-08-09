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

# parse_command_args tests
dummy_help() { echo "HELP"; }

parse_command_args dummy_help ""
assert_eq "/project/conf/wowserver.conf" "${PARSED_CONFIG_FILE}" "parse_command_args default config"
[ "${#PARSED_POSITIONAL_ARGS[@]}" -eq 0 ] || fail "parse_command_args no positionals by default"
[ "${#PARSED_FLAGS[@]}" -eq 0 ] || fail "parse_command_args no flags by default"

parse_command_args dummy_help "" ./conf/solo.conf
assert_eq "/project/./conf/solo.conf" "${PARSED_CONFIG_FILE}" "parse_command_args relative config"

parse_command_args dummy_help "--skip-game" --skip-game
assert_eq "true" "${PARSED_FLAGS[--skip-game]}" "parse_command_args boolean flag"

parse_command_args dummy_help "--database=" --database mydb
assert_eq "mydb" "${PARSED_FLAGS[--database]}" "parse_command_args value flag"

parse_command_args dummy_help "--skip-git --database=" --skip-git --database mydb ./conf/x.conf
assert_eq "mydb" "${PARSED_FLAGS[--database]}" "parse_command_args mixed flags and config"
assert_eq "true" "${PARSED_FLAGS[--skip-git]}" "parse_command_args mixed boolean flag"
assert_eq "/project/./conf/x.conf" "${PARSED_CONFIG_FILE}" "parse_command_args mixed config"
[ "${#PARSED_POSITIONAL_ARGS[@]}" -eq 0 ] || fail "parse_command_args mixed no positionals"

exit_code=0
(parse_command_args dummy_help "--database=" --database >/dev/null 2>&1) || exit_code=$?
[ "${exit_code}" -eq 1 ] || fail "parse_command_args missing value exits 1"

exit_code=0
(parse_command_args dummy_help "--database=" --database --skip-git >/dev/null 2>&1) || exit_code=$?
[ "${exit_code}" -eq 1 ] || fail "parse_command_args value followed by flag exits 1"

parse_command_args dummy_help "" --unknown
assert_eq "--unknown" "${PARSED_POSITIONAL_ARGS[0]}" "parse_command_args unknown arg becomes positional"

exit_code=0
(reject_positional_args dummy_help >/dev/null 2>&1) || exit_code=$?
[ "${exit_code}" -eq 1 ] || fail "reject_positional_args exits 1 on unknown arg"

if ! (parse_command_args dummy_help "" --help >/dev/null 2>&1); then
    fail "parse_command_args --help should exit 0"
fi

if ! (parse_command_args dummy_help "" -h >/dev/null 2>&1); then
    fail "parse_command_args -h should exit 0"
fi

echo "PASS: args_test"
