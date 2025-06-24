const { Sequelize } = require('sequelize');
const logger = require('../utils/logger');

// Configuración de la base de datos
const sequelize = new Sequelize(
    process.env.DB_NAME || 'crud_app',
    process.env.DB_USER || 'app_user',
    process.env.DB_PASSWORD || 'password',
    {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 3306,
        dialect: 'mysql',
        logging: (msg) => logger.debug(msg),
        pool: {
            max: 10,
            min: 0,
            acquire: 30000,
            idle: 10000
        },
        retry: {
            match: [
                /SequelizeConnectionError/,
                /SequelizeConnectionRefusedError/,
                /SequelizeHostNotFoundError/,
                /SequelizeHostNotReachableError/,
                /SequelizeInvalidConnectionError/,
                /SequelizeConnectionTimedOutError/
            ],
            max: 3
        },
        define: {
            timestamps: true,
            underscored: false,
            freezeTableName: true
        }
    }
);

// Importar modelos
const User = require('./User')(sequelize);

// Establecer asociaciones (si las hay en el futuro)
// User.hasMany(Post);
// Post.belongsTo(User);

// Exportar
module.exports = {
    sequelize,
    User
};
