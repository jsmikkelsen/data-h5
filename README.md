# Datatekniker med Speciale i Infrastruktur – Hovedforløb 5 (H5)
## Samlet Infrastrukturprojekt: Netværk, Virtualisering, Sikkerhed og Monitorering

Dette repository indeholder den komplette tekniske dokumentation, designovervejelser, konfigurationer og testrapporter for det samlede infrastrukturprojekt på **Hovedforløb 5 (H5)**.

Projektet omfatter etablering af en fuldt redundant, segmenteret og overvåget hostingplatform fordelt over tre sammenhængende faser:

---

## 📂 Projektets Hovedfaser og Dokumentationsmoduler

### 🌐 [Del 1: Netværksplatform v2](./infrastrukturprojekt-del1-v2/)
*Opbygning af den redundante netværksinfrastruktur, switching, routing og sikkerhed.*
*   **Arkitektur:** Collapsed Core med 2 × Cisco Catalyst 3650 (`ds-01`, `ds-02`) og Cisco 2960X access-switche (`ms-01`).
*   **Redundans:** HSRP (Hot Standby Router Protocol) gateways og LACP EtherChannels (802.3ad).
*   **Edge Sikkerhed:** 2 × FortiGate 60F i FGCP Active/Passive HA-klynge med direkte WAN BDI-bridging på Cisco ISR 4331 (`wan-rt01`).
*   **Segmentering:** VRF-Lite med 100% adskilte kundenetværk for **Kunde Alfa** (VLAN 10), **Bravo** (VLAN 20), **Charlie** (VLAN 30), **Delta** (VLAN 40) samt **Management** (VLAN 99) og **Server Shared** (VLAN 100).
*   **Route Leaking:** Statisk VRF-leaking via Global Routing Table mod FortiGate for kontrolleret internetadgang.
*   👉 **[Gå til Del 1 Dokumentation](./infrastrukturprojekt-del1-v2/)**

---

### 🖥️ [Del 2: Virtualiseringsplatform (Proxmox VE)](./infrastrukturprojekt-del2/)
*Konsolidering af servermiljøer på Dell PowerEdge R630 under Proxmox VE.*
*   **Hardware Integration:** Dual 10G SFP+ interfaces i LACP bond (`bond0`) direkte mod Cisco 3650 Core switche samt redundant 1G management bond (`bond1`).
*   **Virtuelle Netværk:** Separate Linux Bridges (`vmbr10`, `vmbr20`, `vmbr30`, `vmbr40`, `vmbr99`, `vmbr100`) bundet til 802.1Q subinterfaces for streng L2-isolation.
*   **Ressourcestyring:** Dedikerede **Resource Pools** (`pool-alfa`, `pool-bravo`, `pool-charlie`, `pool-delta`).
*   **RBAC & Least Privilege:** Kundebrugere (`kunde-alfa@pve` osv.) med skræddersyet `CustomerVMAdmin` rolle tildelt isoleret på pool-stien.
*   **Proxmox Firewall:** 3-lags firewall-beskyttelse (Datacenter, Node og VM) med anti-spoofing (`ipfilter`) og restriktiv port-adgang.
*   **Kundeserverne:** Fire uafhængige virtuelle webservere med tilpasset Nginx identifikation.
*   👉 **[Gå til Del 2 Dokumentation](./infrastrukturprojekt-del2/)**

---

### 📊 [Del 3: Central Logging og Monitorering (LibreNMS & Netdata)](./infrastrukturprojekt-del3/)
*Enterprise overvågning, logopsamling og diagnostik.*
*   **Platforme:**
    *   **LibreNMS (NMS):** Central SNMP-polling (v2c og sikker v3 med SHA/AES), autodiscovery via LLDP/CDP, integreret Syslog-modtager, alerting engine og overbliksdashboards.
    *   **Netdata:** Realtids 1-sekunds telemetri på Dell R630 hypervisor og kundemaskiner til fange micro-bursts og CPU/RAM/Disk anomalier.
*   **Placering:** Placeret på server/shared segmentet VLAN 100 (`192.168.100.150`).
*   **Sikker Monitorering:** HTTP/ICMP health checks af kunders servere uden at kompromittere VRF-isolationen.
*   **Teori & Fagmål:** Omfattende teoretisk gennemgang af **NMS ➔ SNMP ➔ Enhed ➔ MIB ➔ OID**, sammenligning af **SNMPv2c vs SNMPv3** samt **SNMP vs Syslog vs NetFlow**.
*   **Tidssynkronisering:** Central NTP-synkronisering på tværs af alle switches, firewalls og servere.
*   **Fejlfinding:** Gennemførte og dokumenterede fejlscenarier (Webserver stop, link down, CPU stress og VM nedbrud) efter modellen **Sensor ➔ Graf ➔ Alarm ➔ Syslog**.
*   👉 **[Gå til Del 3 Dokumentation](./infrastrukturprojekt-del3/)**

---

## 📁 Øvrige Mapper og Værktøjer
*   **[`aktiv-overvaagning-ip-sla/`](./aktiv-overvaagning-ip-sla/):** Dagsopgave – Aktiv overvågning med Cisco IP SLA, Enhanced Object Tracking og automatisk floating static route failover/recovery.
*   **`case/`:** De originale opgavebeskrivelser for Del 1, Del 2 og Del 3 samt backup af fysiske configs (`ds-01.txt`, `ds-02.txt`, `ms-01.txt`, FortiGate configs).
*   **`proxmox-deploy/`:** Ansible playbooks og Cloud-Init scripts til automatiseret udrulning af VM'er og LXC containere i Proxmox.
