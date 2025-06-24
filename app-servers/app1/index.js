require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const path = require('path');

const { sequelize } = require('../shared/models');
const logger = require('../shared/utils/logger');
const userRoutes = require('./routes/users');
const healthRoutes = require('./routes/health');
const errorHandler = require('../shared/middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3001;
const SERVER_NAME = process.env.SERVER_NAME || 'app1';

// Middleware de seguridad
app.use(helmet());
app.use(compression());

// CORS
app.use(cors({
    origin: process.env.CORS_ORIGIN || '*',
    credentials: true
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutos
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
    message: {
        error: 'Demasiadas solicitudes desde esta IP, intente de nuevo más tarde.'
    },
    standardHeaders: true,
    legacyHeaders: false,
});
app.use('/api/', limiter);

// Logging
app.use(morgan('combined', {
    stream: {
        write: (message) => logger.info(message.trim())
    }
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Headers personalizados
app.use((req, res, next) => {
    res.set('X-Powered-By', 'Node.js');
    res.set('X-Server-Name', SERVER_NAME);
    next();
});

// Rutas principales
app.use('/api/users', userRoutes);
app.use('/health', healthRoutes);

// Ruta raíz
app.get('/', (req, res) => {
    res.json({
        message: `¡Bienvenido al servidor ${SERVER_NAME}!`,
        server: SERVER_NAME,
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV,
        version: require('../package.json').version
    });
});

// Ruta de información del servidor
app.get('/info', (req, res) => {
    res.json({
        server: SERVER_NAME,
        port: PORT,
        environment: process.env.NODE_ENV,
        database: {
            host: process.env.DB_HOST,
            port: process.env.DB_PORT,
            name: process.env.DB_NAME
        },
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        timestamp: new Date().toISOString()
    });
});

// Middleware de manejo de errores
app.use(errorHandler);

// Manejo de rutas no encontradas
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Ruta no encontrada',
        path: req.originalUrl,
        server: SERVER_NAME
    });
});

// Función para iniciar el servidor
async function startServer() {
    try {
        // Verificar conexión a la base de datos
        await sequelize.authenticate();
        logger.info('Conexión a base de datos establecida correctamente');

        // Sincronizar modelos (solo en desarrollo)
        if (process.env.NODE_ENV === 'development') {
            await sequelize.sync({ alter: true });
            logger.info('Modelos sincronizados con la base de datos');
        }

        // Iniciar servidor
        app.listen(PORT, () => {
            logger.info(`Servidor ${SERVER_NAME} ejecutándose en puerto ${PORT}`);
            logger.info(`Entorno: ${process.env.NODE_ENV}`);
            logger.info(`Base de datos: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);
        });

    } catch (error) {
        logger.error('Error al iniciar el servidor:', error);
        process.exit(1);
    }
}

// Manejo de señales de cierre
process.on('SIGTERM', async () => {
    logger.info('Recibida señal SIGTERM, cerrando servidor...');
    await sequelize.close();
    process.exit(0);
});

process.on('SIGINT', async () => {
    logger.info('Recibida señal SIGINT, cerrando servidor...');
    await sequelize.close();
    process.exit(0);
});

// Manejo de errores no capturados
process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception:', error);
    process.exit(1);
});

// Iniciar servidor
if (require.main === module) {
    startServer();
}

module.exports = app;
