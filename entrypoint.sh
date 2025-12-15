#!/bin/bash
set -e

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Samba 4 Active Directory Domain Controller ===${NC}"
echo -e "${GREEN}Domain: ${SAMBA_DOMAIN}${NC}"
echo -e "${GREEN}Realm: ${SAMBA_REALM}${NC}"

# Prüfen ob Samba bereits provisioniert wurde
if [ ! -f /var/lib/samba/private/sam.ldb ]; then
    echo -e "${YELLOW}Samba AD DC wird erstmalig provisioniert...${NC}"
    
    # Alte Konfiguration entfernen falls vorhanden
    rm -f /etc/samba/smb.conf
    # Entferne alles außer gemounteten Zertifikaten
    find /var/lib/samba/private -mindepth 1 -maxdepth 1 ! -name 'tls' -exec rm -rf {} \; 2>/dev/null || true
    find /var/lib/samba/private/tls -mindepth 1 ! -name '*.pem' -exec rm -f {} \; 2>/dev/null || true
    rm -rf /var/lib/samba/sysvol/*
    
    # Kerberos Konfiguration vorbereiten
    cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${SAMBA_REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = true
EOF

    # Domain provisionieren
    samba-tool domain provision \
        --server-role=dc \
        --use-rfc2307 \
        --dns-backend=SAMBA_INTERNAL \
        --realm="${SAMBA_REALM}" \
        --domain="${SAMBA_DOMAIN}" \
        --adminpass="${SAMBA_ADMIN_PASSWORD}" \
        --option="dns forwarder = ${SAMBA_DNS_FORWARDER}" \
        --option="allow dns updates = nonsecure and secure"
    
    # Kerberos Konfiguration von Samba übernehmen
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
    
    # Sicherstellen, dass die korrekte smb.conf verwendet wird
    # samba-tool erstellt sie in /etc/samba/smb.conf
    if [ ! -f /etc/samba/smb.conf ] || ! grep -q "server role = active directory domain controller" /etc/samba/smb.conf; then
        echo -e "${RED}FEHLER: smb.conf wurde nicht korrekt erstellt!${NC}"
        exit 1
    fi
    
    # LDAP konfigurieren (LDAPS deaktiviert)
    echo -e "${YELLOW}Konfiguriere LDAP (unverschlüsselt)...${NC}"
    
    # Erlaube unverschlüsselte LDAP-Verbindungen für LAM
    if ! grep -q "ldap server require strong auth" /etc/samba/smb.conf; then
        sed -i '/^\[global\]/,/^\[/ { /^\[global\]/a\
	ldap server require strong auth = no
}' /etc/samba/smb.conf
        echo -e "${GREEN}Unverschlüsselte LDAP-Verbindungen erlaubt!${NC}"
    fi
    
    echo -e "${GREEN}Samba AD DC erfolgreich provisioniert!${NC}"
    echo -e "${YELLOW}Administrator Passwort: ${SAMBA_ADMIN_PASSWORD}${NC}"
else
    echo -e "${GREEN}Samba AD DC ist bereits provisioniert.${NC}"
    
    # Stelle sicher, dass die richtige smb.conf verwendet wird
    # Wenn die smb.conf fehlt oder nicht korrekt ist, erstelle sie neu
    if [ ! -f /etc/samba/smb.conf ] || ! grep -q "server role = active directory domain controller" /etc/samba/smb.conf 2>/dev/null; then
        echo -e "${YELLOW}smb.conf ist nicht korrekt, erstelle sie neu...${NC}"
        # Erstelle korrekte smb.conf für AD DC
        cat > /etc/samba/smb.conf <<EOF
[global]
    server role = active directory domain controller
    realm = ${SAMBA_REALM}
    workgroup = ${SAMBA_DOMAIN}
    netbios name = DC1
    dns forwarder = ${SAMBA_DNS_FORWARDER}
    allow dns updates = nonsecure and secure
    idmap_ldb:use rfc2307 = yes
    ldap server require strong auth = no
    tls enabled = no
    server services = -winbindd

[sysvol]
    path = /var/lib/samba/sysvol
    read only = No

[netlogon]
    path = /var/lib/samba/sysvol/${SAMBA_REALM,,}/scripts
    read only = No
EOF
        echo -e "${GREEN}smb.conf neu erstellt!${NC}"
    fi
    
    # LDAP konfigurieren (LDAPS deaktiviert)
    echo -e "${YELLOW}Konfiguriere LDAP (unverschlüsselt)...${NC}"
    
    # Entferne alle TLS-Einstellungen aus smb.conf
    sed -i '/^[[:space:]]*tls enabled/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls keyfile/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls certfile/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls cafile/d' /etc/samba/smb.conf
    
    # Erlaube unverschlüsselte LDAP-Verbindungen für LAM
    if ! grep -q "ldap server require strong auth" /etc/samba/smb.conf; then
        sed -i '/^\[global\]/,/^\[/ { /^\[global\]/a\
	ldap server require strong auth = no
}' /etc/samba/smb.conf
        echo -e "${GREEN}Unverschlüsselte LDAP-Verbindungen erlaubt!${NC}"
    fi
    
    # Winbindd in AD DC Mode deaktivieren (verursacht Probleme)
    if ! grep -q "server services = -winbindd" /etc/samba/smb.conf; then
        # Entferne winbindd aus server services
        sed -i 's/server services = .*/server services = -winbindd/' /etc/samba/smb.conf
        if ! grep -q "server services" /etc/samba/smb.conf; then
            sed -i '/^\[global\]/,/^\[/ { /^\[global\]/a\
	server services = -winbindd
}' /etc/samba/smb.conf
        fi
        echo -e "${GREEN}Winbindd deaktiviert (nicht benötigt in AD DC Mode)!${NC}"
    fi
fi

# DNS Resolver für Container konfigurieren
if [ -n "${SAMBA_HOST_IP}" ]; then
    echo -e "${GREEN}DNS Resolver wird auf ${SAMBA_HOST_IP} gesetzt${NC}"
    echo "nameserver ${SAMBA_HOST_IP}" > /etc/resolv.conf
fi

# Samba Konfiguration anzeigen
echo -e "${YELLOW}=== Samba Konfiguration ===${NC}"
echo -e "${GREEN}Domain: ${SAMBA_DOMAIN}${NC}"
echo -e "${GREEN}Realm: ${SAMBA_REALM}${NC}"
echo -e "${GREEN}DNS Forwarder: ${SAMBA_DNS_FORWARDER}${NC}"

# Berechtigungen setzen (ignoriere read-only gemountete Zertifikate)
chown -R root:root /var/lib/samba 2>/dev/null || true
find /var/lib/samba -type d -exec chmod 755 {} \; 2>/dev/null || true
find /var/lib/samba -type f ! -path "*/tls/*.pem" -exec chmod 644 {} \; 2>/dev/null || true

# Spezielle Berechtigungen für ntp_signd (WICHTIG für Samba-Start!)
# MUSS 750 sein, sonst startet Samba nicht und LDAP läuft nicht!
mkdir -p /var/lib/samba/ntp_signd 2>/dev/null || true
chmod 750 /var/lib/samba/ntp_signd 2>/dev/null || true
chown root:root /var/lib/samba/ntp_signd 2>/dev/null || true

# Entferne alle TLS-Einstellungen aus smb.conf (LDAPS deaktiviert)
if [ -f /etc/samba/smb.conf ]; then
    sed -i '/^[[:space:]]*tls enabled/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls keyfile/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls certfile/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls cafile/d' /etc/samba/smb.conf
    # Stelle sicher, dass TLS deaktiviert ist
    if ! grep -q "tls enabled = no" /etc/samba/smb.conf; then
        sed -i '/^\[global\]/a\
	tls enabled = no' /etc/samba/smb.conf
    fi
fi

# Apache für LAM konfigurieren
echo -e "${YELLOW}Konfiguriere Apache für LAM...${NC}"
if [ ! -f /etc/apache2/sites-enabled/lam.conf ]; then
    # LAM Apache-Konfiguration aktivieren
    a2enmod php 2>/dev/null || true
    a2enmod rewrite 2>/dev/null || true
    a2enmod ldap 2>/dev/null || true
    
    # LAM Virtual Host konfigurieren
    cat > /etc/apache2/sites-available/lam.conf <<EOF
<VirtualHost *:8080>
    ServerName localhost
    DocumentRoot /usr/share/ldap-account-manager
    
    <Directory /usr/share/ldap-account-manager>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/lam_error.log
    CustomLog \${APACHE_LOG_DIR}/lam_access.log combined
</VirtualHost>
EOF
    
    # Port 8080 für Apache konfigurieren
    if ! grep -q "Listen 8080" /etc/apache2/ports.conf; then
        echo "Listen 8080" >> /etc/apache2/ports.conf
    fi
    
    a2ensite lam.conf 2>/dev/null || true
    
    echo -e "${GREEN}Apache für LAM konfiguriert!${NC}"
fi

# LAM Konfigurationsverzeichnis erstellen
mkdir -p /etc/ldap-account-manager/config
chown -R www-data:www-data /etc/ldap-account-manager 2>/dev/null || true
echo -e "${GREEN}LAM-Verzeichnis vorbereitet!${NC}"
echo -e "${YELLOW}LAM URL: http://localhost:8080${NC}"
echo -e "${YELLOW}Bitte LAM manuell konfigurieren (siehe README.md)${NC}"

# WICHTIG: Berechtigungen für ntp_signd VOR Samba-Start setzen
# Dies muss direkt vor dem Start passieren, da das Volume die Berechtigungen zurücksetzt
mkdir -p /var/lib/samba/ntp_signd
chmod 750 /var/lib/samba/ntp_signd
chown root:root /var/lib/samba/ntp_signd

# Entferne alle TLS-Einstellungen aus smb.conf (falls noch vorhanden)
if [ -f /etc/samba/smb.conf ]; then
    sed -i '/^[[:space:]]*tls enabled/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls keyfile/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls certfile/d' /etc/samba/smb.conf
    sed -i '/^[[:space:]]*tls cafile/d' /etc/samba/smb.conf
    # Stelle sicher, dass TLS deaktiviert ist
    if ! grep -q "tls enabled = no" /etc/samba/smb.conf; then
        sed -i '/^\[global\]/a\
	tls enabled = no' /etc/samba/smb.conf
    fi
    # Winbindd deaktivieren (wichtig für AD DC Mode)
    if ! grep -q "server services = -winbindd" /etc/samba/smb.conf; then
        # Entferne winbindd aus server services
        sed -i 's/server services = .*/server services = -winbindd/' /etc/samba/smb.conf
        if ! grep -q "server services" /etc/samba/smb.conf; then
            sed -i '/^\[global\]/a\
	server services = -winbindd' /etc/samba/smb.conf
        fi
    fi
fi

echo -e "${GREEN}=== Starte Samba Services ===${NC}"

# Kommando ausführen
exec "$@"

