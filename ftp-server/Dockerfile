FROM ubuntu:22.04

# Instalar vsftpd y herramientas necesarias
RUN apt-get update && apt-get install -y \
    vsftpd \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Crear directorios necesarios
RUN mkdir -p /var/ftp/apps /var/ftp/backup /var/ftp/logs /etc/vsftpd/users \
    && mkdir -p /etc/ssl/certs /etc/ssl/private

# Copiar archivo de configuración
COPY vsftpd.conf /etc/vsftpd.conf

# Copiar scripts de configuración
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Copiar lista de usuarios chroot
COPY vsftpd.chroot_list /etc/vsftpd.chroot_list

# Copiar configuraciones de usuarios
COPY users/ /etc/vsftpd/users/

# Crear certificado SSL
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/vsftpd.key \
    -out /etc/ssl/certs/vsftpd.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Configurar usuarios FTP
RUN /usr/local/bin/setup-users.sh

# Exponer puertos
EXPOSE 21 21000-21010

# Comando de inicio
CMD ["/usr/local/bin/start-vsftpd.sh"]
