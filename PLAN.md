# Plan de Backup Google Services -> pCloud (Docker)

## Indice

1. [Analisis de Herramientas por Servicio](#1-analisis-de-herramientas-por-servicio)
2. [Analisis de Destinos de Almacenamiento](#2-analisis-de-destinos-de-almacenamiento)
3. [Arquitectura Propuesta](#3-arquitectura-propuesta)
4. [Recomendacion Final](#4-recomendacion-final)

---

## 1. Analisis de Herramientas por Servicio

### 1.1 Google Drive

#### Opcion A: rclone (RECOMENDADA)

| Aspecto | Detalle |
|---------|---------|
| Herramienta | [rclone](https://rclone.org/drive/) |
| Backend | `drive` (nativo, primera clase) |
| Sync incremental | Si - compara timestamps/checksums, solo transfiere cambios |
| Multi-cuenta | Si - multiples remotes en rclone.conf |
| Docker | Imagen oficial `rclone/rclone` |
| Export formatos nativos | Si - convierte Docs/Sheets/Slides a docx/xlsx/pptx o PDF |
| Shared Drives | Si - soporte completo |

**Pros:**
- Herramienta madura y activamente mantenida (Go, alta performance)
- Soporte nativo tanto para Google Drive (origen) como pCloud (destino)
- `rclone sync` / `rclone copy` hacen sync incremental de forma natural
- Manejo integrado de rate limits y reintentos
- Soporta filtros, exclusiones, bandwidth limits
- Una sola herramienta cubre origen Y destino
- Logs detallados, modo dry-run, verificacion de integridad

**Contras:**
- No usa la Changes API de Google (recorre el arbol completo para comparar), lo cual puede ser lento en drives con millones de archivos
- La descarga via API v3 esta limitada a ~20-30 MB/s
- El setup inicial de OAuth requiere browser

**Cuotas API relevantes:**
- Google Drive API: 12,000 queries/100s por proyecto, 10 queries/s por usuario
- rclone gestiona esto automaticamente con backoff

#### Opcion B: google-api-python-client (script custom)

| Aspecto | Detalle |
|---------|---------|
| Herramienta | Script Python con `google-api-python-client` |
| Backend | Drive API v3 directo |
| Sync incremental | Manual - implementar con `changes.list` + page tokens |
| Multi-cuenta | Manual - multiples credenciales |

**Pros:**
- Control total sobre la logica
- Puede usar Changes API para sync verdaderamente incremental (solo cambios)
- Posibilidad de guardar estado en SQLite

**Contras:**
- Hay que implementar TODO: descarga, export, manejo de errores, reintentos, rate limits
- Mucho mas codigo que mantener
- Reinventar lo que rclone ya hace bien

**Veredicto Drive:** rclone es la opcion clara. No tiene sentido reimplementar lo que ya resuelve de forma robusta.

---

### 1.2 Google Photos

> **ALERTA CRITICA:** Desde el 31 de marzo de 2025, Google elimino los scopes
> `photoslibrary.readonly` y `photoslibrary.sharing`. La Library API ahora SOLO
> permite acceder a fotos subidas por tu propia aplicacion. Esto invalida la
> mayoria de herramientas tradicionales de backup.

#### Opcion A: rclone + gphotosdl proxy (RECOMENDADA)

| Aspecto | Detalle |
|---------|---------|
| Herramienta | [rclone](https://rclone.org/googlephotos/) + [gphotosdl](https://github.com/rclone/gphotosdl) |
| Mecanismo | gphotosdl ejecuta headless browser, expone proxy HTTP en localhost |
| Resolucion | Original (sin modificar) |
| Incremental | Si - rclone compara lo ya descargado |

**Pros:**
- Resolucion original garantizada
- Sortea las restricciones de la API (usa interfaz web via browser)
- rclone gestiona la sincronizacion incremental y el destino
- Proyecto oficial de rclone

**Contras:**
- Requiere headless browser (Chromium) - mayor consumo de recursos
- Fragilidad: depende de que Google no cambie la interfaz web
- Autenticacion via cookies de browser (no OAuth estandar)
- Proyecto relativamente nuevo, puede tener bugs
- No es claro si funciona de forma desatendida a largo plazo

#### Opcion B: gphoto-cdp / docker-gphotos-sync (JakeWharton)

| Aspecto | Detalle |
|---------|---------|
| Herramienta | [docker-gphotos-sync](https://github.com/JakeWharton/docker-gphotos-sync) |
| Mecanismo | Chrome DevTools Protocol para navegar Google Photos web |
| Resolucion | Original |
| Docker | Si - imagen Docker dedicada con cron integrado |

**Pros:**
- Docker-first, incluye scheduling via CRON
- Descarga calidad original
- Incremental (solo descarga lo nuevo)
- Probado por la comunidad desde hace tiempo

**Contras:**
- Misma fragilidad que Opcion A (depende de la interfaz web)
- Requiere Chromium/Chrome en el contenedor
- Sesion de cookies puede expirar y requerir re-login manual
- No usa la API oficial (puede romperse sin previo aviso)

#### Opcion C: gphotos-sync (gilesknap)

| Aspecto | Detalle |
|---------|---------|
| Herramienta | [gphotos-sync](https://github.com/gilesknap/gphotos-sync) |
| Mecanismo | Library API de Google Photos |
| Docker | Si - multiples imagenes Docker |

**Pros:**
- Python puro, facil de extender
- Soporte historico para backup completo

**Contras:**
- **ROTO desde marzo 2025** - Los scopes que usaba fueron eliminados
- Solo puede acceder a fotos subidas por la propia app (inutil para backup)
- El proyecto tiene issues abiertos reconociendo el problema

#### Opcion D: Google Takeout manual

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | Export manual desde takeout.google.com |
| Automatizable | NO - no hay API publica |

**Pros:**
- Export completo y oficial
- Incluye metadatos en JSON

**Contras:**
- Completamente manual, no automatizable
- No es incremental (siempre export completo)
- Archivos ZIP gigantes
- No es viable para un sistema de backup automatizado

**Veredicto Photos:** La situacion es complicada. Las opciones basadas en headless browser (A y B) son las unicas viables post-marzo 2025 para backup automatizado de calidad original. Recomiendo la **Opcion A (rclone + gphotosdl)** porque unifica la herramienta de destino (rclone para pCloud) y tiene respaldo oficial del equipo de rclone. La **Opcion B (docker-gphotos-sync)** es una alternativa solida como fallback.

---

### 1.3 Gmail

#### Opcion A: Got Your Back (GYB) (RECOMENDADA)

| Aspecto | Detalle |
|---------|---------|
| Herramienta | [Got Your Back](https://github.com/GAM-team/got-your-back) |
| API | Gmail API (oficial) |
| Formato | EML (RFC 2822) o GYB nativo |
| Incremental | Si - guarda estado local de mensajes ya descargados |
| Docker | Si - [docker-gyb](https://github.com/awbn/docker-gyb) |
| Multi-cuenta | Si - via multiples configuraciones |
| Service accounts | Si - para Google Workspace |

**Pros:**
- Proyecto activamente mantenido (equipo GAM)
- Backup incremental nativo (solo mensajes nuevos)
- Soporte OAuth2 y service accounts
- Preserva labels de Gmail
- Capacidad de restore
- Bien documentado

**Contras:**
- Python (puede ser lento para mailboxes muy grandes)
- Docker images son de la comunidad, no oficiales
- El formato nativo GYB no es estandar (pero soporta EML)

#### Opcion B: gwbackupy

| Aspecto | Detalle |
|---------|---------|
| Herramienta | [gwbackupy](https://github.com/smartondev/gwbackupy) |
| API | Gmail API |
| Incremental | Si - escanea y solo descarga mensajes nuevos |
| Docker | Si - [gwbackupy-docker](https://github.com/smartondev/gwbackupy-docker) |
| Multi-cuenta | Si |

**Pros:**
- Alternativa moderna a gmvault
- Docker oficial del autor
- Soporte multi-cuenta en Docker
- Scheduling integrado en el contenedor

**Contras:**
- Proyecto mas joven, menor comunidad
- Marcado como "en desarrollo"
- Menos probado en produccion

#### Opcion C: gmvault

| Aspecto | Detalle |
|---------|---------|
| Herramienta | [gmvault](http://gmvault.org/) |
| Estado | **NO mantenido activamente** |

**Pros:**
- Historicamente la referencia para backup Gmail
- Formato mbox/maildir

**Contras:**
- **Problemas con OAuth moderno de Google**
- No se actualiza regularmente
- Requiere workarounds para funcionar
- Sin soporte Docker oficial

#### Opcion D: Script custom con Gmail API

**Pros:**
- Control total
- Puede usar `messages.list` + `messages.get` con formato RAW

**Contras:**
- Reimplementar logica de incremental, manejo de labels, rate limits
- Innecesario cuando GYB ya lo resuelve

**Veredicto Gmail:** **Got Your Back (GYB)** es la recomendacion. Proyecto maduro, mantenido, incremental, multi-cuenta, con Docker. gwbackupy es una alternativa viable si GYB presenta problemas.

---

## 2. Analisis de Destinos de Almacenamiento

### 2.1 Integracion con pCloud

pCloud ofrece tres vias de integracion:

| Via | Detalle | Recomendacion |
|-----|---------|---------------|
| **rclone backend `pcloud`** | Soporte nativo, OAuth, API propia de pCloud | RECOMENDADA |
| **WebDAV** | `https://webdav.pcloud.com` (US) / `https://ewebdav.pcloud.com` (EU) | Alternativa |
| **pCloud API directa** | REST API propietaria | Solo si se necesita algo muy especifico |

**Recomendacion:** Usar rclone como capa de abstraccion para el destino. rclone ya soporta pCloud de forma nativa, lo que significa que el mismo `rclone copy/sync` que usamos para Google Drive puede escribir directamente a pCloud.

### 2.2 Patron de Abstraccion para Multiples Destinos

La clave para soportar multiples destinos es: **rclone ES la abstraccion.**

```
[Fuente Google]  -->  [Descarga local temporal]  -->  [rclone sync a destino(s)]
```

rclone soporta 70+ backends de almacenamiento. Cambiar o agregar un destino es simplemente:
- Agregar un nuevo remote en `rclone.conf`
- Agregar una variable de entorno con el nombre del remote

Ejemplo de destinos configurables:

```ini
# rclone.conf

# Destino actual
[pcloud-backup]
type = pcloud
token = {"access_token":"xxx","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}

# Futuro destino adicional
[backblaze-backup]
type = b2
account = xxx
key = xxx

# O almacenamiento local/NAS
[nas-backup]
type = local
```

### 2.3 Multi-destino Simultaneo

Para enviar a dos destinos a la vez, hay dos enfoques:

**Enfoque A: Secuencial (simple)**
```bash
rclone sync /backup/drive pcloud-backup:drive-backup/
rclone sync /backup/drive backblaze-backup:drive-backup/
```

**Enfoque B: rclone union backend**
```ini
[multi-dest]
type = union
upstreams = pcloud-backup:backup backblaze-backup:backup
action_policy = all  # escribe a todos
```

**Enfoque C: Script wrapper parametrizado**
```bash
# Variable de entorno con lista de destinos
BACKUP_DESTINATIONS="pcloud-backup:backups,backblaze-backup:backups"

for dest in ${BACKUP_DESTINATIONS//,/ }; do
    rclone sync /local/backup "$dest/drive/" --log-file="/logs/sync-${dest%%:*}.log"
done
```

El **Enfoque C** es el mas flexible y recomendado para nuestro caso.

---

## 3. Arquitectura Propuesta

### 3.1 Estructura de Directorios

```
backup/
|-- docker-compose.yml
|-- .env                          # Variables de entorno globales
|-- .env.example                  # Plantilla documentada
|
|-- config/
|   |-- rclone/
|   |   |-- rclone.conf           # Configuracion de remotes (Drive, Photos, pCloud, etc.)
|   |
|   |-- gmail/
|   |   |-- account1/             # Credenciales y estado GYB para cuenta 1
|   |   |-- account2/             # Credenciales y estado GYB para cuenta 2
|   |
|   |-- gphotosdl/
|   |   |-- cookies/              # Cookies del browser para cada cuenta
|   |
|   |-- ofelia/
|       |-- config.ini            # Configuracion del scheduler (alternativa a labels)
|
|-- data/
|   |-- drive/
|   |   |-- account1/             # Backup local de Drive cuenta 1
|   |   |-- account2/
|   |
|   |-- photos/
|   |   |-- account1/             # Backup local de Photos cuenta 1
|   |   |-- account2/
|   |
|   |-- gmail/
|       |-- account1/             # Backup local de Gmail cuenta 1
|       |-- account2/
|
|-- logs/                         # Logs de todos los servicios
|
|-- scripts/
    |-- backup-drive.sh           # Script de backup Drive
    |-- backup-photos.sh          # Script de backup Photos
    |-- backup-gmail.sh           # Script de backup Gmail
    |-- sync-to-destinations.sh   # Script de sync a destino(s)
    |-- setup-oauth.sh            # Script de setup inicial OAuth
    |-- healthcheck.sh            # Script de healthcheck
```

### 3.2 Contenedores

```
+------------------+     +------------------+     +------------------+
|  drive-backup    |     |  photos-backup   |     |  gmail-backup    |
|                  |     |                  |     |                  |
|  rclone sync     |     |  rclone +        |     |  GYB (got your   |
|  drive: -> local |     |  gphotosdl proxy |     |  back) -> local  |
|  local -> pcloud |     |  -> local        |     |  local -> pcloud |
|                  |     |  local -> pcloud |     |  (via rclone)    |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         +------------+-----------+------------------------+
                      |
              +-------+--------+
              |    ofelia       |
              |  (scheduler)   |
              |                |
              | Ejecuta los    |
              | contenedores   |
              | segun cron     |
              +----------------+
```

### 3.3 Docker Compose

```yaml
# docker-compose.yml

services:

  # ============================================================
  # SCHEDULER - Orquesta todos los backups
  # ============================================================
  scheduler:
    image: mcuadros/ofelia:latest
    container_name: backup-scheduler
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./logs:/logs
    labels:
      ofelia.enabled: "true"
    depends_on:
      - drive-backup
      - photos-backup
      - gmail-backup

  # ============================================================
  # GOOGLE DRIVE BACKUP
  # ============================================================
  drive-backup:
    image: rclone/rclone:latest
    container_name: drive-backup
    entrypoint: ["/bin/sh", "/scripts/backup-drive.sh"]
    environment:
      - GOOGLE_ACCOUNTS=${GOOGLE_ACCOUNTS}
      - BACKUP_DESTINATIONS=${BACKUP_DESTINATIONS}
      - RCLONE_LOG_LEVEL=${RCLONE_LOG_LEVEL:-INFO}
    volumes:
      - ./config/rclone:/config/rclone
      - ./data/drive:/data/drive
      - ./logs:/logs
      - ./scripts:/scripts:ro
    labels:
      ofelia.enabled: "true"
      ofelia.job-run.drive-backup.schedule: "${DRIVE_SCHEDULE:-0 0 2 * * *}"
      ofelia.job-run.drive-backup.container: "drive-backup"
    # El contenedor se ejecuta y termina; ofelia lo lanza periodicamente
    # Para ejecucion via ofelia job-exec, el contenedor debe estar running.
    # Alternativa: usar restart: "no" y que ofelia haga job-run.
    restart: "no"

  # ============================================================
  # GOOGLE PHOTOS BACKUP
  # ============================================================
  photos-backup:
    build:
      context: .
      dockerfile: Dockerfile.photos
    container_name: photos-backup
    environment:
      - GOOGLE_ACCOUNTS=${GOOGLE_ACCOUNTS}
      - BACKUP_DESTINATIONS=${BACKUP_DESTINATIONS}
      - RCLONE_LOG_LEVEL=${RCLONE_LOG_LEVEL:-INFO}
      - GPHOTOSDL_PORT=8282
    volumes:
      - ./config/rclone:/config/rclone
      - ./config/gphotosdl:/config/gphotosdl
      - ./data/photos:/data/photos
      - ./logs:/logs
      - ./scripts:/scripts:ro
    labels:
      ofelia.enabled: "true"
      ofelia.job-run.photos-backup.schedule: "${PHOTOS_SCHEDULE:-0 0 3 * * *}"
      ofelia.job-run.photos-backup.container: "photos-backup"
    restart: "no"

  # ============================================================
  # GMAIL BACKUP
  # ============================================================
  gmail-backup:
    build:
      context: .
      dockerfile: Dockerfile.gmail
    container_name: gmail-backup
    environment:
      - GOOGLE_ACCOUNTS=${GOOGLE_ACCOUNTS}
      - BACKUP_DESTINATIONS=${BACKUP_DESTINATIONS}
      - RCLONE_LOG_LEVEL=${RCLONE_LOG_LEVEL:-INFO}
    volumes:
      - ./config/rclone:/config/rclone
      - ./config/gmail:/config/gmail
      - ./data/gmail:/data/gmail
      - ./logs:/logs
      - ./scripts:/scripts:ro
    labels:
      ofelia.enabled: "true"
      ofelia.job-run.gmail-backup.schedule: "${GMAIL_SCHEDULE:-0 0 4 * * *}"
      ofelia.job-run.gmail-backup.container: "gmail-backup"
    restart: "no"

# Todos los contenedores comparten la misma red
networks:
  default:
    name: backup-network
```

### 3.4 Variables de Entorno (.env)

```bash
# .env

# ============================================================
# CUENTAS DE GOOGLE (separadas por coma)
# Cada cuenta debe tener su remote configurado en rclone.conf
# con el patron: drive-{cuenta}, photos-{cuenta}
# Y su directorio de credenciales GYB en config/gmail/{cuenta}/
# ============================================================
GOOGLE_ACCOUNTS=cuenta1@gmail.com,cuenta2@gmail.com

# ============================================================
# DESTINOS DE BACKUP (separados por coma)
# Cada destino es un remote de rclone definido en rclone.conf
# ============================================================
BACKUP_DESTINATIONS=pcloud-backup:google-backups

# Para multi-destino:
# BACKUP_DESTINATIONS=pcloud-backup:google-backups,b2-backup:google-backups

# ============================================================
# SCHEDULES (formato cron de 6 campos: seg min hora dia mes diasem)
# ============================================================
DRIVE_SCHEDULE=0 0 2 * * *
PHOTOS_SCHEDULE=0 0 3 * * *
GMAIL_SCHEDULE=0 0 4 * * *

# ============================================================
# RCLONE
# ============================================================
RCLONE_LOG_LEVEL=INFO
RCLONE_TRANSFERS=4
RCLONE_CHECKERS=8
RCLONE_BWLIMIT=0

# ============================================================
# NOTIFICACIONES (opcional)
# ============================================================
# NTFY_URL=https://ntfy.sh/mi-backup-topic
# NTFY_TOKEN=tk_xxxxxxxxx
```

### 3.5 Scripts de Backup

#### backup-drive.sh

```bash
#!/bin/sh
set -e

LOG_FILE="/logs/drive-$(date +%Y%m%d-%H%M%S).log"
RCLONE_CONF="/config/rclone/rclone.conf"

echo "[$(date)] Iniciando backup de Google Drive" | tee "$LOG_FILE"

# Iterar por cada cuenta
IFS=',' read -r -a accounts <<< "$GOOGLE_ACCOUNTS"
# Nota: sh no soporta arrays bash. Usar otra forma:
for account in $(echo "$GOOGLE_ACCOUNTS" | tr ',' ' '); do
    # Extraer nombre de cuenta (parte antes de @)
    account_name="${account%%@*}"
    remote_name="drive-${account_name}"
    local_path="/data/drive/${account_name}"

    echo "[$(date)] Backup Drive: $account -> $local_path" | tee -a "$LOG_FILE"

    # Paso 1: Google Drive -> Local
    rclone sync \
        --config "$RCLONE_CONF" \
        --log-file "$LOG_FILE" \
        --log-level "$RCLONE_LOG_LEVEL" \
        --transfers "${RCLONE_TRANSFERS:-4}" \
        --checkers "${RCLONE_CHECKERS:-8}" \
        --drive-export-formats docx,xlsx,pptx,pdf \
        --drive-acknowledge-abuse \
        "${remote_name}:" "$local_path"

    # Paso 2: Local -> Destino(s)
    for dest in $(echo "$BACKUP_DESTINATIONS" | tr ',' ' '); do
        echo "[$(date)] Sync: $local_path -> $dest/drive/$account_name" | tee -a "$LOG_FILE"
        rclone sync \
            --config "$RCLONE_CONF" \
            --log-file "$LOG_FILE" \
            --log-level "$RCLONE_LOG_LEVEL" \
            --transfers "${RCLONE_TRANSFERS:-4}" \
            "$local_path" "${dest}/drive/${account_name}"
    done
done

echo "[$(date)] Backup de Google Drive completado" | tee -a "$LOG_FILE"
```

#### backup-gmail.sh

```bash
#!/bin/sh
set -e

LOG_FILE="/logs/gmail-$(date +%Y%m%d-%H%M%S).log"
RCLONE_CONF="/config/rclone/rclone.conf"

echo "[$(date)] Iniciando backup de Gmail" | tee "$LOG_FILE"

for account in $(echo "$GOOGLE_ACCOUNTS" | tr ',' ' '); do
    account_name="${account%%@*}"
    local_path="/data/gmail/${account_name}"
    config_path="/config/gmail/${account_name}"

    echo "[$(date)] Backup Gmail: $account" | tee -a "$LOG_FILE"

    # Paso 1: Gmail -> Local (GYB incremental)
    gyb --email "$account" \
        --action backup \
        --local-folder "$local_path" \
        --config-folder "$config_path" \
        --service-account \
        2>&1 | tee -a "$LOG_FILE"

    # Paso 2: Local -> Destino(s) via rclone
    for dest in $(echo "$BACKUP_DESTINATIONS" | tr ',' ' '); do
        echo "[$(date)] Sync: $local_path -> $dest/gmail/$account_name" | tee -a "$LOG_FILE"
        rclone sync \
            --config "$RCLONE_CONF" \
            --log-file "$LOG_FILE" \
            --log-level "$RCLONE_LOG_LEVEL" \
            "$local_path" "${dest}/gmail/${account_name}"
    done
done

echo "[$(date)] Backup de Gmail completado" | tee -a "$LOG_FILE"
```

### 3.6 Gestion de Credenciales

```
Tipo de Credencial          | Ubicacion                          | Permisos
----------------------------+------------------------------------+---------
rclone.conf (todos los      | config/rclone/rclone.conf          | 600
remotes OAuth)              |                                    |
GYB OAuth tokens            | config/gmail/{cuenta}/             | 600
GYB service account key     | config/gmail/oauth2service.json    | 600
gphotosdl cookies           | config/gphotosdl/cookies/          | 600
```

**Principios:**
- Nunca se commitean credenciales a git (`.gitignore`)
- Los volumenes de config tienen permisos restrictivos
- El script `setup-oauth.sh` guia el proceso inicial de autenticacion
- Los tokens de rclone incluyen refresh token y se auto-renuevan

### 3.7 Mecanismo de Sincronizacion Incremental

El flujo de cada backup sigue el patron **two-stage sync:**

```
Etapa 1 (Pull): Google Service -> Almacenamiento local del contenedor
Etapa 2 (Push): Almacenamiento local -> Destino(s) remoto(s) via rclone
```

**Por que dos etapas?**

1. **Desacopla origen de destino:** Si pCloud falla, los datos ya estan en local. Si Google falla, lo que ya esta en local se sube igual.
2. **Permite multi-destino:** La etapa 2 puede ejecutarse contra N destinos.
3. **Cada etapa es incremental por separado:**
   - Pull: rclone (Drive) o GYB (Gmail) solo descargan lo nuevo
   - Push: rclone sync solo sube lo que cambio localmente

**Estado de sincronizacion:**
- **Google Drive:** rclone mantiene estado implicito comparando el arbol local con el remoto
- **Google Photos:** gphotosdl/rclone descargan a carpeta local; rclone compara para no re-descargar
- **Gmail:** GYB mantiene una base de datos SQLite local con IDs de mensajes ya descargados

### 3.8 Esquema de Planificacion

```
Hora    | Servicio       | Razon
--------|----------------|-----------------------------------------------
02:00   | Google Drive   | Backup mas pesado, ejecutar en horario de baja actividad
03:00   | Google Photos  | Separado de Drive para no competir por recursos
04:00   | Gmail          | Generalmente el mas rapido
```

Ofelia ejecuta cada contenedor segun su schedule. Los contenedores arrancan, ejecutan el backup, y terminan. Ofelia los re-lanza en el siguiente ciclo.

---

## 4. Recomendacion Final

### Resumen de Decisiones

| Servicio | Herramienta | Razon |
|----------|-------------|-------|
| **Google Drive** | **rclone** | Madura, incremental nativa, soporta Drive y pCloud, Docker oficial |
| **Google Photos** | **rclone + gphotosdl** | Unica via viable post-marzo 2025 para calidad original. Proyecto oficial rclone |
| **Gmail** | **Got Your Back (GYB)** | Mantenida, incremental, multi-cuenta, Docker comunitario |
| **Destino** | **rclone** (capa de abstraccion) | 70+ backends, cambiar destino = cambiar un remote en config |
| **Scheduler** | **Ofelia** | Nativo Docker, configuracion via labels, ligero |

### Riesgos y Mitigaciones

| Riesgo | Probabilidad | Mitigacion |
|--------|-------------|------------|
| Google Photos: gphotosdl deja de funcionar por cambio en interfaz web | Media | Tener Google Takeout manual como plan B. Monitorizar issues del repo |
| Google Photos: sesion de cookies expira | Alta | Alertas de fallo + script de re-autenticacion. Monitorizar logs |
| pCloud rate limits o downtime | Baja | Multi-destino como failover. Datos en local como cache |
| Google API rate limits | Baja | rclone maneja backoff automaticamente. Ejecutar en horarios escalonados |
| GYB deja de mantenerse | Baja | gwbackupy como alternativa lista. Formato EML es estandar |

### Orden de Implementacion Sugerido

1. **Fase 1 - Google Drive** (menor riesgo, mayor valor)
   - Configurar rclone con Drive y pCloud
   - Implementar contenedor + script
   - Probar con una cuenta
   - Agregar scheduling con Ofelia

2. **Fase 2 - Gmail**
   - Configurar GYB con OAuth
   - Implementar contenedor + script de sync a pCloud via rclone
   - Probar incremental

3. **Fase 3 - Google Photos** (mayor riesgo tecnico)
   - Configurar gphotosdl + rclone
   - Probar estabilidad de la sesion headless
   - Implementar alertas de fallo
   - Evaluar si el enfoque es viable a largo plazo

4. **Fase 4 - Hardening**
   - Notificaciones (ntfy/gotify)
   - Verificacion de integridad
   - Documentacion de restore
   - Multi-cuenta completo

---

## Fuentes

- [rclone - Google Drive backend](https://rclone.org/drive/)
- [rclone - Google Photos backend](https://rclone.org/googlephotos/)
- [rclone - pCloud backend](https://rclone.org/pcloud/)
- [rclone/gphotosdl - Original resolution Google Photos downloader](https://github.com/rclone/gphotosdl)
- [JakeWharton/docker-gphotos-sync](https://github.com/JakeWharton/docker-gphotos-sync)
- [GAM-team/got-your-back (GYB)](https://github.com/GAM-team/got-your-back)
- [awbn/docker-gyb](https://github.com/awbn/docker-gyb)
- [smartondev/gwbackupy](https://github.com/smartondev/gwbackupy)
- [smartondev/gwbackupy-docker](https://github.com/smartondev/gwbackupy-docker)
- [gilesknap/gphotos-sync](https://github.com/gilesknap/gphotos-sync)
- [mcuadros/ofelia - Docker job scheduler](https://github.com/mcuadros/ofelia)
- [Google Photos API updates - March 2025](https://developers.google.com/photos/support/updates)
- [Google Photos API limits and quotas](https://developers.google.com/photos/overview/api-limits-quotas)
- [Google Drive API v3 - changes.list](https://developers.google.com/workspace/drive/api/reference/rest/v3/changes/list)
- [besynnerlig/rclone-pcloud-sync](https://github.com/besynnerlig/rclone-pcloud-sync)
