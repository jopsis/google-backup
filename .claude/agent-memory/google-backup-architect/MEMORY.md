# Agent Memory - Google Backup Architect

## Google Photos API - CRITICO (desde 31 Mar 2025)
- Scopes `photoslibrary.readonly`, `photoslibrary.sharing`, `photoslibrary` ELIMINADOS
- Library API solo permite acceder a fotos SUBIDAS POR TU APP
- Nueva Picker API requiere seleccion manual del usuario (no sirve para backup automatizado)
- rclone Google Photos backend: solo descarga fotos que el propio rclone subio
- Solucion viable: `rclone/gphotosdl` proxy (headless browser, descarga resolucion original)
- Alternativa: `gphoto-cdp` via Chrome DevTools Protocol (JakeWharton/docker-gphotos-sync)
- Google Takeout NO tiene API publica para automatizacion

## rclone + pCloud
- pCloud soportado nativamente por rclone (backend `pcloud`)
- WebDAV tambien disponible: `https://webdav.pcloud.com` (US) / `https://ewebdav.pcloud.com` (EU)
- rclone sync/copy funciona bien para destino pCloud
- Token setup requiere browser para OAuth inicial

## Gmail Backup Tools
- gmvault: NO mantenido activamente, problemas con OAuth moderno
- Got Your Back (GYB): mantenido, OAuth2, service accounts, Docker images disponibles
- gwbackupy: alternativa moderna, Docker oficial, incremental, multi-cuenta, Python

## Google Drive
- rclone es la mejor opcion (backend `drive` nativo)
- Changes API v3 existe pero rclone NO la usa internamente (usa listing + comparacion)
- rclone sync/copy igualmente eficiente para incremental con --checksum o timestamps
- API v3 max download ~20-30MB/s (vs 100MB/s en v2 ya deprecada)

## Scheduler Docker
- Ofelia: scheduler nativo Docker, labels-based, tipos job-exec/job-run/job-local
- Chadburn: fork mejorado de Ofelia
- Ambos ligeros y en Go

## Preferencias usuario
- Idioma: Espanol
- Sin emojis
- Solucion Docker Compose portable
- Multi-cuenta Google
- Destino abstracto/plugin (ahora pCloud, futuro otros)
