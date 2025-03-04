#!/bin/bash
IP=$(curl -s ifconfig.me)  # Externe IP abrufen
API_KEY="dein-api-schlüssel"
DOMAIN="example.com"
RECORD_ID="deine-record-id"  # Muss man oft vorher auslesen

# API-Endpunkt, das eigentliche Update der IP
curl -X PUT "https://api.deindnsanbieter.com/dns/$RECORD_ID" \
     -H "Authorization: Bearer $API_KEY" \
     -H "Content-Type: application/json" \
     -d "{\"ip\":\"$IP\"}"

# Cronjob einrichten, exemplarisch !! nicht in diesem Skript ausführen !!
#*/5 * * * * /pfad/zum/script.sh # Alle 5 Minuten