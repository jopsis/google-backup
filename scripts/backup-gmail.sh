#!/bin/sh
set -e
set -o pipefail

# Source common functions
. /scripts/common.sh

# Trap errors
trap 'handle_error $LINENO' ERR

LOG_FILE="/logs/gmail-$(date +%Y%m%d-%H%M%S).log"
RCLONE_CONF="/config/rclone/rclone.conf"

log "============================================================" | tee "$LOG_FILE"
log "Iniciando backup de Gmail" | tee -a "$LOG_FILE"
log "============================================================" | tee -a "$LOG_FILE"

# Verificar configuracion
if [ ! -f "$RCLONE_CONF" ]; then
    log "ERROR: No existe rclone.conf en $RCLONE_CONF" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Gmail Failed" "Falta archivo rclone.conf"
    exit 1
fi

if [ -z "$GOOGLE_ACCOUNTS" ]; then
    log "ERROR: Variable GOOGLE_ACCOUNTS no configurada" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Gmail Failed" "GOOGLE_ACCOUNTS no configurada"
    exit 1
fi

# Verificar que gyb este disponible
if ! command -v gyb >/dev/null 2>&1; then
    log "ERROR: gyb (Got Your Back) no esta instalado" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Gmail Failed" "gyb no disponible"
    exit 1
fi

# Iterar por cada cuenta
for account in $(echo "$GOOGLE_ACCOUNTS" | tr ',' ' '); do
    account_name="${account%%@*}"
    local_path="/data/gmail/${account_name}"
    config_path="/config/gmail/${account_name}"

    log "------------------------------------------------------------" | tee -a "$LOG_FILE"
    log "Procesando cuenta: $account" | tee -a "$LOG_FILE"
    log "Path local: $local_path" | tee -a "$LOG_FILE"
    log "Config path: $config_path" | tee -a "$LOG_FILE"
    log "------------------------------------------------------------" | tee -a "$LOG_FILE"

    # Crear directorios si no existen
    mkdir -p "$local_path"
    mkdir -p "$config_path"

    # Verificar que existan credenciales
    if [ ! -f "${config_path}/oauth2.txt" ] && [ ! -f "${config_path}/oauth2service.json" ]; then
        log "WARNING: No hay credenciales OAuth para $account en $config_path" | tee -a "$LOG_FILE"
        log "Saltando cuenta $account" | tee -a "$LOG_FILE"
        notify "high" "Backup Gmail Warning" "Falta configuracion OAuth para $account"
        continue
    fi

    # ETAPA 1: Gmail -> Local via GYB
    log "ETAPA 1: Pull desde Gmail" | tee -a "$LOG_FILE"

    if gyb --email "$account" \
           --action backup \
           --local-folder "$local_path" \
           --config-folder "$config_path" \
           --service-account \
           2>&1 | tee -a "$LOG_FILE"; then
        log "Pull exitoso para $account" | tee -a "$LOG_FILE"
    else
        gyb_exit_code=$?
        log "ERROR: Fallo pull de Gmail para $account (exit code: $gyb_exit_code)" | tee -a "$LOG_FILE"
        notify "high" "Backup Gmail Error" "Fallo pull de $account"
        continue
    fi

    # ETAPA 2: Local -> Destino(s)
    if [ -n "$BACKUP_DESTINATIONS" ]; then
        log "ETAPA 2: Push a destinos remotos" | tee -a "$LOG_FILE"

        if sync_to_destinations "$local_path" "gmail/${account_name}" 2>&1 | tee -a "$LOG_FILE"; then
            log "Push exitoso para $account" | tee -a "$LOG_FILE"
        else
            log "ERROR: Fallo push para $account" | tee -a "$LOG_FILE"
            notify "high" "Backup Gmail Error" "Fallo push de $account a destinos"
        fi
    else
        log "ETAPA 2: Saltada (sin destinos configurados)" | tee -a "$LOG_FILE"
    fi

    log "Cuenta $account completada" | tee -a "$LOG_FILE"
done

log "============================================================" | tee -a "$LOG_FILE"
log "Backup de Gmail completado exitosamente" | tee -a "$LOG_FILE"
log "============================================================" | tee -a "$LOG_FILE"

notify "default" "Backup Gmail OK" "Backup de Gmail completado"
