#!/bin/sh
set -e
set -o pipefail

# Source common functions
. /scripts/common.sh

# Trap errors
trap 'handle_error $LINENO' ERR

LOG_FILE="/logs/drive-$(date +%Y%m%d-%H%M%S).log"
RCLONE_CONF="/config/rclone/rclone.conf"

log "============================================================" | tee "$LOG_FILE"
log "Iniciando backup de Google Drive" | tee -a "$LOG_FILE"
log "============================================================" | tee -a "$LOG_FILE"

# Verificar configuracion
if [ ! -f "$RCLONE_CONF" ]; then
    log "ERROR: No existe rclone.conf en $RCLONE_CONF" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Drive Failed" "Falta archivo rclone.conf"
    exit 1
fi

if [ -z "$GOOGLE_ACCOUNTS" ]; then
    log "ERROR: Variable GOOGLE_ACCOUNTS no configurada" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Drive Failed" "GOOGLE_ACCOUNTS no configurada"
    exit 1
fi

if [ -z "$BACKUP_DESTINATIONS" ]; then
    log "WARNING: Variable BACKUP_DESTINATIONS no configurada" | tee -a "$LOG_FILE"
fi

# Iterar por cada cuenta
for account in $(echo "$GOOGLE_ACCOUNTS" | tr ',' ' '); do
    # Extraer nombre de cuenta (parte antes de @)
    account_name="${account%%@*}"
    remote_name="drive-${account_name}"
    local_path="/data/drive/${account_name}"

    log "------------------------------------------------------------" | tee -a "$LOG_FILE"
    log "Procesando cuenta: $account" | tee -a "$LOG_FILE"
    log "Remote: $remote_name" | tee -a "$LOG_FILE"
    log "Path local: $local_path" | tee -a "$LOG_FILE"
    log "------------------------------------------------------------" | tee -a "$LOG_FILE"

    # Crear directorio local si no existe
    mkdir -p "$local_path"

    # ETAPA 1: Google Drive -> Local
    log "ETAPA 1: Pull desde Google Drive" | tee -a "$LOG_FILE"

    if rclone sync \
        --config "$RCLONE_CONF" \
        --log-file "$LOG_FILE" \
        --log-level "${RCLONE_LOG_LEVEL:-INFO}" \
        --transfers "${RCLONE_TRANSFERS:-4}" \
        --checkers "${RCLONE_CHECKERS:-8}" \
        ${RCLONE_BWLIMIT:+--bwlimit "$RCLONE_BWLIMIT"} \
        --drive-export-formats docx,xlsx,pptx,pdf \
        --drive-acknowledge-abuse \
        --drive-skip-gdocs \
        --exclude ".tmp/**" \
        "${remote_name}:" "$local_path"; then
        log "Pull exitoso para $account" | tee -a "$LOG_FILE"
    else
        log "ERROR: Fallo pull de Google Drive para $account" | tee -a "$LOG_FILE"
        notify "high" "Backup Drive Error" "Fallo pull de $account"
        continue
    fi

    # ETAPA 2: Local -> Destino(s)
    if [ -n "$BACKUP_DESTINATIONS" ]; then
        log "ETAPA 2: Push a destinos remotos" | tee -a "$LOG_FILE"

        if sync_to_destinations "$local_path" "drive/${account_name}" 2>&1 | tee -a "$LOG_FILE"; then
            log "Push exitoso para $account" | tee -a "$LOG_FILE"
        else
            log "ERROR: Fallo push para $account" | tee -a "$LOG_FILE"
            notify "high" "Backup Drive Error" "Fallo push de $account a destinos"
        fi
    else
        log "ETAPA 2: Saltada (sin destinos configurados)" | tee -a "$LOG_FILE"
    fi

    log "Cuenta $account completada" | tee -a "$LOG_FILE"
done

log "============================================================" | tee -a "$LOG_FILE"
log "Backup de Google Drive completado exitosamente" | tee -a "$LOG_FILE"
log "============================================================" | tee -a "$LOG_FILE"

notify "default" "Backup Drive OK" "Backup de Google Drive completado"
