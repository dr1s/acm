#!/bin/bash
#
# Database/config backup and retention cleanup.
#

source "${SCRIPT_DIR}/lib/utils/container.sh"
source "${SCRIPT_DIR}/lib/utils/config.sh"

resolve_backup_dir() {
    local BACKUP_DIR="${BACKUP_DIR:-./backups}"
    case "${BACKUP_DIR}" in
        /*) ;;
        *) BACKUP_DIR="${SCRIPT_DIR}/${BACKUP_DIR}" ;;
    esac
    echo "${BACKUP_DIR}"
}

stop_worldserver_and_authserver() {
    log_info "Stopping worldserver and authserver before backup..."
    container_stop ac-worldserver ac-authserver 2>/dev/null || true

    log_info "Waiting for worldserver to fully stop..."
    wait_for_container_stopped ac-worldserver 60

    log_info "Waiting for authserver to fully stop..."
    wait_for_container_stopped ac-authserver 60
}

stop_database_container() {
    log_info "Stopping database container..."
    container_stop ac-database 2>/dev/null || true
    log_info "Waiting for database to fully stop..."
    wait_for_container_stopped ac-database 60
}

backup_databases() {
    local DB_ROOT_PASSWORD="${1}"
    local BACKUP_DIR="${2}"
    local CONFIG_NAME="${3}"
    local TIMESTAMP="${4}"

    mkdir -p "${BACKUP_DIR}"
    local BACKUP_FILE="${BACKUP_DIR}/db_backup_${CONFIG_NAME}_${TIMESTAMP}.sql"
    local BACKUP_START
    BACKUP_START=$(date +%s)

    log_info "Backing up and compressing databases to ${BACKUP_FILE}.gz..."
    container_compose exec -T ac-database \
        env MYSQL_PWD="${DB_ROOT_PASSWORD}" mysqldump -u root \
        --all-databases \
        --single-transaction \
        --routines \
        --events \
        --triggers \
        > "${BACKUP_FILE}"

    gzip -9 "${BACKUP_FILE}"

    BACKUP_FILE="${BACKUP_FILE}.gz"
    local BACKUP_SIZE
    BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    local BACKUP_ELAPSED=$(( $(date +%s) - BACKUP_START ))
    log_info "Database backup complete (${BACKUP_SIZE}) in ${BACKUP_ELAPSED}s."

    echo "${BACKUP_FILE}"
}

backup_configs() {
    local BACKUP_DIR="${1}"
    local CONFIG_NAME="${2}"
    local TIMESTAMP="${3}"

    mkdir -p "${BACKUP_DIR}"
    local CONFIG_BACKUP="${BACKUP_DIR}/config_backup_${CONFIG_NAME}_${TIMESTAMP}.tar.gz"

    log_info "Backing up config files to ${CONFIG_BACKUP}..."
    tar -czf "${CONFIG_BACKUP}" -C "${SERVER_DIR}" env/dist/etc/ lua_scripts/

    local CONFIG_SIZE
    CONFIG_SIZE=$(du -h "${CONFIG_BACKUP}" | cut -f1)
    log_info "Config backup complete (${CONFIG_SIZE})."

    echo "${CONFIG_BACKUP}"
}

cleanup_backups() {
    local BACKUP_DIR="${1}"
    local CONFIG_NAME="${2}"

    log_info "Cleaning up old backups..."

    local KEEP_ALL_BACKUPS
    KEEP_ALL_BACKUPS="$(read_config_value KEEP_ALL_BACKUPS "${CONFIG_FILE}")"
    KEEP_ALL_BACKUPS="${KEEP_ALL_BACKUPS:-false}"
    if [ "${KEEP_ALL_BACKUPS}" = true ]; then
        log_info "KEEP_ALL_BACKUPS is enabled; skipping cleanup."
        return 0
    fi

    local KEEP_DAILY KEEP_WEEKLY KEEP_MONTHLY
    KEEP_DAILY="$(read_config_value BACKUP_RETAIN_DAILY "${CONFIG_FILE}")"
    KEEP_DAILY="${KEEP_DAILY:-7}"
    KEEP_WEEKLY="$(read_config_value BACKUP_RETAIN_WEEKLY "${CONFIG_FILE}")"
    KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
    KEEP_MONTHLY="$(read_config_value BACKUP_RETAIN_MONTHLY "${CONFIG_FILE}")"
    KEEP_MONTHLY="${KEEP_MONTHLY:-12}"

    local TODAY
    TODAY=$(date +%Y%m%d)

    local -A KEEP_FILES

    local f
    for f in "${BACKUP_DIR}/db_backup_${CONFIG_NAME}_${TODAY}_"*.sql.gz; do
        [ -e "$f" ] && KEEP_FILES["$f"]=1
    done
    for f in "${BACKUP_DIR}/config_backup_${CONFIG_NAME}_${TODAY}_"*.tar.gz; do
        [ -e "$f" ] && KEEP_FILES["$f"]=1
    done

    local i DATE LATEST_DB LATEST_CFG
    if [ "${KEEP_DAILY}" -gt 1 ]; then
        for i in $(seq 1 "$((KEEP_DAILY - 1))"); do
            DATE=$(date -d "${TODAY} - ${i} days" +%Y%m%d 2>/dev/null || date -v-"${i}"d +%Y%m%d 2>/dev/null)
            LATEST_DB=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "db_backup_${CONFIG_NAME}_${DATE}_*.sql.gz" 2>/dev/null | sort -r | head -1 || true)
            [ -n "$LATEST_DB" ] && KEEP_FILES["$LATEST_DB"]=1
            LATEST_CFG=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "config_backup_${CONFIG_NAME}_${DATE}_*.tar.gz" 2>/dev/null | sort -r | head -1 || true)
            [ -n "$LATEST_CFG" ] && KEEP_FILES["$LATEST_CFG"]=1
        done
    fi

    if [ "${KEEP_WEEKLY}" -gt 0 ]; then
        for i in $(seq 1 "${KEEP_WEEKLY}"); do
            DATE=$(date -d "${TODAY} - $((i * 7)) days" +%Y%m%d 2>/dev/null || date -v-"$((i * 7))"d +%Y%m%d 2>/dev/null)
            LATEST_DB=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "db_backup_${CONFIG_NAME}_${DATE}_*.sql.gz" 2>/dev/null | sort -r | head -1 || true)
            [ -n "$LATEST_DB" ] && KEEP_FILES["$LATEST_DB"]=1
            LATEST_CFG=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "config_backup_${CONFIG_NAME}_${DATE}_*.tar.gz" 2>/dev/null | sort -r | head -1 || true)
            [ -n "$LATEST_CFG" ] && KEEP_FILES["$LATEST_CFG"]=1
        done
    fi

    if [ "${KEEP_MONTHLY}" -gt 0 ]; then
        for i in $(seq 1 "${KEEP_MONTHLY}"); do
            DATE=$(date -d "${TODAY} - ${i} months" +%Y%m 2>/dev/null || date -v-"${i}"m +%Y%m 2>/dev/null)
            LATEST_DB=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "db_backup_${CONFIG_NAME}_${DATE}??_*.sql.gz" 2>/dev/null | sort -r | head -1 || true)
            [ -n "$LATEST_DB" ] && KEEP_FILES["$LATEST_DB"]=1
            LATEST_CFG=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "config_backup_${CONFIG_NAME}_${DATE}??_*.tar.gz" 2>/dev/null | sort -r | head -1 || true)
            [ -n "$LATEST_CFG" ] && KEEP_FILES["$LATEST_CFG"]=1
        done
    fi

    local DELETED=0
    for f in "${BACKUP_DIR}/db_backup_${CONFIG_NAME}_"*.sql.gz "${BACKUP_DIR}/config_backup_${CONFIG_NAME}_"*.tar.gz; do
        [ -e "$f" ] || continue
        if [ -z "${KEEP_FILES[$f]+x}" ]; then
            log_info "Removing old backup: $(basename "$f")"
            rm -f "$f"
            DELETED=$((DELETED + 1))
        fi
    done

    log_info "Cleanup complete. Removed ${DELETED} old backup(s)."
}
