FROM nginx:alpine

# Copiar configuración personalizada
COPY nginx.conf /etc/nginx/nginx.conf
COPY sites-available/ /etc/nginx/sites-available/
COPY sites-enabled/ /etc/nginx/sites-enabled/

# Crear directorios necesarios
RUN mkdir -p /var/www/html /var/www/static

# Copiar páginas de error personalizadas
COPY error-pages/ /var/www/html/

# Establecer permisos correctos
RUN chown -R nginx:nginx /var/www/

# Exponer puertos
EXPOSE 80 443

# Verificar configuración al iniciar
CMD ["sh", "-c", "nginx -t && nginx -g 'daemon off;'"]
