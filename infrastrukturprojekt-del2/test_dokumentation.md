# Testplan og Verifikationsdokumentation for Virtualiseringsplatform (Del 2)

Dette dokument beskriver testprocedurerne, forventede resultater og faktiske verifikationer for virksomhedens virtualiseringsplatform (**Del 2**), afviklet på **Proxmox VE (Dell PowerEdge R630)**.

Testene dokumenterer, at virtualiseringen er integreret med netværksarkitekturen fra Del 1 (v2), at kunderne er isolerede på både netværks-, firewall- og administrationsniveau, og at de etablerede webservere fungerer som forventet.

---

## 1. Test- og Verifikationsmatrix for Del 2

| Test ID | Kategori | Testscenarie / Formål | Testmetode & Kommando | Forventet Resultat | Status |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **TC-201** | Netværk | Kontroller Proxmox LACP Bond (`bond0`) status | Kør `cat /proc/net/bonding/bond0` på Proxmox host. | Bonding Mode er `IEEE 802.3ad Dynamic link aggregation`. Både `eno1` og `eno2` er markeret som `Slave Interface: enoX` og er `MII Status: up`. | [Godkendt] |
| **TC-202** | Netværk | Verificer status for Linux Bridges og VLAN-tilknytning | Kør `ip -br link show type bridge` og `bridge link` på PVE. | `vmbr10`, `vmbr20`, `vmbr30`, `vmbr40`, `vmbr99`, `vmbr100` er alle i tilstand `UP`. De respektive `bond0.X` interfaces er korrekt slaved. | [Godkendt] |
| **TC-203** | Konnektivitet | Verificer VM netværkskonnektivitet mod HSRP Gateway | Fra `vm-alfa-web01` kør: `ping -c 4 192.168.10.1`. | 0% packet loss. RTT < 1 ms. Pakken når Cisco 3650 SVI gateway VIP. | [Godkendt] |
| **TC-204** | Web Service | Verificer Webserver drift og korrekt kundeidentifikation | Kør `curl -s http://192.168.10.10 \| grep "KUNDE ALFA"`. | HTTP 200 OK returneres med HTML-siden, der entydigt identificerer kunden som Kunde Alfa. | [Godkendt] |
| **TC-205** | Isolation | Verificer komplet netværksisolation mellem kunders VM'er | Fra `vm-alfa-web01` (`192.168.10.10`), ping Kunde Bravo (`192.168.20.10`). | 100% packet loss. Trafikken blokeres af VRF-Lite segmenteringen (`vrf-alfa` vs `vrf-bravo`). | [Godkendt] |
| **TC-206** | Firewall | Test Proxmox VM Firewall regler (Port 80 vs uautoriseret port) | Kør `nmap -p 80,443,8080 192.168.10.10` fra ekstern testklient. | Port 80 og 443 rapporteres som `open`. Port 8080 rapporteres som `filtered` (droppet af Proxmox firewall). | [Godkendt] |
| **TC-207** | Sikkerhed | Anti-Spoofing test via Proxmox IP-filter | Forsøg manuelt at ændre IP på VM 110 til `192.168.20.10` og send pakker. | Pakkerne droppes i kernen af `ipfilter-net0` reglerne i `ebtables`/`iptables`. VM mister al netværksadgang. | [Godkendt] |
| **TC-208** | Sikkerhed | Verificer Proxmox Hypervisor Management isolation | Fra `vm-alfa-web01` forsøg at tilgå Proxmox Web GUI: `curl -k https://192.168.99.100:8006`. | Forbindelsen timer ud / Connection dropped. Node Firewall blokerer adgang fra kundenetværk. | [Godkendt] |
| **TC-209** | RBAC | Verificer kundelogin og ressourceisolation i Proxmox Web UI | Log ind i Proxmox Web GUI som `kunde-alfa@pve`. | Brugeren ser udelukkende `pool-alfa` og `vm-alfa-web01`. Kunde Bravo, Charlie, Delta og serverens hardware/storage er usynlige. | [Godkendt] |
| **TC-210** | RBAC | Afprøv kunders magtbeføjelser (Least Privilege) | Som `kunde-alfa@pve`, forsøg at genstarte VM 110 vs at slette disken eller oprette ny VM. | Reboot og Console fungerer fejlfrit. Oprettelse af nye VM'er, ændring af hardware eller sletning af diske afvises med *"Permission denied"*. | [Godkendt] |

---

## 2. Detaljeret Dokumentation af Testudførelse og CLI Output

### A. TC-201: Verifikation af LACP 10G Bond på Proxmox
```bash
root@pve:~# cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v5.15.131-2-pve

Bonding Mode: IEEE 802.3ad Dynamic link aggregation
Transmit Hash Policy: layer2+3 (2)
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0

802.3ad info
LACP rate: fast
Min links: 0
Aggregator ID: 1
Number of ports: 2

Slave Interface: eno1
MII Status: up
Speed: 10000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: 24:6e:96:XX:XX:01
Aggregator ID: 1

Slave Interface: eno2
MII Status: up
Speed: 10000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: 24:6e:96:XX:XX:02
Aggregator ID: 1
```
*Tolkning:* Både `eno1` og `eno2` kører fuld 10 Gbit/s LACP mod de to Cisco Catalyst 3650 switches.

---

### B. TC-204 & TC-205: Verifikation af Webserver Respons og VRF Adskillelse
Fra en administrationsklient forbundet til netværket testes webserverne:

```bash
# Test 1: Tilgå Kunde Alfa Webserver
curl -I http://192.168.10.10
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Wed, 30 Sep 2026 12:00:00 GMT
Content-Type: text/html
Content-Length: 1450
Connection: keep-alive

# Test 2: Netværksisolationstest (fra VM Alfa 192.168.10.10 mod VM Bravo 192.168.20.10)
admin@vm-alfa-web01:~$ ping -c 3 192.168.20.10
PING 192.168.20.10 (192.168.20.10) 56(84) bytes of data.

--- 192.168.20.10 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2048ms
```
*Tolkning:* Kunde Alfa kan besvare legitime webforespørgsler, men kan under ingen omstændigheder nå Kunde Bravo's server, da Cisco 3650 håndhæver streng isolation mellem `vrf-alfa` og `vrf-bravo`.

---

### C. TC-209 & TC-210: Verifikation af Proxmox RBAC Adgangskontrol
Test udført via Proxmox API CLI (`pvesh`) for at simulere adgangsbegrænsningerne:

```bash
# Logget ind som kunde-alfa@pve:
# 1. Bekræft at brugeren kan læse status på egen VM (VM 110):
pvesh get /nodes/pve/qemu/110/status/current
{
   "status" : "running",
   "vmid" : 110,
   "name" : "vm-alfa-web01",
   "cpu" : 0.015,
   "mem" : 419430400
}

# 2. Forsøg på at tilgå Kunde Bravo's VM (VM 120):
pvesh get /nodes/pve/qemu/120/status/current
403 Permission check failed (no permissions on '/vms/120' or '/pool/pool-bravo')

# 3. Forsøg på at læse hypervisorens netværkskonfiguration:
pvesh get /nodes/pve/network
403 Permission check failed (no permissions on '/nodes/pve')
```
*Tolkning:* Den konfigurerede rolle `CustomerVMAdmin` tildelt på `/pool/pool-alfa` håndhæver princippet om *Least Privilege*. Brugeren kan administrere sin egen maskine, men har absolut ingen adgang til andre kunders ressourcer eller systemindstillinger.
