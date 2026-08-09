#!/bin/bash
#
# Container and Compose helpers.
#

CONTAINER_CMD="${CONTAINER_CMD:-podman}"

container_compose() {
    "${CONTAINER_CMD}" compose -p "${COMPOSE_PROJECT}" "$@"
}

container_exec() {
    local SERVICE="${1}"
    shift
    container_compose exec -T "${SERVICE}" "$@"
}

container_stop() {
    container_compose stop "$@"
}

container_down() {
    container_compose down
}

container_up() {
    container_compose up -d "$@"
}

container_rm() {
    local SERVICE="${1}"
    container_compose rm -f -s "${SERVICE}"
}

container_volume_inspect() {
    local VOLUME="${1}"
    ${CONTAINER_CMD} volume inspect "${VOLUME}"
}

container_volume_rm() {
    local VOLUME="${1}"
    ${CONTAINER_CMD} volume rm "${VOLUME}"
}

container_ps_q() {
    local SERVICE="${1}"
    container_compose ps -q "${SERVICE}" 2>/dev/null
}

container_images() {
    container_compose config --images
}

wait_for_container_stopped() {
    local CONTAINER="${1}"
    local TIMEOUT="${2:-60}"
    local WAIT_START
    WAIT_START=$(date +%s)

    while true; do
        local STATE
        STATE=$(${CONTAINER_CMD} inspect --format '{{.State.Status}}' "${CONTAINER}" 2>/dev/null || echo "none")
        if [ "${STATE}" = "none" ] || [ "${STATE}" = "exited" ] || [ "${STATE}" = "dead" ]; then
            return 0
        fi

        local ELAPSED=$(( $(date +%s) - WAIT_START ))
        if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
            log_warn "Container '${CONTAINER}' still in state '${STATE}' after ${ELAPSED}s, force removing"
            ${CONTAINER_CMD} container rm -f "${CONTAINER}" 2>/dev/null || true
            return 1
        fi

        sleep 2
    done
}

ensure_compose_containers_stopped() {
    local PROJECT="${1:-${COMPOSE_PROJECT}}"
    local CONTAINERS
    CONTAINERS=$(${CONTAINER_CMD} ps -a --filter label="com.docker.compose.project=${PROJECT}" --format '{{.Names}}' 2>/dev/null || true)

    if [ -z "${CONTAINERS}" ]; then
        return
    fi

    log_info "Found existing containers from compose project '${PROJECT}', cleaning up..."

    local ALL_CONTAINERS=()
    while IFS= read -r CONTAINER; do
        [ -z "${CONTAINER}" ] && continue
        ALL_CONTAINERS+=("${CONTAINER}")
    done <<< "${CONTAINERS}"

    log_info "Stopping containers: ${ALL_CONTAINERS[*]}"
    ${CONTAINER_CMD} stop "${ALL_CONTAINERS[@]}" 2>/dev/null || true

    local CONTAINER
    for CONTAINER in "${ALL_CONTAINERS[@]}"; do
        if ! wait_for_container_stopped "${CONTAINER}" 30; then
            log_error "Failed to stop container '${CONTAINER}'."
            exit 1
        fi
    done

    log_info "All containers from project '${PROJECT}' are stopped."
}
