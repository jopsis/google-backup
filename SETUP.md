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

## 4. Configurar Google Photos (gphotosdl)

> **Importante:** Google elimino los scopes de lectura de la Library API en marzo 2025.
> Ya no es posible usar la API oficial para backup. gphotosdl usa un headless browser
> (Chromium) para descargar las fotos en calidad original desde la interfaz web.
> Esto requiere cookies de sesion de Google.

### 4.1 Crear directorio de cookies

```bash
mkdir -p config/gphotosdl/cookies
```

### 4.2 Obtener cookies de sesion de Google Photos

gphotosdl necesita las cookies de tu sesion de Google Photos para autenticarse.
Hay que exportarlas desde tu navegador.

**Opcion A: Extension de navegador (recomendada)**

1. Instala una extension para exportar cookies en formato Netscape:
   - Chrome: [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
   - Firefox: [cookies.txt](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/)

2. Ve a [https://photos.google.com](https://photos.google.com) e inicia sesion con tu cuenta

3. Usa la extension para exportar las cookies de la pagina

4. Guarda el archivo como `config/gphotosdl/cookies/{cuenta}.txt`
   (donde `{cuenta}` es la parte antes del @ de tu email, ej: `config/gphotosdl/cookies/tucuenta.txt`)

**Opcion B: Manualmente desde DevTools**

1. Abre [https://photos.google.com](https://photos.google.com) en tu navegador
2. Abre DevTools (F12) > Application > Cookies
3. Copia todas las cookies del dominio `photos.google.com` y `google.com`
4. Guardalas en formato Netscape en `config/gphotosdl/cookies/{cuenta}.txt`

### 4.3 Configurar remote de rclone para Photos

No se necesita un remote especifico en rclone.conf para Google Photos.
El script `backup-photos.sh` usa gphotosdl como proxy HTTP local (`http://localhost:8282`)
y rclone descarga desde ahi con `:http:`.

Solo necesitas tener configurado el **remote de destino** (pCloud), que ya configuraste en el paso 2.

### 4.4 Verificar que funciona

```bash
# Construir la imagen de photos primero
docker-compose build photos-backup

# Ejecutar backup manual de prueba
docker-compose run --rm photos-backup

# Verificar logs
tail -f logs/photos-*.log
```

### 4.5 Renovacion de cookies

Las cookies de sesion de Google **expiran periodicamente** (normalmente cada 1-2 semanas).
Cuando el backup de Photos falle, revisa los logs:

```bash
tail -20 logs/photos-*.log
```

Si ves errores de autenticacion, repite el paso 4.2 para exportar cookies frescas.

> **Consejo:** Configura notificaciones via ntfy (variable NTFY_URL en .env) para recibir
> alertas cuando el backup de Photos falle, asi puedes renovar las cookies a tiempo.

### 4.6 Multi-cuenta

Para cada cuenta de Google, repite el proceso:

```bash
# Para cuenta2
mkdir -p config/gphotosdl/cookies
# Exportar cookies de photos.google.com con la sesion de cuenta2
# Guardar en config/gphotosdl/cookies/cuenta2.txt
```

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
