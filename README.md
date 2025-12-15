# Samba 4 Active Directory Domain Controller mit LAM WebGUI

Docker-Container mit Samba 4 Active Directory Domain Controller und integriertem LDAP Account Manager (LAM) WebGUI.

## Docker Image

Das Docker Image wird automatisch bei jedem Push zu GitHub gebaut und ist verfügbar unter:

```bash
docker pull ghcr.io/bitcircuiteu/smb4-on-docker:latest
```

**Repository**: [https://github.com/BitcircuitEU/smb4-on-docker](https://github.com/BitcircuitEU/smb4-on-docker)

**Verfügbare Tags**:
- `latest` - Neueste Version
- `a1b2c3d` - SHA-Version (7 Zeichen, bei jedem Push zu main)
- Vollständiger SHA - Vollständiger Commit-SHA

Siehe [.github/workflows/README.md](.github/workflows/README.md) für Details zum automatischen Build-Prozess.

## Schnellstart

1. **Environment-Variablen anpassen** in `docker-compose.yml`:
   - `SAMBA_DOMAIN`: Domain-Name (z.B. `TERHORST`)
   - `SAMBA_REALM`: Realm (z.B. `AD.TERHORST.IO`)
   - `SAMBA_ADMIN_PASSWORD`: Administrator-Passwort
   - `SAMBA_DNS_FORWARDER`: DNS-Forwarder (z.B. `1.1.1.1`)

2. **Container starten**:
   ```bash
   docker compose up -d
   ```

3. **LAM konfigurieren** (siehe unten)

4. **Zugriff**:
   - LAM WebGUI: http://localhost:8080
   - Samba AD DC: Ports 88, 135, 139, 389, 445, 464, 3268

## Docker Run (ohne Compose)

Alternativ kannst du den Container auch direkt mit `docker run` starten:

```bash
docker run -d \
  --name samba-ad-dc \
  --hostname dc1 \
  --privileged \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --cap-add SYS_TIME \
  --dns 127.0.0.1 \
  --dns 1.1.1.1 \
  -p 88:88/tcp -p 88:88/udp \
  -p 135:135/tcp \
  -p 139:139/tcp \
  -p 389:389/tcp -p 389:389/udp \
  -p 445:445/tcp \
  -p 464:464/tcp -p 464:464/udp \
  -p 3268:3268/tcp \
  -p 8080:8080 \
  -e SAMBA_DOMAIN=TERHORST \
  -e SAMBA_REALM=AD.TERHORST.IO \
  -e SAMBA_ADMIN_PASSWORD=DeinSicheresPasswort123! \
  -e SAMBA_DNS_FORWARDER=1.1.1.1 \
  -e TZ=Europe/Berlin \
  -v samba-data:/var/lib/samba \
  -v samba-config:/etc/samba/external \
  -v samba-logs:/var/log/samba \
  -v lam-config:/etc/ldap-account-manager \
  ghcr.io/bitcircuiteu/smb4-on-docker:latest
```

**Wichtig**: Passe die Umgebungsvariablen (`-e`) an deine Domain an:
- `SAMBA_DOMAIN`: Dein Domain-Name (z.B. `TERHORST`)
- `SAMBA_REALM`: Dein Realm (z.B. `AD.TERHORST.IO`)
- `SAMBA_ADMIN_PASSWORD`: Dein Administrator-Passwort
- `SAMBA_DNS_FORWARDER`: DNS-Forwarder (z.B. `1.1.1.1` oder `8.8.8.8`)

## LAM (LDAP Account Manager) Konfiguration

### 1. Erste Anmeldung

1. Öffne http://localhost:8080 im Browser
2. Standard-Passwort: `lam` (wird beim ersten Login geändert)
3. Nach dem Login: Oben rechts auf das Profil-Symbol klicken → "Server profiles" wählen

### 2. Server-Profil konfigurieren

#### 2.1 Allgemeine Einstellungen

- **Server address**: `ldap://localhost:389`
- **TLS**: `no` (deaktiviert)
- **Tree suffix**: `dc=ad,dc=terhorst,dc=io` (anpassen an deinen Realm)
  - Realm `AD.TERHORST.IO` → `dc=ad,dc=terhorst,dc=io`
  - Realm `EXAMPLE.COM` → `dc=example,dc=com`
- **Administrator DN**: `cn=Administrator,cn=Users,dc=ad,dc=terhorst,dc=io`
  - Anpassen: `cn=Administrator,cn=Users,<dein-tree-suffix>`
- **Password**: Dein `SAMBA_ADMIN_PASSWORD` aus `docker-compose.yml`

#### 2.2 Account Types aktivieren

Unter "Account types" die folgenden Typen aktivieren:

- ✅ **User** (Benutzer)
- ✅ **Group** (Gruppen)
- ✅ **Host** (Computer)
- ❌ **Samba domain** (deaktivieren - nicht für Samba 4 AD DC)

#### 2.3 Type Settings konfigurieren

Für jeden Account Type die folgenden Suffixe setzen:

**User (Benutzer)**:
- **Suffix**: `cn=Users,dc=ad,dc=terhorst,dc=io`
- **Modules**: `windowsUser` aktivieren

**Group (Gruppen)**:
- **Suffix**: `cn=Users,dc=ad,dc=terhorst,dc=io`
- **Modules**: `windowsGroup` aktivieren

**Host (Computer)**:
- **Suffix**: `cn=Computers,dc=ad,dc=terhorst,dc=io`
- **Modules**: `windowsHost` aktivieren

### 3. Module aktivieren

Unter "Modules" für jeden Account Type:

#### User (Benutzer)
- ✅ **Windows user** (`windowsUser`)
- ✅ **POSIX account** (optional, für Linux-Integration)
- ✅ **Samba SAM account** (optional, für Samba-spezifische Einstellungen)

#### Group (Gruppen)
- ✅ **Windows group** (`windowsGroup`)
- ✅ **POSIX group** (optional, für Linux-Integration)

#### Host (Computer)
- ✅ **Windows host** (`windowsHost`)
- ✅ **POSIX account** (optional)

### 4. Login-Einstellungen

Unter "Login settings":
- **Login method**: `List` oder `List + Search`
- **Login search suffix**: `dc=ad,dc=terhorst,dc=io` (dein Tree suffix)
- **Login search filter**: `(sAMAccountName=%USER%)`

### 5. Speichern

Nach der Konfiguration auf "Save" klicken.

## Realm zu LDAP-DN Umrechnung

Um deinen Realm in einen LDAP-DN umzuwandeln:

1. Realm in Kleinbuchstaben umwandeln
2. Jeden Punkt (`.`) durch `,dc=` ersetzen
3. Am Anfang `dc=` hinzufügen

**Beispiele**:
- `AD.TERHORST.IO` → `dc=ad,dc=terhorst,dc=io`
- `EXAMPLE.COM` → `dc=example,dc=com`
- `CORP.DOMAIN.LOCAL` → `dc=corp,dc=domain,dc=local`

## Wichtige LDAP-DNs

- **Tree suffix**: `dc=ad,dc=terhorst,dc=io`
- **Administrator DN**: `cn=Administrator,cn=Users,dc=ad,dc=terhorst,dc=io`
- **Users Container**: `cn=Users,dc=ad,dc=terhorst,dc=io`
- **Computers Container**: `cn=Computers,dc=ad,dc=terhorst,dc=io`

## Troubleshooting

### LAM zeigt "Cannot connect to LDAP server"

1. Prüfe, ob Samba läuft: `docker compose logs samba-ad-dc`
2. Prüfe Server-Adresse: Muss `ldap://localhost:389` sein (nicht `ldaps://`)
3. Prüfe TLS-Einstellung: Muss `no` sein
4. Prüfe Administrator DN und Passwort

### "Samba domain" Modul-Fehler

- Das "Samba domain" Modul ist nur für Samba 3, nicht für Samba 4 AD DC
- Unter "Account types" → "Samba domain" deaktivieren

### Standard-Benutzer ist "Manager" statt "Administrator"

1. In LAM einloggen
2. Oben rechts auf Profil-Symbol → "Server profiles"
3. Unter "General settings" → "Administrator DN" auf `cn=Administrator,cn=Users,<dein-tree-suffix>` setzen
4. Passwort auf dein `SAMBA_ADMIN_PASSWORD` setzen
5. Speichern

## Container-Verwaltung

```bash
# Container starten
docker compose up -d

# Container stoppen
docker compose down

# Logs anzeigen
docker compose logs -f samba-ad-dc

# Container neu bauen
docker compose build --no-cache

# Volumes zurücksetzen (ACHTUNG: Löscht alle Daten!)
docker compose down -v
```

## Ports

- **88**: Kerberos
- **135**: MS-RPC
- **139**: NetBIOS Session Service
- **389**: LDAP
- **445**: SMB
- **464**: Kerberos Password Change
- **3268**: Global Catalog
- **8080**: LAM WebGUI

## Volumes

- `samba-data`: Samba-Daten (Domain-Datenbank, etc.)
- `samba-config`: Samba-Konfiguration
- `samba-logs`: Samba-Logs
- `lam-config`: LAM-Konfiguration

## Weitere Informationen

- [Samba 4 AD DC Dokumentation](https://wiki.samba.org/index.php/User_and_Group_management)
- [LAM Dokumentation](https://www.ldap-account-manager.org/)

