# Google Services Backup to pCloud

Sistema automatizado de backup de Google Drive, Google Photos y Gmail a pCloud (o cualquier destino compatible con rclone) usando Docker.

## Requisitos

- Docker >= 20.10
- Docker Compose >= 2.0
- Acceso a API de Google (OAuth2 credentials)
- Cuenta de pCloud (o cualquier backend soportado por rclone)
- Minimo 10GB de espacio en disco local para cache temporal

## Arquitectura

El sistema usa una arquitectura two-stage sync:

1. **Pull**: Google Service -> Almacenamiento local del contenedor
2. **Push**: Almacenamiento local -> Destino(s) remoto(s)

Tres contenedores independientes gestionados por Ofelia scheduler:

- `drive-backup`: rclone para Google Drive
- `photos-backup`: rclone + gphotosdl (headless browser) para Google Photos
- `gmail-backup`: Got Your Back (GYB) para Gmail

## Instalacion

### 1. Clonar o descargar el proyecto

```bash
cd /home/jopsis/projects/backup
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
```

Editar `.env` y configurar:

```bash
GOOGLE_ACCOUNTS=tu_cuenta@gmail.com
BACKUP_DESTINATIONS=pcloud-backup:google-backups
```

### 3. Configurar rclone

#### 3.1 Crear archivo de configuracion

```bash
mkdir -p config/rclone
touch config/rclone/rclone.conf
chmod 600 config/rclone/rclone.conf
```

#### 3.2 Configurar Google Drive

Para cada cuenta en GOOGLE_ACCOUNTS, crear un remote con el patron `drive-{cuenta}`:

```bash
docker run --rm -it \
  -v $(pwd)/config/rclone:/config/rclone \
  rclone/rclone:latest \
  config
```

Seguir el wizard:
- Name: `drive-juan` (si la cuenta es juan@gmail.com)
- Storage: `drive` (opcion 18)
- Client ID/Secret: (dejar vacio para usar el de rclone)
- Scope: `drive` (acceso completo)
- Root folder ID: (dejar vacio)
- Service account: (dejar vacio)
- Advanced config: No
- Auto config: Si (abrira browser para OAuth)

Repetir para cada cuenta.

#### 3.3 Configurar pCloud

```bash
docker run --rm -it \
  -v $(pwd)/config/rclone:/config/rclone \
  rclone/rclone:latest \
  config
```

- Name: `pcloud-backup`
- Storage: `pcloud` (opcion 41)
- Client ID/Secret: (dejar vacio)
- Region: US o EU segun tu cuenta
- Auto config: Si

#### 3.4 (Opcional) Configurar Google Photos

Para cada cuenta, crear remote `photos-{cuenta}`:

```bash
docker run --rm -it \
  -v $(pwd)/config/rclone:/config/rclone \
  rclone/rclone:latest \
  config
```

- Name: `photos-juan`
- Storage: `googlephotos` (opcion 20)
- Auto config: Si

Nota: gphotosdl requiere configuracion adicional de cookies del browser.

### 4. Configurar Gmail (GYB)

Para cada cuenta, crear directorio de configuracion:

```bash
mkdir -p config/gmail/juan  # Si la cuenta es juan@gmail.com
```

Ejecutar GYB para generar credenciales OAuth:

```bash
docker run --rm -it \
  -v $(pwd)/config/gmail/juan:/config \
  -v $(pwd)/data/gmail/juan:/data \
  python:3.11-slim bash -c "pip install gyb && gyb --email juan@gmail.com --action quota --local-folder /data --config-folder /config"
```

Seguir las instrucciones para autorizar el acceso.

### 5. Construir contenedores

```bash
docker-compose build
```

### 6. Iniciar scheduler

```bash
docker-compose up -d scheduler
```

## Configuracion

### Variables de Entorno (.env)

| Variable | Descripcion | Default | Ejemplo |
|----------|-------------|---------|---------|
| `GOOGLE_ACCOUNTS` | Cuentas de Google separadas por coma | - | `juan@gmail.com,maria@gmail.com` |
| `BACKUP_DESTINATIONS` | Destinos rclone separados por coma | - | `pcloud-backup:backups` |
| `DRIVE_SCHEDULE` | Cron 6 campos para Drive | `0 0 2 * * *` | Diario a las 2 AM |
| `PHOTOS_SCHEDULE` | Cron 6 campos para Photos | `0 0 3 * * *` | Diario a las 3 AM |
| `GMAIL_SCHEDULE` | Cron 6 campos para Gmail | `0 0 4 * * *` | Diario a las 4 AM |
| `RCLONE_LOG_LEVEL` | Nivel de logging rclone | `INFO` | `DEBUG`, `INFO`, `NOTICE`, `ERROR` |
| `RCLONE_TRANSFERS` | Transferencias paralelas | `4` | `1-32` |
| `RCLONE_CHECKERS` | Checkers paralelos | `8` | `1-32` |
| `RCLONE_BWLIMIT` | Limite de ancho de banda | `0` | `1M`, `10M`, `100M` |
| `NTFY_URL` | URL ntfy.sh para notificaciones | - | `https://ntfy.sh/mi-topic` |
| `NTFY_TOKEN` | Token de autenticacion ntfy | - | `tk_xxxxx` |

### Formato de Cron

Ofelia usa formato de 6 campos: `segundos minutos horas dia mes diasemana`

Ejemplos:
- `0 0 2 * * *` - Diario a las 2:00 AM
- `0 30 3 * * 0` - Domingos a las 3:30 AM
- `0 0 */6 * * *` - Cada 6 horas

### Multi-cuenta

Configurar multiples cuentas separadas por coma en `GOOGLE_ACCOUNTS`:

```bash
GOOGLE_ACCOUNTS=juan@gmail.com,maria@gmail.com,empresa@empresa.com
```

Cada cuenta debe tener:
- Remote rclone: `drive-juan`, `drive-maria`, `drive-empresa`
- Directorio config GYB: `config/gmail/juan/`, `config/gmail/maria/`, `config/gmail/empresa/`

### Multi-destino

Configurar multiples destinos separados por coma en `BACKUP_DESTINATIONS`:

```bash
BACKUP_DESTINATIONS=pcloud-backup:google,b2-backup:google,nas-backup:/mnt/backups/google
```

## Uso

### Ejecutar backup manualmente

```bash
# Backup de Google Drive
docker-compose run --rm drive-backup

# Backup de Google Photos
docker-compose run --rm photos-backup

# Backup de Gmail
docker-compose run --rm gmail-backup
```

### Ver logs

```bash
# Logs en tiempo real del scheduler
docker-compose logs -f scheduler

# Logs de un backup especifico
ls -lh logs/
tail -f logs/drive-20260213-020000.log
```

### Verificar status de contenedores

```bash
docker-compose ps
```

### Detener el sistema

```bash
docker-compose down
```

### Reiniciar completamente

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d scheduler
```

## Estructura de Directorios

```
backup/
├── config/
│   ├── rclone/
│   │   └── rclone.conf          (credenciales OAuth rclone)
│   ├── gmail/
│   │   ├── juan/                (credenciales GYB cuenta juan)
│   │   └── maria/               (credenciales GYB cuenta maria)
│   └── gphotosdl/
│       └── cookies/             (cookies browser para gphotosdl)
├── data/                        (cache local de backups)
│   ├── drive/
│   │   ├── juan/
│   │   └── maria/
│   ├── photos/
│   │   ├── juan/
│   │   └── maria/
│   └── gmail/
│       ├── juan/
│       └── maria/
├── logs/                        (logs de ejecucion)
├── scripts/                     (scripts de backup)
└── docker-compose.yml
```

## Seguridad

- Los archivos de credenciales deben tener permisos `600`
- No commitear `.env` ni archivos en `config/` a git
- Los contenedores ejecutan con usuario no-root
- Usar service accounts para Google Workspace cuando sea posible
- Configurar autenticacion en ntfy si se usa para notificaciones

## Troubleshooting

### Error: rclone.conf no existe

```bash
# Verificar que el archivo existe y tiene permisos correctos
ls -l config/rclone/rclone.conf
chmod 600 config/rclone/rclone.conf
```

### Error: OAuth token expirado

```bash
# Re-configurar el remote afectado
docker run --rm -it \
  -v $(pwd)/config/rclone:/config/rclone \
  rclone/rclone:latest \
  config reconnect drive-juan
```

### Error: GYB authentication failed

```bash
# Eliminar credenciales y re-autorizar
rm -rf config/gmail/juan/oauth2.txt
docker-compose run --rm gmail-backup
```

### Ver logs detallados

```bash
# Cambiar nivel de log en .env
RCLONE_LOG_LEVEL=DEBUG

# Reiniciar
docker-compose down
docker-compose up -d scheduler
```

### Contenedor no se ejecuta segun schedule

```bash
# Verificar labels de Ofelia
docker inspect backup-scheduler | grep ofelia

# Ver logs de Ofelia
docker logs backup-scheduler
```

## Mantenimiento

### Limpiar logs antiguos

```bash
find logs/ -name "*.log" -mtime +30 -delete
```

### Limpiar cache local (liberar espacio)

```bash
# ATENCION: Solo hacer si los datos ya estan en destinos remotos
rm -rf data/drive/* data/photos/* data/gmail/*
```

### Actualizar imagenes

```bash
docker-compose pull
docker-compose build --no-cache
docker-compose up -d scheduler
```

## Limitaciones Conocidas

- Google Photos depende de gphotosdl, que usa la interfaz web (puede romperse si Google cambia UI)
- Cookies de gphotosdl pueden expirar, requiere re-login manual
- Google Drive no usa Changes API (escanea todo el arbol en cada sync)
- Rate limits de API: 12,000 queries/100s por proyecto

## Referencias

- [rclone Documentation](https://rclone.org/docs/)
- [Got Your Back (GYB)](https://github.com/GAM-team/got-your-back)
- [gphotosdl](https://github.com/rclone/gphotosdl)
- [Ofelia Scheduler](https://github.com/mcuadros/ofelia)
