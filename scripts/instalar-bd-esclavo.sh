#!/bin/bash

# Script de Instalación para Servidor de Base de Datos MySQL Esclavo + RAID 1
# BD2: 192.168.218.104 (MySQL Esclavo + RAID 1)
# Universidad San Francisco Xavier de Chuquisaca - SIS313

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
SERVIDOR_IP="192.168.218.104"
HOSTNAME_SERVIDOR="bd2.sis313.usfx.bo"
DB_ROOT_PASSWORD="root_password_super_seguro_123"
DB_NAME="sistema_clientes"
DB_USER="usuario_bd"
DB_PASSWORD="clave_bd_segura_123"
MASTER_IP="192.168.218.102"
REPLICA_USER="replica_user"
REPLICA_PASSWORD="replica_password_123"

# Variables para RAID (se detectarán automáticamente)
RAID_DEVICE="/dev/md0"
RAID_MOUNT="/mnt/raid1"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

exito() {
    echo -e "${GREEN}[ÉXITO] $1${NC}"
}

advertencia() {
    echo -e "${YELLOW}[ADVERTENCIA] $1${NC}"
}

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}  INSTALACIÓN MYSQL ESCLAVO + RAID 1    ${NC}"
echo -e "${BLUE}  IP: $SERVIDOR_IP                      ${NC}"
echo -e "${BLUE}===========================================${NC}"

# 1. VERIFICAR USUARIO ROOT
if [ "$EUID" -ne 0 ]; then
    error "Este script debe ejecutarse como root o con sudo"
fi

# 2. ACTUALIZAR SISTEMA
log "Actualizando sistema operativo..."
apt update && apt upgrade -y
exito "Sistema actualizado"

# 3. INSTALAR HERRAMIENTAS NECESARIAS
log "Instalando herramientas para RAID..."
apt install -y mdadm parted gdisk
exito "Herramientas RAID instaladas"

# 4. DETECTAR DISCOS DISPONIBLES PARA RAID
log "Detectando discos disponibles para RAID..."
echo ""
echo "📦 DISCOS DETECTADOS:"
lsblk -d -o NAME,SIZE,TYPE | grep disk

# Buscar discos adicionales (excluyendo el disco del sistema)
AVAILABLE_DISKS=$(lsblk -dn -o NAME | grep -E '^(sd[b-z]|vd[b-z]|nvme[1-9])' | head -2)

if [ -z "$AVAILABLE_DISKS" ]; then
    advertencia "No se detectaron discos adicionales para RAID"
    echo "Para un entorno de producción, asegúrese de tener al menos 2 discos adicionales"
    echo "Continuando con instalación sin RAID..."
    SETUP_RAID=false
else
    echo ""
    echo "💿 DISCOS DISPONIBLES PARA RAID:"
    echo "$AVAILABLE_DISKS" | while read disk; do
        size=$(lsblk -dno SIZE /dev/$disk)
        echo "  /dev/$disk - $size"
    done
    
    echo ""
    read -p "¿Desea configurar RAID 1 con estos discos? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SETUP_RAID=true
        DISK1="/dev/$(echo "$AVAILABLE_DISKS" | head -1)"
        DISK2="/dev/$(echo "$AVAILABLE_DISKS" | tail -1)"
        
        if [ "$DISK1" = "$DISK2" ]; then
            advertencia "Solo se detectó un disco adicional. RAID 1 requiere al menos 2 discos."
            SETUP_RAID=false
        fi
    else
        SETUP_RAID=false
    fi
fi

# 5. CONFIGURAR RAID 1 (si se solicitó)
if [ "$SETUP_RAID" = true ]; then
    log "Configurando RAID 1 con $DISK1 y $DISK2..."
    
    # Advertencia sobre destrucción de datos
    echo -e "${RED}⚠️  ADVERTENCIA: Esto destruirá todos los datos en $DISK1 y $DISK2${NC}"
    read -p "¿Está seguro de continuar? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Operación cancelada por el usuario"
    fi
    
    # Limpiar discos
    wipefs -a "$DISK1" "$DISK2"
    
    # Crear particiones para RAID
    parted "$DISK1" --script mklabel gpt
    parted "$DISK1" --script mkpart primary 0% 100%
    parted "$DISK1" --script set 1 raid on
    
    parted "$DISK2" --script mklabel gpt  
    parted "$DISK2" --script mkpart primary 0% 100%
    parted "$DISK2" --script set 1 raid on
    
    # Crear RAID 1
    mdadm --create --verbose "$RAID_DEVICE" --level=1 --raid-devices=2 "${DISK1}1" "${DISK2}1"
    
    # Esperar que el RAID se sincronice (parcialmente)
    echo "Esperando sincronización inicial del RAID..."
    sleep 10
    
    # Crear sistema de archivos
    mkfs.ext4 "$RAID_DEVICE"
    
    # Crear punto de montaje
    mkdir -p "$RAID_MOUNT"
    
    # Montar RAID
    mount "$RAID_DEVICE" "$RAID_MOUNT"
    
    # Configurar montaje automático
    UUID=$(blkid -s UUID -o value "$RAID_DEVICE")
    echo "UUID=$UUID $RAID_MOUNT ext4 defaults,nofail,discard 0 0" >> /etc/fstab
    
    # Guardar configuración de RAID
    mdadm --detail --scan >> /etc/mdadm/mdadm.conf
    update-initramfs -u
    
    exito "RAID 1 configurado correctamente"
    
    # Mostrar estado del RAID
    echo ""
    echo "📊 ESTADO DEL RAID:"
    cat /proc/mdstat
    
    # Configurar directorio para MySQL en RAID
    MYSQL_DATA_DIR="$RAID_MOUNT/mysql"
    mkdir -p "$MYSQL_DATA_DIR"
    
else
    log "Continuando sin RAID..."
    MYSQL_DATA_DIR="/var/lib/mysql"
fi

# 6. CONFIGURAR HOSTNAME Y HOSTS
log "Configurando hostname y archivo hosts..."
hostnamectl set-hostname bd2-sis313

cat > /etc/hosts << 'EOF'
127.0.0.1 localhost
127.0.1.1 bd2-sis313

# Servidores del Proyecto SIS313
192.168.218.100 proxy.sis313.usfx.bo proxy-sis313
192.168.218.101 app1.sis313.usfx.bo app1-sis313
192.168.218.102 bd1.sis313.usfx.bo bd1-sis313
192.168.218.103 app2.sis313.usfx.bo app2-sis313
192.168.218.104 bd2.sis313.usfx.bo bd2-sis313
EOF

exito "Hostname y hosts configurados"

# 7. CONFIGURAR RED CON NETPLAN
log "Configurando interfaz de red con netplan..."
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true  # NAT para Internet
    ens37:         # Red del proyecto (bridged)
      dhcp4: false
      addresses: [$SERVIDOR_IP/24]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: 192.168.218.0/24
          via: 192.168.218.1
EOF

netplan apply
exito "Red configurada"

# 8. CONFIGURAR FIREWALL
log "Configurando firewall UFW..."
ufw --force enable
ufw allow OpenSSH
ufw allow 3306/tcp
ufw allow from 192.168.218.0/24
exito "Firewall configurado"

# 9. INSTALAR MYSQL SERVER
log "Instalando MySQL Server..."

export DEBIAN_FRONTEND=noninteractive
echo "mysql-server mysql-server/root_password password $DB_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DB_ROOT_PASSWORD" | debconf-set-selections

apt install -y mysql-server mysql-client

# Detener MySQL para mover datos si se usa RAID
systemctl stop mysql

# 10. MOVER MYSQL A RAID (si está configurado)
if [ "$SETUP_RAID" = true ]; then
    log "Moviendo MySQL al RAID..."
    
    # Copiar datos de MySQL al RAID
    rsync -av /var/lib/mysql/ "$MYSQL_DATA_DIR/"
    
    # Hacer backup de la configuración original
    mv /var/lib/mysql /var/lib/mysql.bak
    
    # Crear enlace simbólico
    ln -s "$MYSQL_DATA_DIR" /var/lib/mysql
    
    # Configurar permisos
    chown -R mysql:mysql "$MYSQL_DATA_DIR"
    chown -h mysql:mysql /var/lib/mysql
    
    exito "MySQL movido al RAID"
fi

# 11. CONFIGURAR MYSQL COMO ESCLAVO
log "Configurando MySQL como esclavo..."

cat > /etc/mysql/mysql.conf.d/esclavo.cnf << 'EOF'
[mysqld]
# Configuración de Replicación - Servidor Esclavo
server-id = 2
relay_log = /var/log/mysql/mysql-relay-bin.log
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = sistema_clientes
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 100M

# Configuración específica de esclavo
read_only = 1
relay_log_recovery = 1
slave_skip_errors = 1062

# Configuración de red
bind-address = 0.0.0.0

# Configuración de performance
innodb_buffer_pool_size = 256M
query_cache_type = 1
query_cache_size = 64M
query_cache_limit = 2M

# Configuración de logs
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2

# Configuración de conexiones
max_connections = 200
connect_timeout = 10
wait_timeout = 600
max_allowed_packet = 64M
thread_cache_size = 128
sort_buffer_size = 4M
bulk_insert_buffer_size = 16M
tmp_table_size = 32M
max_heap_table_size = 32M
EOF

# 12. INICIAR MYSQL Y CONFIGURAR REPLICACIÓN
log "Iniciando MySQL y configurando replicación..."

systemctl enable mysql
systemctl start mysql

# Esperar a que MySQL esté completamente iniciado
sleep 10

if ! systemctl is-active --quiet mysql; then
    error "MySQL no pudo iniciarse"
fi

# Configurar seguridad básica
mysql -u root -p"$DB_ROOT_PASSWORD" << 'EOF'
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;
EOF

# 13. SOLICITAR INFORMACIÓN DE REPLICACIÓN
echo -e "\n${YELLOW}🔗 CONFIGURACIÓN DE REPLICACIÓN${NC}"
echo "Para configurar la replicación, necesitamos la información del servidor maestro."
echo ""

# Intentar obtener información automáticamente del maestro
log "Intentando conectar al maestro para obtener información de replicación..."

MASTER_LOG_FILE=""
MASTER_LOG_POS=""

if mysql -h "$MASTER_IP" -u "$REPLICA_USER" -p"$REPLICA_PASSWORD" -e "SELECT 1;" &>/dev/null; then
    log "Conexión al maestro exitosa, obteniendo información de replicación..."
    
    MASTER_STATUS=$(mysql -h "$MASTER_IP" -u "$REPLICA_USER" -p"$REPLICA_PASSWORD" -e "SHOW MASTER STATUS;" 2>/dev/null)
    
    if [ -n "$MASTER_STATUS" ]; then
        MASTER_LOG_FILE=$(echo "$MASTER_STATUS" | awk 'NR==2 {print $1}')
        MASTER_LOG_POS=$(echo "$MASTER_STATUS" | awk 'NR==2 {print $2}')
        
        echo -e "✅ Información obtenida automáticamente:"
        echo -e "   📄 Archivo: $MASTER_LOG_FILE"
        echo -e "   📍 Posición: $MASTER_LOG_POS"
    fi
else
    advertencia "No se pudo conectar automáticamente al maestro"
fi

# Si no se pudo obtener automáticamente, solicitar manualmente
if [ -z "$MASTER_LOG_FILE" ] || [ -z "$MASTER_LOG_POS" ]; then
    echo ""
    echo "📋 Ejecute en el servidor maestro (BD1):"
    echo "   mysql -u root -p -e \"SHOW MASTER STATUS;\""
    echo ""
    read -p "Ingrese el archivo de log (ej: mysql-bin.000001): " MASTER_LOG_FILE
    read -p "Ingrese la posición (ej: 12345): " MASTER_LOG_POS
fi

# Configurar replicación en el esclavo
log "Configurando replicación en el esclavo..."

mysql -u root -p"$DB_ROOT_PASSWORD" << EOF
-- Detener replicación si está activa
STOP SLAVE;

-- Configurar maestro
CHANGE MASTER TO
    MASTER_HOST='$MASTER_IP',
    MASTER_USER='$REPLICA_USER',
    MASTER_PASSWORD='$REPLICA_PASSWORD',
    MASTER_LOG_FILE='$MASTER_LOG_FILE',
    MASTER_LOG_POS=$MASTER_LOG_POS;

-- Iniciar replicación
START SLAVE;

-- Mostrar estado
SHOW SLAVE STATUS\G
EOF

# Verificar estado de replicación
sleep 5
SLAVE_STATUS=$(mysql -u root -p"$DB_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" 2>/dev/null)

IO_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_IO_Running:" | awk '{print $2}')
SQL_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_SQL_Running:" | awk '{print $2}')

if [ "$IO_RUNNING" = "Yes" ] && [ "$SQL_RUNNING" = "Yes" ]; then
    exito "Replicación configurada correctamente"
else
    advertencia "Problemas con la replicación - Verificar configuración"
    echo "IO Running: $IO_RUNNING"
    echo "SQL Running: $SQL_RUNNING"
fi

# 14. CREAR SCRIPTS DE ADMINISTRACIÓN
log "Creando scripts de administración..."

# Script de verificación de RAID
cat > /usr/local/bin/verificar-raid.sh << 'EOF'
#!/bin/bash

echo "======================================"
echo "  VERIFICACIÓN RAID 1"
echo "======================================"

if [ -f /proc/mdstat ]; then
    echo "📊 ESTADO DEL RAID:"
    cat /proc/mdstat
    echo ""
    
    # Verificar dispositivos RAID
    if [ -b /dev/md0 ]; then
        echo "🔍 DETALLES DEL RAID:"
        mdadm --detail /dev/md0
        echo ""
        
        # Verificar montaje
        if mount | grep -q "/dev/md0"; then
            echo "✅ RAID montado correctamente"
            df -h /dev/md0
        else
            echo "❌ RAID no está montado"
        fi
    else
        echo "❌ No se encontró dispositivo RAID /dev/md0"
    fi
else
    echo "ℹ️  No hay dispositivos RAID configurados"
fi

echo ""
echo "📦 TODOS LOS DISPOSITIVOS DE BLOQUE:"
lsblk
EOF

chmod +x /usr/local/bin/verificar-raid.sh

# Script de verificación de esclavo
cat > /usr/local/bin/verificar-esclavo.sh << EOF
#!/bin/bash

echo "======================================"
echo "  VERIFICACIÓN MYSQL ESCLAVO"
echo "======================================"

# Verificar servicio MySQL
if systemctl is-active --quiet mysql; then
    echo "✅ Servicio MySQL: ACTIVO"
else
    echo "❌ Servicio MySQL: INACTIVO"
    exit 1
fi

# Verificar puerto
if netstat -tuln | grep -q ":3306"; then
    echo "✅ Puerto 3306: ESCUCHANDO"
else
    echo "❌ Puerto 3306: NO DISPONIBLE"
fi

# Verificar replicación
echo ""
echo "🔄 ESTADO DE REPLICACIÓN:"
mysql -u root -p'$DB_ROOT_PASSWORD' -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Master_Host|Seconds_Behind_Master)"

# Verificar conexión al maestro
echo ""
echo "🔗 CONECTIVIDAD AL MAESTRO:"
if timeout 5 bash -c "</dev/tcp/$MASTER_IP/3306" 2>/dev/null; then
    echo "✅ Maestro ($MASTER_IP): ALCANZABLE"
else
    echo "❌ Maestro ($MASTER_IP): NO ALCANZABLE"
fi

# Verificar datos replicados
echo ""
echo "📋 DATOS REPLICADOS:"
mysql -u root -p'$DB_ROOT_PASSWORD' -e "SELECT COUNT(*) as total_clientes FROM $DB_NAME.clientes;" 2>/dev/null

echo ""
echo "🔗 Comandos útiles:"
echo "- Ver estado completo: mysql -u root -p -e 'SHOW SLAVE STATUS\\G'"
echo "- Reiniciar replicación: mysql -u root -p -e 'STOP SLAVE; START SLAVE;'"
EOF

chmod +x /usr/local/bin/verificar-esclavo.sh

# Script de backup del esclavo
cat > /usr/local/bin/backup-bd-esclavo.sh << EOF
#!/bin/bash

BACKUP_DIR="/opt/backups/mysql"
mkdir -p "\$BACKUP_DIR"

FECHA=\$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="\$BACKUP_DIR/backup_esclavo_\$FECHA.sql"

echo "Iniciando backup de BD Esclavo..."

mysqldump -u root -p"$DB_ROOT_PASSWORD" \\
    --single-transaction \\
    --routines \\
    --triggers \\
    --events \\
    "$DB_NAME" > "\$BACKUP_FILE"

if [ \$? -eq 0 ]; then
    gzip "\$BACKUP_FILE"
    echo "✅ Backup completado: \$BACKUP_FILE.gz"
    find "\$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
else
    echo "❌ Error en backup"
    exit 1
fi
EOF

chmod +x /usr/local/bin/backup-bd-esclavo.sh

# Script de monitoreo de RAID
if [ "$SETUP_RAID" = true ]; then
    cat > /usr/local/bin/monitorear-raid.sh << 'EOF'
#!/bin/bash

echo "Monitoreo RAID 1 - Presiona Ctrl+C para salir"
echo "=============================================="

while true; do
    clear
    echo "$(date) - Estado RAID 1 (BD2)"
    echo "=============================="
    
    if [ -f /proc/mdstat ]; then
        cat /proc/mdstat
        echo ""
        
        # Estado de sincronización
        if grep -q "recovery" /proc/mdstat; then
            echo "🔄 RAID en proceso de sincronización"
        elif grep -q "resync" /proc/mdstat; then
            echo "🔄 RAID en proceso de resincronización"
        else
            echo "✅ RAID sincronizado"
        fi
        
        # Espacio disponible
        if mount | grep -q "/dev/md0"; then
            echo ""
            echo "💾 ESPACIO EN RAID:"
            df -h /dev/md0
        fi
    else
        echo "❌ No hay dispositivos RAID activos"
    fi
    
    echo ""
    echo "Próxima actualización en 10 segundos..."
    sleep 10
done
EOF

    chmod +x /usr/local/bin/monitorear-raid.sh
fi

exito "Scripts de administración creados"

# 15. CONFIGURAR MONITOREO AUTOMÁTICO
log "Configurando monitoreo automático..."

# Crear script de alerta para fallos de RAID
if [ "$SETUP_RAID" = true ]; then
    cat > /usr/local/bin/alerta-raid.sh << 'EOF'
#!/bin/bash

# Script de alerta para fallos de RAID
EMAIL="admin@sis313.usfx.bo"

if [ -f /proc/mdstat ]; then
    if grep -q "_" /proc/mdstat; then
        echo "⚠️  ALERTA: Disco dañado detectado en RAID"
        echo "Estado actual:"
        cat /proc/mdstat
        
        # Enviar email si está configurado
        if command -v mail &> /dev/null; then
            echo "RAID degradado en BD2 - $(date)" | mail -s "ALERTA RAID SIS313" "$EMAIL"
        fi
        
        # Log del evento
        echo "[$(date)] RAID degradado detectado" >> /var/log/raid-alerts.log
    fi
fi
EOF

    chmod +x /usr/local/bin/alerta-raid.sh
    
    # Configurar cron para verificar RAID cada 10 minutos
    (crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/alerta-raid.sh") | crontab -
fi

# Backup automático diario
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/backup-bd-esclavo.sh >> /var/log/backup-mysql.log 2>&1") | crontab -

exito "Monitoreo automático configurado"

# 16. MOSTRAR RESUMEN
echo -e "\n${GREEN}===========================================${NC}"
echo -e "${GREEN}     INSTALACIÓN COMPLETADA              ${NC}"
echo -e "${GREEN}===========================================${NC}"

echo -e "\n📊 INFORMACIÓN DEL SERVIDOR:"
echo -e "🖥️  Hostname: $(hostname)"
echo -e "🌐 IP: $SERVIDOR_IP"
echo -e "🗄️ Base de datos: $DB_NAME (ESCLAVO)"
echo -e "🔗 Maestro: $MASTER_IP"

if [ "$SETUP_RAID" = true ]; then
echo -e "💿 RAID 1: CONFIGURADO"
echo -e "📂 MySQL en RAID: $MYSQL_DATA_DIR"
fi

echo -e "⚡ Servicios activos:"
systemctl is-active mysql && echo "  ✅ MySQL Server"

echo -e "\n🔐 CREDENCIALES:"
echo -e "  Root: root / $DB_ROOT_PASSWORD"
echo -e "  App User: $DB_USER / $DB_PASSWORD"

echo -e "\n📋 Comandos útiles:"
echo -e "  Verificar esclavo: /usr/local/bin/verificar-esclavo.sh"
echo -e "  Verificar RAID: /usr/local/bin/verificar-raid.sh"
echo -e "  Backup manual: /usr/local/bin/backup-bd-esclavo.sh"
if [ "$SETUP_RAID" = true ]; then
echo -e "  Monitorear RAID: /usr/local/bin/monitorear-raid.sh"
fi

echo -e "\n🔄 ESTADO DE REPLICACIÓN:"
mysql -u root -p"$DB_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running)" | while read line; do
    if [[ $line == *"Yes"* ]]; then
        echo -e "  ✅ $line"
    else
        echo -e "  ❌ $line"
    fi
done

if [ "$SETUP_RAID" = true ]; then
echo -e "\n💿 ESTADO DEL RAID:"
cat /proc/mdstat | head -5
fi

echo -e "\n${BLUE}MySQL Esclavo con RAID 1 configurado exitosamente!${NC}"

# 17. EJECUTAR VERIFICACIONES INICIALES
log "Ejecutando verificaciones iniciales..."
sleep 3

echo -e "\n${YELLOW}=== VERIFICACIÓN MYSQL ESCLAVO ===${NC}"
/usr/local/bin/verificar-esclavo.sh

if [ "$SETUP_RAID" = true ]; then
    echo -e "\n${YELLOW}=== VERIFICACIÓN RAID 1 ===${NC}"
    /usr/local/bin/verificar-raid.sh
fi

echo -e "\n${GREEN}¡Instalación completada exitosamente!${NC}"
echo -e "${YELLOW}El servidor esclavo con RAID 1 está listo para uso.${NC}"
