#!/bin/sh
# validate-config.sh - Validar configuracion antes de ejecutar backups

set -e

echo "============================================================"
echo "Validacion de Configuracion"
echo "============================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

# Funcion helper
check_file() {
    local file="$1"
    local desc="$2"

    if [ -f "$file" ]; then
        echo "${GREEN}[OK]${NC} $desc: $file"
        return 0
    else
        echo "${RED}[ERROR]${NC} $desc no encontrado: $file"
        errors=$((errors + 1))
        return 1
    fi
}

check_dir() {
    local dir="$1"
    local desc="$2"

    if [ -d "$dir" ]; then
        echo "${GREEN}[OK]${NC} $desc: $dir"
        return 0
    else
        echo "${YELLOW}[WARN]${NC} $desc no existe: $dir"
        warnings=$((warnings + 1))
        return 1
    fi
}

check_var() {
    local var_name="$1"
    local var_value="$2"
    local desc="$3"

    if [ -n "$var_value" ]; then
        echo "${GREEN}[OK]${NC} $desc ($var_name): $var_value"
        return 0
    else
        echo "${RED}[ERROR]${NC} $desc no configurada: $var_name"
        errors=$((errors + 1))
        return 1
    fi
}

echo "--- Archivos de Configuracion ---"
check_file ".env" "Archivo de variables de entorno"
check_file "docker-compose.yml" "Docker Compose"
check_file "config/rclone/rclone.conf" "rclone.conf"
echo ""

echo "--- Directorios ---"
check_dir "config/rclone" "Config rclone"
check_dir "config/gmail" "Config Gmail"
check_dir "data" "Data cache"
check_dir "logs" "Logs"
check_dir "scripts" "Scripts"
echo ""

# Cargar .env si existe
if [ -f ".env" ]; then
    # Exportar variables
    export $(grep -v '^#' .env | xargs)

    echo "--- Variables de Entorno ---"
    check_var "GOOGLE_ACCOUNTS" "$GOOGLE_ACCOUNTS" "Cuentas Google"
    check_var "BACKUP_DESTINATIONS" "$BACKUP_DESTINATIONS" "Destinos backup"
    check_var "DRIVE_SCHEDULE" "$DRIVE_SCHEDULE" "Schedule Drive"
    check_var "PHOTOS_SCHEDULE" "$PHOTOS_SCHEDULE" "Schedule Photos"
    check_var "GMAIL_SCHEDULE" "$GMAIL_SCHEDULE" "Schedule Gmail"
    echo ""

    echo "--- Validacion por Cuenta ---"
    if [ -n "$GOOGLE_ACCOUNTS" ]; then
        for account in $(echo "$GOOGLE_ACCOUNTS" | tr ',' ' '); do
            account_name="${account%%@*}"
            echo ""
            echo "Cuenta: $account"
            check_dir "config/gmail/$account_name" "  Config GYB"
            check_dir "data/drive/$account_name" "  Data Drive" || mkdir -p "data/drive/$account_name"
            check_dir "data/photos/$account_name" "  Data Photos" || mkdir -p "data/photos/$account_name"
            check_dir "data/gmail/$account_name" "  Data Gmail" || mkdir -p "data/gmail/$account_name"
        done
    fi
    echo ""
fi

echo "--- Permisos rclone.conf ---"
if [ -f "config/rclone/rclone.conf" ]; then
    perms=$(stat -c "%a" config/rclone/rclone.conf 2>/dev/null || stat -f "%Lp" config/rclone/rclone.conf 2>/dev/null)
    if [ "$perms" = "600" ] || [ "$perms" = "400" ]; then
        echo "${GREEN}[OK]${NC} Permisos correctos: $perms"
    else
        echo "${YELLOW}[WARN]${NC} Permisos inseguros: $perms (recomendado: 600)"
        echo "  Ejecutar: chmod 600 config/rclone/rclone.conf"
        warnings=$((warnings + 1))
    fi
fi
echo ""

echo "============================================================"
echo "Resumen de Validacion"
echo "============================================================"
echo "Errores: $errors"
echo "Advertencias: $warnings"
echo ""

if [ $errors -eq 0 ]; then
    echo "${GREEN}Configuracion lista para usar${NC}"
    exit 0
else
    echo "${RED}Se encontraron errores. Revisar configuracion.${NC}"
    exit 1
fi
