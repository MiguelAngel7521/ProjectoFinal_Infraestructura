const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    const User = sequelize.define('User', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        name: {
            type: DataTypes.STRING(100),
            allowNull: false,
            validate: {
                notEmpty: {
                    msg: 'El nombre no puede estar vacío'
                },
                len: {
                    args: [2, 100],
                    msg: 'El nombre debe tener entre 2 y 100 caracteres'
                }
            }
        },
        email: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: {
                msg: 'Este email ya está registrado'
            },
            validate: {
                isEmail: {
                    msg: 'Debe ser un email válido'
                },
                notEmpty: {
                    msg: 'El email no puede estar vacío'
                }
            }
        },
        age: {
            type: DataTypes.INTEGER,
            allowNull: true,
            validate: {
                min: {
                    args: [1],
                    msg: 'La edad debe ser mayor a 0'
                },
                max: {
                    args: [120],
                    msg: 'La edad debe ser menor a 120'
                }
            }
        },
        phone: {
            type: DataTypes.STRING(20),
            allowNull: true,
            validate: {
                is: {
                    args: /^[0-9+\-\s()]+$/,
                    msg: 'El teléfono solo puede contener números, espacios, paréntesis, + y -'
                }
            }
        },
        isActive: {
            type: DataTypes.BOOLEAN,
            defaultValue: true,
            allowNull: false
        }
    }, {
        tableName: 'users',
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ['email']
            },
            {
                fields: ['name']
            },
            {
                fields: ['isActive']
            }
        ],
        hooks: {
            beforeCreate: (user) => {
                // Normalizar email
                if (user.email) {
                    user.email = user.email.toLowerCase().trim();
                }
                // Normalizar nombre
                if (user.name) {
                    user.name = user.name.trim();
                }
            },
            beforeUpdate: (user) => {
                // Normalizar email
                if (user.email) {
                    user.email = user.email.toLowerCase().trim();
                }
                // Normalizar nombre
                if (user.name) {
                    user.name = user.name.trim();
                }
            }
        }
    });

    // Método de instancia
    User.prototype.toJSON = function() {
        const values = { ...this.get() };
        // Ocultar campos sensibles si los hubiera
        return values;
    };

    // Métodos de clase
    User.findByEmail = function(email) {
        return this.findOne({
            where: { email: email.toLowerCase().trim() }
        });
    };

    User.findActive = function() {
        return this.findAll({
            where: { isActive: true },
            order: [['createdAt', 'DESC']]
        });
    };

    return User;
};
