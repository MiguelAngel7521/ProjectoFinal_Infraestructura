const express = require('express');
const { sequelize } = require('../../shared/models');

const router = express.Router();

// Health check básico
router.get('/', async (req, res) => {
    const healthCheck = {
        uptime: process.uptime(),
        message: 'OK',
        timestamp: new Date().toISOString(),
        server: process.env.SERVER_NAME || 'app1',
        version: require('../../package.json').version,
        environment: process.env.NODE_ENV,
        database: 'disconnected',
        memory: process.memoryUsage()
    };

    try {
        // Verificar conexión a base de datos
        await sequelize.authenticate();
        healthCheck.database = 'connected';
        healthCheck.status = 'healthy';
        
        res.status(200).json(healthCheck);
    } catch (error) {
        healthCheck.status = 'unhealthy';
        healthCheck.error = error.message;
        res.status(503).json(healthCheck);
    }
});

// Health check detallado
router.get('/detailed', async (req, res) => {
    const checks = {
        timestamp: new Date().toISOString(),
        server: process.env.SERVER_NAME || 'app1',
        version: require('../../package.json').version,
        environment: process.env.NODE_ENV,
        uptime: process.uptime(),
        status: 'healthy',
        checks: {
            database: { status: 'unknown', responseTime: 0 },
            memory: { status: 'unknown', usage: process.memoryUsage() },
            disk: { status: 'unknown' }
        }
    };

    try {
        // Check database
        const dbStart = Date.now();
        await sequelize.authenticate();
        const dbEnd = Date.now();
        
        checks.checks.database = {
            status: 'healthy',
            responseTime: dbEnd - dbStart,
            host: process.env.DB_HOST,
            port: process.env.DB_PORT,
            database: process.env.DB_NAME
        };

        // Check memory usage
        const memUsage = process.memoryUsage();
        const memoryStatus = memUsage.heapUsed / memUsage.heapTotal > 0.9 ? 'warning' : 'healthy';
        
        checks.checks.memory = {
            status: memoryStatus,
            usage: memUsage,
            percentage: Math.round((memUsage.heapUsed / memUsage.heapTotal) * 100)
        };

        // Overall status
        const allHealthy = Object.values(checks.checks).every(check => check.status === 'healthy');
        checks.status = allHealthy ? 'healthy' : 'degraded';

        res.status(200).json(checks);
    } catch (error) {
        checks.status = 'unhealthy';
        checks.error = error.message;
        res.status(503).json(checks);
    }
});

module.exports = router;
