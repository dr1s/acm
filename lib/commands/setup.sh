#!/bin/bash
#
# acm setup command.
#

source "${SCRIPT_DIR}/lib/utils/args.sh"
source "${SCRIPT_DIR}/lib/utils/git.sh"
source "${SCRIPT_DIR}/lib/utils/container.sh"

show_setup_help() {
    cat <<'EOF'
Usage: ./acm setup [OPTIONS] [config-file]

Clone/update AzerothCore and modules, then rebuild the container stack.

Options:
  --clean         Remove old container images before rebuild
  --no-cache      Rebuild images without using build cache
  --skip-update   Skip git pull/clone, only rebuild images
  --skip-stale    Skip removal of stale modules not in config
  --skip-build    Skip container compose build
  --prune         Remove dangling images, externally pulled images, and build cache after rebuild
  -h, --help      Show this help message
EOF
}

update_main_repo() {
    local MAIN_REPO
    MAIN_REPO="$(read_config_value MAIN_REPO "${CONFIG_FILE}")"
    MAIN_REPO="${MAIN_REPO:-https://github.com/mod-playerbots/azerothcore-wotlk.git}"

    parse_module_repo "${MAIN_REPO}"
    local REPO_URL="${PARSED_REPO_URL}"
    local BRANCH="${PARSED_BRANCH}"

    if [ -d ".git" ]; then
        log_info "Resetting main repository..."
        git reset --hard HEAD
    fi

    git_clone_or_pull "${REPO_URL}" "." "${BRANCH}"
}

read_expected_modules() {
    EXPECTED_MODULES=()
    local line
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        parse_module_repo "${line}"
        EXPECTED_MODULES+=("${PARSED_MODULE_NAME}")
    done < <(read_config_values MODULE_REPO "${CONFIG_FILE}")
}

setup_cache_dir() {
    local CACHE_KEY="${1}"
    local BRANCH="${2}"
    if [ -n "${BRANCH}" ]; then
        echo "${SCRIPT_DIR}/setup-cache/${CACHE_KEY}-${BRANCH}"
    else
        echo "${SCRIPT_DIR}/setup-cache/${CACHE_KEY}"
    fi
}

sync_module_from_cache() {
    local CACHE_DIR="${1}"
    local MODULE_DIR="${2}"
    local SUBFOLDER="${3}"

    mkdir -p "$(dirname "${MODULE_DIR}")"

    if [ -n "${SUBFOLDER}" ]; then
        local SRC="${CACHE_DIR}/${SUBFOLDER}"
        if [ ! -d "${SRC}" ]; then
            log_error "Subfolder '${SUBFOLDER}' not found in ${CACHE_DIR}."
            exit 1
        fi
        rm -rf "${MODULE_DIR}"
        mkdir -p "${MODULE_DIR}"
        rsync -a "${SRC}/" "${MODULE_DIR}/"
    else
        rm -rf "${MODULE_DIR}"
        cp -a "${CACHE_DIR}" "${MODULE_DIR}"
    fi
}

update_modules() {
    local MODULES_DIR="./modules"
    mkdir -p "${MODULES_DIR}"

    local line
    while IFS= read -r line; do
        [ -z "${line}" ] && continue

        parse_module_repo "${line}"
        local REPO_NAME="${PARSED_MODULE_NAME}"
        local REPO_DIR="${MODULES_DIR}/${REPO_NAME}"
        EXPECTED_MODULES+=("${REPO_NAME}")

        local CACHE_DIR
        CACHE_DIR="$(setup_cache_dir "${PARSED_REPO_NAME}" "${PARSED_BRANCH}")"

        git_clone_or_pull "${PARSED_REPO_URL}" "${CACHE_DIR}" "${PARSED_BRANCH}"
        sync_module_from_cache "${CACHE_DIR}" "${REPO_DIR}" "${PARSED_SUBFOLDER}"
    done < <(read_config_values MODULE_REPO "${CONFIG_FILE}")
}

remove_stale_modules() {
    local MODULES_DIR="./modules"
    local dir
    for dir in "${MODULES_DIR}"/*/; do
        [ -d "${dir}" ] || continue

        local DIR_NAME
        DIR_NAME="$(basename "${dir}")"
        local FOUND=false
        local expected
        for expected in "${EXPECTED_MODULES[@]}"; do
            if [ "${DIR_NAME}" = "${expected}" ]; then
                FOUND=true
                break
            fi
        done
        if [ "${FOUND}" = true ]; then
            continue
        fi

        if [ -f "${dir}.stale-keep" ]; then
            log_warn "Stale module '${DIR_NAME}' has .stale-keep file, skipping removal."
        else
            log_info "Removing stale module '${DIR_NAME}'..."
            rm -rf "${dir}"
        fi
    done
}

sync_compose_override() {
    local OVERRIDE_NAME="${CONTAINER_CMD}-compose.override.yml"
    local OVERRIDE_SRC="${SCRIPT_DIR}/compose/${OVERRIDE_NAME}"
    local OVERRIDE_DST="./docker-compose.override.yml"

    if [ ! -f "${OVERRIDE_SRC}" ]; then
        log_warn "No compose/${OVERRIDE_NAME} found. Skipping."
        return
    fi

    log_info "Creating Compose override from compose/${OVERRIDE_NAME}..."
    # shellcheck disable=SC2016
    envsubst '${DOCKER_IMAGE_TAG}' < "${OVERRIDE_SRC}" > "${OVERRIDE_DST}"
}

patch_compose_dependency() {
    local COMPOSE_FILE="./docker-compose.yml"
    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_warn "No ${COMPOSE_FILE} found, skipping dependency patch."
        return
    fi

    local PATCH_FILE="${SCRIPT_DIR}/compose/patch/docker-compose-remove-client-data-init-dependency.diff"
    if [ ! -f "${PATCH_FILE}" ]; then
        log_warn "No ${PATCH_FILE} found, skipping dependency patch."
        return
    fi

    if ! grep -q '^[[:space:]]*ac-client-data-init:[[:space:]]*$' "${COMPOSE_FILE}"; then
        log_info "ac-client-data-init dependency already removed from ${COMPOSE_FILE}."
        return
    fi

    log_info "Patching ${COMPOSE_FILE} to remove ac-client-data-init dependency..."
    if ! patch "${COMPOSE_FILE}" < "${PATCH_FILE}"; then
        log_error "Failed to patch ${COMPOSE_FILE}. The ac-client-data-init dependency may need to be removed manually."
        exit 1
    fi
}

remove_old_images() {
    if [ "${CLEAN}" = false ]; then
        return
    fi

    log_info "Removing existing images (except database)..."
    container_compose config --images | \
    while IFS= read -r image; do
        if echo "${image}" | grep -qv 'mysql'; then
            "${CONTAINER_CMD}" rmi "${image}" 2>/dev/null || true
        fi
    done
}

build_images() {
    log_info "Rebuilding all images..."
    if [ "${NO_CACHE}" = true ]; then
        container_compose build --no-cache
    else
        container_compose build
    fi
}

prune_images() {
    log_info "Pruning dangling images..."
    "${CONTAINER_CMD}" image prune -f
    log_info "Pruning external images..."
    "${CONTAINER_CMD}" image prune --external -f
}

prune_build_cache() {
    log_info "Pruning build cache..."
    "${CONTAINER_CMD}" builder prune -f
}

ensure_module_configs() {
    local MODULES_ETC="./env/dist/etc/modules"
    mkdir -p "${MODULES_ETC}"

    local module_dir dist_file
    for module_dir in ./modules/*/; do
        [ -d "${module_dir}conf" ] || continue

        for dist_file in "${module_dir}conf/"*.conf.dist; do
            [ -f "${dist_file}" ] || continue
            local BASENAME CONF_NAME TARGET
            BASENAME="$(basename "${dist_file}")"
            CONF_NAME="${BASENAME%.dist}"
            TARGET="${MODULES_ETC}/${CONF_NAME}"

            if [ ! -f "${TARGET}" ]; then
                log_info "Creating module config '${CONF_NAME}' from '${dist_file}'..."
                cp "${dist_file}" "${TARGET}"
            fi
        done
    done
}

command_setup() {
    parse_command_args show_setup_help "--clean --no-cache --skip-update --skip-updates --skip-stale --skip-build --prune" "$@"
    reject_positional_args show_setup_help
    init_command_environment "${PARSED_CONFIG_FILE}"

    local CLEAN="${PARSED_FLAGS[--clean]:-false}"
    local NO_CACHE="${PARSED_FLAGS[--no-cache]:-false}"
    local SKIP_UPDATE="${PARSED_FLAGS[--skip-update]:-${PARSED_FLAGS[--skip-updates]:-false}}"
    local SKIP_STALE="${PARSED_FLAGS[--skip-stale]:-false}"
    local SKIP_BUILD="${PARSED_FLAGS[--skip-build]:-false}"
    local PRUNE="${PARSED_FLAGS[--prune]:-false}"

    if [ "${SKIP_UPDATE}" = false ]; then
        update_main_repo
        update_modules
    fi
    if [ "${SKIP_STALE}" = false ]; then
        read_expected_modules
        remove_stale_modules
    fi

    sync_compose_override
    patch_compose_dependency

    if [ "${CLEAN}" = true ]; then
        remove_old_images
    fi
    if [ "${SKIP_BUILD}" = false ]; then
        build_images
    fi
    if [ "${PRUNE}" = true ]; then
        prune_images
        prune_build_cache
    fi

    ensure_module_configs
    log_info "Done."
}
