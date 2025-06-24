#!/bin/bash

# Script de monitoreo para servicios
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
LOG_FILE="${PROJECT_DIR}/logs/monitor.log"

# Logging
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

success() {
    local message="[SUCCESS] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

warning() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

# Ayuda
show_help() {
    cat << EOF
Script de Monitoreo - Proyecto Final

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --continuous        Monitoreo continuo (cada 30s)
    --once              Verificación única
    --alert-email EMAIL Email para alertas
    --json              Output en formato JSON
    -h, --help          Mostrar ayuda

EXAMPLES:
    $0 --once
    $0 --continuous
    $0 --json

EOF
}

# Verificar contenedor
check_container() {
    local container_name="$1"
    local service_name="$2"
    
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
        
        if [[ "$status" == "healthy" || "$status" == "no-healthcheck" ]]; then
            success "$service_name: Contenedor activo"
            return 0
        else
            error "$service_name: Contenedor no saludable ($status)"
            return 1
        fi
    else
        error "$service_name: Contenedor no encontrado o no activo"
        return 1
    fi
}

# Verificar conectividad HTTP
check_http_endpoint() {
    local url="$1"
    local service_name="$2"
    local timeout="${3:-5}"
    
    if curl -f -s --max-time "$timeout" "$url" > /dev/null 2>&1; then
        success "$service_name: Endpoint HTTP accesible"
        return 0
    else
        error "$service_name: Endpoint HTTP no accesible ($url)"
        return 1
    fi
}

# Verificar base de datos
check_database() {
    local container_name="$1"
    local service_name="$2"
    
    if check_container "$container_name" "$service_name"; then
        if docker exec "$container_name" mysqladmin ping -u root -proot_password_123 > /dev/null 2>&1; then
            success "$service_name: Base de datos responde"
            
            # Verificar replicación si es slave
            if [[ "$container_name" == *"slave"* ]]; then
                local repl_status=$(docker exec "$container_name" mysql -u root -proot_password_123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running" | awk '{print $2}')
                if [[ "$repl_status" == "Yes" ]]; then
                    success "$service_name: Replicación activa"
                else
                    error "$service_name: Replicación no activa"
                    return 1
                fi
            fi
            return 0
        else
            error "$service_name: Base de datos no responde"
            return 1
        fi
    fi
    return 1
}

# Verificar uso de recursos
check_resources() {
    local container_name="$1"
    local service_name="$2"
    
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        local stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" "$container_name" 2>/dev/null)
        if [[ -n "$stats" ]]; then
            success "$service_name: Recursos OK - $stats"
            return 0
        else
            warning "$service_name: No se pudieron obtener estadísticas de recursos"
            return 1
        fi
    fi
    return 1
}

# Verificar logs por errores
check_logs() {
    local container_name="$1"
    local service_name="$2"
    
    local error_count=$(docker logs --tail 100 "$container_name" 2>&1 | grep -i error | wc -l)
    
    if [[ $error_count -gt 0 ]]; then
        warning "$service_name: $error_count errores encontrados en logs recientes"
        return 1
    else
        success "$service_name: No hay errores en logs recientes"
        return 0
    fi
}

# Monitoreo completo
perform_monitoring() {
    local json_output="$1"
    local results=()
    
    log "Iniciando monitoreo de servicios..."
    
    # Servicios a monitorear
    declare -A services=(
        ["proyecto-load-balancer"]="Load Balancer"
        ["proyecto-app1"]="App Server 1"
        ["proyecto-app2"]="App Server 2"
        ["proyecto-db-master"]="Database Master"
        ["proyecto-db-slave"]="Database Slave"
        ["proyecto-ftp-server"]="FTP Server"
    )
    
    # Verificar cada servicio
    for container in "${!services[@]}"; do
        local service_name="${services[$container]}"
        local service_status="healthy"
        
        log "Verificando $service_name..."
        
        # Verificar contenedor
        if ! check_container "$container" "$service_name"; then
            service_status="unhealthy"
        fi
        
        # Verificaciones específicas por servicio
        case "$container" in
            "proyecto-load-balancer")
                check_http_endpoint "http://localhost/nginx-health" "$service_name" || service_status="degraded"
                ;;
            "proyecto-app1")
                check_http_endpoint "http://localhost:3001/health" "$service_name" || service_status="degraded"
                ;;
            "proyecto-app2")
                check_http_endpoint "http://localhost:3002/health" "$service_name" || service_status="degraded"
                ;;
            "proyecto-db-master"|"proyecto-db-slave")
                check_database "$container" "$service_name" || service_status="degraded"
                ;;
        esac
        
        # Verificar recursos
        check_resources "$container" "$service_name"
        
        # Verificar logs
        check_logs "$container" "$service_name"
        
        # Guardar resultado
        if [[ "$json_output" == "true" ]]; then
            results+=("{\"service\":\"$service_name\",\"container\":\"$container\",\"status\":\"$service_status\"}")
        fi
    done
    
    # Verificar conectividad general
    log "Verificando conectividad general..."
    check_http_endpoint "http://localhost" "Aplicación Principal"
    
    # Output JSON si se solicita
    if [[ "$json_output" == "true" ]]; then
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"overall_status\": \"healthy\","
        echo "  \"services\": ["
        printf "%s\n" "${results[@]}" | sed 's/^/    /' | sed '$!s/$/,/'
        echo "  ]"
        echo "}"
    fi
    
    success "Monitoreo completado"
}

# Monitoreo continuo
continuous_monitoring() {
    local json_output="$1"
    
    log "Iniciando monitoreo continuo (Ctrl+C para detener)..."
    
    while true; do
        perform_monitoring "$json_output"
        echo ""
        sleep 30
    done
}

# Función principal
main() {
    local mode="once"
    local json_output="false"
    local alert_email=""
    
    # Crear directorio de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --continuous)
                mode="continuous"
                shift
                ;;
            --once)
                mode="once"
                shift
                ;;
            --json)
                json_output="true"
                shift
                ;;
            --alert-email)
                alert_email="$2"
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
    
    case "$mode" in
        "once")
            perform_monitoring "$json_output"
            ;;
        "continuous")
            continuous_monitoring "$json_output"
            ;;
    esac
}

# Manejo de señales
trap 'log "Monitoreo detenido"; exit 0' INT TERM

# Ejecutar
main "$@"
