# Configuración de Base de Datos

Este directorio contiene las configuraciones para la replicación maestro-esclavo de MySQL.

## Arquitectura

```
┌─────────────┐    Replicación    ┌─────────────┐
│   Master    │ ───────────────> │   Slave     │
│  (Lectura/  │                  │  (Solo      │
│  Escritura) │                  │  Lectura)   │
└─────────────┘                  └─────────────┘
```

## Características

- **Master**: Maneja escrituras y lecturas
- **Slave**: Solo lecturas, replica datos del master
- **Failover**: Configuración para promoción automática
- **Backup**: Scripts automatizados de backup

## Configuración

### Master (Puerto 3306)
- Binlog habilitado
- Server ID: 1
- Escrituras permitidas

### Slave (Puerto 3307)
- Replicación desde master
- Server ID: 2
- Solo lecturas

## Archivos

- `master/` - Configuración del servidor maestro
- `slave/` - Configuración del servidor esclavo
- `init-scripts/` - Scripts de inicialización
- `backup/` - Scripts de backup
- `docker-compose.yml` - Para desarrollo local
