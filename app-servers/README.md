# Servidores de Aplicación Node.js

Este directorio contiene las aplicaciones Node.js que implementan un CRUD básico.

## Estructura

```
app-servers/
├── app1/                 # Servidor de aplicación 1
├── app2/                 # Servidor de aplicación 2
├── shared/               # Código compartido
└── package.json          # Dependencias comunes
```

## Características

- **Framework**: Express.js
- **Base de Datos**: MySQL con Sequelize ORM
- **Autenticación**: JWT (opcional)
- **Validación**: Joi
- **Logging**: Winston
- **Monitoreo**: Health checks

## CRUD Endpoints

- `GET /api/users` - Listar usuarios
- `POST /api/users` - Crear usuario
- `GET /api/users/:id` - Obtener usuario específico
- `PUT /api/users/:id` - Actualizar usuario
- `DELETE /api/users/:id` - Eliminar usuario
- `GET /health` - Health check

## Variables de Entorno

Copiar `.env.example` a `.env` y configurar:

```bash
# Base de datos
DB_HOST=localhost
DB_PORT=3306
DB_NAME=crud_app
DB_USER=app_user
DB_PASS=password

# Servidor
PORT=3001
NODE_ENV=development

# JWT (opcional)
JWT_SECRET=your-secret-key
```

## Instalación

```bash
npm install
npm run dev    # Desarrollo
npm start      # Producción
```
