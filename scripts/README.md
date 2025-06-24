# Scripts de Automatización

Este directorio contiene scripts para automatizar el despliegue, monitoreo y mantenimiento de la infraestructura.

## Scripts Disponibles

### Despliegue
- `deploy.sh` - Despliegue completo de la infraestructura
- `update-app.sh` - Actualizar aplicaciones via FTP
- `rollback.sh` - Rollback a versión anterior

### Backup y Restauración
- `backup.sh` - Backup de bases de datos
- `restore.sh` - Restaurar desde backup
- `cleanup-backups.sh` - Limpiar backups antiguos

### Monitoreo
- `monitor.sh` - Monitorear estado de servicios
- `health-check.sh` - Verificación de salud general
- `log-analyzer.sh` - Analizar logs del sistema

### Mantenimiento
- `maintenance.sh` - Modo de mantenimiento
- `ssl-renew.sh` - Renovar certificados SSL
- `optimize-db.sh` - Optimizar bases de datos

## Uso

### Despliegue inicial
```bash
./scripts/deploy.sh --environment production
```

### Actualizar aplicación
```bash
./scripts/update-app.sh --version 1.2.0
```

### Backup
```bash
./scripts/backup.sh --full
```

### Monitoreo
```bash
./scripts/monitor.sh --continuous
```

## Configuración

Los scripts utilizan variables de entorno definidas en:
- `.env.production`
- `.env.staging`
- `.env.development`
