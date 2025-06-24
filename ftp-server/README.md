# Configuración del Servicio FTP

Este directorio contiene la configuración del servicio FTP usando vsftpd.

## Características

- **Servidor**: vsftpd (Very Secure FTP Daemon)
- **Seguridad**: Usuarios virtuales, chroot jail
- **SSL/TLS**: Soporte para conexiones seguras
- **Logs**: Logging detallado de conexiones y transferencias

## Configuración

### Usuarios FTP

- `deploy_user`: Usuario para despliegue de aplicaciones
- `backup_user`: Usuario para transferencias de backup

### Directorios

- `/var/ftp/apps/`: Directorio para aplicaciones
- `/var/ftp/backup/`: Directorio para backups
- `/var/ftp/logs/`: Logs del servicio FTP

## Puertos

- **Puerto 21**: Comando FTP
- **Puertos 21000-21010**: Modo pasivo

## Uso

```bash
# Conectar para despliegue
ftp deploy_user@localhost

# Subir aplicación
put app.tar.gz /apps/

# Conectar para backup
ftp backup_user@localhost
```
