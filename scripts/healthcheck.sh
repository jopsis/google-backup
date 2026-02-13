#!/bin/sh
# healthcheck.sh - Verificar estado del sistema de backup

set -e

# Colors (solo si stdout es un terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

echo "${BLUE}============================================================${NC}"
echo "${BLUE}Health Check - Sistema de Backup Google Services${NC}"
echo "${BLUE}============================================================${NC}"
echo ""

# Cargar variables de entorno
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

# 1. Verificar contenedores
echo "${BLUE}[1/5] Estado de Contenedores${NC}"
echo "---"

if docker ps -a --filter "name=backup-scheduler" --format "{{.Names}}" | grep -q scheduler; then
    scheduler_status=$(docker inspect -f '{{.State.Status}}' backup-scheduler 2>/dev/null || echo "unknown")
    if [ "$scheduler_status" = "running" ]; then
        echo "${GREEN}✓${NC} Scheduler: running"
    else
        echo "${YELLOW}⚠${NC} Scheduler: $scheduler_status"
    fi
else
    echo "${RED}✗${NC} Scheduler: no existe"
fi

for service in drive-backup photos-backup gmail-backup; do
    if docker ps -a --filter "name=$service" --format "{{.Names}}" | grep -q "$service"; then
        status=$(docker inspect -f '{{.State.Status}}' "$service" 2>/dev/null || echo "unknown")
        # Para servicios con restart: "no", exited es normal
        if [ "$status" = "exited" ] || [ "$status" = "created" ]; then
            echo "${GREEN}✓${NC} $service: $status (normal para job-run)"
        elif [ "$status" = "running" ]; then
            echo "${BLUE}●${NC} $service: running (ejecutando backup)"
        else
            echo "${YELLOW}⚠${NC} $service: $status"
        fi
    else
        echo "${RED}✗${NC} $service: no existe"
    fi
done
echo ""

# 2. Verificar configuracion
echo "${BLUE}[2/5] Configuracion${NC}"
echo "---"

if [ -f config/rclone/rclone.conf ]; then
    remotes=$(docker run --rm -v "$(pwd)/config/rclone:/config/rclone" rclone/rclone:latest listremotes 2>/dev/null | wc -l)
    echo "${GREEN}✓${NC} rclone.conf: $remotes remotes configurados"
else
    echo "${RED}✗${NC} rclone.conf: no existe"
fi

if [ -n "$GOOGLE_ACCOUNTS" ]; then
    num_accounts=$(echo "$GOOGLE_ACCOUNTS" | tr ',' '\n' | wc -l)
    echo "${GREEN}✓${NC} Cuentas Google: $num_accounts configuradas"
else
    echo "${YELLOW}⚠${NC} Cuentas Google: no configuradas"
fi

if [ -n "$BACKUP_DESTINATIONS" ]; then
    num_dests=$(echo "$BACKUP_DESTINATIONS" | tr ',' '\n' | wc -l)
    echo "${GREEN}✓${NC} Destinos: $num_dests configurados"
else
    echo "${YELLOW}⚠${NC} Destinos: no configurados"
fi
echo ""

# 3. Verificar schedules
echo "${BLUE}[3/5] Schedules${NC}"
echo "---"
echo "Drive:  ${DRIVE_SCHEDULE:-no configurado}"
echo "Photos: ${PHOTOS_SCHEDULE:-no configurado}"
echo "Gmail:  ${GMAIL_SCHEDULE:-no configurado}"
echo ""

# 4. Logs recientes
echo "${BLUE}[4/5] Logs Recientes${NC}"
echo "---"

if [ -d logs ] && [ "$(ls -A logs 2>/dev/null)" ]; then
    echo "Ultimos 3 logs:"
    ls -t logs/*.log 2>/dev/null | head -3 | while read -r logfile; do
        size=$(du -h "$logfile" | cut -f1)
        filename=$(basename "$logfile")
        echo "  - $filename ($size)"
    done

    # Verificar errores en logs recientes
    recent_errors=$(find logs -name "*.log" -mtime -1 -exec grep -l "ERROR" {} \; 2>/dev/null | wc -l)
    if [ "$recent_errors" -gt 0 ]; then
        echo "${YELLOW}⚠${NC} Errores encontrados en $recent_errors logs recientes"
    else
        echo "${GREEN}✓${NC} Sin errores en logs de ultimas 24h"
    fi
else
    echo "${YELLOW}⚠${NC} No hay logs todavia"
fi
echo ""

# 5. Espacio en disco
echo "${BLUE}[5/5] Espacio en Disco${NC}"
echo "---"

if [ -d data ]; then
    data_size=$(du -sh data 2>/dev/null | cut -f1)
    echo "Cache local (data/): $data_size"
fi

if [ -d logs ]; then
    logs_size=$(du -sh logs 2>/dev/null | cut -f1)
    echo "Logs: $logs_size"
fi

disk_usage=$(df -h . | tail -1 | awk '{print $5}')
disk_avail=$(df -h . | tail -1 | awk '{print $4}')
echo "Disco: $disk_usage usado, $disk_avail disponible"
echo ""

# Resumen final
echo "${BLUE}============================================================${NC}"
echo "${BLUE}Resumen${NC}"
echo "${BLUE}============================================================${NC}"

# Verificar si hay problemas criticos
critical=0

if ! docker ps --filter "name=backup-scheduler" --format "{{.Names}}" | grep -q scheduler; then
    echo "${RED}✗${NC} Scheduler no esta corriendo"
    critical=1
fi

if [ ! -f config/rclone/rclone.conf ]; then
    echo "${RED}✗${NC} Falta rclone.conf"
    critical=1
fi

if [ -z "$GOOGLE_ACCOUNTS" ]; then
    echo "${YELLOW}⚠${NC} No hay cuentas configuradas"
fi

if [ "$critical" -eq 0 ]; then
    echo "${GREEN}✓ Sistema operativo${NC}"
    exit 0
else
    echo "${RED}✗ Problemas criticos detectados${NC}"
    exit 1
fi
