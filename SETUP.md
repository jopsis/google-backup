# Setup Rapido

Guia de configuracion inicial paso a paso.

## 1. Variables de Entorno

```bash
cp .env.example .env
nano .env
```

Configurar minimo:
```bash
GOOGLE_ACCOUNTS=tu_cuenta@gmail.com
BACKUP_DESTINATIONS=pcloud-backup:google-backups
```

## 2. Configurar rclone.conf

### Google Drive

```bash
docker run --rm -it -v $(pwd)/config/rclone:/config/rclone rclone/rclone:latest config

# En el wizard:
# n) New remote
# name> drive-tucuenta (sin @gmail.com)
# Storage> 18 (Google Drive)
# client_id> (Enter - dejar vacio)
# client_secret> (Enter - dejar vacio)
# scope> 1 (Full access)
# service_account_file> (Enter - dejar vacio)
# Advanced config> n
# Auto config> y (abrira browser)
# Team drive> n
# Confirm> y
# q) Quit
```

### pCloud

```bash
docker run --rm -it -v $(pwd)/config/rclone:/config/rclone rclone/rclone:latest config

# En el wizard:
# n) New remote
# name> pcloud-backup
# Storage> 41 (pCloud)
# client_id> (Enter - dejar vacio)
# client_secret> (Enter - dejar vacio)
# region> 1 (US) o 2 (EU)
# Advanced config> n
# Auto config> y (abrira browser)
# Confirm> y
# q) Quit
```

## 3. Configurar Gmail (GYB)

```bash
# Crear directorio para cada cuenta
mkdir -p config/gmail/tucuenta

# Ejecutar GYB para autorizar (cambia tucuenta@gmail.com)
docker run --rm -it \
  -v $(pwd)/config/gmail/tucuenta:/config \
  -v $(pwd)/data/gmail/tucuenta:/data \
  python:3.11-slim bash -c "\
    pip install -q gyb && \
    gyb --email tucuenta@gmail.com \
        --action quota \
        --local-folder /data \
        --config-folder /config"

# Seguir las instrucciones en pantalla para autorizar
```

## 4. Construir y Arrancar

```bash
# Construir imagenes
docker-compose build

# Iniciar scheduler
docker-compose up -d scheduler

# Verificar que este corriendo
docker-compose ps
```

## 5. Primer Backup Manual (Recomendado)

Antes de confiar en el scheduler, ejecutar un backup manual para verificar configuracion:

```bash
# Backup de Drive (prueba)
docker-compose run --rm drive-backup

# Ver logs
ls -lh logs/
tail -f logs/drive-*.log
```

Si todo funciona bien, el scheduler ejecutara los backups automaticamente segun los horarios configurados.

## 6. Verificacion

```bash
# Ver logs del scheduler
docker logs backup-scheduler

# Verificar que rclone puede ver los remotes
docker run --rm -v $(pwd)/config/rclone:/config/rclone \
  rclone/rclone:latest listremotes

# Verificar destino pCloud
docker run --rm -v $(pwd)/config/rclone:/config/rclone \
  rclone/rclone:latest lsd pcloud-backup:
```

## Notas

- Los backups automaticos se ejecutan segun los schedules en .env:
  - Drive: 02:00 AM (default)
  - Photos: 03:00 AM (default)
  - Gmail: 04:00 AM (default)

- Los logs se guardan en `logs/` con timestamp

- Los datos locales se cachean en `data/` (se puede limpiar una vez verificado que estan en destino)

- Para multi-cuenta: repetir configuracion de rclone y GYB para cada cuenta
