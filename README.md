# Proyecto Final - Infraestructura de Aplicaciones Web
## Universidad San Francisco Xavier de Chuquisaca - SIS313

Este proyecto implementa una infraestructura completa con balanceador de carga NGINX, servidores de aplicaciones Node.js y bases de datos MySQL con replicación maestro-esclavo, incluyendo tolerancia a fallos con RAID 1.

### Integrantes del Grupo
-Rodriguez Vela Miguel Angel
-Flores Mosquera Saul


### Materia
- SIS313 - Infraestructuras de Sistemas

## Topología de Red

### Asignación de IPs (Red Bridged: 192.168.218.x)

| Servidor | Rol | IP Principal | Puerto | Descripción |
|----------|-----|--------------|--------|-------------|
| **Proxy** | Balanceador NGINX | 192.168.218.100 | 80, 8080 | proxy.sis313.usfx.bo |
| **App1** | Servidor Node.js | 192.168.218.101 | 3000 | Aplicación CRUD |
| **App2** | Servidor Node.js | 192.168.218.103 | 3000 | Aplicación CRUD |
| **BD1** | MySQL Maestro | 192.168.218.102 | 3306 | Base de datos principal |
| **BD2** | MySQL Esclavo + RAID1 | 192.168.218.104 | 3306 | Replicación + tolerancia fallos |

## Arquitectura del Sistema

```
                    ┌─────────────────┐
                    │     PROXY       │
                    │ 192.168.218.100 │ <- Puerto 80 (Balanceador)
                    │     NGINX       │    Puerto 8080 (Status)
                    └─────────┬───────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
            ┌───────▼───────┐   ┌───────▼───────┐
            │     APP1      │   │     APP2      │
            │192.168.218.101│   │192.168.218.103│ <- Puerto 3000
            │   Node.js     │   │   Node.js     │
            │   CRUD        │   │   CRUD        │
            └───────┬───────┘   └───────┬───────┘
                    │                   │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │                   │
            ┌───────▼───────┐   ┌───────▼───────┐
            │     BD1       │   │     BD2       │
            │192.168.218.102│   │192.168.218.104│ <- Puerto 3306
            │ MySQL MAESTRO │   │ MySQL ESCLAVO │
            │               │   │  + RAID 1     │
            └───────────────┘   └───────────────┘
                    │ Replicación →    │
```

## Servicios Implementados

- **Balanceador de Carga (NGINX)**: Distribuye tráfico entre App1 y App2
- **Servidores de Aplicación**: 2 instancias Node.js con CRUD de clientes
- **Base de Datos MySQL**: Configuración Maestro-Esclavo con replicación
- **RAID 1**: Tolerancia a fallos de disco en BD2
- **Alta Disponibilidad**: Sistema tolerante a fallos de servicios

## Tolerancia a Fallos

### Escenarios de Fallo y Recuperación

1. **Falla App1 o App2**: El proxy NGINX redirige automáticamente el tráfico al servidor disponible
2. **Falla BD1 (Maestro)**: BD2 mantiene todos los datos actualizados por replicación
3. **Falla disco en BD2**: RAID 1 permite operación continua con un solo disco
4. **Recuperación**: Reintegración automática de servicios al restaurarse

## Estructura del Proyecto

```
ProyectoFinal/
├── configuracion-red/          # Configuración de red netplan
├── proxy-nginx/                # Balanceador de carga NGINX
├── aplicaciones-nodejs/        # Servidores de aplicación CRUD
├── bases-datos/                # Configuración MySQL maestro-esclavo
├── scripts-automatizacion/     # Scripts de despliegue y monitoreo
└── documentacion/              # Documentación técnica completa
```

## URLs de Acceso

- **Aplicación Principal**: http://192.168.218.100 (Balanceada)
- **Estado del Proxy**: http://192.168.218.100:8080
- **App Server 1 Directo**: http://192.168.218.101:3000
- **App Server 2 Directo**: http://192.168.218.103:3000

## Configuración de Red (netplan)

Cada VM utiliza dos interfaces de red:
- **ens33**: DHCP (NAT para Internet)
- **ens37**: IP estática (Red del proyecto)

### Ejemplo de configuración netplan:
```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true     # NAT para Internet
    ens37:            # Red del proyecto
      dhcp4: false
      addresses: [192.168.218.XXX/24]  # IP según el servidor
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

## Base de Datos

### Esquema de Clientes
```sql
CREATE TABLE clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    direccion TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);
```

### Configuración de Replicación

**BD1 (Maestro - 192.168.218.102):**
- server-id = 1
- log-bin activado
- Usuario 'replica' para replicación

**BD2 (Esclavo - 192.168.218.104):**
- server-id = 2
- RAID 1 configurado
- Replica desde BD1

## API CRUD - Endpoints

### Gestión de Clientes

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/` | Listar todos los clientes |
| GET | `/nuevo` | Formulario nuevo cliente |
| POST | `/crear` | Crear nuevo cliente |
| GET | `/editar/:id` | Formulario editar cliente |
| PUT | `/actualizar/:id` | Actualizar cliente |
| DELETE | `/eliminar/:id` | Eliminar cliente |

## Instalación y Configuración

### Requisitos Previos
- Ubuntu Server 20.04+ en cada VM
- 2 interfaces de red configuradas
- Acceso root o sudo

### Configuración Paso a Paso

1. **Configurar red en cada VM**
2. **Instalar y configurar NGINX en Proxy**
3. **Instalar Node.js en App1 y App2**
4. **Configurar MySQL en BD1 y BD2**
5. **Configurar RAID 1 en BD2**
6. **Establecer replicación MySQL**

Ver documentación detallada en [INSTALACION.md](documentacion/INSTALACION.md)

## Usuarios y Credenciales

- **MySQL usuario_bd**: Para conexión desde aplicaciones
- **MySQL replica**: Para replicación BD1→BD2
- **Sistema**: Usuarios locales para cada servicio

## Scripts de Automatización

- `scripts-automatizacion/desplegar.sh` - Despliegue completo
- `scripts-automatizacion/monitorear.sh` - Monitoreo de servicios
- `scripts-automatizacion/respaldo.sh` - Backup de bases de datos
- `scripts-automatizacion/estado-raid.sh` - Verificación RAID 1

## Dominio Configurado

**proxy.sis313.usfx.bo** → 192.168.218.100

## Contribuir

1. Fork el proyecto
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## Licencia

Este proyecto es para fines educativos - Universidad San Francisco Xavier de Chuquisaca - SIS313
