#!/bin/bash
# ==============================================================================
# SCRIPT: create_template.sh
# FORMÅL: Automatisk oprettelse af Ubuntu 24.04 LTS Cloud-Init Template i Proxmox
# ==============================================================================
set -e

VMID=9000
VM_NAME="ubuntu-2404-cloudinit-template"
STORAGE="local-lvm"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_FILE="/tmp/noble-server-cloudimg-amd64.img"

echo "=== [1/6] Downloader Ubuntu 24.04 Cloud Image ==="
if [ ! -f "$IMAGE_FILE" ]; then
    wget -q --show-progress "$IMAGE_URL" -O "$IMAGE_FILE"
else
    echo "Cloud image findes allerede i $IMAGE_FILE."
fi

echo "=== [2/6] Opretter basis VM ($VMID) ==="
qm create $VMID \
    --name "$VM_NAME" \
    --memory 2048 \
    --cores 2 \
    --cpu host \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

echo "=== [3/6] Importerer og forbinder disk ==="
qm importdisk $VMID "$IMAGE_FILE" "$STORAGE"
qm set $VMID --scsi0 "$STORAGE:vm-$VMID-disk-0,discard=on,ssd=1"

echo "=== [4/6] Opretter Cloud-Init drev og boot ==="
qm set $VMID --ide2 "$STORAGE:cloudinit"
qm set $VMID --boot order=scsi0 --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0

echo "=== [5/6] Aktiverer QEMU Guest Agent og udvider disk ==="
qm set $VMID --agent enabled=1
qm disk resize $VMID scsi0 +20G

echo "=== [6/6] Konverterer VM til Template ==="
qm template $VMID

echo "Template $VMID ($VM_NAME) er nu klar til udrulning!"
