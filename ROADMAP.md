# Roadmap y Mejoras Futuras

## Fase Actual: MVP Implementado

Sistema funcional con:
- Backup automatizado de Google Drive, Photos y Gmail
- Scheduling via Ofelia
- Multi-cuenta y multi-destino
- Logging estructurado
- Notificaciones opcionales via ntfy

## Mejoras a Corto Plazo

### 1. Verificacion de Integridad
- Implementar checksums post-backup
- Script de verificacion que compare hashes local vs remoto
- Alertas si se detectan inconsistencias

### 2. Retencion y Rotacion
- Politica de retencion configurable (7d, 30d, 90d, etc)
- Script de limpieza automatica de cache local antiguo
- Rotacion de logs automatica

### 3. Metricas y Monitoreo
- Exportar metricas a Prometheus
- Dashboard Grafana para visualizar:
  - Tamaño de backups
  - Tiempo de ejecucion
  - Tasa de errores
  - Uso de bandwidth

### 4. Restore Testing
- Script de restore automatizado
- Pruebas periodicas de restore (dry-run)
- Documentacion de procedimientos de restore

## Mejoras a Medio Plazo

### 5. Compresion
- Opcion de comprimir antes de subir a destino
- Usar rclone crypt para encriptacion
- Evaluar ahorro de espacio vs overhead CPU

### 6. Deduplicacion
- Evaluar rclone dedupe para eliminar duplicados
- Snapshots diferenciales

### 7. Backup Incremental Inteligente
- Para Drive: implementar Changes API via script custom
- Guardar estado en SQLite para skip de archivos sin cambios

### 8. Multi-region Failover
- Detectar fallo de destino primario
- Failover automatico a destino secundario
- Alertas de degradacion

## Mejoras a Largo Plazo

### 9. Web UI
- Dashboard web para visualizar estado
- Configuracion via GUI
- Trigger manual de backups
- Busqueda de archivos en backups

### 10. Soporte Google Workspace
- Service accounts para Workspace
- Backup de Shared Drives
- Backup de Drive de toda la organizacion

### 11. Soporte Adicional de Servicios
- Google Calendar
- Google Contacts
- Google Keep (via Takeout)

### 12. Optimizaciones de Performance
- Paralelizacion de cuentas
- Rate limit adaptativo segun quotas API
- Caching inteligente de metadata

## Limitaciones Conocidas a Resolver

### Google Photos (gphotosdl)
- Dependencia de interfaz web (fragil)
- Evaluar alternativas:
  - JakeWharton/docker-gphotos-sync como fallback
  - Integracion con Google Takeout automatizado

### Rate Limits
- Implementar backoff exponencial mas agresivo
- Distribuir requests en ventanas de tiempo

### Sesiones OAuth
- Auto-refresh de tokens
- Re-autenticacion automatica cuando sea posible
- Alertas proactivas de expiracion

## Contribuciones Deseadas

- Documentacion de casos de uso reales
- Tests de integracion
- Soporte para mas destinos (S3, Azure Blob, etc)
- Mejoras de performance
- Reportes de bugs y edge cases

## Compatibilidad

### Versiones Objetivo
- Docker >= 20.10
- Docker Compose >= 2.0
- rclone >= 1.65
- GYB >= 1.76
- Python >= 3.11

### Sistemas Operativos
- Linux (probado: Debian 13)
- macOS (deberia funcionar, no probado)
- Windows WSL2 (deberia funcionar, no probado)
