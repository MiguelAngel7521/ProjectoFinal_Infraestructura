FROM mysql:8.0

# Copiar archivo de configuración
COPY my.cnf /etc/mysql/my.cnf

# Copiar scripts de inicialización
COPY init-scripts/ /docker-entrypoint-initdb.d/

# Crear directorios necesarios
RUN mkdir -p /var/log/mysql /var/lib/mysql-files
RUN chown -R mysql:mysql /var/log/mysql /var/lib/mysql-files

# Exponer puerto
EXPOSE 3307

# Variables de entorno por defecto
ENV MYSQL_ROOT_PASSWORD=root_password_123
ENV MYSQL_DATABASE=crud_app
ENV MYSQL_USER=app_user
ENV MYSQL_PASSWORD=secure_password_123

# Comando personalizado para esperar al master
CMD ["sh", "-c", "docker-entrypoint.sh mysqld"]
