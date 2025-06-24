const winston = require('winston');
const path = require('path');

// Configuración del logger
const logDir = path.join(__dirname, '../../logs');

// Crear directorio de logs si no existe
const fs = require('fs');
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

// Configurar formatos
const logFormat = winston.format.combine(
    winston.format.timestamp({
        format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.printf(({ level, message, timestamp, stack }) => {
        return `${timestamp} [${level.toUpperCase()}]: ${stack || message}`;
    })
);

// Crear logger
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: logFormat,
    transports: [
        // Archivo de log general
        new winston.transports.File({
            filename: path.join(logDir, 'app.log'),
            maxsize: 5242880, // 5MB
            maxFiles: 5,
            tailable: true
        }),
        // Archivo de errores
        new winston.transports.File({
            filename: path.join(logDir, 'error.log'),
            level: 'error',
            maxsize: 5242880, // 5MB
            maxFiles: 5,
            tailable: true
        })
    ],
    exitOnError: false
});

// En desarrollo, también log a consola
if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
        )
    }));
}

module.exports = logger;
