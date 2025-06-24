const express = require('express');
const mysql = require('mysql2');
const bodyParser = require('body-parser');
const methodOverride = require('method-override');
const path = require('path');
const helmet = require('helmet');
const compression = require('compression');
const cors = require('cors');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;
const SERVER_NAME = process.env.SERVER_NAME || 'App-Server';

// Configuración de la base de datos
const db = mysql.createConnection({
    host: '192.168.218.102',    // BD1 - Maestro
    user: 'usuario_bd',
    password: 'clave_bd_segura_123',
    database: 'sistema_clientes',
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

// RUTAS PRINCIPALES

// Página principal - Lista de clientes
app.get('/', (req, res) => {
    const sql = `
        SELECT id, nombre, email, telefono, direccion, 
               DATE_FORMAT(fecha_registro, '%d/%m/%Y %H:%i') as fecha_formateada,
               activo
        FROM clientes 
        ORDER BY fecha_registro DESC
    `;
    
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
    const { nombre, email, telefono, direccion } = req.body;
    
    // Validación básica
    if (!nombre || !email) {
        return res.status(400).render('clientes/formulario', {
            titulo: 'Nuevo Cliente',
            cliente: req.body,
            accion: 'crear',
            error: 'Nombre y email son obligatorios'
        });
    }
    
    const sql = `
        INSERT INTO clientes (nombre, email, telefono, direccion, fecha_registro, activo)
        VALUES (?, ?, ?, ?, NOW(), 1)
    `;
    
    db.query(sql, [nombre, email, telefono, direccion], (err, resultado) => {
        if (err) {
            console.error('Error al crear cliente:', err);
            return res.status(500).render('clientes/formulario', {
                titulo: 'Nuevo Cliente',
                cliente: req.body,
                accion: 'crear',
                error: 'Error al guardar el cliente'
            });
        }
        
        console.log(`✅ Cliente creado - ID: ${resultado.insertId}`);
        res.redirect('/?mensaje=Cliente creado exitosamente');
    });
});

// Formulario editar cliente
app.get('/editar/:id', (req, res) => {
    const { id } = req.params;
    
    const sql = 'SELECT * FROM clientes WHERE id = ?';
    db.query(sql, [id], (err, resultados) => {
        if (err || resultados.length === 0) {
            return res.status(404).render('error', {
                mensaje: 'Cliente no encontrado',
                error: err
            });
        }
        
        res.render('clientes/formulario', {
            titulo: 'Editar Cliente',
            cliente: resultados[0],
            accion: 'actualizar'
        });
    });
});

// Actualizar cliente
app.put('/actualizar/:id', (req, res) => {
    const { id } = req.params;
    const { nombre, email, telefono, direccion, activo } = req.body;
    
    const sql = `
        UPDATE clientes 
        SET nombre = ?, email = ?, telefono = ?, direccion = ?, activo = ?
        WHERE id = ?
    `;
    
    db.query(sql, [nombre, email, telefono, direccion, activo ? 1 : 0, id], (err) => {
        if (err) {
            console.error('Error al actualizar cliente:', err);
            return res.status(500).redirect(`/editar/${id}?error=Error al actualizar`);
        }
        
        console.log(`✅ Cliente actualizado - ID: ${id}`);
        res.redirect('/?mensaje=Cliente actualizado exitosamente');
    });
});

// Eliminar cliente
app.delete('/eliminar/:id', (req, res) => {
    const { id } = req.params;
    
    const sql = 'DELETE FROM clientes WHERE id = ?';
    db.query(sql, [id], (err) => {
        if (err) {
            console.error('Error al eliminar cliente:', err);
            return res.status(500).json({ error: 'Error al eliminar cliente' });
        }
        
        console.log(`✅ Cliente eliminado - ID: ${id}`);
        res.json({ mensaje: 'Cliente eliminado exitosamente' });
    });
});

// API JSON para integración
app.get('/api/clientes', (req, res) => {
    const sql = 'SELECT * FROM clientes ORDER BY fecha_registro DESC';
    db.query(sql, (err, clientes) => {
        if (err) {
            return res.status(500).json({ error: 'Error al obtener clientes' });
        }
        res.json({
            servidor: SERVER_NAME,
            total: clientes.length,
            clientes: clientes
        });
    });
});

// Health check
app.get('/health', (req, res) => {
    db.ping((err) => {
        if (err) {
            return res.status(503).json({
                status: 'unhealthy',
                servidor: SERVER_NAME,
                database: 'disconnected',
                timestamp: new Date().toISOString()
            });
        }
        
        res.json({
            status: 'healthy',
            servidor: SERVER_NAME,
            database: 'connected',
            uptime: process.uptime(),
            timestamp: new Date().toISOString()
        });
    });
});

// Manejo de errores 404
app.use((req, res) => {
    res.status(404).render('error', {
        mensaje: 'Página no encontrada',
        error: { status: 404 }
    });
});

// Manejador de errores general
app.use((err, req, res, next) => {
    console.error('Error no manejado:', err);
    res.status(500).render('error', {
        mensaje: 'Error interno del servidor',
        error: err
    });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor ${SERVER_NAME} ejecutándose en puerto ${PORT}`);
    console.log(`📍 Dirección: http://0.0.0.0:${PORT}`);
    console.log(`🗄️  Base de datos: 192.168.218.102 (BD1)`);
});

// Manejo de cierre graceful
process.on('SIGTERM', () => {
    console.log('📴 Cerrando servidor...');
    db.end();
    process.exit(0);
});
