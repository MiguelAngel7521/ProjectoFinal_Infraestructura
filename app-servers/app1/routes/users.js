const express = require('express');
const Joi = require('joi');
const { User } = require('../../shared/models');
const logger = require('../../shared/utils/logger');
const { validateRequest } = require('../../shared/middleware/validation');

const router = express.Router();

// Esquemas de validación
const createUserSchema = Joi.object({
    name: Joi.string().min(2).max(100).required(),
    email: Joi.string().email().required(),
    age: Joi.number().integer().min(1).max(120).optional(),
    phone: Joi.string().pattern(/^[0-9+\-\s()]+$/).optional()
});

const updateUserSchema = Joi.object({
    name: Joi.string().min(2).max(100).optional(),
    email: Joi.string().email().optional(),
    age: Joi.number().integer().min(1).max(120).optional(),
    phone: Joi.string().pattern(/^[0-9+\-\s()]+$/).optional()
}).min(1);

const paramsSchema = Joi.object({
    id: Joi.number().integer().positive().required()
});

// GET /api/users - Listar todos los usuarios
router.get('/', async (req, res, next) => {
    try {
        const { page = 1, limit = 10, search = '' } = req.query;
        const offset = (page - 1) * limit;

        const whereClause = search ? {
            [require('sequelize').Op.or]: [
                { name: { [require('sequelize').Op.like]: `%${search}%` } },
                { email: { [require('sequelize').Op.like]: `%${search}%` } }
            ]
        } : {};

        const users = await User.findAndCountAll({
            where: whereClause,
            limit: parseInt(limit),
            offset: parseInt(offset),
            order: [['createdAt', 'DESC']]
        });

        res.json({
            success: true,
            data: users.rows,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total: users.count,
                totalPages: Math.ceil(users.count / limit)
            },
            server: process.env.SERVER_NAME || 'app1'
        });

        logger.info(`Usuarios listados - Total: ${users.count}, Página: ${page}`);
    } catch (error) {
        next(error);
    }
});

// GET /api/users/:id - Obtener usuario por ID
router.get('/:id', validateRequest(paramsSchema, 'params'), async (req, res, next) => {
    try {
        const { id } = req.params;
        
        const user = await User.findByPk(id);
        
        if (!user) {
            return res.status(404).json({
                success: false,
                error: 'Usuario no encontrado',
                server: process.env.SERVER_NAME || 'app1'
            });
        }

        res.json({
            success: true,
            data: user,
            server: process.env.SERVER_NAME || 'app1'
        });

        logger.info(`Usuario obtenido - ID: ${id}`);
    } catch (error) {
        next(error);
    }
});

// POST /api/users - Crear nuevo usuario
router.post('/', validateRequest(createUserSchema), async (req, res, next) => {
    try {
        const userData = req.body;
        
        // Verificar si el email ya existe
        const existingUser = await User.findOne({ where: { email: userData.email } });
        if (existingUser) {
            return res.status(400).json({
                success: false,
                error: 'El email ya está registrado',
                server: process.env.SERVER_NAME || 'app1'
            });
        }

        const user = await User.create(userData);
        
        res.status(201).json({
            success: true,
            data: user,
            message: 'Usuario creado exitosamente',
            server: process.env.SERVER_NAME || 'app1'
        });

        logger.info(`Usuario creado - ID: ${user.id}, Email: ${user.email}`);
    } catch (error) {
        next(error);
    }
});

// PUT /api/users/:id - Actualizar usuario
router.put('/:id', 
    validateRequest(paramsSchema, 'params'),
    validateRequest(updateUserSchema),
    async (req, res, next) => {
        try {
            const { id } = req.params;
            const updateData = req.body;

            const user = await User.findByPk(id);
            if (!user) {
                return res.status(404).json({
                    success: false,
                    error: 'Usuario no encontrado',
                    server: process.env.SERVER_NAME || 'app1'
                });
            }

            // Verificar email único si se está actualizando
            if (updateData.email && updateData.email !== user.email) {
                const existingUser = await User.findOne({ where: { email: updateData.email } });
                if (existingUser) {
                    return res.status(400).json({
                        success: false,
                        error: 'El email ya está registrado',
                        server: process.env.SERVER_NAME || 'app1'
                    });
                }
            }

            await user.update(updateData);
            
            res.json({
                success: true,
                data: user,
                message: 'Usuario actualizado exitosamente',
                server: process.env.SERVER_NAME || 'app1'
            });

            logger.info(`Usuario actualizado - ID: ${id}`);
        } catch (error) {
            next(error);
        }
    }
);

// DELETE /api/users/:id - Eliminar usuario
router.delete('/:id', validateRequest(paramsSchema, 'params'), async (req, res, next) => {
    try {
        const { id } = req.params;
        
        const user = await User.findByPk(id);
        if (!user) {
            return res.status(404).json({
                success: false,
                error: 'Usuario no encontrado',
                server: process.env.SERVER_NAME || 'app1'
            });
        }

        await user.destroy();
        
        res.json({
            success: true,
            message: 'Usuario eliminado exitosamente',
            server: process.env.SERVER_NAME || 'app1'
        });

        logger.info(`Usuario eliminado - ID: ${id}`);
    } catch (error) {
        next(error);
    }
});

module.exports = router;
