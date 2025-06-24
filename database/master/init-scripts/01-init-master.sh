#!/bin/bash
set -e

echo "Inicializando base de datos master..."

# Crear base de datos principal
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS crud_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    
    -- Crear usuario para la aplicación
    CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY 'secure_password_123';
    GRANT SELECT, INSERT, UPDATE, DELETE ON crud_app.* TO 'app_user'@'%';
    
    -- Crear usuario para replicación
    CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'replication_password_123';
    GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
    
    -- Crear tabla de usuarios
    USE crud_app;
    
    CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) NOT NULL UNIQUE,
        age INT NULL CHECK (age > 0 AND age <= 120),
        phone VARCHAR(20) NULL,
        isActive BOOLEAN NOT NULL DEFAULT TRUE,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_name (name),
        INDEX idx_email (email),
        INDEX idx_active (isActive)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    
    -- Insertar datos de prueba
    INSERT INTO users (name, email, age, phone) VALUES 
    ('Juan Pérez', 'juan.perez@email.com', 25, '+1234567890'),
    ('María García', 'maria.garcia@email.com', 30, '+1234567891'),
    ('Carlos López', 'carlos.lopez@email.com', 28, '+1234567892'),
    ('Ana Martínez', 'ana.martinez@email.com', 32, '+1234567893'),
    ('Luis Rodríguez', 'luis.rodriguez@email.com', 27, '+1234567894')
    ON DUPLICATE KEY UPDATE name=VALUES(name);
    
    FLUSH PRIVILEGES;
EOSQL

echo "Master database initialized successfully!"

# Mostrar estado del master
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS;"
