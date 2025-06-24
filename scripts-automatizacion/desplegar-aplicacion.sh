#!/bin/bash

# Script de Despliegue Automatizado - SIS313
# Universidad San Francisco Xavier de Chuquisaca
# Proyecto Final - Infraestructura de Aplicaciones Web

set -euo pipefail

# Configuración
REPO_URL="https://github.com/usuario/proyecto-final-sis313.git"
APP_DIR="/opt/aplicacion-nodejs"
BACKUP_DIR="/opt/backups/deployments"
LOG_FILE="/var/log/deployment.log"
NODE_ENV="production"

# Servidores de aplicación
SERVERS=("192.168.218.101" "192.168.218.103")
SSH_USER="deploy"
SSH_KEY="/home/deploy/.ssh/id_rsa"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función de logging
log_mensaje() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para ejecutar comandos remotos
ejecutar_remoto() {
    local servidor=$1
    local comando=$2
    
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$servidor" "$comando"
}

# Función para verificar prerrequisitos
verificar_prerrequisitos() {
    echo -e "${YELLOW}🔍 VERIFICANDO PRERREQUISITOS${NC}"
    echo "----------------------------------------"
    
    # Verificar git
    if ! command -v git &> /dev/null; then
        echo -e "❌ Git no está instalado"
        exit 1
    fi
    
    # Verificar Node.js
    if ! command -v node &> /dev/null; then
        echo -e "❌ Node.js no está instalado"
        exit 1
    fi
    
    # Verificar npm
    if ! command -v npm &> /dev/null; then
        echo -e "❌ npm no está instalado"
        exit 1
    fi
    
    # Verificar conectividad a servidores
    for servidor in "${SERVERS[@]}"; do
        if ! ping -c 1 "$servidor" &>/dev/null; then
            echo -e "❌ No se puede conectar a $servidor"
            exit 1
        fi
    done
    
    echo -e "✅ Todos los prerrequisitos verificados"
}

# Función para crear backup antes del despliegue
crear_backup_pre_deploy() {
    echo -e "\n${YELLOW}💾 CREANDO BACKUP PRE-DESPLIEGUE${NC}"
    echo "----------------------------------------"
    
    local fecha=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "$BACKUP_DIR"
    
    if [ -d "$APP_DIR" ]; then
        local backup_file="$BACKUP_DIR/pre_deploy_${fecha}.tar.gz"
        if tar -czf "$backup_file" -C "$(dirname "$APP_DIR")" "$(basename "$APP_DIR")"; then
            echo -e "✅ Backup creado: $backup_file"
            log_mensaje "Backup pre-despliegue creado: $backup_file"
        else
            echo -e "❌ Error creando backup"
            exit 1
        fi
    else
        echo -e "ℹ️  No existe instalación previa para respaldar"
    fi
}

# Función para descargar código
descargar_codigo() {
    echo -e "\n${YELLOW}📥 DESCARGANDO CÓDIGO FUENTE${NC}"
    echo "----------------------------------------"
    
    local temp_dir="/tmp/deploy_$(date +%s)"
    
    if git clone "$REPO_URL" "$temp_dir"; then
        echo -e "✅ Código descargado exitosamente"
        
        # Mover código a directorio de aplicación
        mkdir -p "$APP_DIR"
        cp -r "$temp_dir"/* "$APP_DIR/"
        rm -rf "$temp_dir"
        
        log_mensaje "Código fuente actualizado desde repositorio"
    else
        echo -e "❌ Error descargando código"
        exit 1
    fi
}

# Función para instalar dependencias
instalar_dependencias() {
    echo -e "\n${YELLOW}📦 INSTALANDO DEPENDENCIAS${NC}"
    echo "----------------------------------------"
    
    cd "$APP_DIR"
    
    if [ -f "package.json" ]; then
        # Limpiar node_modules si existe
        if [ -d "node_modules" ]; then
            rm -rf node_modules
        fi
        
        # Instalar dependencias
        if npm ci --only=production; then
            echo -e "✅ Dependencias instaladas correctamente"
            log_mensaje "Dependencias Node.js instaladas"
        else
            echo -e "❌ Error instalando dependencias"
            exit 1
        fi
    else
        echo -e "❌ No se encontró package.json"
        exit 1
    fi
}

# Función para ejecutar tests
ejecutar_tests() {
    echo -e "\n${YELLOW}🧪 EJECUTANDO TESTS${NC}"
    echo "----------------------------------------"
    
    cd "$APP_DIR"
    
    if npm run test --if-present; then
        echo -e "✅ Tests ejecutados correctamente"
        log_mensaje "Tests pasaron exitosamente"
    else
        echo -e "⚠️  Tests fallaron o no están configurados"
        log_mensaje "Tests fallaron - continuando despliegue"
    fi
}

# Función para configurar variables de entorno
configurar_ambiente() {
    echo -e "\n${YELLOW}⚙️  CONFIGURANDO AMBIENTE${NC}"
    echo "----------------------------------------"
    
    cd "$APP_DIR"
    
    # Crear archivo .env si no existe
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# Configuración de Producción SIS313
NODE_ENV=production
PORT=3000
SERVER_NAME=\$(hostname)

# Base de Datos
DB_HOST=192.168.218.102
DB_USER=usuario_bd
DB_PASS=clave_bd_segura_123
DB_NAME=sistema_clientes

# Configuración de Logs
LOG_LEVEL=info
LOG_FILE=/var/log/aplicacion-nodejs/app.log

# Configuración de Seguridad
SESSION_SECRET=clave_sesion_super_secreta_2024
JWT_SECRET=jwt_token_secreto_sis313

# Configuración de Email (opcional)
SMTP_HOST=smtp.usfx.bo
SMTP_PORT=587
SMTP_USER=noreply@sis313.usfx.bo
SMTP_PASS=password_email
EOF
        echo -e "✅ Archivo .env creado"
    else
        echo -e "ℹ️  Archivo .env ya existe"
    fi
    
    # Configurar permisos
    chown -R nodejs:nodejs "$APP_DIR"
    chmod 640 .env
    
    log_mensaje "Ambiente de producción configurado"
}

# Función para reiniciar servicios
reiniciar_servicios() {
    echo -e "\n${YELLOW}🔄 REINICIANDO SERVICIOS${NC}"
    echo "----------------------------------------"
    
    # Reiniciar aplicación Node.js
    if systemctl is-active --quiet aplicacion-nodejs; then
        if systemctl restart aplicacion-nodejs; then
            echo -e "✅ Servicio aplicacion-nodejs reiniciado"
        else
            echo -e "❌ Error reiniciando aplicacion-nodejs"
            exit 1
        fi
    else
        if systemctl start aplicacion-nodejs; then
            echo -e "✅ Servicio aplicacion-nodejs iniciado"
        else
            echo -e "❌ Error iniciando aplicacion-nodejs"
            exit 1
        fi
    fi
    
    # Esperar que el servicio esté completamente levantado
    sleep 5
    
    # Verificar que el servicio responde
    if curl -s -f "http://localhost:3000/health" > /dev/null; then
        echo -e "✅ Aplicación responde correctamente"
        log_mensaje "Aplicación desplegada y funcionando"
    else
        echo -e "❌ Aplicación no responde"
        log_mensaje "Error: Aplicación no responde después del despliegue"
        exit 1
    fi
}

# Función para verificar despliegue
verificar_despliegue() {
    echo -e "\n${YELLOW}✅ VERIFICANDO DESPLIEGUE${NC}"
    echo "----------------------------------------"
    
    local errores=0
    
    # Verificar servicio systemd
    if systemctl is-active --quiet aplicacion-nodejs; then
        echo -e "✅ Servicio systemd: ACTIVO"
    else
        echo -e "❌ Servicio systemd: INACTIVO"
        ((errores++))
    fi
    
    # Verificar puerto de aplicación
    if netstat -tuln | grep -q ":3000 "; then
        echo -e "✅ Puerto 3000: ESCUCHANDO"
    else
        echo -e "❌ Puerto 3000: NO DISPONIBLE"
        ((errores++))
    fi
    
    # Verificar endpoint de salud
    if curl -s -f "http://localhost:3000/health" > /dev/null; then
        echo -e "✅ Health check: EXITOSO"
    else
        echo -e "❌ Health check: FALLO"
        ((errores++))
    fi
    
    # Verificar logs de aplicación
    if journalctl -u aplicacion-nodejs --since "1 minute ago" --no-pager | grep -q "Servidor iniciado"; then
        echo -e "✅ Logs de aplicación: CORRECTOS"
    else
        echo -e "⚠️  Logs de aplicación: REVISAR"
    fi
    
    # Verificar conexión a base de datos
    if timeout 5 bash -c "</dev/tcp/192.168.218.102/3306" 2>/dev/null; then
        echo -e "✅ Conexión a BD: EXITOSA"
    else
        echo -e "❌ Conexión a BD: FALLO"
        ((errores++))
    fi
    
    return $errores
}

# Función para despliegue en cluster
desplegar_cluster() {
    echo -e "\n${YELLOW}🌐 DESPLEGANDO EN CLUSTER${NC}"
    echo "----------------------------------------"
    
    for servidor in "${SERVERS[@]}"; do
        echo -e "\n🖥️  Desplegando en servidor: $servidor"
        
        # Sincronizar código
        if rsync -avz --delete "$APP_DIR/" "$SSH_USER@$servidor:$APP_DIR/"; then
            echo -e "  ✅ Código sincronizado"
        else
            echo -e "  ❌ Error sincronizando código"
            continue
        fi
        
        # Instalar dependencias remotamente
        if ejecutar_remoto "$servidor" "cd $APP_DIR && npm ci --only=production"; then
            echo -e "  ✅ Dependencias instaladas"
        else
            echo -e "  ❌ Error instalando dependencias"
            continue
        fi
        
        # Reiniciar servicio remoto
        if ejecutar_remoto "$servidor" "sudo systemctl restart aplicacion-nodejs"; then
            echo -e "  ✅ Servicio reiniciado"
        else
            echo -e "  ❌ Error reiniciando servicio"
            continue
        fi
        
        # Verificar servicio remoto
        sleep 3
        if ejecutar_remoto "$servidor" "curl -s -f http://localhost:3000/health"; then
            echo -e "  ✅ Verificación exitosa"
            log_mensaje "Despliegue exitoso en servidor $servidor"
        else
            echo -e "  ❌ Verificación falló"
            log_mensaje "Error en despliegue en servidor $servidor"
        fi
    done
}

# Función para rollback
rollback() {
    echo -e "\n${RED}🔄 EJECUTANDO ROLLBACK${NC}"
    echo "----------------------------------------"
    
    local ultimo_backup=$(ls -t "$BACKUP_DIR"/pre_deploy_*.tar.gz 2>/dev/null | head -1)
    
    if [ -n "$ultimo_backup" ]; then
        echo -e "📦 Restaurando desde: $ultimo_backup"
        
        # Detener servicio
        systemctl stop aplicacion-nodejs
        
        # Restaurar backup
        rm -rf "$APP_DIR"
        tar -xzf "$ultimo_backup" -C "$(dirname "$APP_DIR")"
        
        # Reiniciar servicio
        systemctl start aplicacion-nodejs
        
        if systemctl is-active --quiet aplicacion-nodejs; then
            echo -e "✅ Rollback completado exitosamente"
            log_mensaje "Rollback ejecutado exitosamente"
        else
            echo -e "❌ Error en rollback"
            log_mensaje "Error ejecutando rollback"
        fi
    else
        echo -e "❌ No se encontraron backups para rollback"
        log_mensaje "No hay backups disponibles para rollback"
    fi
}

# FUNCIÓN PRINCIPAL
main() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    DESPLIEGUE AUTOMATIZADO SIS313       ${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    log_mensaje "Iniciando proceso de despliegue"
    
    # Verificar si se solicita rollback
    if [ "${1:-}" = "rollback" ]; then
        rollback
        exit 0
    fi
    
    # Proceso normal de despliegue
    verificar_prerrequisitos
    crear_backup_pre_deploy
    descargar_codigo
    instalar_dependencias
    ejecutar_tests
    configurar_ambiente
    reiniciar_servicios
    
    if verificar_despliegue; then
        echo -e "\n🎉 ${GREEN}¡DESPLIEGUE COMPLETADO EXITOSAMENTE!${NC}"
        log_mensaje "Despliegue completado exitosamente"
        
        # Desplegar en otros servidores del cluster
        if [ "${1:-}" = "cluster" ]; then
            desplegar_cluster
        fi
    else
        echo -e "\n❌ ${RED}DESPLIEGUE FALLÓ - EJECUTANDO ROLLBACK${NC}"
        log_mensaje "Despliegue falló - ejecutando rollback automático"
        rollback
        exit 1
    fi
    
    echo -e "\n📊 RESUMEN DEL DESPLIEGUE"
    echo "----------------------------------------"
    echo -e "📅 Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "📂 Directorio: $APP_DIR"
    echo -e "🔗 Repositorio: $REPO_URL"
    echo -e "📋 Log: $LOG_FILE"
    echo -e "🔄 Para rollback: $0 rollback"
    echo -e "🌐 Para cluster: $0 cluster"
}

# Verificar si el script se ejecuta como root o con sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root o con sudo${NC}"
    exit 1
fi

# Ejecutar función principal
main "$@"
