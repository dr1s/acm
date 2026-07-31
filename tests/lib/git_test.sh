#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/git.sh"

fail() { echo "FAIL: ${1}"; exit 1; }

parse_module_repo "https://github.com/user/mod-playerbots.git"
[ "${PARSED_REPO_URL}" = "https://github.com/user/mod-playerbots.git" ] || fail "simple url"
[ "${PARSED_REPO_NAME}" = "mod-playerbots" ] || fail "simple repo name"
[ "${PARSED_MODULE_NAME}" = "mod-playerbots" ] || fail "simple module name"
[ "${PARSED_SUBFOLDER}" = "" ] || fail "simple subfolder"
[ "${PARSED_BRANCH}" = "" ] || fail "simple branch"

parse_module_repo "https://github.com/user/repo.git@main#modules/foo"
[ "${PARSED_REPO_URL}" = "https://github.com/user/repo.git" ] || fail "complex url"
[ "${PARSED_REPO_NAME}" = "repo" ] || fail "complex repo name"
[ "${PARSED_MODULE_NAME}" = "foo" ] || fail "complex module name"
[ "${PARSED_SUBFOLDER}" = "modules/foo" ] || fail "complex subfolder"
[ "${PARSED_BRANCH}" = "main" ] || fail "complex branch"

echo "PASS: git_test"
