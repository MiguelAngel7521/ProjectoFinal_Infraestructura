#!/bin/bash

# Script de backup para bases de datos
# Autor: Proyecto Final Infraestructura

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PROJECT_DIR}/backups"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose/docker-compose.yml"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Ayuda
show_help() {
    cat << EOF
Script de Backup - Proyecto Final

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --full              Backup completo (estructura + datos)
    --data-only         Solo datos
    --structure-only    Solo estructura
    --compress          Comprimir backup
    --retention DAYS    Días de retención (default: 7)
    -h, --help          Mostrar ayuda

EXAMPLES:
    $0 --full --compress
    $0 --data-only --retention 30

EOF
}

# Crear directorio de backup
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log "Directorio de backup: $BACKUP_DIR"
}

# Verificar contenedores
check_containers() {
    if ! docker-compose -f "$COMPOSE_FILE" ps db-master | grep -q "Up"; then
        error "Contenedor db-master no está corriendo"
        exit 1
    fi
    
    log "Contenedores verificados"
}

# Realizar backup
perform_backup() {
    local backup_type="$1"
    local compress="$2"
    
    local filename="backup_${backup_type}_${DATE}.sql"
    local filepath="${BACKUP_DIR}/${filename}"
    
    log "Realizando backup $backup_type..."
    
    # Opciones de mysqldump
    local dump_options=""
    case "$backup_type" in
        "full")
            dump_options="--routines --triggers"
            ;;
        "data-only")
            dump_options="--no-create-info"
            ;;
        "structure-only")
            dump_options="--no-data --routines --triggers"
            ;;
    esac
    
    # Ejecutar backup
    if docker-compose -f "$COMPOSE_FILE" exec -T db-master \
        mysqldump -u root -proot_password_123 \
        --single-transaction --lock-tables=false \
        $dump_options crud_app > "$filepath"; then
        
        success "Backup creado: $filename"
        
        # Comprimir si se solicita
        if [[ "$compress" == "true" ]]; then
            log "Comprimiendo backup..."
            gzip "$filepath"
            filepath="${filepath}.gz"
            success "Backup comprimido: ${filename}.gz"
        fi
        
        # Mostrar información del archivo
        local size=$(du -h "$filepath" | cut -f1)
        log "Tamaño del backup: $size"
        
    else
        error "Error al crear backup"
        exit 1
    fi
}

# Limpiar backups antiguos
cleanup_old_backups() {
    local retention_days="$1"
    
    log "Limpiando backups antiguos (>$retention_days días)..."
    
    local deleted_count=0
    while IFS= read -r -d '' file; do
        rm "$file"
        deleted_count=$((deleted_count + 1))
        log "Eliminado: $(basename "$file")"
    done < <(find "$BACKUP_DIR" -name "backup_*.sql*" -type f -mtime +$retention_days -print0)
    
    if [[ $deleted_count -gt 0 ]]; then
        success "Eliminados $deleted_count backups antiguos"
    else
        log "No hay backups antiguos para eliminar"
    fi
}

# Verificar integridad del backup
verify_backup() {
    local filepath="$1"
    
    log "Verificando integridad del backup..."
    
    # Verificar que el archivo no esté vacío
    if [[ ! -s "$filepath" ]]; then
        error "El archivo de backup está vacío"
        return 1
    fi
    
    # Para archivos comprimidos
    if [[ "$filepath" == *.gz ]]; then
        if ! gzip -t "$filepath" 2>/dev/null; then
            error "El archivo comprimido está corrupto"
            return 1
        fi
    fi
    
    success "Backup verificado correctamente"
    return 0
}

# Función principal
main() {
    local backup_type="full"
    local compress="false"
    local retention_days=$RETENTION_DAYS
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                backup_type="full"
                shift
                ;;
            --data-only)
                backup_type="data-only"
                shift
                ;;
            --structure-only)
                backup_type="structure-only"
                shift
                ;;
            --compress)
                compress="true"
                shift
                ;;
            --retention)
                retention_days="$2"
                shift 2
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
    
    log "Iniciando backup de base de datos..."
    
    create_backup_dir
    check_containers
    perform_backup "$backup_type" "$compress"
    
    # Verificar backup creado
    local latest_backup=$(find "$BACKUP_DIR" -name "backup_*_${DATE}.sql*" -type f | head -1)
    if [[ -n "$latest_backup" ]]; then
        verify_backup "$latest_backup"
    fi
    
    cleanup_old_backups "$retention_days"
    
    success "Proceso de backup completado"
}

# Ejecutar
main "$@"
