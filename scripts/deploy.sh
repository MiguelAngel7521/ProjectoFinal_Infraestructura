#!/bin/bash

# Script de despliegue completo para el Proyecto Final
# Autor: Proyecto Final Infraestructura
# Version: 1.0.0

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables por defecto
ENVIRONMENT="development"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose/docker-compose.yml"
LOG_FILE="${PROJECT_DIR}/logs/deploy.log"

# Función de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Función de ayuda
show_help() {
    cat << EOF
Script de Despliegue - Proyecto Final

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Entorno de despliegue (development|staging|production)
    -f, --force             Forzar recreación de contenedores
    -b, --build             Forzar rebuild de imágenes
    -h, --help              Mostrar esta ayuda
    --no-backup             Saltar backup de base de datos
    --quick                 Despliegue rápido (saltar checks)

EXAMPLES:
    $0 --environment production
    $0 --environment development --build
    $0 --force --no-backup

EOF
}

# Verificar prerequisites
check_prerequisites() {
    log "Verificando prerequisites..."
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        error "Docker no está instalado"
        exit 1
    fi
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose no está instalado"
        exit 1
    fi
    
    # Verificar que Docker esté corriendo
    if ! docker info &> /dev/null; then
        error "Docker no está corriendo"
        exit 1
    fi
    
    success "Prerequisites verificados"
}

# Crear directorios necesarios
create_directories() {
    log "Creando directorios necesarios..."
    
    mkdir -p "${PROJECT_DIR}/logs"
    mkdir -p "${PROJECT_DIR}/backups"
    mkdir -p "${PROJECT_DIR}/temp"
    
    success "Directorios creados"
}

# Backup de base de datos
backup_database() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        warning "Saltando backup de base de datos"
        return 0
    fi
    
    log "Realizando backup de base de datos..."
    
    local backup_file="${PROJECT_DIR}/backups/backup_$(date +%Y%m%d_%H%M%S).sql"
    
    if docker-compose -f "$COMPOSE_FILE" ps db-master | grep -q "Up"; then
        docker-compose -f "$COMPOSE_FILE" exec -T db-master \
            mysqldump -u root -proot_password_123 crud_app > "$backup_file"
        success "Backup realizado: $backup_file"
    else
        warning "Base de datos no está corriendo, saltando backup"
    fi
}

# Construir imágenes
build_images() {
    if [[ "$FORCE_BUILD" == "true" ]]; then
        log "Construyendo imágenes..."
        docker-compose -f "$COMPOSE_FILE" build --no-cache
        success "Imágenes construidas"
    else
        log "Usando imágenes existentes (usa --build para forzar rebuild)"
    fi
}

# Desplegar servicios
deploy_services() {
    log "Desplegando servicios..."
    
    # Detener servicios existentes si --force
    if [[ "$FORCE_RECREATE" == "true" ]]; then
        log "Deteniendo servicios existentes..."
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # Iniciar servicios
    log "Iniciando servicios..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    success "Servicios desplegados"
}

# Verificar salud de servicios
health_check() {
    if [[ "$QUICK_DEPLOY" == "true" ]]; then
        warning "Saltando health checks (modo rápido)"
        return 0
    fi
    
    log "Verificando salud de servicios..."
    
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        attempt=$((attempt + 1))
        
        # Verificar base de datos
        if docker-compose -f "$COMPOSE_FILE" exec -T db-master mysqladmin ping -u root -proot_password_123 &> /dev/null; then
            success "Base de datos master: OK"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            error "Base de datos master no responde después de $max_attempts intentos"
            exit 1
        fi
        
        log "Esperando base de datos... (intento $attempt/$max_attempts)"
        sleep 5
    done
    
    # Verificar aplicaciones
    for app in app1 app2; do
        attempt=0
        while [[ $attempt -lt $max_attempts ]]; do
            attempt=$((attempt + 1))
            
            local port=$([[ "$app" == "app1" ]] && echo "3001" || echo "3002")
            
            if curl -f "http://localhost:$port/health" &> /dev/null; then
                success "$app: OK"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                error "$app no responde después de $max_attempts intentos"
                exit 1
            fi
            
            log "Esperando $app... (intento $attempt/$max_attempts)"
            sleep 5
        done
    done
    
    # Verificar balanceador
    if curl -f "http://localhost/health" &> /dev/null; then
        success "Balanceador de carga: OK"
    else
        error "Balanceador de carga no responde"
        exit 1
    fi
    
    success "Todos los servicios están saludables"
}

# Mostrar estado final
show_status() {
    log "Estado final del despliegue:"
    echo ""
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    
    log "URLs de acceso:"
    echo "  - Aplicación: http://localhost"
    echo "  - App Server 1: http://localhost:3001"
    echo "  - App Server 2: http://localhost:3002"
    echo "  - FTP Server: ftp://localhost:21"
    echo ""
    
    log "Usuarios FTP:"
    echo "  - deploy_user:deploy_password_123"
    echo "  - backup_user:backup_password_123"
    echo ""
    
    success "Despliegue completado exitosamente!"
}

# Función principal
main() {
    # Variables por defecto
    FORCE_RECREATE="false"
    FORCE_BUILD="false"
    SKIP_BACKUP="false"
    QUICK_DEPLOY="false"
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_RECREATE="true"
                shift
                ;;
            -b|--build)
                FORCE_BUILD="true"
                shift
                ;;
            --no-backup)
                SKIP_BACKUP="true"
                shift
                ;;
            --quick)
                QUICK_DEPLOY="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar entorno
    if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
        error "Entorno inválido: $ENVIRONMENT"
        exit 1
    fi
    
    log "Iniciando despliegue para entorno: $ENVIRONMENT"
    
    # Ejecutar pasos del despliegue
    check_prerequisites
    create_directories
    backup_database
    build_images
    deploy_services
    health_check
    show_status
}

# Manejo de señales
trap 'error "Despliegue interrumpido"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
