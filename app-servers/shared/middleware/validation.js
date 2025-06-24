const Joi = require('joi');

// Middleware para validar requests
const validateRequest = (schema, property = 'body') => {
    return (req, res, next) => {
        const dataToValidate = req[property];
        
        const { error, value } = schema.validate(dataToValidate, {
            abortEarly: false,
            stripUnknown: true
        });

        if (error) {
            const errorDetails = error.details.map(detail => ({
                field: detail.path.join('.'),
                message: detail.message
            }));

            return res.status(400).json({
                success: false,
                error: 'Datos de entrada inválidos',
                details: errorDetails,
                server: process.env.SERVER_NAME || 'unknown'
            });
        }

        // Reemplazar los datos validados y limpios
        req[property] = value;
        next();
    };
};

module.exports = {
    validateRequest
};
