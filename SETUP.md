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
    apt-get update -qq && apt-get install -y -qq curl xz-utils && \
    curl -L -o gyb.tar.xz https://github.com/GAM-team/got-your-back/releases/download/v1.95/gyb-1.95-linux-x86_64-glibc2.35.tar.xz && \
    tar -xf gyb.tar.xz && chmod +x gyb && \
    ./gyb --email tucuenta@gmail.com \
        --action quota \
        --local-folder /data \
        --config-folder /config"

# Seguir las instrucciones en pantalla para autorizar OAuth
```

## 4. Configurar Google Photos (gphotosdl)

> **Importante:** Google elimino los scopes de lectura de la Library API en marzo 2025.
> Ya no es posible usar la API oficial para backup. gphotosdl usa un headless browser
> (Chromium) para descargar las fotos en calidad original desde la interfaz web.

### 4.1 Login inicial con gphotosdl

gphotosdl necesita hacer login a Google Photos la primera vez. Ejecuta el contenedor en modo interactivo:

```bash
# Construir la imagen primero si no lo has hecho
docker compose build photos-backup

# Ejecutar login interactivo (abrirá un navegador)
docker run --rm -it \
  -v $(pwd)/config/gphotosdl:/root/.config/gphotosdl \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --entrypoint /bin/sh \
  backup-photos-backup -c "gphotosdl -login -show"
```

> **Nota:** El comando anterior requiere X11 forwarding. Si estás en un servidor sin GUI,
> necesitarás hacer el login desde tu máquina local o usar VNC.

**Alternativa sin X11 (servidor remoto):**

Si no tienes GUI, puedes hacer el login manualmente exportando cookies de tu navegador:

1. En tu navegador local, ve a [https://photos.google.com](https://photos.google.com) y haz login
2. Exporta las cookies usando una extensión:
   - Chrome: [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
   - Firefox: [cookies.txt](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/)
3. Copia el archivo de cookies a `config/gphotosdl/` en el servidor

### 4.2 Verificar la sesión

Una vez autenticado, gphotosdl guarda la sesión en `config/gphotosdl/`. Verifica que funciona:

```bash
# Iniciar gphotosdl en modo servidor
docker run --rm -it \
  -v $(pwd)/config/gphotosdl:/root/.config/gphotosdl \
  -p 8282:8282 \
  --entrypoint /bin/sh \
  backup-photos-backup -c "gphotosdl -addr 0.0.0.0:8282"

# En otra terminal, prueba que responde
curl http://localhost:8282/
```

Si ves un listado de fotos/álbumes, la autenticación funciona.

### 4.3 Configurar remote de rclone para Photos

No se necesita un remote especifico en rclone.conf para Google Photos.
El script `backup-photos.sh` usa gphotosdl como proxy HTTP local (`http://localhost:8282`)
y rclone descarga desde ahi con `:http:`.

Solo necesitas tener configurado el **remote de destino** (pCloud), que ya configuraste en el paso 2.

### 4.4 Verificar que funciona

```bash
# Ejecutar backup manual de prueba
docker compose run --rm photos-backup

# Verificar logs
tail -f logs/photos-*.log
```

### 4.5 Renovacion de sesión

La sesión de gphotosdl **expira periódicamente** (normalmente cada 1-2 semanas).
Cuando el backup de Photos falle, revisa los logs:

```bash
tail -20 logs/photos-*.log
```

Si ves errores de autenticación, repite el paso 4.1 para hacer login nuevamente.

> **Consejo:** Configura notificaciones via ntfy (variable NTFY_URL en .env) para recibir
> alertas cuando el backup de Photos falle, así puedes renovar la sesión a tiempo.

### 4.6 Multi-cuenta

**Limitación actual:** gphotosdl solo soporta una cuenta de Google a la vez en su configuración.
Para hacer backup de múltiples cuentas, necesitarías:

1. Ejecutar instancias separadas de gphotosdl en puertos diferentes
2. Tener directorios de configuración separados para cada cuenta

Esto requiere modificar el docker-compose.yml para tener un servicio por cuenta.
Por ahora, la implementación soporta una sola cuenta de Google Photos.

---

## 5. Construir y Arrancar

```bash
# Construir imagenes
docker-compose build

# Iniciar scheduler
docker-compose up -d scheduler

# Verificar que este corriendo
docker-compose ps
```

## 6. Primer Backup Manual (Recomendado)

Antes de confiar en el scheduler, ejecutar un backup manual para verificar configuracion:

```bash
# Backup de Drive (prueba)
docker-compose run --rm drive-backup

# Ver logs
ls -lh logs/
tail -f logs/drive-*.log
```

Si todo funciona bien, el scheduler ejecutara los backups automaticamente segun los horarios configurados.

## 7. Verificacion

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
