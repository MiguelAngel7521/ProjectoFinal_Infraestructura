# Proyecto Final - Infraestructura de Aplicaciones Web

Este proyecto implementa una infraestructura completa con balanceador de carga, servidores de aplicaciones Node.js y bases de datos con replicación maestro-esclavo.

## Arquitectura

```
┌─────────────────┐
│   Balanceador   │
│   de Carga      │ <- Puerto 80/443
│   (NGINX)       │
└─────────┬───────┘
          │
    ┌─────┴─────┐
    │           │
┌───▼───┐   ┌───▼───┐
│App 1  │   │App 2  │ <- Puertos 3001, 3002
│Node.js│   │Node.js│
└───┬───┘   └───┬───┘
    │           │
    └─────┬─────┘
          │
    ┌─────▼─────┐
    │           │
┌───▼───┐   ┌───▼───┐
│DB     │   │DB     │ <- Puertos 3306, 3307
│Master │   │Slave  │
└───────┘   └───────┘
```

## Servicios Implementados

- **Balanceador de Carga**: NGINX configurado para distribuir tráfico
- **Servidores de Aplicación**: 2 instancias Node.js con CRUD básico
- **Base de Datos**: MySQL con replicación Maestro-Esclavo
- **Servicio FTP**: vsftpd para actualización de aplicaciones

## Estructura del Proyecto

```
├── load-balancer/          # Configuración del balanceador de carga
├── app-servers/            # Servidores de aplicación Node.js
├── database/               # Configuración de bases de datos
├── ftp-server/             # Configuración del servicio FTP
├── docker-compose/         # Configuración Docker para desarrollo
├── scripts/                # Scripts de automatización
└── docs/                   # Documentación adicional
```

## Requisitos Previos

- Docker y Docker Compose
- Node.js 18+ (para desarrollo local)
- MySQL/MariaDB (para producción)
- NGINX (para producción)

## Instalación y Configuración

### Usando Docker (Recomendado para desarrollo)

1. Clonar el repositorio:
```bash
git clone <url-del-repositorio>
cd ProyectoFinal
```

2. Levantar todos los servicios:
```bash
docker-compose -f docker-compose/docker-compose.yml up -d
```

3. Verificar que todos los servicios estén corriendo:
```bash
docker-compose -f docker-compose/docker-compose.yml ps
```

### Configuración Manual (Producción)

Ver la documentación específica en cada directorio:
- [Balanceador de Carga](load-balancer/README.md)
- [Servidores de Aplicación](app-servers/README.md)
- [Base de Datos](database/README.md)
- [Servicio FTP](ftp-server/README.md)

## URLs de Acceso

- **Aplicación Web**: http://localhost (balanceada automáticamente)
- **App Server 1**: http://localhost:3001 (acceso directo)
- **App Server 2**: http://localhost:3002 (acceso directo)
- **FTP Server**: ftp://localhost:21

## API Endpoints

La aplicación CRUD expone los siguientes endpoints:

- `GET /api/users` - Listar usuarios
- `POST /api/users` - Crear usuario
- `GET /api/users/:id` - Obtener usuario
- `PUT /api/users/:id` - Actualizar usuario
- `DELETE /api/users/:id` - Eliminar usuario

## Scripts de Automatización

- `scripts/deploy.sh` - Despliegue completo
- `scripts/backup.sh` - Backup de base de datos
- `scripts/monitor.sh` - Monitoreo de servicios
- `scripts/update-app.sh` - Actualización de aplicación vía FTP

## Contribuir

1. Fork el proyecto
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## Licencia

Este proyecto es para fines educativos - Universidad XYZ
