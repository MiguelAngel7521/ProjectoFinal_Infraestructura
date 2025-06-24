#!/bin/bash

# Script de Instalación para Servidor Proxy (NGINX)
# IP: 192.168.218.100
# Universidad San Francisco Xavier de Chuquisaca - SIS313

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
SERVIDOR_IP="192.168.218.100"
HOSTNAME_SERVIDOR="proxy.sis313.usfx.bo"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

exito() {
    echo -e "${GREEN}[ÉXITO] $1${NC}"
}

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}   INSTALACIÓN SERVIDOR PROXY NGINX     ${NC}"
echo -e "${BLUE}   IP: $SERVIDOR_IP                     ${NC}"
echo -e "${BLUE}===========================================${NC}"

# 1. VERIFICAR USUARIO ROOT
if [ "$EUID" -ne 0 ]; then
    error "Este script debe ejecutarse como root o con sudo"
fi

# 2. ACTUALIZAR SISTEMA
log "Actualizando sistema operativo..."
apt update && apt upgrade -y
exito "Sistema actualizado"

# 3. CONFIGURAR HOSTNAME Y HOSTS
log "Configurando hostname y archivo hosts..."
hostnamectl set-hostname proxy-sis313
echo "127.0.0.1 $HOSTNAME_SERVIDOR proxy-sis313" >> /etc/hosts

# Configurar /etc/hosts con todos los servidores
cat >> /etc/hosts << 'EOF'

# Servidores del Proyecto SIS313
192.168.218.100 proxy.sis313.usfx.bo proxy-sis313
192.168.218.101 app1.sis313.usfx.bo app1-sis313
192.168.218.102 bd1.sis313.usfx.bo bd1-sis313
192.168.218.103 app2.sis313.usfx.bo app2-sis313
192.168.218.104 bd2.sis313.usfx.bo bd2-sis313
EOF

exito "Hostname y hosts configurados"

# 4. CONFIGURAR RED CON NETPLAN
log "Configurando interfaz de red con netplan..."
cat > /etc/netplan/01-netcfg.yaml << 'EOF'
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true  # NAT para Internet
    ens37:         # Red del proyecto (bridged)
      dhcp4: false
      addresses: [192.168.218.100/24]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: 192.168.218.0/24
          via: 192.168.218.1
EOF

netplan apply
exito "Red configurada"

# 5. INSTALAR NGINX
log "Instalando NGINX..."
apt install nginx -y
systemctl enable nginx
systemctl start nginx
exito "NGINX instalado"

# 6. CONFIGURAR FIREWALL
log "Configurando firewall UFW..."
ufw --force enable
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw allow 80/tcp
ufw allow 8080/tcp
ufw allow 443/tcp
exito "Firewall configurado"

# 7. CREAR CONFIGURACIÓN DEL BALANCEADOR
log "Configurando balanceador de carga..."

# Crear directorio para configuraciones personalizadas
mkdir -p /etc/nginx/conf.d

# Configuración principal del balanceador
cat > /etc/nginx/conf.d/balanceador.conf << 'EOF'
# Configuración upstream - Servidores de aplicación
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

    # Logs específicos
    access_log /var/log/nginx/balanceador_access.log;
    error_log /var/log/nginx/balanceador_error.log;

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
        return 200 "Balanceador NGINX funcionando correctamente\\nFecha: $time_local\\nServidor: $hostname\\n";
        add_header Content-Type text/plain;
    }

    # Página de error personalizada
    error_page 502 503 504 @error_backend;
    location @error_backend {
        root /var/www/html;
        try_files /50x.html =502;
    }
}
EOF

# 8. CREAR SERVIDOR DE ESTADO EN PUERTO 8080
cat > /etc/nginx/conf.d/estado.conf << 'EOF'
# Servidor de estado y monitoreo - Puerto 8080
server {
    listen 8080;
    server_name proxy.sis313.usfx.bo 192.168.218.100;
    
    root /var/www/proxy-status;
    index index.html;
    
    # Logs específicos para monitoreo
    access_log /var/log/nginx/status_access.log;
    error_log /var/log/nginx/status_error.log;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Status de NGINX
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 192.168.218.0/24;
        deny all;
    }
    
    # Información del sistema
    location /system-info {
        access_log off;
        return 200 "Sistema: Ubuntu Server\\nServidor: Proxy NGINX\\nIP: 192.168.218.100\\nFecha: $time_local\\nUptime: Sistema iniciado\\n";
        add_header Content-Type text/plain;
    }
}
EOF

# 9. CREAR PÁGINAS WEB DE ESTADO
log "Creando páginas web de estado..."

# Directorio principal para páginas de estado
mkdir -p /var/www/proxy-status
mkdir -p /var/www/html

# Página principal de estado
cat > /var/www/proxy-status/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Estado del Proxy - SIS313</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 20px;
            color: white;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            padding: 30px;
            backdrop-filter: blur(10px);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .status-card {
            background: rgba(255, 255, 255, 0.2);
            border-radius: 10px;
            padding: 20px;
            text-align: center;
        }
        .status-ok { border-left: 5px solid #00ff88; }
        .status-warning { border-left: 5px solid #ffaa00; }
        .status-error { border-left: 5px solid #ff4444; }
        .btn {
            background: rgba(255, 255, 255, 0.2);
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            text-decoration: none;
            display: inline-block;
            margin: 5px;
            cursor: pointer;
        }
        .btn:hover {
            background: rgba(255, 255, 255, 0.3);
        }
    </style>
    <script>
        function actualizarEstado() {
            location.reload();
        }
        
        // Auto-refresh cada 30 segundos
        setInterval(actualizarEstado, 30000);
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ Estado del Servidor Proxy</h1>
            <h2>Universidad San Francisco Xavier de Chuquisaca - SIS313</h2>
            <p>IP: 192.168.218.100 | Hostname: proxy.sis313.usfx.bo</p>
        </div>
        
        <div class="status-grid">
            <div class="status-card status-ok">
                <h3>🌐 Balanceador NGINX</h3>
                <p>Estado: <strong>ACTIVO</strong></p>
                <p>Puerto: 80</p>
                <a href="/nginx-health" class="btn">Health Check</a>
            </div>
            
            <div class="status-card status-ok">
                <h3>📊 Monitoreo</h3>
                <p>Estado: <strong>FUNCIONANDO</strong></p>
                <p>Puerto: 8080</p>
                <a href="/nginx_status" class="btn">NGINX Status</a>
            </div>
            
            <div class="status-card status-ok">
                <h3>🎯 Servidores de Aplicación</h3>
                <p>App1: 192.168.218.101:3000</p>
                <p>App2: 192.168.218.103:3000</p>
                <a href="http://192.168.218.101:3000" class="btn" target="_blank">Test App1</a>
                <a href="http://192.168.218.103:3000" class="btn" target="_blank">Test App2</a>
            </div>
            
            <div class="status-card status-ok">
                <h3>🗄️ Bases de Datos</h3>
                <p>BD1 (Maestro): 192.168.218.102:3306</p>
                <p>BD2 (Esclavo): 192.168.218.104:3306</p>
            </div>
        </div>
        
        <div style="text-align: center; margin-top: 30px;">
            <a href="/" class="btn">🏠 Aplicación Principal</a>
            <button onclick="actualizarEstado()" class="btn">🔄 Actualizar Estado</button>
            <a href="/system-info" class="btn">ℹ️ Info del Sistema</a>
        </div>
        
        <div style="text-align: center; margin-top: 20px; font-size: 12px;">
            <p>Actualización automática cada 30 segundos</p>
            <p>Proyecto Final - Infraestructura de Sistemas</p>
        </div>
    </div>
</body>
</html>
EOF

# Página de error 50x personalizada
cat > /var/www/html/50x.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Error 500 - Servidor No Disponible</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .error-container {
            background: white;
            padding: 2rem;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
        }
        .error-code {
            font-size: 4rem;
            color: #e74c3c;
            margin: 0;
        }
        .error-message {
            font-size: 1.5rem;
            color: #333;
            margin: 1rem 0;
        }
        .error-description {
            color: #666;
            margin-bottom: 2rem;
        }
        .back-button {
            background-color: #3498db;
            color: white;
            padding: 0.75rem 1.5rem;
            text-decoration: none;
            border-radius: 4px;
            display: inline-block;
        }
        .back-button:hover {
            background-color: #2980b9;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <h1 class="error-code">50x</h1>
        <h2 class="error-message">Servidores Temporalmente No Disponibles</h2>
        <p class="error-description">
            Los servidores de aplicación están experimentando problemas técnicos. 
            Por favor, inténtelo de nuevo en unos momentos.
        </p>
        <p class="error-description">
            <strong>Proyecto SIS313 - USFX</strong><br>
            Balanceador NGINX - IP: 192.168.218.100
        </p>
        <a href="http://192.168.218.100:8080" class="back-button">📊 Ver Estado del Sistema</a>
        <a href="/" class="back-button">🔄 Reintentar</a>
    </div>
</body>
</html>
EOF

# 10. CONFIGURAR PERMISOS
chown -R www-data:www-data /var/www/
chmod -R 755 /var/www/

# 11. CREAR SCRIPT DE VERIFICACIÓN
cat > /usr/local/bin/verificar-balanceador.sh << 'EOF'
#!/bin/bash

# Script de Verificación del Balanceador - SIS313
# Ejecutar: /usr/local/bin/verificar-balanceador.sh

echo "======================================"
echo "  VERIFICACIÓN BALANCEADOR NGINX"
echo "======================================"

# Verificar servicio NGINX
if systemctl is-active --quiet nginx; then
    echo "✅ NGINX: ACTIVO"
else
    echo "❌ NGINX: INACTIVO"
fi

# Verificar puertos
echo ""
echo "📡 PUERTOS EN ESCUCHA:"
netstat -tuln | grep -E ":80|:8080"

# Verificar conectividad a apps
echo ""
echo "🎯 CONECTIVIDAD A APLICACIONES:"
for app in "192.168.218.101:3000" "192.168.218.103:3000"; do
    if timeout 5 bash -c "</dev/tcp/${app/:/ }" 2>/dev/null; then
        echo "✅ $app: ALCANZABLE"
    else
        echo "❌ $app: NO ALCANZABLE"
    fi
done

# Test del balanceador
echo ""
echo "⚖️  TEST DE BALANCEO:"
for i in {1..5}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
    echo "Petición $i: HTTP $response"
done

echo ""
echo "🔗 URLs de verificación:"
echo "- Aplicación: http://192.168.218.100/"
echo "- Estado: http://192.168.218.100:8080/"
echo "- Health: http://192.168.218.100/nginx-health"
EOF

chmod +x /usr/local/bin/verificar-balanceador.sh

# 12. VALIDAR CONFIGURACIÓN
log "Validando configuración de NGINX..."
nginx -t
if [ $? -eq 0 ]; then
    exito "Configuración de NGINX válida"
    systemctl reload nginx
else
    error "Error en configuración de NGINX"
fi

# 13. REINICIAR SERVICIOS
log "Reiniciando servicios..."
systemctl restart nginx
systemctl status nginx --no-pager

# 14. MOSTRAR RESUMEN
echo -e "\n${GREEN}===========================================${NC}"
echo -e "${GREEN}     INSTALACIÓN COMPLETADA              ${NC}"
echo -e "${GREEN}===========================================${NC}"

echo -e "\n📊 INFORMACIÓN DEL SERVIDOR:"
echo -e "🖥️  Hostname: $(hostname)"
echo -e "🌐 IP: $SERVIDOR_IP"
echo -e "⚡ Servicios activos:"
systemctl is-active nginx && echo "  ✅ NGINX"

echo -e "\n🔗 URLs de acceso:"
echo -e "  🏠 Aplicación: http://$SERVIDOR_IP/"
echo -e "  📊 Estado: http://$SERVIDOR_IP:8080/"
echo -e "  🩺 Health: http://$SERVIDOR_IP/nginx-health"

echo -e "\n📋 Comandos útiles:"
echo -e "  Verificar balanceador: /usr/local/bin/verificar-balanceador.sh"
echo -e "  Reiniciar NGINX: systemctl restart nginx"
echo -e "  Ver logs: tail -f /var/log/nginx/balanceador_*.log"

echo -e "\n${BLUE}Instalación del servidor Proxy completada exitosamente!${NC}"

# 15. EJECUTAR VERIFICACIÓN INICIAL
log "Ejecutando verificación inicial..."
sleep 3
/usr/local/bin/verificar-balanceador.sh
