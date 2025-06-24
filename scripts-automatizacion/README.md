# Scripts de Automatización - Proyecto SIS313

Este directorio contiene scripts para automatizar el despliegue, monitoreo y mantenimiento de la infraestructura.

## Scripts Disponibles

### Despliegue e Instalación
- `instalar-completo.sh` - Instalación completa en todos los servidores
- `configurar-red.sh` - Configuración de red en todas las VMs
- `desplegar-proxy.sh` - Configurar balanceador NGINX
- `desplegar-apps.sh` - Desplegar aplicaciones Node.js
- `configurar-mysql.sh` - Configurar replicación MySQL

### Monitoreo y Verificación
- `monitorear-sistema.sh` - Monitoreo completo del sistema
- `verificar-salud.sh` - Health check de todos los servicios
- `estado-tolerancia-fallos.sh` - Verificar tolerancia a fallos
- `pruebas-carga.sh` - Pruebas de carga del balanceador

### Backup y Mantenimiento
- `respaldar-datos.sh` - Backup de bases de datos
- `limpiar-logs.sh` - Limpiar logs antiguos
- `optimizar-mysql.sh` - Optimización de bases de datos
- `mantenimiento-raid.sh` - Mantenimiento del RAID 1

### Demostración de Tolerancia a Fallos
- `simular-fallo-app.sh` - Simular fallo de servidor de aplicación
- `simular-fallo-bd.sh` - Simular fallo de base de datos
- `simular-fallo-disco.sh` - Simular fallo de disco en RAID
- `recuperar-servicios.sh` - Recuperar servicios después de fallos

## Configuración

### Variables de Entorno

Los scripts utilizan las siguientes variables:

```bash
# IPs de los servidores
PROXY_IP="192.168.218.100"
APP1_IP="192.168.218.101"
BD1_IP="192.168.218.102"
APP2_IP="192.168.218.103"
BD2_IP="192.168.218.104"

# Credenciales de Base de Datos
DB_USER="usuario_bd"
DB_PASS="clave_bd_segura_123"
DB_NAME="sistema_clientes"

# Usuario del sistema
SYSTEM_USER="usuario"
```

## Uso de Scripts

### Instalación inicial completa:
```bash
sudo chmod +x *.sh
./instalar-completo.sh
```

### Monitoreo continuo:
```bash
./monitorear-sistema.sh --continuo
```

### Backup de emergencia:
```bash
./respaldar-datos.sh --completo --comprimido
```

### Pruebas de tolerancia a fallos:
```bash
./simular-fallo-app.sh app1
./verificar-salud.sh
./recuperar-servicios.sh app1
```

## Automatización con Cron

### Configuración de tareas automáticas:

```bash
# Editar crontab
crontab -e

# Agregar las siguientes líneas:

# Monitoreo cada 5 minutos
*/5 * * * * /ruta/a/scripts/verificar-salud.sh >> /var/log/monitoreo.log 2>&1

# Backup diario a las 2:00 AM
0 2 * * * /ruta/a/scripts/respaldar-datos.sh --completo

# Limpieza semanal de logs (domingos a las 3:00 AM)
0 3 * * 0 /ruta/a/scripts/limpiar-logs.sh

# Verificación de RAID cada hora
0 * * * * /ruta/a/scripts/mantenimiento-raid.sh --verificar
```

## Logs

### Ubicación de logs:

- Logs del sistema: `/var/log/sis313/`
- Logs de aplicaciones: `/var/log/aplicacion-crud/`
- Logs de monitoreo: `/var/log/monitoreo.log`
- Logs de backup: `/var/log/backup.log`

## Alertas

### Configuración de alertas por email:

```bash
# Instalar mailutils
sudo apt install mailutils -y

# Configurar en scripts:
ALERT_EMAIL="admin@sis313.usfx.bo"
SMTP_SERVER="smtp.usfx.bo"
```

## Seguridad

### Permisos de archivos:

```bash
# Solo el propietario puede ejecutar
chmod 700 *.sh

# Propietario y grupo pueden ejecutar
chmod 750 *.sh

# Verificar permisos
ls -la *.sh
```
