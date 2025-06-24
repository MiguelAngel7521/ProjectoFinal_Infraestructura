#!/bin/bash
set -e

echo "Configurando usuarios FTP..."

# Crear usuario deploy_user
useradd -m -d /var/ftp/deploy_user -s /bin/bash deploy_user
echo "deploy_user:deploy_password_123" | chpasswd

# Crear usuario backup_user
useradd -m -d /var/ftp/backup_user -s /bin/bash backup_user
echo "backup_user:backup_password_123" | chpasswd

# Configurar directorios
mkdir -p /var/ftp/deploy_user/apps
mkdir -p /var/ftp/backup_user/backup

# Establecer permisos
chown -R deploy_user:deploy_user /var/ftp/deploy_user
chown -R backup_user:backup_user /var/ftp/backup_user

chmod 755 /var/ftp/deploy_user
chmod 755 /var/ftp/backup_user

echo "Usuarios FTP configurados exitosamente!"
