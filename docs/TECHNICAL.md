# Documentación Técnica - Proyecto Final

## Arquitectura del Sistema

### Componentes Principales

1. **Balanceador de Carga (NGINX)**
   - Distribuye tráfico entre servidores de aplicación
   - Implementa health checks
   - Maneja SSL/TLS termination

2. **Servidores de Aplicación (Node.js)**
   - API REST con CRUD básico
   - Conexión a base de datos con pool de conexiones
   - Logging estructurado y manejo de errores

3. **Bases de Datos (MySQL)**
   - Configuración Maestro-Esclavo
   - Replicación automática
   - Backup automatizado

4. **Servidor FTP (vsftpd)**
   - Usuarios virtuales para despliegue
   - Conexiones seguras con SSL/TLS
   - Directorio chroot para seguridad

## Configuraciones de Red

### Puertos Utilizados

- 80: HTTP (Balanceador)
- 443: HTTPS (Balanceador)
- 3001: App Server 1
- 3002: App Server 2
- 3306: MySQL Master
- 3307: MySQL Slave
- 21: FTP Control
- 21000-21010: FTP Data (Passive Mode)

### Redes Docker

- `proyecto-final-network`: Red bridge para comunicación entre contenedores

## Base de Datos

### Esquema de Usuario

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    age INT NULL CHECK (age > 0 AND age <= 120),
    phone VARCHAR(20) NULL,
    isActive BOOLEAN NOT NULL DEFAULT TRUE,
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Configuración de Replicación

**Master:**
- server-id = 1
- log-bin = mysql-bin
- binlog-format = ROW

**Slave:**
- server-id = 2
- read-only = 1
- relay-log = relay-log

## API Endpoints

### Usuarios

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/users` | Listar usuarios |
| GET | `/api/users/:id` | Obtener usuario |
| POST | `/api/users` | Crear usuario |
| PUT | `/api/users/:id` | Actualizar usuario |
| DELETE | `/api/users/:id` | Eliminar usuario |

### Sistema

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/health/detailed` | Health check detallado |
| GET | `/info` | Información del servidor |

## Seguridad

### Medidas Implementadas

1. **Aplicación:**
   - Validación de entrada con Joi
   - Rate limiting
   - Helmet.js para headers de seguridad
   - CORS configurado

2. **Base de Datos:**
   - Usuarios con permisos mínimos
   - Conexiones SSL (opcional)
   - Backup cifrado

3. **FTP:**
   - Usuarios virtuales
   - Chroot jail
   - SSL/TLS habilitado

4. **Infraestructura:**
   - Contenedores no-root
   - Redes aisladas
   - Volúmenes persistentes

## Monitoreo y Logs

### Ubicación de Logs

- Aplicación: `/app/logs/`
- NGINX: `/var/log/nginx/`
- MySQL: `/var/log/mysql/`
- FTP: `/var/log/vsftpd.log`

### Métricas Monitoreadas

- Estado de contenedores
- Conectividad HTTP/HTTPS
- Estado de replicación de BD
- Uso de recursos (CPU/Memoria)
- Errores en logs

## Backup y Recuperación

### Estrategia de Backup

1. **Base de Datos:**
   - Backup completo diario
   - Backup incremental cada 6 horas
   - Retención: 30 días

2. **Aplicación:**
   - Backup antes de cada despliegue
   - Código en repositorio Git

### Procedimiento de Recuperación

1. Detener servicios afectados
2. Restaurar desde backup más reciente
3. Verificar integridad de datos
4. Reiniciar servicios
5. Verificar funcionalidad

## Despliegue

### Proceso Automatizado

1. **Preparación:**
   - Verificar prerequisites
   - Crear backup de seguridad

2. **Construcción:**
   - Build de imágenes Docker
   - Verificación de configuraciones

3. **Despliegue:**
   - Stop de servicios existentes
   - Actualización de contenedores
   - Health checks

4. **Verificación:**
   - Tests de conectividad
   - Verificación de logs
   - Monitoreo post-despliegue

## Solución de Problemas

### Problemas Comunes

1. **Aplicación no responde:**
   - Verificar logs de aplicación
   - Comprobar conexión a BD
   - Reiniciar contenedor

2. **Replicación de BD falla:**
   - Verificar conectividad entre master/slave
   - Comprobar configuración de replicación
   - Resetear replicación si es necesario

3. **Balanceador devuelve 502:**
   - Verificar estado de app servers
   - Comprobar configuración de upstream
   - Revisar logs de NGINX

### Comandos de Diagnóstico

```bash
# Estado de servicios
docker-compose ps

# Logs de un servicio
docker-compose logs -f [servicio]

# Health check manual
curl http://localhost/health

# Estado de replicación
docker exec proyecto-db-slave mysql -u root -proot_password_123 -e "SHOW SLAVE STATUS\G"
```
