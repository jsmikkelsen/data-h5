# Opgavebesvarelse & Teknisk Dokumentation: Proxmox Templates og Cloud-Init

Dette repository indeholder den komplette dokumentation, vejledning og automatiseringsscripts til opgaven **Proxmox Templates og Cloud-Init**.

Dokumentationen er struktureret, så en anden systemadministrator direkte kan forstå, genskabe og verificere hele udrulningsprocessen.

---

## Indholdsfortegnelse

1. [Indledning & Case](#indledning--case)
2. [Del 1 – Undersøg teknologien](#del-1--undersøg-teknologien)
   - [Template](#1-template-skabelon)
   - [Clone (Full vs. Linked)](#2-clone-full-vs-linked-clone)
   - [Cloud-Init](#3-cloud-init)
3. [Del 2 – Opret en Cloud-Init template](#del-2--opret-en-cloud-init-template)
   - [Trin-for-trin oprettelse i Proxmox CLI](#trin-for-trin-oprettelse-af-template)
   - [Gennemgang af centrale qm-kommandoer](#gennemgang-af-centrale-qm-kommandoer)
4. [Del 3 – Cloud-Init konfiguration](#del-3--cloud-init-konfiguration)
   - [Hvad kan Cloud-Init konfigurere?](#hvad-kan-cloud-init-konfigurere)
   - [Image-konfiguration vs. Cloud-Init data](#forskel-image-konfiguration-vs-cloud-init-data)
5. [Del 4 & 5 – Udrulning af servere og automatisk webserver](#del-4--5--udrulning-af-servere-og-automatisk-webserver)
   - [Serveroversigt](#serveroversigt)
   - [Cloud-Init User-Data snippet (Nginx + Dynamisk Hostname)](#cloud-init-user-data-snippet)
   - [Udrulning af web01, web02 og test01](#udrulning-af-serverne)
   - [Verifikation af servere og webinterface](#verifikation-af-servere-og-webinterface)
6. [Del 6 – Test af reproducerbarhed (Redeployment)](#del-6--test-af-reproducerbarhed-redeployment)
7. [Del 7 – Fejlfinding i Cloud-Init](#del-7--fejlfinding-i-cloud-init)
   - [Relevante logfiler og værktøjer](#relevante-logfiler-og-diagnostiske-værktøjer)
   - [Fejlfindingscase (Fejl → Symptom → Undersøgelse → Årsag → Løsning)](#fejlfindingscase)
8. [Del 8 – Deployment 100% fra Proxmox CLI (web03)](#del-8--deployment-100-fra-proxmox-cli-web03)
9. [Del 9 – Tænk som administrator](#del-9--tænk-som-administrator)
   - [Sammenligningsmatrix: Manuel installation vs. Template + Cloud-Init (50 servere)](#sammenligningsmatrix-50-linux-servere)
   - [Hvad skal i templaten vs. hvad skal i Cloud-Init?](#hvad-skal-i-templaten-vs-hvad-skal-i-cloud-init)
10. [Bonus – Golden Template & Avanceret Cloud-Init](#bonus--golden-template--avanceret-cloud-init)
11. [Konklusion](#konklusion)

---

## Indledning & Case

### Case
Virksomheden oplever løbende behov for at oprette nye Linux-servere til både kunder og interne udviklingsmiljøer. Indtil nu har oprettelsen været baseret på manuelle ISO-installationer, hvor en administrator hver gang bruger tid på sprogvalg, partitionering, brugeroprettelse, IP-opsætning, SSH-nøgler og installation af standardsoftware.

Denne manuelle fremgangsmåde har to store ulemper:
1. **Tidsrøver**: Oprettelse og konfiguration tager typisk 20–30 minutter pr. maskine.
2. **Konfigurationsdrift**: Menneskelige fejl og variationer betyder, at serverne ender med at være konfigureret forskelligt (inconsistent environments).

### Løsning
Ved at implementere en standardiseret **Proxmox Cloud-Init Template** kan deployment automatiseres. Resultatet er, at nye virtuelle servere kan klones og udrulles på under ét minut med garanteret konsistens, korrekte netværksoplysninger og foruddefineret software.

---

## Del 1 – Undersøg teknologien

### 1. Template (Skabelon)
* **Hvad er en VM-template?**  
  En VM-template er en frossen, skrivebeskyttet kopi af en virtuel maskine. I Proxmox markeres en template med et særligt skabelon-ikon, og konfigurationen indeholder direktivet `template: 1`.
* **Hvorfor bruger man templates?**  
  Templates danner et standardiseret fundament. De gør det muligt at springe hele styresystemets installationsfase over ved at genbruge en færdigforberedt systemdisk.
* **Forskellen på en almindelig VM og en template:**  
  En almindelig VM kan startes, stoppes, modificeres og slettes frit. En template kan **ikke startes** eller tages i drift direkte; den fungerer udelukkende som kilde for kloning af nye VM'er.
* **Fordele sammenlignet med manuel installation:**  
  - **Hastighed:** En ny VM deployes på 10–30 sekunder.
  - **Ensartethed:** Alle instanser bygger på præcis samme OS-kerne, pakkestandard og filsystemstruktur.
  - **Infrastruktur som kode (IaC):** Gør det muligt at automatisere udrulninger via CLI, scripts, Ansible eller Terraform.

### 2. Clone (Full vs. Linked Clone)

| Kriterie | Full Clone | Linked Clone |
| :--- | :--- | :--- |
| **Teknisk virkemåde** | Kopierer samtlige blokke fra templatedisken til en ny selvstændig virtuel disk. | Etablerer et *Copy-on-Write* (CoW) link. VM'en læser fra templatedisken og gemmer udelukkende nye/ændrede blokke på sin egen disk. |
| **Udrulningstid** | Typisk 20–60 sekunder afhængigt af diskstørrelse og storage I/O. | **1–3 sekunder** (næsten øjeblikkelig oprettelse). |
| **Diskforbrug** | Bruger den fulde tildelte diskstørrelse fra dag ét. | Minimalt ved opstart (få megabytes), vokser kun i takt med nye ændringer. |
| **Afhængighed** | **100% uafhængig.** Templaten kan slettes, flyttes eller renames uden påvirkning af VM'en. | **Høj afhængighed.** Slettes eller beskadiges basistemplaten, stopper alle linked clones med at fungere. |
| **Bedst til** | Produktionsmiljøer, langsigtede servere, uafhængige workloads. | Testmiljøer, labs, skiftende servere eller miljøer med begrænset lagerplads. |

### 3. Cloud-Init
* **Hvad er Cloud-Init?**  
  Cloud-Init er industristandarden til *early system initialization* på Linux i cloud- og virtualiseringsplatforme (AWS, OpenStack, Azure, Proxmox m.fl.).
* **Hvad bruges det til?**  
  Det tildeler en generisk virtuel maskine sin unikke identitet og netværkskonfiguration under første opstart.
* **Hvornår køres det?**  
  Det kører som en række systemd-tjenester under maskinens opstartsfaser:
  1. `cloud-init-local` (finder datakilde og klargør basalt netværk)
  2. `cloud-init` (indlæser metadata, tildeler hostname)
  3. `cloud-config` (opretter brugere, SSH keys, disk resize)
  4. `cloud-final` (installerer pakker via apt, kører `runcmd` scripts)  
  *Bemærk:* De fleste moduler afvikles udelukkende ved maskinens **første boot** (*per-instance*).
* **Hvilke informationer leveres?**  
  - **Meta-data:** Hostname, instance-id.
  - **User-data:** Lokale brugere, adgangskoder, SSH public keys, pakker (`packages`), tilpassede scripts (`runcmd`), filoprettelse (`write_files`).
  - **Network-config:** Statisk IP/DHCP, gateway, subnet maske, DNS servere og søgedomæner.
* **Hvorfor passer Cloud-Init godt sammen med templates?**  
  En template må aldrig indeholde statiske IP-adresser, specifikke hostnames eller delte SSH-hostnøgler (da det skaber netværkskonflikter og sikkerhedshuller). Cloud-Init tillader, at templaten forbliver 100% neutral og anonym, mens alle unikke parametre indsprøjtes i det sekund, maskinen klones og starter.

---

## Del 2 – Opret en Cloud-Init template

Til denne opgave anvendes et officielt **Ubuntu 24.04 LTS (Noble Numbat)** Cloud Image (`.img`/qcow2 format).

### Trin-for-trin oprettelse af Template

Kommandoerne udføres direkte i Proxmox CLI (via SSH eller Web Shell som `root`):

```bash
# 1. Hent det officielle Ubuntu Cloud Image
cd /tmp
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O noble-server-cloudimg.img

# 2. Definer variabler
VMID=9000
VM_NAME="ubuntu-2404-cloudinit-template"
STORAGE="local-lvm"  # Skift til f.eks. 'local-zfs' ved ZFS storage

# 3. Opret den virtuelle maskine med de krævede specifikationer
qm create $VMID \
    --name "$VM_NAME" \
    --memory 2048 \
    --cores 2 \
    --cpu host \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

# 4. Importer det hentede Cloud Image til Proxmox storage
qm importdisk $VMID noble-server-cloudimg.img $STORAGE

# 5. Forbind den importerede disk til SCSI controlleren
qm set $VMID --scsi0 $STORAGE:vm-$VMID-disk-0,discard=on,ssd=1

# 6. Tilføj Cloud-Init CD-ROM drev på IDE controlleren
qm set $VMID --ide2 $STORAGE:cloudinit

# 7. Sæt boot-rækkefølge til SCSI disken
qm set $VMID --boot order=scsi0 --bootdisk scsi0

# 8. Tilknyt seriel konsol og display (nødvendigt for Cloud-Init / xterm.js)
qm set $VMID --serial0 socket --vga serial0

# 9. Aktiver QEMU Guest Agent
qm set $VMID --agent enabled=1

# 10. Forøg diskstørrelsen (f.eks. med 20 GB)
qm disk resize $VMID scsi0 +20G

# 11. Konverter den virtuelle maskine til en Template
qm template $VMID
```

### Gennemgang af centrale qm-kommandoer:

1. **`qm create <vmid> [options]`**  
   *Formål:* Opretter en ny virtuel maskines metadata og tildeler dens hardwareprofil. Kommandoen opretter konfigurationsfilen `/etc/pve/qemu-server/<vmid>.conf` og tildeler 2 vCPU, 2 GB RAM og et VirtIO-netkort på bridge `vmbr0`.
2. **`qm importdisk <vmid> <disk-fil> <storage>`**  
   *Formål:* Konverterer og overfører det downloadede operativsystem-image til Proxmox' storage pool (f.eks. LVM-thin eller ZFS). Den oprettede disk optræder herefter som `unused0` på den angivne VM.
3. **`qm set <vmid> [options]`**  
   *Formål:* Ændrer og tilføjer hardware til en eksisterende VM-konfiguration. I vores proces bruges kommandoen til:
   - At tilknytte disken som `scsi0`.
   - At oprette et virtuelt Cloud-Init ISO-drev på `ide2`.
   - At aktivere QEMU Guest Agent (`--agent enabled=1`), så Proxmox kan udveksle data om IP-adresser og foretage sikre genstarter.
   - At sætte seriel skærm og boot-rækkefølge.
4. **`qm template <vmid>`**  
   *Formål:* Låser maskinen permanent mod fremtidig start og direkte skrivning. Den tilføjer flaget `template: 1` i konfigurationen, hvilket omdanner VM'en til en skabelon i Web UI og gør den tilgængelig som kilde til kloning.

---

## Del 3 – Cloud-Init konfiguration

### Hvad kan Cloud-Init konfigurere?
Cloud-Init kan levere samtlige nødvendige basale serverindstillinger:
- **Brugernavn:** Standard bruger oprettes med sudo-rettigheder (f.eks. `administrator`).
- **Adgangskontrol:** Injektion af offentlige SSH-nøgler (`authorized_keys`) og eventuelt password-hashing.
- **Hostname:** Sætter serverens unikke navn (`/etc/hostname` og opdaterer `/etc/hosts`).
- **Netværksadresser:** Statisk IPv4/IPv6 adresse inkl. subnetmaske/CIDR.
- **Default Gateway:** Routing til eksterne netværk og internettet.
- **DNS-servere:** Navneopløsning (`/etc/resolv.conf`).

### Forskel: Image-konfiguration vs. Cloud-Init Data

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ BASE IMAGE / TEMPLATE (Fælles fundament)                                │
│ ─────────────────────────────────────────────────────────────────────── │
│ - Linux-kerne (Kernel) og standard systembiblioteker                    │
│ - Forudinstallerede services: systemd, openssh-server, cloud-init-core  │
│ - QEMU Guest Agent daemon                                               │
│ - INGEN IP-adresser                                                     │
│ - INGEN faste hostnames                                                 │
│ - INGEN unikke SSH host-nøgler (/etc/ssh/ssh_host_* slettes i image)    │
│ - INGEN unikke maskin-ID'er (/etc/machine-id er tomt)                   │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                        Kloning og første opstart
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CLOUD-INIT INJEKTION (Unik instans-konfiguration)                       │
│ ─────────────────────────────────────────────────────────────────────── │
│ - Hostname: Tildeles f.eks. "web01"                                     │
│ - Netværk: Tildeles f.eks. 192.168.1.101/24 og gateway 192.168.1.1      │
│ - Administrator-konto med specifik SSH public key                       │
│ - Generering af helt nye, unikke SSH host keys for sikkerhed            │
│ - Generering af nyt /etc/machine-id                                     │
│ - Kørsel af specifikke installations-scripts (f.eks. Nginx webserver)   │
└─────────────────────────────────────────────────────────────────────────┘
```

**Konklusion på forskellen:**  
Templaten indeholder udelukkende den statiske, generiske infrastruktur. Cloud-Init indeholder den dynamiske identitet. Dette gør, at én enkelt template kan ligge til grund for 100 forskellige servere med 100 forskellige roller.

---

## Del 4 & 5 – Udrulning af servere og automatisk webserver

### Serveroversigt

| VMID | Navn / Hostname | Netværk | IPv4 / CIDR | Gateway | DNS | Rolle |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **101** | `web01` | Statisk IP | `192.168.1.101/24` | `192.168.1.1` | `1.1.1.1` | Webserver (Nginx) |
| **102** | `web02` | Statisk IP | `192.168.1.102/24` | `192.168.1.1` | `1.1.1.1` | Webserver (Nginx) |
| **103** | `test01` | DHCP | Automatisk | Automatisk | Automatisk | Generel testserver |

*(Netværkstilpasning: Ret IP-adresser og gateway, så de matcher dit faktiske Proxmox bridge-subnet).*

---

### Cloud-Init User-Data snippet

For at opfylde kravene i **Del 5** anvendes en Cloud-Init user-data snippet på Proxmox-hosten.

1. **Placering på Proxmox-vært:**  
   Filen placeres i `/var/lib/vz/snippets/webserver-userdata.yaml`  
   *(Sørg for, at `snippets` er aktiveret under Storage `local` i Proxmox Web UI).*

2. **Indhold af `webserver-userdata.yaml`:**
   ```yaml
   #cloud-config
   package_update: true
   packages:
     - nginx
     - curl

   write_files:
     - path: /var/www/html/index.html
       owner: www-data:www-data
       permissions: '0644'
       content: |
         <!DOCTYPE html>
         <html lang="da">
         <head>
             <meta charset="UTF-8">
             <title>Automatisk Webserver</title>
             <style>
                 body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
                 .card { background: #1e293b; padding: 2.5rem; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; text-align: center; max-width: 520px; }
                 h1 { color: #38bdf8; font-size: 1.6rem; margin-bottom: 0.5rem; }
                 .tag { display: inline-block; padding: 0.25rem 0.75rem; background: #0284c7; color: white; border-radius: 9999px; font-size: 0.8rem; margin-bottom: 1.5rem; }
                 .info { background: #0f172a; padding: 1rem; border-radius: 8px; border: 1px solid #334155; text-align: left; margin-top: 1rem; }
                 .label { color: #94a3b8; font-size: 0.8rem; text-transform: uppercase; }
                 .val { font-family: monospace; font-size: 1.15rem; color: #4ade80; font-weight: bold; }
             </style>
         </head>
         <body>
             <div class="card">
                 <span class="tag">Proxmox Cloud-Init</span>
                 <h1>Server deployed automatically with Proxmox Cloud-Init</h1>
                 <p style="color: #94a3b8;">Webserveren er installeret og sat i drift fuldautomatisk ved første opstart.</p>
                 <div class="info">
                     <div class="label">Server Hostname</div>
                     <div class="val">HOSTNAME_REPLACE</div>
                 </div>
             </div>
         </body>
         </html>

   runcmd:
     # Erstat placeholder dynamisk med maskinens aktuelle hostname
     - sed -i "s/HOSTNAME_REPLACE/$(hostname)/g" /var/www/html/index.html
     - systemctl restart nginx
   ```

---

### Udrulning af serverne

Kør følgende på Proxmox CLI:

#### 1. Udrul `web01` (VMID: 101)
```bash
qm clone 9000 101 --name web01 --full 0
qm set 101 --ciuser administrator
qm set 101 --sshkeys ~/.ssh/id_rsa.pub
qm set 101 --ipconfig0 ip=192.168.1.101/24,gw=192.168.1.1
qm set 101 --nameserver 1.1.1.1
qm set 101 --cicustom "user=local:snippets/webserver-userdata.yaml"
qm start 101
```

#### 2. Udrul `web02` (VMID: 102)
```bash
qm clone 9000 102 --name web02 --full 0
qm set 102 --ciuser administrator
qm set 102 --sshkeys ~/.ssh/id_rsa.pub
qm set 102 --ipconfig0 ip=192.168.1.102/24,gw=192.168.1.1
qm set 102 --nameserver 1.1.1.1
qm set 102 --cicustom "user=local:snippets/webserver-userdata.yaml"
qm start 102
```

#### 3. Udrul `test01` (VMID: 103)
```bash
qm clone 9000 103 --name test01 --full 0
qm set 103 --ciuser administrator
qm set 103 --sshkeys ~/.ssh/id_rsa.pub
qm set 103 --ipconfig0 ip=dhcp
qm start 103
```

---

### Verifikation af servere og webinterface

Efter 30–60 sekunder er serverne færdige med Cloud-Init first-boot fasen.

1. **Test af Webservere i Browser:**
   - Naviger til `http://192.168.1.101/` -> Siden vises med titlen og **Hostname: web01**.
   - Naviger til `http://192.168.1.102/` -> Siden vises med titlen og **Hostname: web02**.

2. **Verifikation via SSH (uden manuelle ændringer):**
   ```bash
   ssh administrator@192.168.1.101
   
   # Tjek hostname
   hostnamectl status
   
   # Tjek IP adresse
   ip -br addr show dev eth0
   
   # Tjek Default Gateway
   ip route show default
   
   # Tjek DNS server
   resolvectl status | grep "DNS Servers" || cat /etc/resolv.conf
   
   # Tjek webserver proces
   systemctl is-active nginx
   ```

---

## Del 6 – Test af reproducerbarhed (Redeployment)

Formålet med denne test er at demonstrere **Pets vs. Cattle** princippet: Servere skal kunne slettes og genskabes øjeblikkeligt uden tab af konfigurationsintegritet.

### Gennemførelse af testen:

1. **Slet den eksisterende `web02`:**
   ```bash
   qm stop 102
   qm destroy 102
   ```
   *Resultat:* VM 102 og dens tilknyttede CoW-disk er nu fuldstændigt fjernet fra Proxmox storage.

2. **Genskab `web02` fra templaten:**
   ```bash
   qm clone 9000 102 --name web02 --full 0
   qm set 102 --ciuser administrator
   qm set 102 --sshkeys ~/.ssh/id_rsa.pub
   qm set 102 --ipconfig0 ip=192.168.1.102/24,gw=192.168.1.1
   qm set 102 --nameserver 1.1.1.1
   qm set 102 --cicustom "user=local:snippets/webserver-userdata.yaml"
   qm start 102
   ```

3. **Verifikation:**
   - Afvent 40 sekunder.
   - Åbn `http://192.168.1.102/`.
   - Nginx serverer straks siden, og hostnamet er korrekt sat til `web02`.
   - **Konklusion:** Deployment er 100% reproducerbar og uafhængig af manuelle handlinger.

---

## Del 7 – Fejlfinding i Cloud-Init

### Relevante logfiler og diagnostiske værktøjer

Inde på den virtuelle Linux-server findes de vigtigste værktøjer:

1. **`cloud-init status --long`**:  
   Giver hurtigt overblik over den overordnede tilstand (`running`, `done` eller `error`) samt start- og sluttidspunkter.
2. **`/var/log/cloud-init.log`**:  
   Detaljeret hændelseslog for samtlige moduler, registrering af datasource (f.eks. `DataSourceNoCloud`) og parsing af metadata.
3. **`/var/log/cloud-init-output.log`**:  
   **Den vigtigste logfil til fejlfinding på software.** Viser direkte output (`stdout` og `stderr`) fra pakkeinstallationer via APT og kommandoer i `runcmd`.
4. **`cloud-init query -a`**:  
   Viser samtlige metadata og user-data værdier, som Cloud-Init har modtaget fra Proxmox.

---

### Fejlfindingscase:

| Fase | Beskrivelse |
| :--- | :--- |
| **1. Fejl** | Der blev konfigureret en ikke-eksisterende default gateway på `web01` (`gw=192.168.1.254` i stedet for `192.168.1.1`). |
| **2. Symptom** | Maskinen starter op, og lokal ping på samme switch/subnet fungerer. Men HTTP på port 80 svarer ikke, og Nginx er ikke installeret (`nginx: command not found`). |
| **3. Undersøgelse** | <br>1. Kørsel af `cloud-init status --long` viste `status: error`.<br>2. Gennemgang af `/var/log/cloud-init-output.log` viste:<br>`Err:1 http://archive.ubuntu.com/ubuntu noble InRelease`<br>`Cannot initiate the connection to archive.ubuntu.com:80 (Network is unreachable)`<br>`E: Unable to locate package nginx`<br>3. Kørsel af `ip route` viste `default via 192.168.1.254 dev eth0`. Gatewayen svarede ikke på ARP requests. |
| **4. Årsag** | På grund af den forkerte gateway manglede serveren internetforbindelse under boot. Da Cloud-Init nåede fasen `packages: [nginx]`, fejlede `apt update` og pakkeinstallationen, hvorefter initialiseringen afbrød med en fejl. |
| **5. Løsning** | <br>1. Ret gateway på Proxmox-hosten:<br>`qm set 101 --ipconfig0 ip=192.168.1.101/24,gw=192.168.1.1`<br>2. På VM'en blev Cloud-Init nulstillet og genstartet:<br>`cloud-init clean --reboot`<br>3. Efter genstart havde maskinen internetadgang, Nginx blev installeret med succes, og websiden fungerede. |

---

## Del 8 – Deployment 100% fra Proxmox CLI (web03)

For at automatisere oprettelsen af `web03` (VMID: 104) anvendes scriptet `scripts/deploy_web03.sh`.

```bash
#!/bin/bash
# ==============================================================================
# SCRIPT: deploy_web03.sh
# FORMÅL: Fuldautomatisk udrulning af web03 via Proxmox CLI
# ==============================================================================
set -e

# --- PARAMETRE ---
TEMPLATE_ID=9000
NEW_VMID=104
NEW_NAME="web03"
NEW_IP="192.168.1.104/24"
GATEWAY="192.168.1.1"
DNS="1.1.1.1"
ADMIN_USER="administrator"
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"
USERDATA_SNIPPET="local:snippets/webserver-userdata.yaml"
# -----------------

echo "[1/4] Kloner template $TEMPLATE_ID til ny VM $NEW_VMID ($NEW_NAME)..."
qm clone $TEMPLATE_ID $NEW_VMID --name "$NEW_NAME" --full 0

echo "[2/4] Konfigurerer Cloud-Init bruger, netværk og SSH..."
qm set $NEW_VMID \
    --ciuser "$ADMIN_USER" \
    --sshkeys "$SSH_KEY_FILE" \
    --ipconfig0 ip="$NEW_IP",gw="$GATEWAY" \
    --nameserver "$DNS"

echo "[3/4] Tilknytter user-data snippet til automatisk Nginx..."
qm set $NEW_VMID --cicustom "user=$USERDATA_SNIPPET"

echo "[4/4] Starter $NEW_NAME..."
qm start $NEW_VMID

echo "================================================================="
echo " Succes! $NEW_NAME er deployet med IP $NEW_IP"
echo " Webserveren er klar på http://${NEW_IP%/*}/ om ~40 sekunder."
echo "================================================================="
```

---

## Del 9 – Tænk som administrator

### Sammenligningsmatrix: 50 Linux-servere

| Kriterie | Manuel Installation (50 servere) | Template + Cloud-Init (50 servere) |
| :--- | :--- | :--- |
| **Tidsforbrug** | **16–25 timer.** 20–30 minutter pr. server ved manuel klik i ISO, reboot og konfiguration. | **Under 5 minutter.** Et simpelt bash-loop eller Ansible playbook kan udrulle alle 50 servere parallelt. |
| **Ensartethed** | **Meget lav.** Menneskelige variationer vil uundgåeligt give forskelle i pakkeversioner, partitionering og filstier. | **100% konsistent.** Samtlige maskiner udspringer af nøjagtig samme binære base-image. |
| **Fejlrisiko** | **Høj.** Risiko for slåfejl i IP-adresser, oversete sikkerhedsindstillinger eller glemte softwarepakker. | **Minimal.** Al konfiguration er defineret som kode (IaC), valideret forud for udrulning. |
| **Vedligeholdelse** | Hver server skal patches og opdateres individuelt fra bunden. | Basistemplaten kan opdateres løbende, så nye servere altid har de nyeste patches. |
| **Skalering** | Lineær stigning i arbejdsbyrde (50 servere = 50x arbejde). | Skalerer frit (samme tidsforbrug for 5 som for 500 maskiner). |
| **Sikkerhed** | Høj risiko for, at en administrator glemmer at lukke porte, oprette SSH-nøgler eller deaktivere svage koder. | Høj. Standardopsætningen gennemtvinger SSH-key-only autentificering og lukker svage services automatisk. |
| **Automatisering** | Umulig at integrere i moderne CI/CD pipelines. | Fuld understøttelse af API, CLI, Terraform og Ansible. |

---

### Hvad skal i templaten vs. hvad skal i Cloud-Init?

#### A. Hvad der BØR ligge permanent i Template-Imaget:
1. **Opdateret styresystem:** De nyeste sikkerhedsopdateringer op til templates oprettelse (sparer enorm båndbredde og tid ved deployment).
2. **QEMU Guest Agent:** Kritisk komponent for Proxmox-integration (rapportering af IP-adresser og shutdown-signaler).
3. **Cloud-Init pakken:** Selve initialiseringsmotoren.
4. **Standard systemværktøjer:** Værktøjer som `curl`, `wget`, `htop`, `vim`, `net-tools`, `git`.
5. **VirtIO-drivere:** KVM-optimerede drivere til netværk og disk.

*Begrundelse:* Disse komponenter er universelle på tværs af alle serverroller. Ved at bage dem ind i imaget undgår man at spilde tid på gentagne downloads under første boot.

#### B. Hvad der FØRST bør konfigureres gennem Cloud-Init:
1. **Netværk (IP, Gateway, Subnet, DNS):** Skal altid være unikt pr. maskine for at undgå netværkskollisioner.
2. **Identitet (Hostname, FQDN):** Maskinens officielle navn.
3. **Brugere og SSH-nøgler:** Hvilke administratorer skal have adgang, og med hvilke nøgler.
4. **SSH Host Keys (`/etc/ssh/ssh_host_*`):** **Må ALDRIG deles mellem maskiner.** Cloud-Init genererer nye unikke nøgler ved boot for at forhindre Man-in-the-Middle angreb.
5. **Maskin-ID (`/etc/machine-id`):** Skal være unikt for at undgå DHCP- og log-konflikter.
6. **Rolle-specifik software:** Installation af f.eks. Nginx, PostgreSQL, Docker eller overvågningsagenter baseret på maskinens specifikke formål.

---

## Bonus – Golden Template & Avanceret Cloud-Init

Under `snippets/golden-userdata.yaml` er der udarbejdet et avanceret user-data manifest til en hærdet produktionsserver (*Golden Server*):
- Fuld systemopgradering ved boot (`package_upgrade: true`).
- Automatisk tidszoneindstilling (`Europe/Copenhagen`).
- Sikkerhedspakker installeret: `fail2ban` og `ufw`.
- Automatisk aktivering af `qemu-guest-agent`.
- Flot, moderne dashboard på port 80 med serverens hostname.

---

## Konklusion

Ved at koble **Cloud Images**, **Proxmox Templates** og **Cloud-Init** sammen opnås en professionel og automatiseret serverinfrastruktur. 

Modellen fjerner alt manuelt tastearbejde, minimerer deployment-tider fra minutter til sekunder, sikrer fuld sporbarhed og gør det muligt at behandle servere som udskiftelige ressourcer (*cattle* frem for *pets*).
