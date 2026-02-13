#!/bin/sh
set -e
set -o pipefail

# Source common functions
. /scripts/common.sh

# Trap errors
trap 'handle_error $LINENO' ERR

LOG_FILE="/logs/photos-$(date +%Y%m%d-%H%M%S).log"
RCLONE_CONF="/config/rclone/rclone.conf"
GPHOTOSDL_PORT="${GPHOTOSDL_PORT:-8282}"
GPHOTOSDL_PID=""

log "============================================================" | tee "$LOG_FILE"
log "Iniciando backup de Google Photos" | tee -a "$LOG_FILE"
log "============================================================" | tee -a "$LOG_FILE"

# Cleanup function para detener gphotosdl
cleanup_gphotosdl() {
    if [ -n "$GPHOTOSDL_PID" ] && kill -0 "$GPHOTOSDL_PID" 2>/dev/null; then
        log "Deteniendo gphotosdl (PID: $GPHOTOSDL_PID)" | tee -a "$LOG_FILE"
        kill "$GPHOTOSDL_PID" 2>/dev/null || true
        wait "$GPHOTOSDL_PID" 2>/dev/null || true
    fi
}

# Trap para cleanup
trap 'cleanup_gphotosdl; handle_error $LINENO' ERR EXIT

# Verificar configuracion
if [ ! -f "$RCLONE_CONF" ]; then
    log "ERROR: No existe rclone.conf en $RCLONE_CONF" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Photos Failed" "Falta archivo rclone.conf"
    exit 1
fi

if [ -z "$GOOGLE_ACCOUNTS" ]; then
    log "ERROR: Variable GOOGLE_ACCOUNTS no configurada" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Photos Failed" "GOOGLE_ACCOUNTS no configurada"
    exit 1
fi

# Verificar que gphotosdl este disponible
if ! command -v gphotosdl >/dev/null 2>&1; then
    log "ERROR: gphotosdl no esta instalado" | tee -a "$LOG_FILE"
    notify "urgent" "Backup Photos Failed" "gphotosdl no disponible"
    exit 1
fi

# Iniciar gphotosdl proxy en segundo plano
log "Iniciando gphotosdl proxy en puerto $GPHOTOSDL_PORT" | tee -a "$LOG_FILE"

gphotosdl -port "$GPHOTOSDL_PORT" -headless 2>&1 | tee -a "$LOG_FILE" &
GPHOTOSDL_PID=$!

log "gphotosdl iniciado (PID: $GPHOTOSDL_PID)" | tee -a "$LOG_FILE"

# Esperar a que el proxy este listo
log "Esperando a que gphotosdl este listo..." | tee -a "$LOG_FILE"
sleep 10

# Iterar por cada cuenta
for account in $(echo "$GOOGLE_ACCOUNTS" | tr ',' ' '); do
    account_name="${account%%@*}"
    remote_name="gphotos-${account_name}"
    local_path="/data/photos/${account_name}"

    log "------------------------------------------------------------" | tee -a "$LOG_FILE"
    log "Procesando cuenta: $account" | tee -a "$LOG_FILE"
    log "Remote: $remote_name" | tee -a "$LOG_FILE"
    log "Path local: $local_path" | tee -a "$LOG_FILE"
    log "------------------------------------------------------------" | tee -a "$LOG_FILE"

    # Crear directorio local si no existe
    mkdir -p "$local_path"

    # ETAPA 1: Google Photos -> Local via gphotosdl proxy
    log "ETAPA 1: Pull desde Google Photos" | tee -a "$LOG_FILE"

    # Nota: gphotosdl expone las fotos en la raiz del proxy HTTP
    # rclone copia desde el proxy a local
    if rclone copy \
        --config "$RCLONE_CONF" \
        --log-file "$LOG_FILE" \
        --log-level "${RCLONE_LOG_LEVEL:-INFO}" \
        --transfers "${RCLONE_TRANSFERS:-4}" \
        --checkers "${RCLONE_CHECKERS:-8}" \
        ${RCLONE_BWLIMIT:+--bwlimit "$RCLONE_BWLIMIT"} \
        --http-url "http://localhost:${GPHOTOSDL_PORT}" \
        ":http:" "$local_path"; then
        log "Pull exitoso para $account" | tee -a "$LOG_FILE"
    else
        log "ERROR: Fallo pull de Google Photos para $account" | tee -a "$LOG_FILE"
        notify "high" "Backup Photos Error" "Fallo pull de $account"
        continue
    fi

    # ETAPA 2: Local -> Destino(s)
    if [ -n "$BACKUP_DESTINATIONS" ]; then
        log "ETAPA 2: Push a destinos remotos" | tee -a "$LOG_FILE"

        if sync_to_destinations "$local_path" "photos/${account_name}" 2>&1 | tee -a "$LOG_FILE"; then
            log "Push exitoso para $account" | tee -a "$LOG_FILE"
        else
            log "ERROR: Fallo push para $account" | tee -a "$LOG_FILE"
            notify "high" "Backup Photos Error" "Fallo push de $account a destinos"
        fi
    else
        log "ETAPA 2: Saltada (sin destinos configurados)" | tee -a "$LOG_FILE"
    fi

    log "Cuenta $account completada" | tee -a "$LOG_FILE"
done

# Cleanup
cleanup_gphotosdl

log "============================================================" | tee -a "$LOG_FILE"
log "Backup de Google Photos completado exitosamente" | tee -a "$LOG_FILE"
log "============================================================" | tee -a "$LOG_FILE"

notify "default" "Backup Photos OK" "Backup de Google Photos completado"

# Reset trap para evitar doble cleanup
trap - EXIT
