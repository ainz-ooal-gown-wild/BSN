#!/bin/bash
IP=$(curl -s ifconfig.me)
USERNAME="dein-username"
PASSWORD="dein-passwort"
HOSTNAME="example.dynu.net"

curl -u "$USERNAME:$PASSWORD" "https://update.dynu.com/nic/update?hostname=$HOSTNAME&myip=$IP"