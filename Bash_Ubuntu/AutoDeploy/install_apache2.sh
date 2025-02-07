#!/bin/bash
CONFIG_FILE="" # Als optionaler Parameter übergeben

# Standardwerte (werden überschrieben, falls eine Config existiert)
SCRIPT_DIR="$(dirname "$0")"
LOG_DIR="$SCRIPT_DIR/log"
TMP_LOGFILE="/tmp/setup_$(hostname).log"
LOGFILE="$TMP_LOGFILE"
ADMIN_CONTACT="yourname@example.com"
WWW_PUBLIC_DIR="/var/www/public/"
SERVER_NAME="localhost"
SERVER_ALIAS=""
MAIN_SITE_CONF_FILE="main.conf"

# "Hier bitte nicht anfassen, außer du weißt genau, was du tust"
APACHE_CONF="/etc/apache2/apache2.conf"
APACHE_SITES_DIR="/etc/apache2/sites-available/"

# Funktionen
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

error_exit() {
    log "FEHLER: $1"
    exit 1
}

# Funktion zum Auslesen von Werten aus einer bestimmten Sektion
parse_config() {
    local section="$1"
    local key="$2"
    local value=$(awk -F= -v section="[$section]" -v key="$key" '
        tolower($0) == tolower(section) {found=1; next} 
        /^\[/ && found {found=0} 
        found && tolower($1) == tolower(key) {print $2; exit}
    ' "$CONFIG_FILE" | tr -d '[:space:]')

    echo "$value"
}
log_config_warning() {
    log "Konnte '$1' nicht aus config parsen. Gehe mit Default."
}

# Parameter verarbeiten
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            log "WARNUNG: Unbekannter Parameter $1 wird ignoriert."
            shift
            ;;
    esac
done

# Beginne Logging
log "=== Apache2 Installation gestartet ==="

# Prüfen, ob Apache2 bereits installiert ist
if dpkg -l | grep -qw apache2; then
    log "Apache2 ist bereits installiert. Beende das Skript."
    log "=== Apache2 Installation abgebrochen ==="
    exit 0
fi

# Konfigurationsdatei einlesen
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" && -s "$CONFIG_FILE" ]]; then
    log "Lade Konfigurationsdatei: $CONFIG_FILE"
    for key in logfile server_name www_public_dir apache_conf apache_sites_dir main_site_conf_file; do
        temp_value=$(parse_config "apache2" "$key")
        if [[ -n "$temp_value" ]]; then
            declare "$(echo $key | tr '[:lower:]' '[:upper:]')"="$temp_value"
        else
            log_config_warning "$key"
        fi
    done
else
    log "Keine oder ungültige Konfigurationsdatei angegeben. Nutze Standardwerte."
    CONFIG_FILE=""
fi

# Installation
log "Aktualisiere Paketlisten..."
sudo apt update || error_exit "apt update fehlgeschlagen"

log "Installiere Apache2..."
sudo apt install -y apache2 || error_exit "Apache2-Installation fehlgeschlagen"

log "Public Verzeichnis anlegen..."
sudo mkdir -p "$WWW_PUBLIC_DIR" || error_exit "Public-Verzeichnis anlegen fehlgeschlagen"

log "Wechsle in das Verzeichnis der VirtualHosts..."
cd "$APACHE_SITES_DIR" || error_exit "Konnte nicht zu $APACHE_SITES_DIR wechseln"

#Konfiguration
log "Erstelle VirtualHost-Konfigurationsdatei $MAIN_SITE_CONF_FILE..."
if [[ -f "$MAIN_SITE_CONF_FILE" ]]; then
    sudo cp "$MAIN_SITE_CONF_FILE" "${MAIN_SITE_CONF_FILE}.bak"
fi
sudo cp 000-default.conf "$MAIN_SITE_CONF_FILE" || error_exit "Kopieren der Standard-Config fehlgeschlagen"

log "Passe die VirtualHost-Konfiguration an..."
sudo sed -i "s|ServerAdmin .*|ServerAdmin $ADMIN_CONTACT|" "$MAIN_SITE_CONF_FILE"
sudo sed -i "s|DocumentRoot .*|DocumentRoot $WWW_PUBLIC_DIR|" "$MAIN_SITE_CONF_FILE"

if grep -q "ServerName" "$MAIN_SITE_CONF_FILE"; then
    sudo sed -i "s|ServerName .*|ServerName $SERVER_NAME|" "$MAIN_SITE_CONF_FILE"
else
    echo "ServerName $SERVER_NAME" | sudo tee -a "$MAIN_SITE_CONF_FILE"
fi

if grep -q "ServerName" "$MAIN_SITE_CONF_FILE"; then
    sudo sed -i "/ServerName/a ServerAlias $SERVER_ALIAS" "$MAIN_SITE_CONF_FILE"
else
    echo "ServerAlias $SERVER_ALIAS" | sudo tee -a "$MAIN_SITE_CONF_FILE"
fi

log "Aktiviere die neue Konfiguration..."
sudo a2ensite "$MAIN_SITE_CONF_FILE" || error_exit "Konnte $MAIN_SITE_CONF_FILE nicht aktivieren"

log "Apache2 neu starten..."
sudo systemctl restart apache2 || error_exit "Neustart von Apache2 fehlgeschlagen"

# Logfile aus tmpfs in das Skriptverzeichnis verschieben
log "Speichere Logdatei..."
sudo mkdir -p "$LOG_DIR"
# Prüfen ob Logdatei bereits vorhanden. Wenn true, Inhalt anhängen
if [[ -f "$LOG_DIR/setup_$(hostname).log" ]]; then
    cat "$TMP_LOGFILE" | sudo tee -a "$LOG_DIR/setup_$(hostname).log" > /dev/null
    sudo rm "$TMP_LOGFILE"
else
    sudo mv "$TMP_LOGFILE" "$LOG_DIR/setup_$(hostname).log" || log "WARNUNG: Konnte Logdatei nicht verschieben!"
fi

exit 0