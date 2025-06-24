FROM node:18-alpine

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache bash curl

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias de Node.js
RUN npm ci --only=production

# Copiar código fuente
COPY . .

# Crear directorio de logs
RUN mkdir -p logs

# Crear usuario no-root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Cambiar propietario de los archivos
RUN chown -R nodejs:nodejs /app
USER nodejs

# Exponer puertos
EXPOSE 3001 3002

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Comando por defecto
CMD ["npm", "start"]
