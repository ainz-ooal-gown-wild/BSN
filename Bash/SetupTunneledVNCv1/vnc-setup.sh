#!/bin/bash
# ==============================================================================
# VNC Server Setup Script
# TigerVNC + XFCE + SSH-Tunnel auf Ubuntu 24.04 vServer
# ==============================================================================
#
# Voraussetzungen:
#   - Ubuntu 24.04 (oder vergleichbar)
#   - Root-Zugang
#   - SSH-Zugang zum Server
#
# Nutzung:
#   chmod +x vnc-setup.sh
#   sudo ./vnc-setup.sh
#
# Nach dem Setup:
#   1. VNC-Passwort setzen:  vncpasswd
#   2. Service starten:      sudo systemctl start vncserver@1
#   3. Lokal SSH-Tunnel:     ssh -L 5901:localhost:5901 -N -f user@server-ip
#   4. VNC-Client verbinden: localhost:5901
# ==============================================================================

set -e  # Bei Fehler sofort abbrechen

# ------------------------------------------------------------------------------
# Konfiguration — hier anpassen
# ------------------------------------------------------------------------------
VNC_USER="${VNC_USER:-root}"                # User unter dem VNC läuft
VNC_DISPLAY="1"                            # Display :1 = Port 5901 (fix)
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"   # Auflösung
VNC_DEPTH="${VNC_DEPTH:-16}"               # Farbtiefe (16-bit spart CPU)

# Home-Verzeichnis des VNC-Users ermitteln
if [ "$VNC_USER" = "root" ]; then
    VNC_HOME="/root"
else
    VNC_HOME="/home/$VNC_USER"
fi

echo "=============================================="
echo " VNC Server Setup"
echo " User: $VNC_USER"
echo " Display: :$VNC_DISPLAY (Port 590$VNC_DISPLAY)"
echo " Auflösung: $VNC_GEOMETRY @ ${VNC_DEPTH}-bit"
echo "=============================================="

# ------------------------------------------------------------------------------
# 1. Pakete installieren
# ------------------------------------------------------------------------------
echo ""
echo "[1/6] Pakete installieren..."

apt update -qq
apt install -y \
    tigervnc-standalone-server \
    tigervnc-common \
    xfce4 \
    xfce4-goodies \
    dbus-x11 \
    x11-xserver-utils

echo "      Pakete installiert."

# ------------------------------------------------------------------------------
# 2. VNC-Verzeichnis und xstartup erstellen
# ------------------------------------------------------------------------------
echo ""
echo "[2/6] VNC-Konfiguration anlegen..."

mkdir -p "$VNC_HOME/.vnc"

# xstartup: Startet XFCE und setzt Display-Berechtigung
cat > "$VNC_HOME/.vnc/xstartup" << 'EOF'
#!/bin/sh
# Session-Variablen zurücksetzen (verhindert Konflikte)
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Display-Berechtigung für Root setzen
# (notwendig damit Snap-Apps wie Firefox starten)
xhost +local:root

# XFCE Desktop starten
exec startxfce4
EOF

chmod +x "$VNC_HOME/.vnc/xstartup"
echo "      xstartup erstellt."

# ------------------------------------------------------------------------------
# 3. VNC-Config erstellen (Optionen die früher per CLI übergeben wurden)
# ------------------------------------------------------------------------------
echo ""
echo "[3/6] VNC-Config schreiben..."

# TigerVNC 1.13+ liest Optionen aus dieser Datei
cat > "$VNC_HOME/.vnc/config" << EOF
# Nur auf localhost lauschen (Sicherheit: kein externer Zugriff ohne SSH-Tunnel)
localhost

# Auflösung und Farbtiefe
geometry=$VNC_GEOMETRY
depth=$VNC_DEPTH
EOF

echo "      Config geschrieben: $VNC_HOME/.vnc/config"

# ------------------------------------------------------------------------------
# 4. Dateibesitz korrigieren (falls Script als root für anderen User läuft)
# ------------------------------------------------------------------------------
if [ "$VNC_USER" != "root" ]; then
    chown -R "$VNC_USER:$VNC_USER" "$VNC_HOME/.vnc"
fi

# ------------------------------------------------------------------------------
# 5. Systemd-Service erstellen
# ------------------------------------------------------------------------------
echo ""
echo "[4/6] Systemd-Service anlegen..."

cat > /etc/systemd/system/vncserver@.service << EOF
[Unit]
Description=TigerVNC Server für Display %i
After=network-online.target

[Service]
Type=forking
User=$VNC_USER
WorkingDirectory=$VNC_HOME

# Alten Prozess aufräumen falls vorhanden
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || :'

# VNC starten (Optionen kommen aus ~/.vnc/config)
ExecStart=/usr/bin/vncserver :%i

# Sauber stoppen
ExecStop=/usr/bin/vncserver -kill :%i

# Bei Crash neu starten
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "      Service erstellt: vncserver@.service"

# ------------------------------------------------------------------------------
# 6. Stale Lock-Files aufräumen
# ------------------------------------------------------------------------------
echo ""
echo "[5/6] Lock-Files aufräumen..."

# Verhindert "A vncserver is already running"-Fehler
rm -f "/tmp/.X${VNC_DISPLAY}-lock" "/tmp/.X11-unix/X${VNC_DISPLAY}" 2>/dev/null || true
echo "      Lock-Files bereinigt."

# ------------------------------------------------------------------------------
# 7. Service aktivieren und starten
# ------------------------------------------------------------------------------
echo ""
echo "[6/6] Service aktivieren..."

systemctl enable "vncserver@${VNC_DISPLAY}"

# Nur starten wenn ein VNC-Passwort existiert
if [ -f "$VNC_HOME/.vnc/passwd" ]; then
    systemctl start "vncserver@${VNC_DISPLAY}"
    echo "      Service gestartet."
else
    echo ""
    echo "  !! WICHTIG: Noch kein VNC-Passwort gesetzt!"
    echo "  Führe als User '$VNC_USER' aus:"
    echo ""
    echo "     vncpasswd"
    echo ""
    echo "  Danach starten mit:"
    echo "     sudo systemctl start vncserver@${VNC_DISPLAY}"
fi

# ------------------------------------------------------------------------------
# Status prüfen
# ------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Setup abgeschlossen!"
echo "=============================================="
echo ""
echo " Status prüfen:"
echo "   sudo systemctl status vncserver@${VNC_DISPLAY}"
echo "   ss -tlnp | grep 590${VNC_DISPLAY}"
echo ""
echo " Vom lokalen Rechner verbinden:"
echo "   1. SSH-Tunnel öffnen:"
echo "      ssh -L 590${VNC_DISPLAY}:localhost:590${VNC_DISPLAY} -N -f ${VNC_USER}@DEINE-SERVER-IP"
echo ""
echo "   2. VNC-Client (TigerVNC Viewer) verbinden auf:"
echo "      localhost:590${VNC_DISPLAY}"
echo ""
echo "   3. In PuTTY (ohne extra Terminal):"
echo "      Connection > SSH > Tunnels"
echo "      Source Port: 590${VNC_DISPLAY}"
echo "      Destination: localhost:590${VNC_DISPLAY}"
echo "      -> Add -> Apply"
echo ""
echo " Performance-Tipps:"
echo "   - XFCE Compositor deaktivieren:"
echo "     Einstellungen > Fensterverwaltung (Erweitert) > Compositor aus"
echo "   - Animationen und Transparenzen abschalten"
echo "   - TigerVNC Viewer statt TightVNC verwenden"
echo "=============================================="
