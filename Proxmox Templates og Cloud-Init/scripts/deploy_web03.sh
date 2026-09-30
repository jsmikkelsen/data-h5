#!/bin/bash
# ==============================================================================
# SCRIPT: deploy_web03.sh
# FORMÅL: Udrulning af web03 via Proxmox CLI med statisk IP og webserver
# ==============================================================================
set -e

TEMPLATE_ID=9000
NEW_VMID=104
NEW_NAME="web03"
NEW_IP="192.168.1.104/24"
GATEWAY="192.168.1.1"
DNS="1.1.1.1"
ADMIN_USER="administrator"
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"
USERDATA_SNIPPET="local:snippets/webserver-userdata.yaml"

echo "=== [1/4] Kloner template $TEMPLATE_ID til $NEW_NAME ($NEW_VMID) ==="
qm clone $TEMPLATE_ID $NEW_VMID --name "$NEW_NAME" --full 0

echo "=== [2/4] Konfigurerer Cloud-Init netværk og bruger ==="
qm set $NEW_VMID \
    --ciuser "$ADMIN_USER" \
    --sshkeys "$SSH_KEY_FILE" \
    --ipconfig0 ip="$NEW_IP",gw="$GATEWAY" \
    --nameserver "$DNS"

echo "=== [3/4] Tilknytter automatisk Nginx-snippet ==="
qm set $NEW_VMID --cicustom "user=$USERDATA_SNIPPET"

echo "=== [4/4] Starter $NEW_NAME ==="
qm start $NEW_VMID

echo "Udrulning færdig! Server tilgængelig på http://${NEW_IP%/*}/ efter boot."
