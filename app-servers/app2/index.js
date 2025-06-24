// app2/index.js - Idéntico a app1 pero con variables de entorno diferentes
require('dotenv').config({ path: require('path').join(__dirname, '.env') });

// Importar y usar la misma configuración que app1
const app = require('../app1/index.js');

// No necesitamos reexportar nada, el archivo app1/index.js ya maneja todo
