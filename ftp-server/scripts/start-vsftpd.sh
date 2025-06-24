#!/bin/bash

echo "Iniciando servidor FTP..."

# Crear directorios de logs si no existen
mkdir -p /var/log

# Verificar configuración
echo "Verificando configuración de vsftpd..."
if ! vsftpd -olisten=NO /etc/vsftpd.conf; then
    echo "Error en la configuración de vsftpd"
    exit 1
fi

echo "Configuración OK. Iniciando vsftpd..."

# Iniciar vsftpd en primer plano
exec vsftpd /etc/vsftpd.conf
