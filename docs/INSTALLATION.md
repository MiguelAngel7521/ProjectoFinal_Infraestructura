# Manual de Instalación - Proyecto Final

## Requisitos del Sistema

### Hardware Mínimo
- CPU: 2 cores
- RAM: 4 GB
- Almacenamiento: 20 GB libres
- Red: Conexión a Internet

### Software Requerido
- Docker 20.10+
- Docker Compose 2.0+
- Git 2.30+
- Curl (para tests)

### Sistemas Operativos Soportados
- Ubuntu 20.04+
- CentOS 8+
- Windows 10+ (con WSL2)
- macOS 11+

## Instalación Paso a Paso

### 1. Preparación del Entorno

#### Ubuntu/Debian
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

#### CentOS/RHEL
```bash
# Instalar Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### Windows (WSL2)
```powershell
# Instalar Docker Desktop para Windows
# Descargar desde: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe

# En WSL2, instalar herramientas adicionales
sudo apt update
sudo apt install -y curl git make
```

### 2. Descargar el Proyecto

```bash
# Clonar repositorio
git clone https://github.com/tu-usuario/ProyectoFinal.git
cd ProyectoFinal

# Verificar estructura
ls -la
```

### 3. Configuración Inicial

```bash
# Copiar variables de entorno
cp app-servers/.env.example app-servers/.env
cp app-servers/.env.example app-servers/app1/.env
cp app-servers/.env.example app-servers/app2/.env

# Editar configuraciones según sea necesario
nano app-servers/.env
```

### 4. Despliegue Automático

```bash
# Hacer ejecutables los scripts
chmod +x scripts/*.sh

# Despliegue completo
./scripts/deploy.sh --environment development --build

# Verificar despliegue
./scripts/monitor.sh --once
```

### 5. Verificación de Instalación

```bash
# Verificar servicios
docker-compose -f docker-compose/docker-compose.yml ps

# Verificar conectividad
curl http://localhost
curl http://localhost:3001/health
curl http://localhost:3002/health

# Verificar base de datos
docker exec proyecto-db-master mysql -u app_user -psecure_password_123 -e "SELECT COUNT(*) FROM crud_app.users;"
```

## Configuración Manual (Producción)

### 1. Preparar Servidores

#### Servidor de Balanceador (nginx-server)
```bash
# Instalar NGINX
sudo apt install -y nginx

# Copiar configuración
sudo cp load-balancer/nginx.conf /etc/nginx/nginx.conf

# Habilitar y iniciar
sudo systemctl enable nginx
sudo systemctl start nginx
```

#### Servidores de Aplicación (app-server-1, app-server-2)
```bash
# Instalar Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Copiar aplicación
sudo mkdir -p /opt/app
sudo cp -r app-servers/* /opt/app/

# Instalar dependencias
cd /opt/app
sudo npm install --production

# Crear servicio systemd
sudo cp docs/systemd/node-app.service /etc/systemd/system/
sudo systemctl enable node-app
sudo systemctl start node-app
```

#### Servidores de Base de Datos (db-master, db-slave)

**Master:**
```bash
# Instalar MySQL
sudo apt install -y mysql-server

# Configurar
sudo cp database/master/my.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

# Ejecutar script de inicialización
sudo mysql < database/master/init-scripts/01-init-master.sh
```

**Slave:**
```bash
# Instalar MySQL
sudo apt install -y mysql-server

# Configurar
sudo cp database/slave/my.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

# Configurar replicación
sudo mysql < database/slave/init-scripts/01-init-slave.sh
```

#### Servidor FTP (ftp-server)
```bash
# Instalar vsftpd
sudo apt install -y vsftpd

# Configurar
sudo cp ftp-server/vsftpd.conf /etc/vsftpd.conf
sudo cp ftp-server/vsftpd.chroot_list /etc/vsftpd.chroot_list

# Crear usuarios
sudo bash ftp-server/scripts/setup-users.sh

# Iniciar servicio
sudo systemctl enable vsftpd
sudo systemctl start vsftpd
```

## Post-Instalación

### 1. Configurar SSL/TLS (Producción)

```bash
# Generar certificados (ejemplo con Let's Encrypt)
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d tu-dominio.com

# O usar certificados propios
sudo cp tu-certificado.crt /etc/ssl/certs/app.crt
sudo cp tu-clave.key /etc/ssl/private/app.key
```

### 2. Configurar Monitoreo

```bash
# Configurar cron para monitoreo
echo "*/5 * * * * /path/to/ProyectoFinal/scripts/monitor.sh --once >> /var/log/app-monitor.log" | sudo crontab -

# Configurar backup automático
echo "0 2 * * * /path/to/ProyectoFinal/scripts/backup.sh --full --compress" | sudo crontab -
```

### 3. Configurar Firewall

```bash
# UFW (Ubuntu)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 21/tcp    # FTP
sudo ufw allow 21000:21010/tcp  # FTP Passive
sudo ufw enable

# iptables (alternativo)
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 21 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 21000:21010 -j ACCEPT
```

## Solución de Problemas

### Error: Docker no se puede conectar
```bash
# Verificar que Docker esté corriendo
sudo systemctl status docker

# Reiniciar Docker si es necesario
sudo systemctl restart docker

# Verificar permisos de usuario
sudo usermod -aG docker $USER
newgrp docker
```

### Error: Puerto ya en uso
```bash
# Verificar qué proceso usa el puerto
sudo netstat -tulpn | grep :80

# Detener proceso conflictivo
sudo systemctl stop apache2  # ejemplo
```

### Error: Base de datos no conecta
```bash
# Verificar logs
docker logs proyecto-db-master

# Verificar conectividad
telnet localhost 3306

# Reiniciar contenedor
docker-compose restart db-master
```

### Error: FTP no accesible
```bash
# Verificar firewall
sudo ufw status

# Verificar configuración pasiva
# Ajustar pasv_address en vsftpd.conf si es necesario
```

## Mantenimiento

### Actualización del Sistema
```bash
# Actualizar aplicación
./scripts/update-app.sh --version 1.1.0

# Backup antes de actualizaciones críticas
./scripts/backup.sh --full --compress

# Monitorear después de cambios
./scripts/monitor.sh --continuous
```

### Limpieza Periódica
```bash
# Limpiar logs antiguos
find /var/log -name "*.log" -mtime +30 -delete

# Limpiar backups antiguos
./scripts/cleanup-backups.sh

# Limpiar imágenes Docker no utilizadas
docker system prune -f
```
