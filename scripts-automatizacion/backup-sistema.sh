#!/bin/bash

# Script de Backup Automatizado - SIS313
# Universidad San Francisco Xavier de Chuquisaca
# Proyecto Final - Infraestructura de Aplicaciones Web

set -euo pipefail

# Configuración
BACKUP_DIR="/opt/backups"
DB_HOST="192.168.218.102"
DB_USER="usuario_bd"
DB_PASS="clave_bd_segura_123"
DB_NAME="sistema_clientes"
RETENTION_DAYS=7
LOG_FILE="/var/log/backup-sistema.log"

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

# Crear directorio de backup si no existe
mkdir -p "$BACKUP_DIR"/{database,config,logs,app}

# Fecha actual
FECHA=$(date +"%Y%m%d_%H%M%S")

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}     BACKUP AUTOMATIZADO SIS313         ${NC}"
echo -e "${BLUE}===========================================${NC}"

log_mensaje "Iniciando proceso de backup completo"

# 1. BACKUP DE BASE DE DATOS
echo -e "\n${YELLOW}🗄️  BACKUP DE BASE DE DATOS${NC}"
echo "----------------------------------------"

DB_BACKUP_FILE="$BACKUP_DIR/database/backup_bd_${FECHA}.sql"
DB_BACKUP_COMPRESSED="$BACKUP_DIR/database/backup_bd_${FECHA}.sql.gz"

log_mensaje "Iniciando backup de base de datos MySQL"

if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --add-drop-table \
    --add-locks \
    --create-options \
    --disable-keys \
    --extended-insert \
    --quick \
    --set-charset \
    "$DB_NAME" > "$DB_BACKUP_FILE"; then
    
    # Comprimir el backup
    if gzip "$DB_BACKUP_FILE"; then
        BACKUP_SIZE=$(du -h "$DB_BACKUP_COMPRESSED" | cut -f1)
        echo -e "✅ Base de datos: ${GREEN}BACKUP EXITOSO${NC} (${BACKUP_SIZE})"
        log_mensaje "Backup de BD completado: $DB_BACKUP_COMPRESSED ($BACKUP_SIZE)"
    else
        echo -e "❌ Error al comprimir backup de BD: ${RED}FALLO${NC}"
        log_mensaje "Error al comprimir backup de base de datos"
    fi
else
    echo -e "❌ Backup de base de datos: ${RED}FALLO${NC}"
    log_mensaje "Error en backup de base de datos"
fi

# 2. BACKUP DE CONFIGURACIONES
echo -e "\n${YELLOW}⚙️  BACKUP DE CONFIGURACIONES${NC}"
echo "----------------------------------------"

CONFIG_BACKUP_FILE="$BACKUP_DIR/config/config_${FECHA}.tar.gz"

log_mensaje "Iniciando backup de configuraciones"

# Archivos y directorios de configuración a respaldar
CONFIG_DIRS=(
    "/etc/nginx"
    "/etc/mysql"
    "/etc/systemd/system"
    "/opt/aplicacion-nodejs"
    "/var/www/html"
)

CONFIG_FILES=(
    "/etc/hosts"
    "/etc/netplan/*.yaml"
    "/etc/fstab"
    "/etc/crontab"
)

# Crear lista de archivos para backup
TEMP_LIST="/tmp/config_backup_list_${FECHA}.txt"
> "$TEMP_LIST"

# Agregar directorios que existen
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "$dir" >> "$TEMP_LIST"
    fi
done

# Agregar archivos que existen
for file_pattern in "${CONFIG_FILES[@]}"; do
    for file in $file_pattern; do
        if [ -f "$file" ]; then
            echo "$file" >> "$TEMP_LIST"
        fi
    done
done

if [ -s "$TEMP_LIST" ]; then
    if tar -czf "$CONFIG_BACKUP_FILE" -T "$TEMP_LIST" 2>/dev/null; then
        CONFIG_SIZE=$(du -h "$CONFIG_BACKUP_FILE" | cut -f1)
        echo -e "✅ Configuraciones: ${GREEN}BACKUP EXITOSO${NC} (${CONFIG_SIZE})"
        log_mensaje "Backup de configuraciones completado: $CONFIG_BACKUP_FILE ($CONFIG_SIZE)"
    else
        echo -e "❌ Backup de configuraciones: ${RED}FALLO${NC}"
        log_mensaje "Error en backup de configuraciones"
    fi
else
    echo -e "⚠️  No se encontraron archivos de configuración para respaldar"
    log_mensaje "No se encontraron archivos de configuración"
fi

rm -f "$TEMP_LIST"

# 3. BACKUP DE LOGS
echo -e "\n${YELLOW}📄 BACKUP DE LOGS${NC}"
echo "----------------------------------------"

LOGS_BACKUP_FILE="$BACKUP_DIR/logs/logs_${FECHA}.tar.gz"

log_mensaje "Iniciando backup de logs"

LOG_DIRS=(
    "/var/log/nginx"
    "/var/log/mysql"
    "/var/log/aplicacion-nodejs"
    "/var/log/syslog*"
    "/var/log/auth.log*"
)

TEMP_LOG_LIST="/tmp/logs_backup_list_${FECHA}.txt"
> "$TEMP_LOG_LIST"

# Agregar logs que existen
for log_pattern in "${LOG_DIRS[@]}"; do
    for log_path in $log_pattern; do
        if [ -e "$log_path" ]; then
            echo "$log_path" >> "$TEMP_LOG_LIST"
        fi
    done
done

if [ -s "$TEMP_LOG_LIST" ]; then
    if tar -czf "$LOGS_BACKUP_FILE" -T "$TEMP_LOG_LIST" 2>/dev/null; then
        LOGS_SIZE=$(du -h "$LOGS_BACKUP_FILE" | cut -f1)
        echo -e "✅ Logs del sistema: ${GREEN}BACKUP EXITOSO${NC} (${LOGS_SIZE})"
        log_mensaje "Backup de logs completado: $LOGS_BACKUP_FILE ($LOGS_SIZE)"
    else
        echo -e "❌ Backup de logs: ${RED}FALLO${NC}"
        log_mensaje "Error en backup de logs"
    fi
else
    echo -e "⚠️  No se encontraron logs para respaldar"
    log_mensaje "No se encontraron logs"
fi

rm -f "$TEMP_LOG_LIST"

# 4. BACKUP DE APLICACIÓN
echo -e "\n${YELLOW}💻 BACKUP DE APLICACIÓN${NC}"
echo "----------------------------------------"

APP_BACKUP_FILE="$BACKUP_DIR/app/app_${FECHA}.tar.gz"

log_mensaje "Iniciando backup de aplicación Node.js"

if [ -d "/opt/aplicacion-nodejs" ]; then
    if tar -czf "$APP_BACKUP_FILE" -C "/opt" "aplicacion-nodejs" --exclude="node_modules" --exclude="*.log"; then
        APP_SIZE=$(du -h "$APP_BACKUP_FILE" | cut -f1)
        echo -e "✅ Aplicación Node.js: ${GREEN}BACKUP EXITOSO${NC} (${APP_SIZE})"
        log_mensaje "Backup de aplicación completado: $APP_BACKUP_FILE ($APP_SIZE)"
    else
        echo -e "❌ Backup de aplicación: ${RED}FALLO${NC}"
        log_mensaje "Error en backup de aplicación"
    fi
else
    echo -e "⚠️  Directorio de aplicación no encontrado"
    log_mensaje "Directorio /opt/aplicacion-nodejs no encontrado"
fi

# 5. VERIFICAR INTEGRIDAD DE BACKUPS
echo -e "\n${YELLOW}🔍 VERIFICACIÓN DE INTEGRIDAD${NC}"
echo "----------------------------------------"

log_mensaje "Verificando integridad de backups"

BACKUP_FILES=(
    "$DB_BACKUP_COMPRESSED"
    "$CONFIG_BACKUP_FILE"
    "$LOGS_BACKUP_FILE"
    "$APP_BACKUP_FILE"
)

INTEGRITY_OK=true

for backup_file in "${BACKUP_FILES[@]}"; do
    if [ -f "$backup_file" ]; then
        if file "$backup_file" | grep -q "gzip"; then
            if gzip -t "$backup_file" 2>/dev/null; then
                echo -e "✅ $(basename "$backup_file"): ${GREEN}ÍNTEGRO${NC}"
            else
                echo -e "❌ $(basename "$backup_file"): ${RED}CORRUPTO${NC}"
                INTEGRITY_OK=false
                log_mensaje "Backup corrupto detectado: $backup_file"
            fi
        elif file "$backup_file" | grep -q "tar"; then
            if tar -tzf "$backup_file" >/dev/null 2>&1; then
                echo -e "✅ $(basename "$backup_file"): ${GREEN}ÍNTEGRO${NC}"
            else
                echo -e "❌ $(basename "$backup_file"): ${RED}CORRUPTO${NC}"
                INTEGRITY_OK=false
                log_mensaje "Backup corrupto detectado: $backup_file"
            fi
        fi
    fi
done

# 6. LIMPIEZA DE BACKUPS ANTIGUOS
echo -e "\n${YELLOW}🧹 LIMPIEZA DE BACKUPS ANTIGUOS${NC}"
echo "----------------------------------------"

log_mensaje "Eliminando backups antiguos (> $RETENTION_DAYS días)"

DELETED_COUNT=0

for backup_dir in "$BACKUP_DIR"/{database,config,logs,app}; do
    if [ -d "$backup_dir" ]; then
        while IFS= read -r -d '' file; do
            echo "  Eliminando: $(basename "$file")"
            rm -f "$file"
            ((DELETED_COUNT++))
        done < <(find "$backup_dir" -name "*.gz" -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    fi
done

if [ $DELETED_COUNT -gt 0 ]; then
    echo -e "✅ Eliminados $DELETED_COUNT backups antiguos"
    log_mensaje "Eliminados $DELETED_COUNT backups antiguos"
else
    echo -e "ℹ️  No hay backups antiguos para eliminar"
fi

# 7. RESUMEN FINAL
echo -e "\n${BLUE}===========================================${NC}"
echo -e "${BLUE}           RESUMEN DEL BACKUP            ${NC}"
echo -e "${BLUE}===========================================${NC}"

TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.gz" -type f | wc -l)

echo -e "📊 Backups creados: $(ls -1 "$BACKUP_DIR"/{database,config,logs,app}/*.gz 2>/dev/null | wc -l)"
echo -e "💾 Espacio total utilizado: $TOTAL_SIZE"
echo -e "📦 Total de archivos de backup: $BACKUP_COUNT"

if [ "$INTEGRITY_OK" = true ]; then
    echo -e "✅ ${GREEN}Todos los backups son íntegros${NC}"
    log_mensaje "Proceso de backup completado exitosamente"
else
    echo -e "⚠️  ${YELLOW}Algunos backups presentan problemas de integridad${NC}"
    log_mensaje "Proceso de backup completado con advertencias"
fi

# 8. CREAR ÍNDICE DE BACKUPS
INDEX_FILE="$BACKUP_DIR/indice_backups_${FECHA}.txt"
echo "# Índice de Backups - $(date)" > "$INDEX_FILE"
echo "# Generado automáticamente por script de backup SIS313" >> "$INDEX_FILE"
echo "" >> "$INDEX_FILE"

for backup_dir in "$BACKUP_DIR"/{database,config,logs,app}; do
    if [ -d "$backup_dir" ]; then
        echo "## $(basename "$backup_dir" | tr '[:lower:]' '[:upper:]')" >> "$INDEX_FILE"
        ls -lh "$backup_dir"/*.gz 2>/dev/null | awk '{print $9 " - " $5 " - " $6 " " $7 " " $8}' >> "$INDEX_FILE" || true
        echo "" >> "$INDEX_FILE"
    fi
done

echo -e "📝 Índice de backups: $INDEX_FILE"

# Programar siguiente backup (si está en crontab)
echo -e "\n⏰ Próximo backup programado: $(date -d '+1 day' '+%Y-%m-%d %H:%M:%S')"
echo -e "📁 Directorio de backups: $BACKUP_DIR"
echo -e "📋 Log de backups: $LOG_FILE"

log_mensaje "Script de backup finalizado"
