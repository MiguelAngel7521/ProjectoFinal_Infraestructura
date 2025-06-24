#!/bin/bash

# Script de Monitoreo Completo del Sistema - SIS313
# Autor: Proyecto Final Infraestructura
# Universidad San Francisco Xavier de Chuquisaca

set -euo pipefail

# Colores para output
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m' # Sin Color

# Configuración de servidores
PROXY_IP="192.168.218.100"
APP1_IP="192.168.218.101"
BD1_IP="192.168.218.102"
APP2_IP="192.168.218.103"
BD2_IP="192.168.218.104"

# Credenciales
DB_USER="usuario_bd"
DB_PASS="clave_bd_segura_123"
DB_NAME="sistema_clientes"

# Archivo de log
LOG_FILE="/var/log/monitoreo-sis313.log"

# Función de logging
log() {
    local mensaje="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${AZUL}${mensaje}${NC}"
    echo "$mensaje" >> "$LOG_FILE"
}

error() {
    local mensaje="[ERROR] $1"
    echo -e "${ROJO}${mensaje}${NC}"
    echo "$mensaje" >> "$LOG_FILE"
}

exito() {
    local mensaje="[ÉXITO] $1"
    echo -e "${VERDE}${mensaje}${NC}"
    echo "$mensaje" >> "$LOG_FILE"
}

advertencia() {
    local mensaje="[ADVERTENCIA] $1"
    echo -e "${AMARILLO}${mensaje}${NC}"
    echo "$mensaje" >> "$LOG_FILE"
}

# Ayuda
mostrar_ayuda() {
    cat << EOF
Script de Monitoreo Completo - Proyecto SIS313

USO:
    $0 [OPCIONES]

OPCIONES:
    --continuo          Monitoreo continuo (cada 30s)
    --una-vez           Verificación única
    --json              Output en formato JSON
    --alerta-email EMAIL Email para alertas críticas
    -h, --ayuda         Mostrar esta ayuda

EJEMPLOS:
    $0 --una-vez
    $0 --continuo
    $0 --json --alerta-email admin@sis313.usfx.bo

EOF
}

# Verificar conectividad a servidor
verificar_ping() {
    local ip="$1"
    local nombre="$2"
    
    if ping -c 3 -W 5 "$ip" > /dev/null 2>&1; then
        exito "$nombre ($ip): Conectividad OK"
        return 0
    else
        error "$nombre ($ip): Sin conectividad"
        return 1
    fi
}

# Verificar servicio HTTP
verificar_http() {
    local url="$1"
    local servicio="$2"
    local timeout="${3:-10}"
    
    if curl -f -s --max-time "$timeout" "$url" > /dev/null 2>&1; then
        exito "$servicio: Servicio HTTP disponible"
        return 0
    else
        error "$servicio: Servicio HTTP no disponible ($url)"
        return 1
    fi
}

# Verificar base de datos
verificar_mysql() {
    local host="$1"
    local nombre="$2"
    
    if mysql -h "$host" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" > /dev/null 2>&1; then
        exito "$nombre: Base de datos disponible"
        
        # Verificar datos
        local count=$(mysql -h "$host" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM clientes;" 2>/dev/null | tail -1)
        log "$nombre: $count clientes en base de datos"
        
        return 0
    else
        error "$nombre: Base de datos no disponible"
        return 1
    fi
}

# Verificar replicación MySQL
verificar_replicacion() {
    log "Verificando replicación MySQL..."
    
    # Verificar estado del esclavo
    local slave_status=$(mysql -h "$BD2_IP" -u "$DB_USER" -p"$DB_PASS" -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running" | awk '{print $2}')
    
    if [[ "$slave_status" == "Yes" ]]; then
        exito "Replicación MySQL: Activa y funcionando"
        return 0
    else
        error "Replicación MySQL: No está funcionando correctamente"
        return 1
    fi
}

# Verificar RAID 1
verificar_raid() {
    log "Verificando estado del RAID 1 en BD2..."
    
    # Conectar vía SSH para verificar RAID (requiere configuración de SSH sin clave)
    local raid_status=$(ssh -o ConnectTimeout=10 usuario@"$BD2_IP" "cat /proc/mdstat 2>/dev/null | grep 'md0'" 2>/dev/null || echo "error")
    
    if [[ "$raid_status" != "error" ]] && [[ "$raid_status" == *"active"* ]]; then
        exito "RAID 1: Funcionando correctamente"
        log "Estado RAID: $raid_status"
        return 0
    else
        advertencia "RAID 1: No se puede verificar o hay problemas"
        return 1
    fi
}

# Verificar balanceador de carga
verificar_balanceador() {
    log "Verificando balanceador de carga..."
    
    # Hacer múltiples requests para verificar balanceo
    local respuestas_app1=0
    local respuestas_app2=0
    
    for i in {1..10}; do
        local respuesta=$(curl -s --max-time 5 "http://$PROXY_IP/api/clientes" 2>/dev/null | grep -o '"servidor":"[^"]*"' | cut -d'"' -f4)
        
        case "$respuesta" in
            *App1*) respuestas_app1=$((respuestas_app1 + 1)) ;;
            *App2*) respuestas_app2=$((respuestas_app2 + 1)) ;;
        esac
        sleep 1
    done
    
    if [[ $respuestas_app1 -gt 0 ]] && [[ $respuestas_app2 -gt 0 ]]; then
        exito "Balanceador: Distribuyendo carga (App1: $respuestas_app1, App2: $respuestas_app2)"
        return 0
    elif [[ $((respuestas_app1 + respuestas_app2)) -gt 0 ]]; then
        advertencia "Balanceador: Funcionando pero no balanceando (App1: $respuestas_app1, App2: $respuestas_app2)"
        return 1
    else
        error "Balanceador: No está funcionando"
        return 1
    fi
}

# Verificar uso de recursos
verificar_recursos() {
    log "Verificando uso de recursos del sistema..."
    
    # Memoria
    local memoria_libre=$(free | grep '^Mem' | awk '{printf "%.1f", ($7/$2)*100}')
    if (( $(echo "$memoria_libre > 10" | bc -l) )); then
        exito "Memoria: ${memoria_libre}% libre"
    else
        advertencia "Memoria: Solo ${memoria_libre}% libre"
    fi
    
    # Disco
    local disco_uso=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disco_uso -lt 80 ]]; then
        exito "Disco: ${disco_uso}% usado"
    else
        advertencia "Disco: ${disco_uso}% usado (crítico)"
    fi
    
    # Carga del sistema
    local carga=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    exito "Carga del sistema: $carga"
}

# Verificación completa
realizar_monitoreo() {
    local json_output="$1"
    local resultados=()
    local estado_general="saludable"
    
    log "=== Iniciando Monitoreo Completo SIS313 ==="
    
    # Verificar conectividad
    log "📡 Verificando conectividad de red..."
    verificar_ping "$PROXY_IP" "Proxy" || estado_general="degradado"
    verificar_ping "$APP1_IP" "App1" || estado_general="degradado"
    verificar_ping "$APP2_IP" "App2" || estado_general="degradado"
    verificar_ping "$BD1_IP" "BD1" || estado_general="degradado"
    verificar_ping "$BD2_IP" "BD2" || estado_general="degradado"
    
    # Verificar servicios HTTP
    log "🌐 Verificando servicios web..."
    verificar_http "http://$PROXY_IP" "Balanceador Principal" || estado_general="degradado"
    verificar_http "http://$PROXY_IP:8080" "Estado del Proxy" || estado_general="degradado"
    verificar_http "http://$APP1_IP:3000/health" "App1 Health Check" || estado_general="degradado"
    verificar_http "http://$APP2_IP:3000/health" "App2 Health Check" || estado_general="degradado"
    
    # Verificar bases de datos
    log "🗄️ Verificando bases de datos..."
    verificar_mysql "$BD1_IP" "BD1 (Maestro)" || estado_general="crítico"
    verificar_mysql "$BD2_IP" "BD2 (Esclavo)" || estado_general="degradado"
    
    # Verificar replicación
    verificar_replicacion || estado_general="degradado"
    
    # Verificar RAID
    verificar_raid || estado_general="degradado"
    
    # Verificar balanceador
    verificar_balanceador || estado_general="degradado"
    
    # Verificar recursos
    verificar_recursos
    
    # Output JSON si se solicita
    if [[ "$json_output" == "true" ]]; then
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"proyecto\": \"SIS313-USFX\","
        echo "  \"estado_general\": \"$estado_general\","
        echo "  \"servidores\": {"
        echo "    \"proxy\": \"$PROXY_IP\","
        echo "    \"app1\": \"$APP1_IP\","
        echo "    \"app2\": \"$APP2_IP\","
        echo "    \"bd1\": \"$BD1_IP\","
        echo "    \"bd2\": \"$BD2_IP\""
        echo "  }"
        echo "}"
    fi
    
    log "=== Monitoreo completado - Estado: $estado_general ==="
    
    # Enviar alerta si es crítico
    if [[ "$estado_general" == "crítico" ]] && [[ -n "${ALERT_EMAIL:-}" ]]; then
        enviar_alerta_critica
    fi
}

# Enviar alerta crítica por email
enviar_alerta_critica() {
    local asunto="ALERTA CRÍTICA - Sistema SIS313"
    local mensaje="Se ha detectado un estado crítico en el sistema de infraestructura SIS313.
    
Timestamp: $(date)
Estado: CRÍTICO

Revise inmediatamente los logs en: $LOG_FILE

Servidores:
- Proxy: $PROXY_IP
- App1: $APP1_IP  
- App2: $APP2_IP
- BD1: $BD1_IP
- BD2: $BD2_IP"

    echo "$mensaje" | mail -s "$asunto" "$ALERT_EMAIL" 2>/dev/null || advertencia "No se pudo enviar alerta por email"
}

# Monitoreo continuo
monitoreo_continuo() {
    local json_output="$1"
    
    log "Iniciando monitoreo continuo (Ctrl+C para detener)..."
    
    while true; do
        realizar_monitoreo "$json_output"
        echo ""
        sleep 30
    done
}

# Función principal
main() {
    local modo="una-vez"
    local json_output="false"
    ALERT_EMAIL=""
    
    # Crear directorio de logs
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --continuo)
                modo="continuo"
                shift
                ;;
            --una-vez)
                modo="una-vez"
                shift
                ;;
            --json)
                json_output="true"
                shift
                ;;
            --alerta-email)
                ALERT_EMAIL="$2"
                shift 2
                ;;
            -h|--ayuda)
                mostrar_ayuda
                exit 0
                ;;
            *)
                error "Opción desconocida: $1"
                mostrar_ayuda
                exit 1
                ;;
        esac
    done
    
    case "$modo" in
        "una-vez")
            realizar_monitoreo "$json_output"
            ;;
        "continuo")
            monitoreo_continuo "$json_output"
            ;;
    esac
}

# Manejo de señales
trap 'log "Monitoreo detenido"; exit 0' INT TERM

# Ejecutar
main "$@"
