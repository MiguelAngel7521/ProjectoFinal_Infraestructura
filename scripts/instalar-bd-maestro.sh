#!/bin/bash

# Script de Instalación para Servidor de Base de Datos MySQL Maestro
# BD1: 192.168.218.102 (MySQL Maestro)
# Universidad San Francisco Xavier de Chuquisaca - SIS313

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
SERVIDOR_IP="192.168.218.102"
HOSTNAME_SERVIDOR="bd1.sis313.usfx.bo"
DB_ROOT_PASSWORD="root_password_super_seguro_123"
DB_NAME="sistema_clientes"
DB_USER="usuario_bd"
DB_PASSWORD="clave_bd_segura_123"
REPLICA_USER="replica_user"
REPLICA_PASSWORD="replica_password_123"

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

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}   INSTALACIÓN MYSQL MAESTRO (BD1)      ${NC}"
echo -e "${BLUE}   IP: $SERVIDOR_IP                     ${NC}"
echo -e "${BLUE}===========================================${NC}"

# 1. VERIFICAR USUARIO ROOT
if [ "$EUID" -ne 0 ]; then
    error "Este script debe ejecutarse como root o con sudo"
fi

# 2. ACTUALIZAR SISTEMA
log "Actualizando sistema operativo..."
apt update && apt upgrade -y
exito "Sistema actualizado"

# 3. CONFIGURAR HOSTNAME Y HOSTS
log "Configurando hostname y archivo hosts..."
hostnamectl set-hostname bd1-sis313

cat > /etc/hosts << 'EOF'
127.0.0.1 localhost
127.0.1.1 bd1-sis313

# Servidores del Proyecto SIS313
192.168.218.100 proxy.sis313.usfx.bo proxy-sis313
192.168.218.101 app1.sis313.usfx.bo app1-sis313
192.168.218.102 bd1.sis313.usfx.bo bd1-sis313
192.168.218.103 app2.sis313.usfx.bo app2-sis313
192.168.218.104 bd2.sis313.usfx.bo bd2-sis313
EOF

exito "Hostname y hosts configurados"

# 4. CONFIGURAR RED CON NETPLAN
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

# 5. CONFIGURAR FIREWALL
log "Configurando firewall UFW..."
ufw --force enable
ufw allow OpenSSH
ufw allow 3306/tcp
ufw allow from 192.168.218.0/24
exito "Firewall configurado"

# 6. INSTALAR MYSQL SERVER
log "Instalando MySQL Server..."

# Pre-configurar la instalación para evitar prompts interactivos
export DEBIAN_FRONTEND=noninteractive
echo "mysql-server mysql-server/root_password password $DB_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DB_ROOT_PASSWORD" | debconf-set-selections

apt install -y mysql-server mysql-client

# Asegurar que MySQL esté iniciado
systemctl enable mysql
systemctl start mysql

exito "MySQL Server instalado"

# 7. CONFIGURAR MYSQL PARA REPLICACIÓN MAESTRO
log "Configurando MySQL como maestro..."

# Crear archivo de configuración personalizado
cat > /etc/mysql/mysql.conf.d/maestro.cnf << 'EOF'
[mysqld]
# Configuración de Replicación - Servidor Maestro
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = sistema_clientes
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 100M

# Configuración de red
bind-address = 0.0.0.0

# Configuración de performance
innodb_buffer_pool_size = 256M
query_cache_type = 1
query_cache_size = 64M
query_cache_limit = 2M

# Configuración de seguridad
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO

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

# Reiniciar MySQL para aplicar configuración
systemctl restart mysql
sleep 5

if systemctl is-active --quiet mysql; then
    exito "MySQL configurado como maestro"
else
    error "Error configurando MySQL"
fi

# 8. CONFIGURAR SEGURIDAD DE MYSQL
log "Configurando seguridad de MySQL..."

# Script de seguridad automatizado
mysql -u root -p"$DB_ROOT_PASSWORD" << EOF
-- Eliminar usuarios anónimos
DELETE FROM mysql.user WHERE User='';

-- Eliminar base de datos test
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Deshabilitar acceso remoto para root (mantener solo local)
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Recargar privilegios
FLUSH PRIVILEGES;
EOF

exito "Seguridad de MySQL configurada"

# 9. CREAR BASE DE DATOS Y USUARIO
log "Creando base de datos y usuario..."

mysql -u root -p"$DB_ROOT_PASSWORD" << EOF
-- Crear base de datos
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario para aplicaciones
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';

-- Crear usuario para replicación
CREATE USER IF NOT EXISTS '$REPLICA_USER'@'%' IDENTIFIED BY '$REPLICA_PASSWORD';
GRANT REPLICATION SLAVE ON *.* TO '$REPLICA_USER'@'%';

-- Crear tabla de clientes
USE $DB_NAME;

CREATE TABLE IF NOT EXISTS clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    telefono VARCHAR(15),
    direccion TEXT,
    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_nombre (nombre),
    INDEX idx_email (email),
    INDEX idx_activo (activo),
    INDEX idx_fecha_registro (fecha_registro)
) ENGINE=InnoDB;

-- Insertar datos de ejemplo
INSERT INTO clientes (nombre, email, telefono, direccion, activo) VALUES 
('Juan Pérez López', 'juan.perez@email.com', '+591 70123456', 'Av. Jaime Mendoza #123, Sucre', TRUE),
('María García Vega', 'maria.garcia@email.com', '+591 71234567', 'Calle Estudiantes #456, Sucre', TRUE),
('Carlos Rodríguez Silva', 'carlos.rodriguez@email.com', '+591 72345678', 'Plaza 25 de Mayo #789, Sucre', TRUE),
('Ana Martínez Flores', 'ana.martinez@email.com', '+591 73456789', 'Av. Hernando Siles #321, Sucre', FALSE),
('Luis Fernando Gutiérrez', 'luis.gutierrez@email.com', '+591 74567890', 'Calle Bolívar #654, Sucre', TRUE);

-- Crear tabla de logs de aplicación
CREATE TABLE IF NOT EXISTS logs_aplicacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servidor VARCHAR(50),
    ip VARCHAR(15),
    accion VARCHAR(100),
    usuario VARCHAR(100),
    detalles TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_servidor (servidor),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB;

-- Recargar privilegios
FLUSH PRIVILEGES;
FLUSH LOGS;
EOF

exito "Base de datos y usuario creados"

# 10. CONFIGURAR LOGS Y MONITOREO
log "Configurando logs y monitoreo..."

# Crear directorio de logs si no existe
mkdir -p /var/log/mysql
chown mysql:mysql /var/log/mysql

# Configurar logrotate para MySQL
cat > /etc/logrotate.d/mysql-server << 'EOF'
/var/log/mysql/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 mysql mysql
    postrotate
        if test -x /usr/bin/mysqladmin && \
           /usr/bin/mysqladmin ping &>/dev/null
        then
           /usr/bin/mysqladmin flush-logs
        fi
    endscript
}
EOF

exito "Logs y monitoreo configurados"

# 11. CREAR SCRIPTS DE ADMINISTRACIÓN
log "Creando scripts de administración..."

# Script de backup
cat > /usr/local/bin/backup-bd-maestro.sh << EOF
#!/bin/bash

# Backup automático de BD Maestro - SIS313
BACKUP_DIR="/opt/backups/mysql"
mkdir -p "\$BACKUP_DIR"

FECHA=\$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="\$BACKUP_DIR/backup_maestro_\$FECHA.sql"

echo "Iniciando backup de BD Maestro..."

mysqldump -u root -p"$DB_ROOT_PASSWORD" \\
    --single-transaction \\
    --routines \\
    --triggers \\
    --events \\
    --master-data=2 \\
    "$DB_NAME" > "\$BACKUP_FILE"

if [ \$? -eq 0 ]; then
    gzip "\$BACKUP_FILE"
    echo "✅ Backup completado: \$BACKUP_FILE.gz"
    
    # Limpiar backups antiguos (más de 7 días)
    find "\$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
else
    echo "❌ Error en backup"
    exit 1
fi
EOF

chmod +x /usr/local/bin/backup-bd-maestro.sh

# Script de verificación de replicación
cat > /usr/local/bin/verificar-maestro.sh << 'EOF'
#!/bin/bash

echo "======================================"
echo "  VERIFICACIÓN MYSQL MAESTRO"  
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

# Verificar estado de maestro
echo ""
echo "📊 ESTADO DEL MAESTRO:"
mysql -u root -p'$DB_ROOT_PASSWORD' -e "SHOW MASTER STATUS\G" 2>/dev/null | grep -E "(File|Position)"

# Verificar conexiones activas
echo ""
echo "🔗 CONEXIONES ACTIVAS:"
mysql -u root -p'$DB_ROOT_PASSWORD' -e "SHOW PROCESSLIST;" 2>/dev/null | wc -l

# Verificar datos de ejemplo
echo ""
echo "📋 DATOS DE EJEMPLO:"
mysql -u root -p'$DB_ROOT_PASSWORD' -e "SELECT COUNT(*) as total_clientes FROM sistema_clientes.clientes;" 2>/dev/null

echo ""
echo "🔗 URLs de verificación:"
echo "- Conectar desde apps: mysql -h 192.168.218.102 -u usuario_bd -p"
echo "- Test replicación: mysql -h 192.168.218.102 -u replica_user -p"
EOF

chmod +x /usr/local/bin/verificar-maestro.sh

# Script de monitoreo en tiempo real
cat > /usr/local/bin/monitorear-mysql.sh << 'EOF'
#!/bin/bash

echo "Monitoreo MySQL Maestro - Presiona Ctrl+C para salir"
echo "=================================================="

while true; do
    clear
    echo "$(date) - Estado MySQL Maestro (BD1)"
    echo "======================================"
    
    # Estado del servicio
    if systemctl is-active --quiet mysql; then
        echo "✅ Estado: ACTIVO"
    else
        echo "❌ Estado: INACTIVO"
    fi
    
    # Conexiones
    conexiones=$(mysql -u root -p'$DB_ROOT_PASSWORD' -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | awk 'NR==2 {print $2}')
    echo "🔗 Conexiones activas: $conexiones"
    
    # Consultas por segundo
    queries=$(mysql -u root -p'$DB_ROOT_PASSWORD' -e "SHOW STATUS LIKE 'Queries';" 2>/dev/null | awk 'NR==2 {print $2}')
    echo "📊 Total consultas: $queries"
    
    # Espacio usado
    espacio=$(du -sh /var/lib/mysql | cut -f1)
    echo "💾 Espacio usado: $espacio"
    
    echo "======================================"
    echo "Próxima actualización en 5 segundos..."
    
    sleep 5
done
EOF

chmod +x /usr/local/bin/monitorear-mysql.sh

exito "Scripts de administración creados"

# 12. CONFIGURAR CRON PARA BACKUPS
log "Configurando backup automático..."

# Crear entrada en crontab para backup diario a las 2:00 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-bd-maestro.sh >> /var/log/backup-mysql.log 2>&1") | crontab -

exito "Backup automático configurado"

# 13. CREAR USUARIO PARA MONITOREO
log "Creando usuario para monitoreo..."

mysql -u root -p"$DB_ROOT_PASSWORD" << 'EOF'
-- Crear usuario para monitoreo con permisos limitados
CREATE USER IF NOT EXISTS 'monitor'@'192.168.218.%' IDENTIFIED BY 'monitor_password_123';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'monitor'@'192.168.218.%';
GRANT SELECT ON performance_schema.* TO 'monitor'@'192.168.218.%';
FLUSH PRIVILEGES;
EOF

exito "Usuario de monitoreo creado"

# 14. VERIFICAR INSTALACIÓN
log "Verificando instalación..."

# Verificar que MySQL esté corriendo
if ! systemctl is-active --quiet mysql; then
    error "MySQL no está activo"
fi

# Verificar que se puede conectar
if ! mysql -u root -p"$DB_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
    error "No se puede conectar a MySQL"
fi

# Verificar que la base de datos existe
if ! mysql -u root -p"$DB_ROOT_PASSWORD" -e "USE $DB_NAME; SELECT COUNT(*) FROM clientes;" &>/dev/null; then
    error "Error accediendo a la base de datos"
fi

exito "Verificación completada"

# 15. MOSTRAR INFORMACIÓN DE REPLICACIÓN
log "Obteniendo información de replicación..."

echo -e "\n${YELLOW}📋 INFORMACIÓN PARA CONFIGURAR ESCLAVO:${NC}"

mysql -u root -p"$DB_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G" 2>/dev/null | while read line; do
    if [[ $line == *"File:"* ]]; then
        BINLOG_FILE=$(echo $line | awk '{print $2}')
        echo -e "📄 Archivo binlog: ${GREEN}$BINLOG_FILE${NC}"
    elif [[ $line == *"Position:"* ]]; then
        BINLOG_POS=$(echo $line | awk '{print $2}')
        echo -e "📍 Posición: ${GREEN}$BINLOG_POS${NC}"
    fi
done

# 16. MOSTRAR RESUMEN
echo -e "\n${GREEN}===========================================${NC}"
echo -e "${GREEN}     INSTALACIÓN COMPLETADA              ${NC}"
echo -e "${GREEN}===========================================${NC}"

echo -e "\n📊 INFORMACIÓN DEL SERVIDOR:"
echo -e "🖥️  Hostname: $(hostname)"
echo -e "🌐 IP: $SERVIDOR_IP"
echo -e "🗄️ Base de datos: $DB_NAME"
echo -e "⚡ Servicios activos:"
systemctl is-active mysql && echo "  ✅ MySQL Server"

echo -e "\n🔐 CREDENCIALES:"
echo -e "  Root: root / $DB_ROOT_PASSWORD"
echo -e "  App User: $DB_USER / $DB_PASSWORD"
echo -e "  Replica User: $REPLICA_USER / $REPLICA_PASSWORD"
echo -e "  Monitor User: monitor / monitor_password_123"

echo -e "\n🔗 Conexión desde aplicaciones:"
echo -e "  mysql -h $SERVIDOR_IP -u $DB_USER -p$DB_PASSWORD $DB_NAME"

echo -e "\n📋 Comandos útiles:"
echo -e "  Verificar maestro: /usr/local/bin/verificar-maestro.sh"
echo -e "  Backup manual: /usr/local/bin/backup-bd-maestro.sh"
echo -e "  Monitoreo: /usr/local/bin/monitorear-mysql.sh"
echo -e "  Ver logs: tail -f /var/log/mysql/error.log"

echo -e "\n${BLUE}MySQL Maestro configurado exitosamente!${NC}"
echo -e "${YELLOW}Ahora configure el servidor esclavo (BD2) con la información de replicación mostrada arriba.${NC}"

# 17. EJECUTAR VERIFICACIÓN INICIAL
log "Ejecutando verificación inicial..."
sleep 3
/usr/local/bin/verificar-maestro.sh
