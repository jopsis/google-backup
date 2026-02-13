#!/bin/sh
# common.sh - Funciones compartidas entre scripts de backup

# Logging con timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Enviar notificacion via ntfy (si configurado)
notify() {
    local priority="$1"
    local title="$2"
    local message="$3"

    if [ -n "$NTFY_URL" ]; then
        log "Enviando notificacion: $title"

        if [ -n "$NTFY_TOKEN" ]; then
            curl -s -H "Authorization: Bearer $NTFY_TOKEN" \
                 -H "Priority: $priority" \
                 -H "Title: $title" \
                 -d "$message" \
                 "$NTFY_URL" > /dev/null 2>&1
        else
            curl -s -H "Priority: $priority" \
                 -H "Title: $title" \
                 -d "$message" \
                 "$NTFY_URL" > /dev/null 2>&1
        fi
    fi
}

# Sincronizar directorio local a todos los destinos remotos
# Uso: sync_to_destinations <path_local> <subdirectorio_remoto>
# Ejemplo: sync_to_destinations /data/drive/juan drive/juan
sync_to_destinations() {
    local local_path="$1"
    local remote_subdir="$2"
    local rclone_conf="${RCLONE_CONF:-/config/rclone/rclone.conf}"

    if [ ! -d "$local_path" ]; then
        log "ERROR: Path local no existe: $local_path"
        return 1
    fi

    if [ -z "$BACKUP_DESTINATIONS" ]; then
        log "WARNING: No hay destinos configurados en BACKUP_DESTINATIONS"
        return 0
    fi

    # Iterar sobre cada destino
    for dest in $(echo "$BACKUP_DESTINATIONS" | tr ',' ' '); do
        local dest_path="${dest}/${remote_subdir}"
        log "Sincronizando: $local_path -> $dest_path"

        if rclone sync \
            --config "$rclone_conf" \
            --log-level "${RCLONE_LOG_LEVEL:-INFO}" \
            --transfers "${RCLONE_TRANSFERS:-4}" \
            --checkers "${RCLONE_CHECKERS:-8}" \
            ${RCLONE_BWLIMIT:+--bwlimit "$RCLONE_BWLIMIT"} \
            "$local_path" "$dest_path"; then
            log "Sync exitoso: $dest_path"
        else
            log "ERROR: Fallo sync a $dest_path"
            notify "high" "Backup Error" "Fallo sincronizacion a $dest_path"
            return 1
        fi
    done

    return 0
}

# Handler de errores para trap
handle_error() {
    local exit_code=$?
    local line_no=$1
    log "ERROR: Script fallo en linea $line_no con codigo $exit_code"
    notify "urgent" "Backup Failed" "Script termino con error en linea $line_no (codigo: $exit_code)"
    exit "$exit_code"
}
