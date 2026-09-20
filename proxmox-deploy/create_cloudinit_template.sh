#!/bin/bash
# ==============================================================================
# SCRIPT: create_cloudinit_template.sh
# FORMÅL: Automatiserer oprettelsen af en Ubuntu 24.04 LTS Cloud-Init skabelon
#         direkte på din Proxmox VE vært.
# KØRSEL: Skal køres som root på Proxmox-værten (via SSH eller Proxmox Shell).
# ==============================================================================

# Stop scriptet ved fejl
set -e

# --- KONFIGURATION (Ret her hvis nødvendigt) ---
VMID=9000
VM_NAME="ubuntu-2404-cloudinit-template"
STORAGE="local-lvm"  # Skift til f.eks. 'local-zfs' eller 'ceph', hvis du ikke bruger LVM
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_FILE="noble-server-cloudimg-amd64.img"
# ------------------------------------------------

echo "================================================================="
echo "   OPRETTER UBUNTU 24.04 CLOUD-INIT SKABELON (VMID: $VMID)       "
echo "================================================================="
echo "Mål-storage: $STORAGE"
echo "Skabelon-navn: $VM_NAME"
echo "-----------------------------------------------------------------"

# 1. Hent nyeste Ubuntu 24.04 LTS Cloud Image, hvis det ikke allerede er hentet
if [ ! -f "$IMAGE_FILE" ]; then
    echo "[+] Downloader Ubuntu 24.04 LTS Cloud-Image..."
    wget -q --show-progress "$IMAGE_URL" -O "$IMAGE_FILE"
else
    echo "[i] Cloud-Image '$IMAGE_FILE' er allerede downloadet. Springer download over."
fi

# 2. Hvis VM'en allerede eksisterer, spørg om den skal slettes eller stop
if qm status $VMID >/dev/null 2>&1; then
    echo "[!] Advarsel: En VM med VMID $VMID eksisterer allerede."
    read -p "Vil du slette den eksisterende VM $VMID og oprette en ny? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "[+] Sletter eksisterende VM $VMID..."
        qm destroy $VMID
    else
        echo "[-] Afbryder. Ingen ændringer foretaget."
        exit 1
    fi
fi

# 3. Opret den nye VM i Proxmox
echo "[+] Opretter ny VM $VMID med navnet '$VM_NAME'..."
qm create $VMID --name "$VM_NAME" \
    --memory 2048 \
    --cores 2 \
    --cpu host \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --onboot 0 \
    --tablet 0

# 4. Importer disken til Proxmox storage
echo "[+] Importerer downloadet Cloud-Image til storage: $STORAGE..."
qm importdisk $VMID "$IMAGE_FILE" "$STORAGE"

# 5. Forbind den importerede disk til VM'en som SCSI0
# Bemærk: qm importdisk opretter en disk i formatet vm-9000-disk-0 (eller lignende).
# Vi finder det nøjagtige navn på disken, der blev oprettet.
echo "[+] Tilknytter disken som scsi0..."
DISK_NAME=$(pvesm list "$STORAGE" | grep "vm-$VMID-disk" | head -n 1 | awk '{print $1}')

if [ -z "$DISK_NAME" ]; then
    # Backup-metode til at finde disknavnet, hvis pvesm fejler
    DISK_NAME="$STORAGE:vm-$VMID-disk-0"
fi

echo "[i] Detekteret disk-id: $DISK_NAME"
qm set $VMID --scsi0 "$DISK_NAME,discard=on,ssd=1"

# 6. Tilføj en Cloud-Init drive (til indsprøjtning af IP, SSH-nøgler osv.)
echo "[+] Tilføjer Cloud-Init drev på ide2..."
qm set $VMID --ide2 "$STORAGE:cloudinit"

# 7. Sæt boot-rækkefølgen til scsi0 og bootdisk
echo "[+] Sætter boot-indstillinger..."
qm set $VMID --boot order=scsi0 --bootdisk scsi0

# 8. Konfigurer seriel konsol (MEGET VIGTIGT for Cloud-Init og konsol-adgang)
echo "[+] Opsætter seriel konsol og skærmkort..."
qm set $VMID --serial0 socket --vga serial0

# 9. Aktiver QEMU Guest Agent (vigtigt så Proxmox kan hente IP-adresser live)
echo "[+] Aktiverer QEMU Guest Agent i VM..."
qm set $VMID --agent enabled=1

# 10. Omdan den konfigurerede VM til en Proxmox-skabelon (Template)
echo "[+] Omdanner VM $VMID til en permanent skabelon..."
qm template $VMID

echo "================================================================="
echo "   UDRULNING AF SKABELON GENNEMFØRT SUCCESFULDT!               "
echo "================================================================="
echo "Du har nu en fungerende Cloud-Init skabelon med VMID $VMID."
echo "Du kan nu bruge dine Ansible playbooks til at klone og udrulle"
echo "nye VM'er lynhurtigt ud fra denne skabelon."
echo "================================================================="
