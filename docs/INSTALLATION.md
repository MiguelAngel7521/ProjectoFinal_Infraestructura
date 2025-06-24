# Guía de Instalación - Proyecto Final SIS313
## Universidad San Francisco Xavier de Chuquisaca

### Infraestructura de Aplicaciones Web
**Balanceador NGINX + Aplicaciones Node.js + MySQL Maestro-Esclavo + RAID 1**

---

## 📋 Índice

1. [Prerrequisitos](#prerrequisitos)
2. [Topología de Red](#topología-de-red)
3. [Instalación por Servidor](#instalación-por-servidor)
4. [Configuración de Red](#configuración-de-red)
5. [Verificación del Sistema](#verificación-del-sistema)
6. [Mantenimiento](#mantenimiento)
7. [Solución de Problemas](#solución-de-problemas)

---

## 🔧 Prerrequisitos

### Hardware Requerido

| Servidor | CPU | RAM | Disco | Red |
|----------|-----|-----|-------|-----|
| **Proxy** | 1 vCPU | 1 GB | 20 GB | 2 NICs |
| **App1** | 1 vCPU | 2 GB | 20 GB | 2 NICs |
| **App2** | 1 vCPU | 2 GB | 20 GB | 2 NICs |
| **BD1** | 2 vCPU | 4 GB | 40 GB | 2 NICs |
| **BD2** | 2 vCPU | 4 GB | 40 GB + 2x20 GB RAID | 2 NICs |

### Software Base
- **Sistema Operativo:** Ubuntu Server 22.04 LTS
- **Virtualizador:** VMware Workstation/VirtualBox
- **Red:** Bridged (192.168.218.x) + NAT para Internet

---

## 🌐 Topología de Red

### Asignación de IPs

| Servidor | Rol | IP Red Proyecto | IP NAT | Hostname |
|----------|-----|-----------------|--------|----------|
| **Proxy** | Balanceador NGINX | 192.168.218.100 | 192.168.13.xxx | proxy.sis313.usfx.bo |
| **App1** | Servidor Node.js | 192.168.218.101 | 192.168.13.xxx | app1.sis313.usfx.bo |
| **App2** | Servidor Node.js | 192.168.218.103 | 192.168.13.xxx | app2.sis313.usfx.bo |
| **BD1** | MySQL Maestro | 192.168.218.102 | 192.168.13.xxx | bd1.sis313.usfx.bo |
| **BD2** | MySQL Esclavo + RAID | 192.168.218.104 | 192.168.13.xxx | bd2.sis313.usfx.bo |

### Configuración de Red (Netplan)

Para cada servidor, configurar `/etc/netplan/01-netcfg.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true     # NAT (para Internet)
    ens37:            # Red del proyecto (bridged)
      dhcp4: false
      addresses: [192.168.218.XXX/24]  # Cambiar XXX por IP correspondiente
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: 192.168.218.0/24
          via: 192.168.218.1
```

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
