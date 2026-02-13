# Quick Start - 5 Minutos

## Setup Minimo

```bash
# 1. Configurar variables
cp .env.example .env
nano .env  # Configurar GOOGLE_ACCOUNTS y BACKUP_DESTINATIONS

# 2. Configurar rclone
make config-rclone
# - Crear remote "drive-{tu_cuenta}" para Google Drive
# - Crear remote "pcloud-backup" para pCloud

# 3. Configurar GYB para Gmail
mkdir -p config/gmail/tu_cuenta
docker run --rm -it \
  -v $(pwd)/config/gmail/tu_cuenta:/config \
  -v $(pwd)/data/gmail/tu_cuenta:/data \
  python:3.11-slim bash -c "pip install gyb && gyb --email tu_cuenta@gmail.com --action quota --local-folder /data --config-folder /config"

# 4. Construir e iniciar
make build
make up
```

## Primer Backup (Manual)

```bash
# Probar un backup manual antes de confiar en el scheduler
make backup-drive

# Ver logs
tail -f logs/drive-*.log
```

## Verificar Estado

```bash
make health
```

## Comandos Utiles

```bash
make status      # Ver contenedores
make logs        # Logs del scheduler
make validate    # Validar configuracion
make down        # Detener todo
```

## Configuracion Minima en .env

```bash
GOOGLE_ACCOUNTS=tu_cuenta@gmail.com
BACKUP_DESTINATIONS=pcloud-backup:google-backups
```

## Estructura de rclone.conf

Debe tener al menos:
- `drive-{cuenta}` - Remote de Google Drive
- `pcloud-backup` - Remote de pCloud (o tu destino)

## Troubleshooting Rapido

- Error "rclone.conf not found": Ejecutar `make config-rclone`
- Error "GOOGLE_ACCOUNTS not set": Editar `.env`
- Contenedores no arrancan: `make build` y luego `make up`
- Logs de error: `ls -lht logs/ | head` y revisar el mas reciente

## Documentacion Completa

- README.md - Documentacion tecnica completa
- SETUP.md - Setup paso a paso detallado
- PLAN.md - Analisis de arquitectura
