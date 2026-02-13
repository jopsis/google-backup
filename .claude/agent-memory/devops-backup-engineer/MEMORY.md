# Proyecto: Google Services Backup System

## Arquitectura Implementada

### Patron: Two-Stage Sync
- **Etapa 1 (Pull)**: Google Service -> Almacenamiento local del contenedor
- **Etapa 2 (Push)**: Almacenamiento local -> Destino(s) remoto(s) via rclone

Razon: Desacopla origen de destino, permite multi-destino, cada etapa es incremental.

### Contenedores
- `scheduler`: Ofelia para orquestacion via Docker socket
- `drive-backup`: rclone/rclone:latest con script bash
- `photos-backup`: Custom Alpine + rclone + gphotosdl + chromium
- `gmail-backup`: Custom Python slim + GYB + rclone

Todos con `restart: "no"` - Ofelia los inicia via job-run.

### Herramientas por Servicio
- **Google Drive**: rclone (backend nativo `drive`)
- **Google Photos**: rclone + gphotosdl (proxy HTTP headless browser)
- **Gmail**: Got Your Back (GYB) - Python, incremental, OAuth2

## Patrones Shell

### Scripts usan `/bin/sh` no bash
Compatible con Alpine. Usar:
- `set -e` y `set -o pipefail`
- `for x in $(echo "$VAR" | tr ',' ' ')` para iterar CSV
- `${VAR%%@*}` para extraer parte antes de @
- `${VAR:+--flag "$VAR"}` para flags condicionales

### Logging
Funcion `log()` en common.sh con timestamp ISO.
Todos los scripts usan `| tee -a "$LOG_FILE"` para stdout + archivo.

### Manejo de Errores
- `trap 'handle_error $LINENO' ERR` en todos los scripts
- Funcion `handle_error()` en common.sh
- Notificaciones via ntfy (opcional)

### Multi-Cuenta y Multi-Destino
- Variable `GOOGLE_ACCOUNTS`: CSV sin espacios (juan@gmail.com,maria@gmail.com)
- Variable `BACKUP_DESTINATIONS`: CSV de remotes rclone (pcloud-backup:path,b2:path)
- Funcion `sync_to_destinations()` itera destinos

## Configuracion rclone

### Naming Convention
- Google Drive: `drive-{cuenta_sin_@}` (ejemplo: drive-juan)
- Google Photos: `photos-{cuenta_sin_@}` (NO usado directamente, gphotosdl maneja)
- Destinos: nombre libre (ejemplo: pcloud-backup, b2-backup)

### Path en Destinos
Estructura en destino remoto:
```
{remote}:
  └─ drive/
      ├─ juan/
      └─ maria/
  └─ photos/
      ├─ juan/
      └─ maria/
  └─ gmail/
      ├─ juan/
      └─ maria/
```

## Docker Compose

### Labels Ofelia
Las labels van en el servicio `scheduler`, NO en los servicios individuales.
Formato para job-run:
```yaml
ofelia.job-run.{nombre}.schedule: "${VAR:-0 0 2 * * *}"
ofelia.job-run.{nombre}.container: "container-name"
```

### Volumenes Compartidos
Todos los servicios comparten:
- `./config/rclone:/config/rclone` (read-only para scripts)
- `./logs:/logs` (escritura)
- `./scripts:/scripts:ro` (scripts compartidos)

## Seguridad

- Usuarios no-root en Dockerfiles (UID 1000)
- rclone.conf debe ser 600 perms
- .gitignore excluye .env y credenciales
- Credenciales OAuth nunca hardcodeadas

## Limitaciones Conocidas

- gphotosdl depende de interfaz web de Google (puede romperse)
- Google Drive no usa Changes API (escanea arbol completo)
- Cookies de gphotosdl pueden expirar
- GYB es Python (lento para mailboxes gigantes)

## Comandos Utiles

- Build: `docker-compose build`
- Start: `docker-compose up -d scheduler`
- Manual run: `docker-compose run --rm drive-backup`
- Config rclone: `make config-rclone`
- Validar: `./scripts/validate-config.sh`
