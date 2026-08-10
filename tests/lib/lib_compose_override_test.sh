#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/setup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

ORIGINAL_DIR="$(pwd)"
TMP_DIR=$(mktemp -d)
trap 'cd "${ORIGINAL_DIR}" && rm -rf "${TMP_DIR}"' EXIT

cd "${TMP_DIR}"

DOCKER_IMAGE_TAG="testtag"
export DOCKER_IMAGE_TAG

# Podman override
CONTAINER_CMD="podman"
export CONTAINER_CMD
sync_compose_override
[ -f "${TMP_DIR}/docker-compose.override.yml" ] || fail "podman override should create docker-compose.override.yml"
grep -q "localhost/acore/ac-wotlk-worldserver:testtag" "${TMP_DIR}/docker-compose.override.yml" || fail "podman override should use localhost image prefix"
grep -q "userns_mode" "${TMP_DIR}/docker-compose.override.yml" || fail "podman override should set userns_mode"

rm -f "${TMP_DIR}/docker-compose.override.yml"

# Docker override
CONTAINER_CMD="docker"
export CONTAINER_CMD
sync_compose_override
[ -f "${TMP_DIR}/docker-compose.override.yml" ] || fail "docker override should create docker-compose.override.yml"
grep -q "acore/ac-wotlk-worldserver:testtag" "${TMP_DIR}/docker-compose.override.yml" || fail "docker override should use non-localhost image"
grep -q "userns_mode" "${TMP_DIR}/docker-compose.override.yml" && fail "docker override should not set userns_mode"

echo "PASS: compose_override_test"
