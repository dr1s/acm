#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

CALL_LOG="${TMP_DIR}/calls.log"

podman() {
    echo "$*" >> "${CALL_LOG}"
    return 0
}

# shellcheck disable=SC2034
COMPOSE_PROJECT="testproject"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/container.sh"

assert_eq "podman" "${CONTAINER_CMD}" "CONTAINER_CMD defaults to podman"

container_compose ps
assert_eq "compose -p testproject ps" "$(cat "${CALL_LOG}")" "container_compose forwards project and args"

: > "${CALL_LOG}"
container_up --build
assert_eq "compose -p testproject up -d --build" "$(cat "${CALL_LOG}")" "container_up forwards args"

: > "${CALL_LOG}"
container_down
assert_eq "compose -p testproject down" "$(cat "${CALL_LOG}")" "container_down"

: > "${CALL_LOG}"
container_stop ac-worldserver ac-authserver
assert_eq "compose -p testproject stop ac-worldserver ac-authserver" "$(cat "${CALL_LOG}")" "container_stop forwards args"

: > "${CALL_LOG}"
container_exec ac-database echo hello
assert_eq "compose -p testproject exec -T ac-database echo hello" "$(cat "${CALL_LOG}")" "container_exec forwards args"

: > "${CALL_LOG}"
container_rm ac-database
assert_eq "compose -p testproject rm -f -s ac-database" "$(cat "${CALL_LOG}")" "container_rm forwards args"

: > "${CALL_LOG}"
container_ps_q ac-database
assert_eq "compose -p testproject ps -q ac-database" "$(cat "${CALL_LOG}")" "container_ps_q forwards args"

: > "${CALL_LOG}"
container_images
assert_eq "compose -p testproject config --images" "$(cat "${CALL_LOG}")" "container_images"

: > "${CALL_LOG}"
container_volume_inspect myvol
assert_eq "volume inspect myvol" "$(cat "${CALL_LOG}")" "container_volume_inspect"

: > "${CALL_LOG}"
container_volume_rm myvol
assert_eq "volume rm myvol" "$(cat "${CALL_LOG}")" "container_volume_rm"

echo "PASS: container_test"
