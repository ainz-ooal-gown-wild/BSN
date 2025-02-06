#!/bin/bash
CONFIG_FILE="" # Als optionaler Parameter übergeben

# Standardwerte (werden überschrieben, falls eine Config existiert)
LOGFILE="/var/log/setup_$(hostname).log"
SSH_PORT="22"
PERMIT_ROOT_LOGIN="no"

# "Feste" Werte - Verändern experimental
SSH_CONF="/etc/ssh/sshd_config" # Veränderungen z.Zt. nicht lauffähig, da keine Implementierung des angepassten Pfads

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
log "=== Openssh-Server Installation gestartet ==="

# Prüfen, ob Openssh-Server bereits installiert ist
if dpkg -l | grep -qw openssh-server; then
    log "Openssh-Server ist bereits installiert. Beende das Skript."
    log "=== Openssh-Server Installation abgebrochen ==="
    exit 0
fi

# Konfigurationsdatei einlesen
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    log "Lade Konfigurationsdatei: $CONFIG_FILE"
    LOGFILE=$(parse_config "general" "logfile") || log_config_warning "logfile"
    SSH_CONF=$(parse_config "openssh" "ssh_conf") || log_config_warning "ssh_conf"
    PERMIT_ROOT_LOGIN=$(parse_config "openssh" "permit_root_login") || log_config_warning "permit_root_login"
else
    log "Keine oder ungültige Konfigurationsdatei angegeben. Nutze Standardwerte."
fi

# Installation
log "Aktualisiere Paketlisten..."
sudo apt update || error_exit "apt update fehlgeschlagen"

log "Installiere Apache2..."
sudo apt install -y openssh-server || error_exit "Apache2-Installation fehlgeschlagen"

# Firewall & Service
log "Aktiviere Service und passe Firewall an..."
sudo systemctl enable ssh || error_exit "Service-Start fehlgeschlagen"
sudo ufw allow ssh || error_exit "Firewall-Regel fehlgeschlagen"

# Konfiguration
log "Sshd Config bearbeiten..."
echo "### Script-generated settings ###" | sudo tee -a "$SSH_CONF"
echo "PermitRootLogin $PERMIT_ROOT_LOGIN" | sudo tee -a "$SSH_CONF" || error_exit "Konnte $SSH_CONF nicht bearbeiten"

# Neustart des Services
log "Starte Openssh-Server neu..."
sudo systemctl daemon-reload || error_exit "deamon-reload fehlgeschlagen"
sudo systemctl restart ssh || error_exit "Openssh-Server konnte nicht neugestartet werden"

log "=== Openssh-Server Installation abgeschlossen ==="
echo "Openssh-Server Installation abgeschlossen..."
exit 0