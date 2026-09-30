# Konfigurationsskabeloner for Virtualiseringsplatform (Del 2)

Dette dokument indeholder komplette, produktionsklare konfigurationer for **Proxmox VE (Dell PowerEdge R630)**, Proxmox Brugerstyring (RBAC), Proxmox Firewall samt webserver-skabeloner for de fire kundemiljøer (**Alfa**, **Bravo**, **Charlie** og **Delta**).

---

## 1. Proxmox VE Netværkskonfiguration (`/etc/network/interfaces`)

Filen placeres på Proxmox-hosten i `/etc/network/interfaces`. Den samler de to 10G interfaces i et LACP bond og opretter de adskilte Linux Bridges for hver kunde samt management.

```bash
# ==============================================================================
# /etc/network/interfaces - Dell PowerEdge R630 (Proxmox VE 8.x)
# ==============================================================================

auto lo
iface lo inet loopback

# --- Fysiske 10G SFP+ Interfaces (Kundetrafik) ---
iface eno1 inet manual
iface eno2 inet manual

# --- Fysiske 1G RJ-45 Interfaces (Management / Out-of-Band) ---
iface eno3 inet manual
iface eno4 inet manual

# ==============================================================================
# 1. MANAGEMENT NETVÆRK (VLAN 99 / 100 via Cisco 2960X ms-01)
# ==============================================================================
auto bond1
iface bond1 inet manual
	bond-slaves eno3 eno4
	bond-miimon 100
	bond-mode active-backup
	bond-primary eno3

auto vmbr99
iface vmbr99 inet static
	address 192.168.99.100/24
	gateway 192.168.99.1
	bridge-ports bond1
	bridge-stp off
	bridge-fd 0
	# Proxmox Hypervisor Management Interface (Web GUI port 8006 & SSH)

# ==============================================================================
# 2. 10G KUNDE-TRUNK (LACP 802.3ad mod Cisco 3650 ds-01 & ds-02)
# ==============================================================================
auto bond0
iface bond0 inet manual
	bond-slaves eno1 eno2
	bond-miimon 100
	bond-mode 802.3ad
	bond-xmit-hash-policy layer2+3
	bond-lacp-rate fast

# 802.1Q VLAN Subinterfaces over 10G LACP Bond
iface bond0.10 inet manual
iface bond0.20 inet manual
iface bond0.30 inet manual
iface bond0.40 inet manual
iface bond0.100 inet manual

# ==============================================================================
# 3. KUNDE LINUX BRIDGES (Strengt isolerede Layer 2 domæner)
# ==============================================================================

# --- KUNDE ALFA (VLAN 10) ---
auto vmbr10
iface vmbr10 inet manual
	bridge-ports bond0.10
	bridge-stp off
	bridge-fd 0
	# Kunde Alfa Virtuelt Netværk (Forbindes til eth0 på VM 110)

# --- KUNDE BRAVO (VLAN 20) ---
auto vmbr20
iface vmbr20 inet manual
	bridge-ports bond0.20
	bridge-stp off
	bridge-fd 0
	# Kunde Bravo Virtuelt Netværk (Forbindes til eth0 på VM 120)

# --- KUNDE CHARLIE (VLAN 30) ---
auto vmbr30
iface vmbr30 inet manual
	bridge-ports bond0.30
	bridge-stp off
	bridge-fd 0
	# Kunde Charlie Virtuelt Netværk (Forbindes til eth0 på VM 130)

# --- KUNDE DELTA (VLAN 40) ---
auto vmbr40
iface vmbr40 inet manual
	bridge-ports bond0.40
	bridge-stp off
	bridge-fd 0
	# Kunde Delta Virtuelt Netværk (Forbindes til eth0 på VM 140)

# --- SHARED / MONITORERING / SERVER ACCESS (VLAN 100) ---
auto vmbr100
iface vmbr100 inet manual
	bridge-ports bond0.100
	bridge-stp off
	bridge-fd 0
	# Fælles server-netværk til LibreNMS / Netdata collector (192.168.100.0/24)
```

Aktivér netværket på Proxmox-hosten:
```bash
ifreload -a
```

---

## 2. Proxmox RBAC & Brugerstyring (CLI / `pveum`)

Kør følgende script på Proxmox-hosten som `root` for automatisk at oprette Resource Pools, den skræddersyede rolle, kundebrugerne og deres isolerede adgangsrettigheder:

```bash
#!/usr/bin/env bash
# ==============================================================================
# setup_proxmox_rbac.sh - Oprettelse af Resource Pools, Roller og Kunderettigheder
# ==============================================================================
set -euo pipefail

echo "=== 1. Opretter Resource Pools for hver kunde ==="
pvesh create /pools -poolid pool-alfa --comment "Kunde Alfa Servermiljø" || true
pvesh create /pools -poolid pool-bravo --comment "Kunde Bravo Servermiljø" || true
pvesh create /pools -poolid pool-charlie --comment "Kunde Charlie Servermiljø" || true
pvesh create /pools -poolid pool-delta --comment "Kunde Delta Servermiljø" || true

echo "=== 2. Opretter Custom Rolle: CustomerVMAdmin (Least Privilege) ==="
# Tillader kun drift af egne VM'er (Console, Power, Audit, Monitor)
pveum role add CustomerVMAdmin -privs "VM.PowerMgmt VM.Console VM.Monitor VM.Audit" || true

echo "=== 3. Opretter Kundebrugere i @pve Authentication Realm ==="
pveum user add kunde-alfa@pve --comment "Kunde Alfa Administrator" --password "AlfaPass2026!" || true
pveum user add kunde-bravo@pve --comment "Kunde Bravo Administrator" --password "BravoPass2026!" || true
pveum user add kunde-charlie@pve --comment "Kunde Charlie Administrator" --password "CharliePass2026!" || true
pveum user add kunde-delta@pve --comment "Kunde Delta Administrator" --password "DeltaPass2026!" || true

echo "=== 4. Tildeler ACL Permissions på Pool-niveau ==="
pveum acl modify /pool/pool-alfa -user kunde-alfa@pve -role CustomerVMAdmin
pveum acl modify /pool/pool-bravo -user kunde-bravo@pve -role CustomerVMAdmin
pveum acl modify /pool/pool-charlie -user kunde-charlie@pve -role CustomerVMAdmin
pveum acl modify /pool/pool-delta -user kunde-delta@pve -role CustomerVMAdmin

echo "=== Proxmox RBAC konfiguration gennemført fejlfrit! ==="
```

---

## 3. Proxmox Firewall Konfiguration

### A. Datacenter Firewall (`/etc/pve/firewall/cluster.fw`)
```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT
policy_forward: ACCEPT

[RULES]
# Tillad etablerede og relaterede forbindelser
IN ACCEPT -p icmp -log nolog
```

### B. Node Firewall (`/etc/pve/nodes/pve/host.fw`)
Beskytter selve Proxmox hypervisoren. Kun administrationsnetværkene (VLAN 99 og VLAN 100) må tilgå Proxmox Web GUI og SSH:
```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Tillad SSH (22) og Web GUI (8006) KUN fra Management & Shared VLANs
IN ACCEPT -source 192.168.99.0/24 -p tcp -dport 8006 -log nolog -comment "Allow PVE GUI from Mgmt"
IN ACCEPT -source 192.168.99.0/24 -p tcp -dport 22 -log nolog -comment "Allow SSH from Mgmt"
IN ACCEPT -source 192.168.100.0/24 -p tcp -dport 8006 -log nolog -comment "Allow PVE GUI from Shared"
IN ACCEPT -source 192.168.100.0/24 -p tcp -dport 22 -log nolog -comment "Allow SSH from Shared"

# Tillad Ping (ICMP) fra Management
IN ACCEPT -source 192.168.99.0/24 -p icmp -log nolog
IN ACCEPT -source 192.168.100.0/24 -p icmp -log nolog
```

### C. VM Firewall Skabelon (`/etc/pve/firewall/110.fw` - Kunde Alfa)
Gentages tilsvarende for VM 120 (Bravo), 130 (Charlie) og 140 (Delta):
```ini
[OPTIONS]
enable: 1
ipfilter: 1
policy_in: DROP
policy_out: ACCEPT

[IPSET ipfilter-net0]
192.168.10.10

[RULES]
# Tillad offentlig Web-trafik (HTTP & HTTPS)
IN ACCEPT -p tcp -dport 80 -log nolog -comment "Allow HTTP Web Traffic"
IN ACCEPT -p tcp -dport 443 -log nolog -comment "Allow HTTPS Web Traffic"

# Tillad Ping til diagnostik
IN ACCEPT -p icmp -log nolog -comment "Allow ICMP Ping"

# Tillad SSH kun fra administrativt subnet (VLAN 99 eller lokalt kundesubnet)
IN ACCEPT -source 192.168.99.0/24 -p tcp -dport 22 -log nolog -comment "Allow SSH from Mgmt"
IN ACCEPT -source 192.168.10.0/24 -p tcp -dport 22 -log nolog -comment "Allow SSH from Alfa LAN"
```

---

## 4. Kunde Webservere (Nginx & Identifikationssider)

På hver af de fire virtuelle maskiner installeres Nginx:
```bash
sudo apt update && sudo apt install -y nginx
```

### Nginx Kunde Webpage (`/var/www/html/index.html` - Eksempel for Kunde Alfa):
```html
<!DOCTYPE html>
<html lang="da">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kunde Alfa – Produktionsserver</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background-color: #0f172a; color: #f8fafc; margin: 0; padding: 40px; }
        .card { max-width: 650px; margin: 0 auto; background: #1e293b; border-radius: 12px; padding: 30px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border-left: 6px solid #38bdf8; }
        h1 { margin-top: 0; color: #38bdf8; font-size: 26px; }
        .meta-table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        .meta-table td { padding: 10px; border-bottom: 1px solid #334155; }
        .label { font-weight: bold; color: #94a3b8; width: 40%; }
        .val { color: #f1f5f9; font-family: monospace; font-size: 14px; }
        .badge { background: #0369a1; color: white; padding: 4px 10px; border-radius: 6px; font-weight: bold; font-size: 12px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🌐 Kunde Alfa – Virtuel Webserver</h1>
        <p>Denne webserver afvikles isoleret på virksomhedens fælles Proxmox VE klynge under VRF-Lite segmentering.</p>
        <table class="meta-table">
            <tr><td class="label">Kunde Identitet:</td><td class="val"><span class="badge">KUNDE ALFA</span></td></tr>
            <tr><td class="label">Server Hostname:</td><td class="val">vm-alfa-web01</td></tr>
            <tr><td class="label">Server IP-adresse:</td><td class="val">192.168.10.10 / 24</td></tr>
            <tr><td class="label">Standard Gateway (VIP):</td><td class="val">192.168.10.1</td></tr>
            <tr><td class="label">Tilknyttet VLAN:</td><td class="val">VLAN 10</td></tr>
            <tr><td class="label">Proxmox Linux Bridge:</td><td class="val">vmbr10 (bond0.10)</td></tr>
            <tr><td class="label">Cisco L3 VRF:</td><td class="val">vrf-alfa</td></tr>
            <tr><td class="label">Proxmox Resource Pool:</td><td class="val">pool-alfa</td></tr>
        </table>
    </div>
</body>
</html>
```

*(For Kunde Bravo ændres farve til `#10b981` (grøn), IP til `192.168.20.10`, VLAN 20, `vmbr20`, `vrf-bravo`; for Charlie `#f59e0b` (gul), IP `192.168.30.10`, VLAN 30; for Delta `#ec4899` (pink), IP `192.168.40.10`, VLAN 40).*

---

## 5. Ansible Automatiseringskonfiguration (`proxmox-deploy/vars.yml`)

Opdateret `vars.yml` i dit `proxmox-deploy` projekt til at udrulle de fire kundemaskiner:

```yaml
# ==============================================================================
# vars.yml - Udrulning af de fire kunde-webservere i Del 2
# ==============================================================================
proxmox_api_host: "192.168.99.100"
proxmox_api_user: "root@pam"
proxmox_node: "pve"
proxmox_validate_certs: false

cloudinit_user: "admin"
cloudinit_password: "ServerPassword2026!"
cloudinit_ssh_keys: |
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..................................... jsm@Macbook

vms_to_deploy:
  - vmid: 110
    name: "vm-alfa-web01"
    clone_template: 9000
    cores: 2
    memory: 2048
    storage: "local-lvm"
    pool: "pool-alfa"
    net0: "virtio,bridge=vmbr10,firewall=1"
    ipconfig0: "ip=192.168.10.10/24,gw=192.168.10.1"

  - vmid: 120
    name: "vm-bravo-web01"
    clone_template: 9000
    cores: 2
    memory: 2048
    storage: "local-lvm"
    pool: "pool-bravo"
    net0: "virtio,bridge=vmbr20,firewall=1"
    ipconfig0: "ip=192.168.20.10/24,gw=192.168.20.1"

  - vmid: 130
    name: "vm-charlie-web01"
    clone_template: 9000
    cores: 2
    memory: 2048
    storage: "local-lvm"
    pool: "pool-charlie"
    net0: "virtio,bridge=vmbr30,firewall=1"
    ipconfig0: "ip=192.168.30.10/24,gw=192.168.30.1"

  - vmid: 140
    name: "vm-delta-web01"
    clone_template: 9000
    cores: 2
    memory: 2048
    storage: "local-lvm"
    pool: "pool-delta"
    net0: "virtio,bridge=vmbr40,firewall=1"
    ipconfig0: "ip=192.168.40.10/24,gw=192.168.40.1"
```
