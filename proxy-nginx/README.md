# Configuración del Balanceador de Carga NGINX

## Servidor: Proxy (192.168.218.100)

### Configuración del balanceador NGINX que distribuye tráfico entre App1 y App2

## Instalación

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar NGINX
sudo apt install nginx -y

# Habilitar servicios
sudo systemctl enable nginx
sudo systemctl start nginx
```

## Configuración Principal

### Archivo: `/etc/nginx/conf.d/balanceador.conf`

```nginx
# Configuración de upstream - Servidores de aplicación
upstream servidores_app {
    # Algoritmo de balanceo: round-robin (por defecto)
    server 192.168.218.101:3000 max_fails=3 fail_timeout=30s;  # App1
    server 192.168.218.103:3000 max_fails=3 fail_timeout=30s;  # App2
    
    # Configuración de health checks
    keepalive 32;
}

# Servidor principal - Puerto 80
server {
    listen 80;
    server_name proxy.sis313.usfx.bo 192.168.218.100;

    # Headers de información
    add_header X-Servidor-Proxy $hostname;
    add_header X-Servidor-Upstream $upstream_addr;

    # Balanceador principal
    location / {
        proxy_pass http://servidores_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Configuración de timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Reintentos en caso de fallo
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
    }

    # Health check del balanceador
    location /nginx-health {
        access_log off;
        return 200 "Balanceador funcionando correctamente\n";
        add_header Content-Type text/plain;
    }

    # Página de error personalizada
    error_page 502 503 504 /error.html;
    location = /error.html {
        root /var/www/html;
        internal;
    }
}

# Servidor de estado - Puerto 8080
server {
    listen 8080;
    server_name proxy.sis313.usfx.bo 192.168.218.100;

    root /var/www/proxy-status;
    index index.html;

    # Página informativa del proxy
    location / {
        try_files $uri $uri/ =404;
    }

    # Estado de NGINX
    location /estado-nginx {
        stub_status on;
        access_log off;
        allow 192.168.218.0/24;
        deny all;
    }
}
```

## Página de Estado del Proxy

### Crear directorio:
```bash
sudo mkdir -p /var/www/proxy-status
```

### Archivo: `/var/www/proxy-status/index.html`

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Estado del Proxy - SIS313</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .info-box {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #3498db;
        }
        .server-status {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px;
            margin: 5px 0;
            background: #e8f5e8;
            border-radius: 5px;
        }
        .status-online {
            color: #27ae60;
            font-weight: bold;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #7f8c8d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Estado del Balanceador de Carga</h1>
            <h2>Universidad San Francisco Xavier - SIS313</h2>
            <p><strong>Proxy:</strong> proxy.sis313.usfx.bo (192.168.218.100)</p>
        </div>

        <div class="info-grid">
            <div class="info-box">
                <h3>📊 Información del Sistema</h3>
                <p><strong>Servidor:</strong> Ubuntu Server 20.04</p>
                <p><strong>Servicio:</strong> NGINX Balanceador</p>
                <p><strong>Puerto Web:</strong> 80</p>
                <p><strong>Puerto Estado:</strong> 8080</p>
            </div>

            <div class="info-box">
                <h3>🌐 Servidores de Aplicación</h3>
                <div class="server-status">
                    <span>App1 (192.168.218.101:3000)</span>
                    <span class="status-online">ACTIVO</span>
                </div>
                <div class="server-status">
                    <span>App2 (192.168.218.103:3000)</span>
                    <span class="status-online">ACTIVO</span>
                </div>
            </div>

            <div class="info-box">
                <h3>🛡️ Tolerancia a Fallos</h3>
                <p>✅ Balanceo automático de carga</p>
                <p>✅ Detección de fallos automática</p>
                <p>✅ Reintentos en caso de error</p>
                <p>✅ Health checks activos</p>
            </div>

            <div class="info-box">
                <h3>📈 Enlaces Útiles</h3>
                <p><a href="/">🏠 Aplicación Principal</a></p>
                <p><a href="/nginx-health">💚 Health Check</a></p>
                <p><a href="http://192.168.218.101:3000">🔗 App1 Directa</a></p>
                <p><a href="http://192.168.218.103:3000">🔗 App2 Directa</a></p>
            </div>
        </div>

        <div class="footer">
            <p>Proyecto Final - Infraestructura de Aplicaciones Web</p>
            <p>Actualizado: <script>document.write(new Date().toLocaleString('es-ES'));</script></p>
        </div>
    </div>
</body>
</html>
```

## Página de Error Personalizada

### Archivo: `/var/www/html/error.html`

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Servicio Temporalmente No Disponible</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            color: white;
        }
        .error-container {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            padding: 3rem;
            border-radius: 15px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 600px;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .error-code {
            font-size: 5rem;
            margin: 0;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
        }
        .error-message {
            font-size: 1.8rem;
            margin: 1.5rem 0;
        }
        .error-description {
            font-size: 1.1rem;
            margin-bottom: 2rem;
            opacity: 0.9;
        }
        .back-button {
            background: rgba(255,255,255,0.2);
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 50px;
            display: inline-block;
            transition: all 0.3s ease;
            border: 1px solid rgba(255,255,255,0.3);
        }
        .back-button:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-2px);
        }
        .server-info {
            margin-top: 2rem;
            font-size: 0.9rem;
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <h1 class="error-code">⚠️</h1>
        <h2 class="error-message">Servidores Temporalmente No Disponibles</h2>
        <p class="error-description">
            Los servidores de aplicación están experimentando problemas técnicos.<br>
            El balanceador está intentando restablecer la conexión automáticamente.
        </p>
        <a href="/" class="back-button">🔄 Reintentar</a>
        <div class="server-info">
            <p>Proxy: proxy.sis313.usfx.bo | SIS313 - USFX</p>
        </div>
    </div>
</body>
</html>
```

## Configuración de Firewall

```bash
# Permitir puertos necesarios
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 8080/tcp    # Estado
sudo ufw allow OpenSSH     # SSH
sudo ufw enable
```

## Verificar Configuración

```bash
# Verificar sintaxis
sudo nginx -t

# Recargar configuración
sudo systemctl reload nginx

# Ver estado
sudo systemctl status nginx

# Ver logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Scripts de Monitoreo

### Script: `verificar-balanceador.sh`

```bash
#!/bin/bash
echo "=== Estado del Balanceador NGINX ==="

# Verificar servicio NGINX
if systemctl is-active nginx > /dev/null; then
    echo "✅ NGINX: Activo"
else
    echo "❌ NGINX: Inactivo"
fi

# Verificar conectividad a App1
if curl -s --max-time 5 http://192.168.218.101:3000 > /dev/null; then
    echo "✅ App1: Disponible"
else
    echo "❌ App1: No disponible"
fi

# Verificar conectividad a App2
if curl -s --max-time 5 http://192.168.218.103:3000 > /dev/null; then
    echo "✅ App2: Disponible"
else
    echo "❌ App2: No disponible"
fi

# Verificar balanceador
if curl -s --max-time 5 http://192.168.218.100 > /dev/null; then
    echo "✅ Balanceador: Funcionando"
else
    echo "❌ Balanceador: Error"
fi
```
