# Configuración de Bases de Datos MySQL

## BD1 - Servidor Maestro (192.168.218.102)
## BD2 - Servidor Esclavo + RAID 1 (192.168.218.104)

### Configuración de replicación MySQL con tolerancia a fallos

## Instalación en BD1 (Maestro)

### Preparación del servidor:

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar MySQL Server
sudo apt install mysql-server -y

# Configurar seguridad inicial
sudo mysql_secure_installation
```

### Configuración MySQL Maestro

#### Archivo: `/etc/mysql/mysql.conf.d/mysqld.cnf`

Agregar/modificar las siguientes líneas:

```ini
[mysqld]
# Configuración básica
bind-address = 0.0.0.0
port = 3306

# Configuración de replicación - MAESTRO
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
binlog_do_db = sistema_clientes
expire_logs_days = 7
max_binlog_size = 100M

# Configuración de rendimiento
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
key_buffer_size = 64M
max_connections = 200

# Configuración de seguridad
local-infile = 0
```

### Crear base de datos y usuarios:

```sql
-- Conectar como root
sudo mysql -u root -p

-- Crear base de datos
CREATE DATABASE sistema_clientes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario para aplicaciones
CREATE USER 'usuario_bd'@'%' IDENTIFIED BY 'clave_bd_segura_123';
GRANT ALL PRIVILEGES ON sistema_clientes.* TO 'usuario_bd'@'%';

-- Crear usuario para replicación
CREATE USER 'replica'@'%' IDENTIFIED BY 'clave_replica_segura_456';
GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';

-- Aplicar cambios
FLUSH PRIVILEGES;

-- Usar la base de datos
USE sistema_clientes;

-- Crear tabla de clientes
CREATE TABLE clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    direccion TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    
    INDEX idx_nombre (nombre),
    INDEX idx_email (email),
    INDEX idx_fecha (fecha_registro),
    INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar datos de prueba
INSERT INTO clientes (nombre, email, telefono, direccion) VALUES 
('Juan Pérez García', 'juan.perez@email.com', '+591 2 1234567', 'Av. Heroínas 123, Sucre'),
('María López Vargas', 'maria.lopez@email.com', '+591 2 1234568', 'Calle Bolívar 456, Sucre'),
('Carlos Mendoza Cruz', 'carlos.mendoza@email.com', '+591 2 1234569', 'Plaza 25 de Mayo 789, Sucre'),
('Ana Rodríguez Silva', 'ana.rodriguez@email.com', '+591 2 1234570', 'Calle Audiencia 321, Sucre'),
('Luis Fernández Torres', 'luis.fernandez@email.com', '+591 2 1234571', 'Av. Venezuela 654, Sucre'),
('Carmen Jiménez Ramos', 'carmen.jimenez@email.com', '+591 2 1234572', 'Calle Dalence 987, Sucre'),
('Roberto Castro Morales', 'roberto.castro@email.com', '+591 2 1234573', 'Plaza San Francisco 147, Sucre'),
('Elena Vargas Delgado', 'elena.vargas@email.com', '+591 2 1234574', 'Calle Junín 258, Sucre');

-- Verificar datos
SELECT COUNT(*) as total_clientes FROM clientes;
SELECT * FROM clientes LIMIT 5;

-- Mostrar estado del maestro (importante para configurar esclavo)
SHOW MASTER STATUS;
```

### Reiniciar MySQL y verificar:

```bash
sudo systemctl restart mysql
sudo systemctl status mysql

# Verificar binlog
sudo ls -la /var/log/mysql/
```

## Configuración en BD2 (Esclavo + RAID 1)

### 1. Configurar RAID 1

```bash
# Instalar mdadm
sudo apt update
sudo apt install mdadm -y

# Verificar discos disponibles
lsblk

# Crear RAID 1 (suponer sdb y sdc como discos adicionales)
sudo mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

# Formatear el RAID
sudo mkfs.ext4 /dev/md0

# Crear punto de montaje
sudo mkdir /mnt/raid1

# Montar el RAID
sudo mount /dev/md0 /mnt/raid1

# Configurar montaje automático
echo '/dev/md0 /mnt/raid1 ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab

# Verificar RAID
sudo mdadm --detail /dev/md0
cat /proc/mdstat
```

### 2. Instalar MySQL

```bash
sudo apt install mysql-server -y
sudo mysql_secure_installation
```

### 3. Mover MySQL al RAID

```bash
# Detener MySQL
sudo systemctl stop mysql

# Crear directorio en RAID
sudo mkdir -p /mnt/raid1/mysql

# Copiar datos existentes
sudo rsync -av /var/lib/mysql/ /mnt/raid1/mysql/

# Hacer backup del directorio original
sudo mv /var/lib/mysql /var/lib/mysql.backup

# Crear enlace simbólico
sudo ln -s /mnt/raid1/mysql /var/lib/mysql

# Cambiar permisos
sudo chown -R mysql:mysql /mnt/raid1/mysql

# Iniciar MySQL
sudo systemctl start mysql
sudo systemctl status mysql
```

### 4. Configurar MySQL Esclavo

#### Archivo: `/etc/mysql/mysql.conf.d/mysqld.cnf`

```ini
[mysqld]
# Configuración básica
bind-address = 0.0.0.0
port = 3306

# Configuración de replicación - ESCLAVO
server-id = 2
relay_log = /var/log/mysql/mysql-relay-bin.log
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
binlog_do_db = sistema_clientes
read_only = 1

# Configuración de rendimiento
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
key_buffer_size = 64M
max_connections = 200

# Configuración de seguridad
local-infile = 0
```

### 5. Configurar Replicación

```bash
# Reiniciar MySQL
sudo systemctl restart mysql

# Conectar a MySQL
sudo mysql -u root -p
```

```sql
-- Crear la base de datos (debe existir)
CREATE DATABASE sistema_clientes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario para aplicaciones (solo lectura)
CREATE USER 'usuario_bd'@'%' IDENTIFIED BY 'clave_bd_segura_123';
GRANT SELECT ON sistema_clientes.* TO 'usuario_bd'@'%';

-- Configurar replicación (usar valores de SHOW MASTER STATUS del maestro)
CHANGE MASTER TO
    MASTER_HOST='192.168.218.102',
    MASTER_USER='replica',
    MASTER_PASSWORD='clave_replica_segura_456',
    MASTER_LOG_FILE='mysql-bin.000001',  -- Ajustar según SHOW MASTER STATUS
    MASTER_LOG_POS=XXX;                  -- Ajustar según SHOW MASTER STATUS

-- Iniciar replicación
START SLAVE;

-- Verificar estado de replicación
SHOW SLAVE STATUS\G

-- Aplicar privilegios
FLUSH PRIVILEGES;
```

## Scripts de Verificación

### Script: `verificar-replicacion.sh`

```bash
#!/bin/bash
echo "=== Verificación de Replicación MySQL ==="

echo "📊 Estado de BD1 (Maestro):"
mysql -h 192.168.218.102 -u usuario_bd -pclave_bd_segura_123 -e "
    USE sistema_clientes;
    SELECT 'Maestro' as servidor, COUNT(*) as total_clientes FROM clientes;
    SHOW MASTER STATUS;
"

echo ""
echo "📊 Estado de BD2 (Esclavo):"
mysql -h 192.168.218.104 -u usuario_bd -pclave_bd_segura_123 -e "
    USE sistema_clientes;
    SELECT 'Esclavo' as servidor, COUNT(*) as total_clientes FROM clientes;
    SHOW SLAVE STATUS\G
"

echo ""
echo "💾 Estado del RAID 1:"
ssh usuario@192.168.218.104 "sudo mdadm --detail /dev/md0 | grep -E 'State|Active Devices'"
```

### Script: `estado-raid.sh`

```bash
#!/bin/bash
echo "=== Estado del RAID 1 en BD2 ==="

echo "📊 Información general del RAID:"
sudo mdadm --detail /dev/md0

echo ""
echo "📈 Estado en tiempo real:"
cat /proc/mdstat

echo ""
echo "💾 Uso del disco:"
df -h /mnt/raid1

echo ""
echo "🔍 Verificación de errores:"
sudo dmesg | grep -i raid | tail -5
```

## Configuración de Firewall

```bash
# En BD1 y BD2
sudo ufw allow 3306/tcp
sudo ufw allow OpenSSH
sudo ufw enable
```

## Pruebas de Tolerancia a Fallos

### 1. Probar fallo de aplicación:
```bash
# Detener App1
ssh usuario@192.168.218.101 "sudo systemctl stop aplicacion-crud"

# El proxy debe redirigir a App2 automáticamente
curl http://192.168.218.100
```

### 2. Simular fallo de disco en RAID:
```bash
# En BD2, simular fallo de un disco
sudo mdadm --manage /dev/md0 --fail /dev/sdb

# Verificar que sigue funcionando con un disco
cat /proc/mdstat
mysql -h 192.168.218.104 -u usuario_bd -pclave_bd_segura_123 -e "SELECT COUNT(*) FROM sistema_clientes.clientes;"
```

### 3. Recuperar disco en RAID:
```bash
# Remover disco fallido
sudo mdadm --manage /dev/md0 --remove /dev/sdb

# Agregar disco de reemplazo
sudo mdadm --manage /dev/md0 --add /dev/sdb

# Verificar reconstrucción
watch cat /proc/mdstat
```
