const logger = require('../utils/logger');

const errorHandler = (err, req, res, next) => {
    let error = { ...err };
    error.message = err.message;

    // Log del error
    logger.error(err);

    // Error de validación de Sequelize
    if (err.name === 'SequelizeValidationError') {
        const message = err.errors.map(e => e.message).join(', ');
        error = {
            message: 'Error de validación',
            details: err.errors.map(e => ({
                field: e.path,
                message: e.message
            }))
        };
        return res.status(400).json({
            success: false,
            error: error.message,
            details: error.details,
            server: process.env.SERVER_NAME || 'unknown'
        });
    }

    // Error de clave duplicada
    if (err.name === 'SequelizeUniqueConstraintError') {
        const message = 'Valor duplicado encontrado';
        return res.status(400).json({
            success: false,
            error: message,
            details: err.errors.map(e => ({
                field: e.path,
                message: e.message
            })),
            server: process.env.SERVER_NAME || 'unknown'
        });
    }

    // Error de conexión a base de datos
    if (err.name === 'SequelizeConnectionError' || 
        err.name === 'SequelizeConnectionRefusedError') {
        return res.status(503).json({
            success: false,
            error: 'Error de conexión a la base de datos',
            server: process.env.SERVER_NAME || 'unknown'
        });
    }

    // Error de sintaxis JSON
    if (err.name === 'SyntaxError' && err.message.includes('JSON')) {
        return res.status(400).json({
            success: false,
            error: 'JSON malformado',
            server: process.env.SERVER_NAME || 'unknown'
        });
    }

    // Error de casting (parámetros inválidos)
    if (err.name === 'CastError') {
        return res.status(400).json({
            success: false,
            error: 'ID de recurso inválido',
            server: process.env.SERVER_NAME || 'unknown'
        });
    }

    // Error por defecto
    res.status(err.statusCode || 500).json({
        success: false,
        error: error.message || 'Error interno del servidor',
        server: process.env.SERVER_NAME || 'unknown',
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
};

module.exports = errorHandler;
