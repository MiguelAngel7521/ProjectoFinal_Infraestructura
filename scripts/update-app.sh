#!/bin/bash

# Script de actualización de aplicaciones via FTP
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
COMPOSE_FILE="${PROJECT_DIR}/docker-compose/docker-compose.yml"
TEMP_DIR="${PROJECT_DIR}/temp"
FTP_HOST="localhost"
FTP_PORT="21"
FTP_USER="deploy_user"
FTP_PASS="deploy_password_123"

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

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Ayuda
show_help() {
    cat << EOF
Script de Actualización de Aplicaciones - Proyecto Final

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --version VERSION   Versión a desplegar
    --file FILE         Archivo de aplicación (.tar.gz)
    --rollback          Rollback a versión anterior
    --no-restart        No reiniciar servicios
    --dry-run           Simular actualización
    -h, --help          Mostrar ayuda

EXAMPLES:
    $0 --version 1.2.0
    $0 --file app-1.2.0.tar.gz
    $0 --rollback

EOF
}

# Verificar prerequisitos
check_prerequisites() {
    log "Verificando prerequisites..."
    
    # Verificar lftp
    if ! command -v lftp &> /dev/null; then
        warning "lftp no encontrado, usando curl para FTP"
    fi
    
    # Verificar que FTP esté corriendo
    if ! nc -z "$FTP_HOST" "$FTP_PORT" 2>/dev/null; then
        error "Servidor FTP no está accesible en $FTP_HOST:$FTP_PORT"
        exit 1
    fi
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    
    success "Prerequisites verificados"
}

# Crear paquete de aplicación
create_app_package() {
    local version="$1"
    local package_file="${TEMP_DIR}/app-${version}.tar.gz"
    
    log "Creando paquete de aplicación v$version..."
    
    # Crear directorio temporal para el paquete
    local temp_app_dir="${TEMP_DIR}/app-${version}"
    mkdir -p "$temp_app_dir"
    
    # Copiar archivos de la aplicación
    cp -r "${PROJECT_DIR}/app-servers"/* "$temp_app_dir/"
    
    # Crear archivo de versión
    echo "$version" > "${temp_app_dir}/VERSION"
    echo "$(date -Iseconds)" > "${temp_app_dir}/BUILD_DATE"
    
    # Crear tarball
    cd "$TEMP_DIR"
    tar -czf "app-${version}.tar.gz" "app-${version}/"
    cd - > /dev/null
    
    # Limpiar directorio temporal
    rm -rf "$temp_app_dir"
    
    success "Paquete creado: $package_file"
    echo "$package_file"
}

# Subir archivo via FTP
upload_via_ftp() {
    local local_file="$1"
    local remote_file="$2"
    
    log "Subiendo archivo via FTP: $(basename "$local_file")"
    
    if command -v lftp &> /dev/null; then
        # Usar lftp si está disponible
        lftp -c "
            set ftp:ssl-allow no;
            set ftp:passive-mode on;
            open -u $FTP_USER,$FTP_PASS $FTP_HOST;
            cd apps;
            put '$local_file' -o '$remote_file';
            quit
        "
    else
        # Usar curl como alternativa
        curl -T "$local_file" \
             --user "$FTP_USER:$FTP_PASS" \
             "ftp://$FTP_HOST/apps/$remote_file"
    fi
    
    if [[ $? -eq 0 ]]; then
        success "Archivo subido exitosamente"
    else
        error "Error al subir archivo"
        exit 1
    fi
}

# Descargar y desplegar aplicación
deploy_from_ftp() {
    local version="$1"
    local restart_services="$2"
    
    log "Desplegando aplicación v$version desde FTP..."
    
    local remote_file="app-${version}.tar.gz"
    local local_file="${TEMP_DIR}/${remote_file}"
    
    # Descargar archivo desde FTP
    log "Descargando $remote_file..."
    
    if command -v lftp &> /dev/null; then
        lftp -c "
            set ftp:ssl-allow no;
            set ftp:passive-mode on;
            open -u $FTP_USER,$FTP_PASS $FTP_HOST;
            cd apps;
            get '$remote_file' -o '$local_file';
            quit
        "
    else
        curl -o "$local_file" \
             --user "$FTP_USER:$FTP_PASS" \
             "ftp://$FTP_HOST/apps/$remote_file"
    fi
    
    if [[ ! -f "$local_file" ]]; then
        error "No se pudo descargar el archivo de aplicación"
        exit 1
    fi
    
    # Extraer y desplegar
    log "Extrayendo aplicación..."
    cd "$TEMP_DIR"
    tar -xzf "$remote_file"
    
    # Backup de la versión actual
    local backup_dir="${PROJECT_DIR}/app-servers-backup-$(date +%Y%m%d_%H%M%S)"
    log "Creando backup de versión actual..."
    cp -r "${PROJECT_DIR}/app-servers" "$backup_dir"
    
    # Reemplazar aplicación
    log "Desplegando nueva versión..."
    rm -rf "${PROJECT_DIR}/app-servers"
    mv "app-${version}" "${PROJECT_DIR}/app-servers"
    
    # Reiniciar servicios si se solicita
    if [[ "$restart_services" == "true" ]]; then
        log "Reiniciando servicios..."
        docker-compose -f "$COMPOSE_FILE" restart app1 app2
        
        # Verificar que los servicios estén funcionando
        sleep 10
        if curl -f "http://localhost:3001/health" > /dev/null 2>&1 && \
           curl -f "http://localhost:3002/health" > /dev/null 2>&1; then
            success "Servicios reiniciados correctamente"
        else
            error "Error al reiniciar servicios, restaurando backup..."
            rm -rf "${PROJECT_DIR}/app-servers"
            mv "$backup_dir" "${PROJECT_DIR}/app-servers"
            docker-compose -f "$COMPOSE_FILE" restart app1 app2
            exit 1
        fi
    fi
    
    success "Aplicación v$version desplegada exitosamente"
    
    # Limpiar archivos temporales
    cd - > /dev/null
    rm -f "$local_file"
    rm -rf "${TEMP_DIR}/app-${version}"
}

# Rollback a versión anterior
perform_rollback() {
    log "Realizando rollback..."
    
    # Buscar backup más reciente
    local latest_backup=$(find "$PROJECT_DIR" -maxdepth 1 -name "app-servers-backup-*" -type d | sort | tail -1)
    
    if [[ -z "$latest_backup" ]]; then
        error "No se encontró backup para rollback"
        exit 1
    fi
    
    log "Restaurando desde: $(basename "$latest_backup")"
    
    # Backup de versión actual
    local current_backup="${PROJECT_DIR}/app-servers-rollback-$(date +%Y%m%d_%H%M%S)"
    mv "${PROJECT_DIR}/app-servers" "$current_backup"
    
    # Restaurar backup
    cp -r "$latest_backup" "${PROJECT_DIR}/app-servers"
    
    # Reiniciar servicios
    log "Reiniciando servicios..."
    docker-compose -f "$COMPOSE_FILE" restart app1 app2
    
    success "Rollback completado"
}

# Función principal
main() {
    local version=""
    local file=""
    local rollback="false"
    local restart_services="true"
    local dry_run="false"
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                version="$2"
                shift 2
                ;;
            --file)
                file="$2"
                shift 2
                ;;
            --rollback)
                rollback="true"
                shift
                ;;
            --no-restart)
                restart_services="false"
                shift
                ;;
            --dry-run)
                dry_run="true"
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
    
    if [[ "$dry_run" == "true" ]]; then
        log "MODO DRY-RUN: No se realizarán cambios reales"
    fi
    
    check_prerequisites
    
    if [[ "$rollback" == "true" ]]; then
        if [[ "$dry_run" == "false" ]]; then
            perform_rollback
        else
            log "DRY-RUN: Se realizaría rollback"
        fi
    elif [[ -n "$version" ]]; then
        if [[ "$dry_run" == "false" ]]; then
            local package_file=$(create_app_package "$version")
            upload_via_ftp "$package_file" "app-${version}.tar.gz"
            deploy_from_ftp "$version" "$restart_services"
        else
            log "DRY-RUN: Se crearía y desplegaría versión $version"
        fi
    elif [[ -n "$file" ]]; then
        if [[ ! -f "$file" ]]; then
            error "Archivo no encontrado: $file"
            exit 1
        fi
        
        if [[ "$dry_run" == "false" ]]; then
            upload_via_ftp "$file" "$(basename "$file")"
            # Extraer versión del nombre del archivo
            local file_version=$(basename "$file" .tar.gz | sed 's/app-//')
            deploy_from_ftp "$file_version" "$restart_services"
        else
            log "DRY-RUN: Se subiría y desplegaría archivo $file"
        fi
    else
        error "Debe especificar --version, --file o --rollback"
        show_help
        exit 1
    fi
}

# Ejecutar
main "$@"
