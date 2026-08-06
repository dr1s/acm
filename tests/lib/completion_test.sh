#!/bin/bash
#
# Unit tests for completions/acm helper functions.
#

source "$(dirname "${BASH_SOURCE[0]}")/../../completions/acm"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

commands_sample='Usage: acm <command>

Commands:
  setup              Clone/update repos and rebuild the stack
  start              Start the compose stack
  run                Start stack, launch game, wait, backup, shutdown
  bundle             Install/manage bundles
  create-account     Create a new WoW account
  help               Show this help message

Run "acm <command> --help" for command-specific options.'

commands_out="$(_acm_parse_commands "${commands_sample}")"
assert_eq "setup
start
run
bundle
create-account
help" "${commands_out}" "parse_commands extracts all commands"

options_sample='Usage: acm setup [OPTIONS] [config-file]

Options:
  --clean         Remove old container images before rebuild
  --no-cache      Rebuild images without using build cache
  -h, --help      Show this help message
  --database      Use a custom database name (default: acore_ale)

Other section:'

options_out="$(_acm_parse_options "${options_sample}")"
assert_eq "--clean
--no-cache
-h
--help
--database" "${options_out}" "parse_options extracts short and long flags"

bundles_sample='Usage: acm bundle <bundle-name> <subcommand>

Bundles:
  arac-updated    All races all classes (updated)
  paragon         Paragon Anniversary

Run ...'

bundles_out="$(_acm_parse_bundles "${bundles_sample}")"
assert_eq "arac-updated
paragon" "${bundles_out}" "parse_bundles extracts bundle names"

subcommands_sample='Usage: acm bundle paragon <subcommand>

Subcommands:
  install       Install Paragon Anniversary
  uninstall     Drop Paragon databases

Options:
  --skip-git      Skip cloning
  --database      Use a custom database name'

subcommands_out="$(_acm_parse_subcommands "${subcommands_sample}")"
assert_eq "install
uninstall" "${subcommands_out}" "parse_subcommands extracts subcommands"

# When run from the project root, ./acm should exist.
if [ -x "./acm" ]; then
    discovered="$(_acm_discover_acm)"
    assert_eq "./acm" "${discovered}" "discover_acm finds ./acm in project root"
fi

# _acm_has_config_arg tests
_acm_has_config_arg --clean ./conf/wowserver.conf
[ $? -eq 0 ] || fail "has_config_arg finds config in middle"

! _acm_has_config_arg --clean --skip-build || fail "has_config_arg returns false when no config"

echo "PASS: completion_test"
