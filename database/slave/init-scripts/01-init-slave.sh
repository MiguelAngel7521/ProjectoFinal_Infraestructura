#!/bin/bash
set -e

echo "Esperando a que el master esté disponible..."

# Función para esperar al master
wait_for_master() {
    local count=0
    while ! mysqladmin ping -h db-master -P 3306 --silent; do
        echo "Esperando al master... ($count/30)"
        sleep 2
        count=$((count + 1))
        if [ $count -eq 30 ]; then
            echo "Error: No se pudo conectar al master después de 60 segundos"
            exit 1
        fi
    done
    echo "Master disponible!"
}

# Esperar al master
wait_for_master

echo "Configurando replicación slave..."

# Configurar la replicación
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
    -- Crear base de datos (debe existir en slave)
    CREATE DATABASE IF NOT EXISTS crud_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    
    -- Crear usuario para la aplicación (solo lectura)
    CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY 'secure_password_123';
    GRANT SELECT ON crud_app.* TO 'app_user'@'%';
    
    -- Configurar replicación
    CHANGE MASTER TO
        MASTER_HOST='db-master',
        MASTER_PORT=3306,
        MASTER_USER='repl_user',
        MASTER_PASSWORD='replication_password_123',
        MASTER_AUTO_POSITION=1;
    
    -- Iniciar replicación
    START SLAVE;
    
    FLUSH PRIVILEGES;
EOSQL

# Verificar estado de la replicación
echo "Verificando estado de replicación..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G"

echo "Slave configurado exitosamente!"
