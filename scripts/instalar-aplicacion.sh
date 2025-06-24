#!/bin/bash

# Script de Instalación para Servidores de Aplicación (Node.js)
# App1: 192.168.218.101 / App2: 192.168.218.103
# Universidad San Francisco Xavier de Chuquisaca - SIS313

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración - Detectar automáticamente el servidor
CURRENT_IP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $7}')

if [[ "$CURRENT_IP" == "192.168.218.101" ]]; then
    SERVIDOR_NUM="1"
    SERVIDOR_IP="192.168.218.101"
    HOSTNAME_SERVIDOR="app1.sis313.usfx.bo"
    SERVER_NAME="App1-SIS313"
elif [[ "$CURRENT_IP" == "192.168.218.103" ]]; then
    SERVIDOR_NUM="2"
    SERVIDOR_IP="192.168.218.103"
    HOSTNAME_SERVIDOR="app2.sis313.usfx.bo"
    SERVER_NAME="App2-SIS313"
else
    echo -e "${YELLOW}⚠️  No se pudo detectar automáticamente el servidor.${NC}"
    echo "Seleccione el servidor a configurar:"
    echo "1) App1 (192.168.218.101)"
    echo "2) App2 (192.168.218.103)"
    read -p "Opción [1-2]: " opcion
    
    case $opcion in
        1)
            SERVIDOR_NUM="1"
            SERVIDOR_IP="192.168.218.101"
            HOSTNAME_SERVIDOR="app1.sis313.usfx.bo"
            SERVER_NAME="App1-SIS313"
            ;;
        2)
            SERVIDOR_NUM="2"
            SERVIDOR_IP="192.168.218.103"
            HOSTNAME_SERVIDOR="app2.sis313.usfx.bo"
            SERVER_NAME="App2-SIS313"
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            exit 1
            ;;
    esac
fi

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
echo -e "${BLUE}   INSTALACIÓN SERVIDOR APLICACIÓN      ${NC}"
echo -e "${BLUE}   App$SERVIDOR_NUM - IP: $SERVIDOR_IP   ${NC}"
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
hostnamectl set-hostname "app$SERVIDOR_NUM-sis313"

# Configurar /etc/hosts con todos los servidores
cat > /etc/hosts << 'EOF'
127.0.0.1 localhost
127.0.1.1 app-sis313

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
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true  # NAT para Internet
    ens37:         # Red del proyecto (bridged)
      dhcp4: false
      addresses: [$SERVIDOR_IP/24]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: 192.168.218.0/24
          via: 192.168.218.1
EOF

netplan apply
exito "Red configurada"

# 5. INSTALAR NODE.JS Y NPM
log "Instalando Node.js y npm..."

# Instalar Node.js desde repositorio oficial
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# Verificar instalación
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)

exito "Node.js $NODE_VERSION y npm $NPM_VERSION instalados"

# 6. INSTALAR HERRAMIENTAS ADICIONALES
log "Instalando herramientas adicionales..."
apt install -y git curl wget unzip build-essential mysql-client
exito "Herramientas adicionales instaladas"

# 7. CREAR USUARIO PARA LA APLICACIÓN
log "Creando usuario para la aplicación..."
if ! id nodejs &>/dev/null; then
    useradd --system --create-home --shell /bin/bash nodejs
    usermod -aG sudo nodejs
    exito "Usuario nodejs creado"
else
    log "Usuario nodejs ya existe"
fi

# 8. CONFIGURAR FIREWALL
log "Configurando firewall UFW..."
ufw --force enable
ufw allow OpenSSH
ufw allow 3000/tcp
ufw allow from 192.168.218.0/24
exito "Firewall configurado"

# 9. CREAR ESTRUCTURA DE DIRECTORIOS
log "Creando estructura de directorios..."
mkdir -p /opt/aplicacion-nodejs/{logs,config,uploads,temp}
mkdir -p /var/log/aplicacion-nodejs
chown -R nodejs:nodejs /opt/aplicacion-nodejs
chown -R nodejs:nodejs /var/log/aplicacion-nodejs
exito "Estructura de directorios creada"

# 10. CREAR APLICACIÓN NODE.JS
log "Creando aplicación Node.js..."

# Package.json
cat > /opt/aplicacion-nodejs/package.json << 'EOF'
{
  "name": "sistema-clientes-sis313",
  "version": "1.0.0",
  "description": "Sistema de gestión de clientes - Proyecto Final SIS313",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "echo \"No tests specified\" && exit 0",
    "lint": "eslint .",
    "prod": "NODE_ENV=production node index.js"
  },
  "keywords": ["node", "express", "mysql", "crud", "sis313"],
  "author": "Estudiantes SIS313 - USFX",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.5",
    "ejs": "^3.1.9",
    "body-parser": "^1.20.2",
    "method-override": "^3.0.0",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  },
  "engines": {
    "node": ">=16.0.0",
    "npm": ">=8.0.0"
  }
}
EOF

# Aplicación principal (index.js)
cat > /opt/aplicacion-nodejs/index.js << EOF
const express = require('express');
const mysql = require('mysql2');
const bodyParser = require('body-parser');
const methodOverride = require('method-override');
const path = require('path');
const helmet = require('helmet');
const compression = require('compression');
const cors = require('cors');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const SERVER_NAME = process.env.SERVER_NAME || '$SERVER_NAME';

// Configuración de la base de datos
const db = mysql.createConnection({
    host: process.env.DB_HOST || '192.168.218.102',
    user: process.env.DB_USER || 'usuario_bd',
    password: process.env.DB_PASS || 'clave_bd_segura_123',
    database: process.env.DB_NAME || 'sistema_clientes',
    charset: 'utf8mb4'
});

// Verificar conexión a BD
db.connect((err) => {
    if (err) {
        console.error('❌ Error conectando a la base de datos:', err);
        process.exit(1);
    }
    console.log('✅ Conectado a MySQL - BD1 (Maestro)');
});

// Configuración de middlewares
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(morgan('combined'));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(methodOverride('_method'));

// Configuración de archivos estáticos
app.use(express.static(path.join(__dirname, 'public')));

// Configuración del motor de plantillas
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Middleware para información del servidor
app.use((req, res, next) => {
    res.locals.servidor = SERVER_NAME;
    res.locals.fecha = new Date().toLocaleString('es-ES');
    next();
});

// HEALTH CHECK
app.get('/health', (req, res) => {
    const healthCheck = {
        status: 'OK',
        timestamp: new Date().toISOString(),
        servidor: SERVER_NAME,
        ip: '$SERVIDOR_IP',
        puerto: PORT,
        baseDatos: 'Conectada',
        memoria: process.memoryUsage(),
        uptime: process.uptime()
    };
    
    res.status(200).json(healthCheck);
});

// API DE ESTADÍSTICAS
app.get('/api/stats', (req, res) => {
    const sql = 'SELECT COUNT(*) as total, SUM(activo) as activos FROM clientes';
    
    db.query(sql, (err, results) => {
        if (err) {
            return res.status(500).json({ error: 'Error obteniendo estadísticas' });
        }
        
        const stats = {
            servidor: SERVER_NAME,
            ip: '$SERVIDOR_IP',
            timestamp: new Date().toISOString(),
            clientes: {
                total: results[0].total,
                activos: results[0].activos,
                inactivos: results[0].total - results[0].activos
            },
            sistema: {
                memoria: process.memoryUsage(),
                uptime: process.uptime(),
                version: process.version
            }
        };
        
        res.json(stats);
    });
});

// Página principal - Lista de clientes
app.get('/', (req, res) => {
    const sql = \`
        SELECT id, nombre, email, telefono, direccion, 
               DATE_FORMAT(fecha_registro, '%d/%m/%Y %H:%i') as fecha_formateada,
               activo
        FROM clientes 
        ORDER BY fecha_registro DESC
    \`;
    
    db.query(sql, (err, clientes) => {
        if (err) {
            console.error('Error al obtener clientes:', err);
            return res.status(500).render('error', { 
                mensaje: 'Error al cargar los clientes',
                error: err 
            });
        }
        
        res.render('clientes/lista', { 
            titulo: 'Lista de Clientes',
            clientes: clientes,
            total: clientes.length
        });
    });
});

// Formulario nuevo cliente
app.get('/nuevo', (req, res) => {
    res.render('clientes/formulario', {
        titulo: 'Nuevo Cliente',
        cliente: {},
        accion: 'crear'
    });
});

// Crear cliente
app.post('/crear', (req, res) => {
    const { nombre, email, telefono, direccion, activo } = req.body;
    
    if (!nombre || !email) {
        return res.status(400).render('clientes/formulario', {
            titulo: 'Nuevo Cliente',
            cliente: req.body,
            accion: 'crear',
            error: 'Nombre y email son obligatorios'
        });
    }
    
    const sql = \`
        INSERT INTO clientes (nombre, email, telefono, direccion, activo, fecha_registro) 
        VALUES (?, ?, ?, ?, ?, NOW())
    \`;
    
    db.query(sql, [nombre, email, telefono || null, direccion || null, activo ? 1 : 0], (err, result) => {
        if (err) {
            console.error('Error creando cliente:', err);
            return res.status(500).render('clientes/formulario', {
                titulo: 'Nuevo Cliente',
                cliente: req.body,
                accion: 'crear',
                error: 'Error al crear el cliente'
            });
        }
        
        console.log(\`✅ Cliente creado: ID \${result.insertId} - \${nombre}\`);
        res.redirect('/');
    });
});

// Ver/Editar cliente
app.get('/editar/:id', (req, res) => {
    const id = req.params.id;
    const sql = \`
        SELECT *, DATE_FORMAT(fecha_registro, '%d/%m/%Y %H:%i') as fecha_formateada 
        FROM clientes WHERE id = ?
    \`;
    
    db.query(sql, [id], (err, results) => {
        if (err || results.length === 0) {
            return res.status(404).render('error', {
                mensaje: 'Cliente no encontrado'
            });
        }
        
        res.render('clientes/formulario', {
            titulo: 'Editar Cliente',
            cliente: results[0],
            accion: 'editar'
        });
    });
});

// Actualizar cliente
app.put('/actualizar/:id', (req, res) => {
    const id = req.params.id;
    const { nombre, email, telefono, direccion, activo } = req.body;
    
    if (!nombre || !email) {
        return res.status(400).redirect(\`/editar/\${id}\`);
    }
    
    const sql = \`
        UPDATE clientes 
        SET nombre = ?, email = ?, telefono = ?, direccion = ?, activo = ?
        WHERE id = ?
    \`;
    
    db.query(sql, [nombre, email, telefono || null, direccion || null, activo ? 1 : 0, id], (err, result) => {
        if (err) {
            console.error('Error actualizando cliente:', err);
            return res.status(500).redirect(\`/editar/\${id}\`);
        }
        
        console.log(\`✅ Cliente actualizado: ID \${id} - \${nombre}\`);
        res.redirect('/');
    });
});

// Eliminar cliente
app.delete('/eliminar/:id', (req, res) => {
    const id = req.params.id;
    const sql = 'DELETE FROM clientes WHERE id = ?';
    
    db.query(sql, [id], (err, result) => {
        if (err) {
            console.error('Error eliminando cliente:', err);
            return res.status(500).redirect('/');
        }
        
        console.log(\`🗑️ Cliente eliminado: ID \${id}\`);
        res.redirect('/');
    });
});

// Manejo de errores 404
app.use((req, res) => {
    res.status(404).render('error', {
        mensaje: 'Página no encontrada'
    });
});

// Manejo de errores generales
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).render('error', {
        mensaje: 'Error interno del servidor'
    });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
    console.log(\`\`);
    console.log(\`🚀 Servidor \${SERVER_NAME} iniciado exitosamente!\`);
    console.log(\`📡 IP: $SERVIDOR_IP\`);
    console.log(\`🌐 Puerto: \${PORT}\`);
    console.log(\`🗄️ Base de datos: MySQL (192.168.218.102)\`);
    console.log(\`⏰ Fecha: \${new Date().toLocaleString('es-ES')}\`);
    console.log(\`\`);
    console.log(\`🔗 URLs disponibles:\`);
    console.log(\`   http://$SERVIDOR_IP:\${PORT}/       - Aplicación principal\`);
    console.log(\`   http://$SERVIDOR_IP:\${PORT}/health - Health check\`);
    console.log(\`   http://$SERVIDOR_IP:\${PORT}/stats  - Estadísticas\`);
    console.log(\`\`);
});

// Manejo graceful de cierre
process.on('SIGTERM', () => {
    console.log('🛑 Recibida señal SIGTERM, cerrando servidor...');
    db.end();
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Recibida señal SIGINT, cerrando servidor...');
    db.end();
    process.exit(0);
});
EOF

# Archivo de configuración .env
cat > /opt/aplicacion-nodejs/.env << EOF
# Configuración de Producción - $SERVER_NAME
NODE_ENV=production
PORT=3000
SERVER_NAME=$SERVER_NAME

# Base de Datos
DB_HOST=192.168.218.102
DB_USER=usuario_bd
DB_PASS=clave_bd_segura_123
DB_NAME=sistema_clientes

# Configuración de Logs
LOG_LEVEL=info
LOG_FILE=/var/log/aplicacion-nodejs/app.log

# Configuración de Seguridad
SESSION_SECRET=clave_sesion_super_secreta_2024_$SERVER_NAME
JWT_SECRET=jwt_token_secreto_sis313_$SERVER_NAME
EOF

# Cambiar propietario
chown -R nodejs:nodejs /opt/aplicacion-nodejs/
exito "Aplicación Node.js creada"

# 11. CREAR PLANTILLAS EJS (simplificadas para instalación)
log "Creando plantillas EJS..."
mkdir -p /opt/aplicacion-nodejs/views/{clientes,layouts}

# Layout principal simplificado
cat > /opt/aplicacion-nodejs/views/layout.ejs << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= locals.titulo || 'Sistema SIS313' %></title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="/"><i class="fas fa-university"></i> Sistema SIS313</a>
            <div class="navbar-text">
                Servidor: <%= locals.servidor || 'App-Server' %> | <%= locals.fecha || new Date().toLocaleString('es-ES') %>
            </div>
        </div>
    </nav>
    <div class="container mt-4">
        <%- body %>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF

# Página de error
cat > /opt/aplicacion-nodejs/views/error.ejs << 'EOF'
<div class="alert alert-danger">
    <h4><i class="fas fa-exclamation-triangle"></i> Error</h4>
    <p><%= mensaje %></p>
    <a href="/" class="btn btn-primary">Volver al inicio</a>
</div>
EOF

chown -R nodejs:nodejs /opt/aplicacion-nodejs/views/
exito "Plantillas EJS creadas"

# 12. INSTALAR DEPENDENCIAS
log "Instalando dependencias de Node.js..."
cd /opt/aplicacion-nodejs
sudo -u nodejs npm install
exito "Dependencias instaladas"

# 13. CREAR SERVICIO SYSTEMD
log "Creando servicio systemd..."
cat > /etc/systemd/system/aplicacion-nodejs.service << EOF
[Unit]
Description=Aplicación Node.js - Sistema de Clientes SIS313
Documentation=https://github.com/usuario/proyecto-final-sis313
After=network.target mysql.service

[Service]
Type=simple
User=nodejs
Group=nodejs
WorkingDirectory=/opt/aplicacion-nodejs
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Variables de entorno
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=SERVER_NAME=$SERVER_NAME
Environment=DB_HOST=192.168.218.102

# Límites de recursos
LimitNOFILE=65536
LimitNPROC=4096

# Seguridad
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable aplicacion-nodejs
exito "Servicio systemd configurado"

# 14. CREAR SCRIPT DE VERIFICACIÓN
cat > /usr/local/bin/verificar-app.sh << EOF
#!/bin/bash

echo "======================================"
echo "  VERIFICACIÓN APLICACIÓN NODE.JS"
echo "  Servidor: $SERVER_NAME"
echo "======================================"

# Verificar servicio
if systemctl is-active --quiet aplicacion-nodejs; then
    echo "✅ Servicio: ACTIVO"
else
    echo "❌ Servicio: INACTIVO"
fi

# Verificar puerto
if netstat -tuln | grep -q ":3000"; then
    echo "✅ Puerto 3000: ESCUCHANDO"
else
    echo "❌ Puerto 3000: NO DISPONIBLE"
fi

# Verificar conectividad a BD
if timeout 5 bash -c "</dev/tcp/192.168.218.102/3306" 2>/dev/null; then
    echo "✅ Conexión BD: EXITOSA"
else
    echo "❌ Conexión BD: FALLO"
fi

# Test HTTP
response=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null || echo "000")
if [ "\$response" = "200" ]; then
    echo "✅ Health Check: OK (\$response)"
else
    echo "❌ Health Check: FALLO (\$response)"
fi

echo ""
echo "🔗 URLs de verificación:"
echo "- Health: http://$SERVIDOR_IP:3000/health"
echo "- Stats: http://$SERVIDOR_IP:3000/api/stats"
echo "- App: http://$SERVIDOR_IP:3000/"
EOF

chmod +x /usr/local/bin/verificar-app.sh

# 15. CONFIGURAR LOGS
log "Configurando sistema de logs..."
mkdir -p /var/log/aplicacion-nodejs
chown nodejs:nodejs /var/log/aplicacion-nodejs

# Configuración de logrotate
cat > /etc/logrotate.d/aplicacion-nodejs << 'EOF'
/var/log/aplicacion-nodejs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 nodejs nodejs
    postrotate
        systemctl reload aplicacion-nodejs > /dev/null 2>&1 || true
    endscript
}
EOF

exito "Sistema de logs configurado"

# 16. INICIAR SERVICIOS
log "Iniciando aplicación..."
systemctl start aplicacion-nodejs

# Esperar que el servicio esté completamente levantado
sleep 5

if systemctl is-active --quiet aplicacion-nodejs; then
    exito "Aplicación iniciada correctamente"
else
    error "Error iniciando la aplicación"
fi

# 17. MOSTRAR RESUMEN
echo -e "\n${GREEN}===========================================${NC}"
echo -e "${GREEN}     INSTALACIÓN COMPLETADA              ${NC}"
echo -e "${GREEN}===========================================${NC}"

echo -e "\n📊 INFORMACIÓN DEL SERVIDOR:"
echo -e "🖥️  Hostname: $(hostname)"
echo -e "🌐 IP: $SERVIDOR_IP"
echo -e "📱 Servidor: $SERVER_NAME"
echo -e "⚡ Servicios activos:"
systemctl is-active aplicacion-nodejs && echo "  ✅ aplicacion-nodejs"

echo -e "\n🔗 URLs de acceso:"
echo -e "  🏠 Aplicación: http://$SERVIDOR_IP:3000/"
echo -e "  🩺 Health: http://$SERVIDOR_IP:3000/health"
echo -e "  📊 Stats: http://$SERVIDOR_IP:3000/api/stats"

echo -e "\n📋 Comandos útiles:"
echo -e "  Verificar app: /usr/local/bin/verificar-app.sh"
echo -e "  Reiniciar: systemctl restart aplicacion-nodejs"
echo -e "  Ver logs: journalctl -u aplicacion-nodejs -f"
echo -e "  Estado: systemctl status aplicacion-nodejs"

echo -e "\n${BLUE}Instalación del servidor de aplicación completada exitosamente!${NC}"

# 18. EJECUTAR VERIFICACIÓN INICIAL
log "Ejecutando verificación inicial..."
sleep 3
/usr/local/bin/verificar-app.sh

# 19. MOSTRAR LOGS EN TIEMPO REAL (opcional)
echo -e "\n${YELLOW}Para ver los logs en tiempo real ejecute:${NC}"
echo -e "journalctl -u aplicacion-nodejs -f"

echo -e "\n${GREEN}¡Instalación completada! El servidor está listo para uso.${NC}"
