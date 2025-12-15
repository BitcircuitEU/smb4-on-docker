FROM debian:bookworm-slim

# Metadaten
LABEL maintainer="Samba AD DC Container"
LABEL description="Samba 4 Active Directory Domain Controller"

# Umgebungsvariablen
ENV DEBIAN_FRONTEND=noninteractive
ENV SAMBA_DOMAIN=EXAMPLE
ENV SAMBA_REALM=EXAMPLE.COM
ENV SAMBA_ADMIN_PASSWORD=Passw0rd
ENV SAMBA_DNS_FORWARDER=8.8.8.8

# System aktualisieren und Samba + LAM installieren
RUN apt-get update && \
    apt-get install -y \
    samba \
    samba-dsdb-modules \
    samba-vfs-modules \
    winbind \
    libpam-winbind \
    libnss-winbind \
    krb5-user \
    krb5-kdc \
    dnsutils \
    ldb-tools \
    net-tools \
    iproute2 \
    supervisor \
    openssl \
    apache2 \
    php \
    php-ldap \
    php-mbstring \
    php-xml \
    php-curl \
    php-zip \
    ldap-account-manager \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verzeichnisse erstellen
RUN mkdir -p /var/lib/samba \
    && mkdir -p /var/lib/samba/private/tls \
    && mkdir -p /var/log/samba \
    && mkdir -p /etc/samba \
    && mkdir -p /etc/samba/external \
    && mkdir -p /run/samba

# Samba Konfiguration und Daten Volumes
VOLUME ["/var/lib/samba", "/etc/samba/external"]

# Entrypoint Skript kopieren
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Supervisor Konfiguration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Ports freigeben
# 53: DNS
# 88: Kerberos
# 135: MS-RPC
# 139: NetBIOS Session Service
# 389: LDAP
# 445: SMB
# 464: Kerberos Password Change
# 636: LDAPS
# 3268-3269: Global Catalog
# 8080: LAM WebGUI
EXPOSE 53 53/udp 88 88/udp 135 139 389 389/udp 445 464 464/udp 636 3268 3269 8080

# Workdir setzen
WORKDIR /var/lib/samba

# Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

