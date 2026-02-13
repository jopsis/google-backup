.PHONY: help build up down logs status clean test health validate backup-drive backup-photos backup-gmail config-rclone

help:
	@echo "Comandos disponibles:"
	@echo "  make build           - Construir imagenes Docker"
	@echo "  make up              - Iniciar scheduler"
	@echo "  make down            - Detener todos los servicios"
	@echo "  make logs            - Ver logs del scheduler"
	@echo "  make status          - Ver estado de contenedores"
	@echo "  make health          - Health check completo del sistema"
	@echo "  make validate        - Validar configuracion"
	@echo "  make backup-drive    - Ejecutar backup manual de Drive"
	@echo "  make backup-photos   - Ejecutar backup manual de Photos"
	@echo "  make backup-gmail    - Ejecutar backup manual de Gmail"
	@echo "  make config-rclone   - Configurar rclone interactivo"
	@echo "  make test            - Verificar configuracion (alias de validate)"
	@echo "  make clean           - Limpiar cache local (CUIDADO)"

build:
	docker-compose build

up:
	docker-compose up -d scheduler

down:
	docker-compose down

logs:
	docker-compose logs -f scheduler

status:
	@echo "=== Estado de contenedores ==="
	@docker-compose ps
	@echo ""
	@echo "=== Logs recientes ==="
	@ls -lht logs/ | head -n 10

backup-drive:
	docker-compose run --rm drive-backup

backup-photos:
	docker-compose run --rm photos-backup

backup-gmail:
	docker-compose run --rm gmail-backup

config-rclone:
	docker run --rm -it -v $(PWD)/config/rclone:/config/rclone rclone/rclone:latest config

health:
	@./scripts/healthcheck.sh

validate:
	@./scripts/validate-config.sh

test: validate

clean:
	@echo "ATENCION: Esto eliminara todos los datos en cache local"
	@echo "Solo proceder si los datos ya estan respaldados en destinos"
	@read -p "Continuar? [y/N]: " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "Limpiando data/..."; \
		rm -rf data/drive/* data/photos/* data/gmail/*; \
		echo "Cache limpiado"; \
	else \
		echo ""; \
		echo "Cancelado"; \
	fi
