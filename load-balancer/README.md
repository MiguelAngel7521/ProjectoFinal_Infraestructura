# Configuración del Balanceador de Carga

Este directorio contiene la configuración de NGINX como balanceador de carga.

## Archivos

- `nginx.conf` - Configuración principal de NGINX
- `sites-available/` - Configuraciones de sitios disponibles
- `ssl/` - Certificados SSL (si se implementa HTTPS)
- `Dockerfile` - Para contenedor Docker

## Configuración

El balanceador está configurado para:
- Distribuir tráfico entre app1:3001 y app2:3002
- Usar algoritmo round-robin
- Manejar fallos de conexión
- Servir archivos estáticos

## Puertos

- Puerto 80: HTTP
- Puerto 443: HTTPS (opcional)
