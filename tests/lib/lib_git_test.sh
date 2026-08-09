#!/bin/bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/git.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

parse_module_repo "https://github.com/user/mod-playerbots.git"
assert_eq "https://github.com/user/mod-playerbots.git" "${PARSED_REPO_URL}" "simple url"
assert_eq "mod-playerbots" "${PARSED_REPO_NAME}" "simple repo name"
assert_eq "mod-playerbots" "${PARSED_MODULE_NAME}" "simple module name"
assert_eq "" "${PARSED_SUBFOLDER}" "simple subfolder"
assert_eq "" "${PARSED_BRANCH}" "simple branch"

parse_module_repo "https://github.com/user/repo.git@main#modules/foo"
assert_eq "https://github.com/user/repo.git" "${PARSED_REPO_URL}" "complex url"
assert_eq "repo" "${PARSED_REPO_NAME}" "complex repo name"
assert_eq "foo" "${PARSED_MODULE_NAME}" "complex module name"
assert_eq "modules/foo" "${PARSED_SUBFOLDER}" "complex subfolder"
assert_eq "main" "${PARSED_BRANCH}" "complex branch"

parse_module_repo "https://github.com/user/repo@develop"
assert_eq "https://github.com/user/repo" "${PARSED_REPO_URL}" "branch without .git suffix url"
assert_eq "repo" "${PARSED_REPO_NAME}" "branch without .git suffix repo name"
assert_eq "repo" "${PARSED_MODULE_NAME}" "branch without .git suffix module name"
assert_eq "" "${PARSED_SUBFOLDER}" "branch without .git suffix subfolder"
assert_eq "develop" "${PARSED_BRANCH}" "branch without .git suffix branch"

parse_module_repo "https://github.com/user/repo#modules/bar"
assert_eq "https://github.com/user/repo" "${PARSED_REPO_URL}" "subfolder without branch url"
assert_eq "repo" "${PARSED_REPO_NAME}" "subfolder without branch repo name"
assert_eq "bar" "${PARSED_MODULE_NAME}" "subfolder without branch module name"
assert_eq "modules/bar" "${PARSED_SUBFOLDER}" "subfolder without branch subfolder"
assert_eq "" "${PARSED_BRANCH}" "subfolder without branch branch"

parse_module_repo "git@github.com:user/repo.git@feature#src/modules/baz"
assert_eq "git@github.com:user/repo.git" "${PARSED_REPO_URL}" "ssh url"
assert_eq "repo" "${PARSED_REPO_NAME}" "ssh repo name"
assert_eq "baz" "${PARSED_MODULE_NAME}" "ssh module name"
assert_eq "src/modules/baz" "${PARSED_SUBFOLDER}" "ssh subfolder"
assert_eq "feature" "${PARSED_BRANCH}" "ssh branch"

echo "PASS: git_test"
