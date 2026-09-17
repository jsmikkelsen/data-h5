# Netværksdesign, Redundans og Statisk VRF Leaking (v2)

Dette dokument beskriver de arkitektoniske valg, overvejelser og tekniske designprincipper bag opbygningen af den fælles netværksplatform for **Infrastrukturprojekt – Del 1 (v2)**, med særligt fokus på **Statisk VRF Route Leaking** samt integration og administration af **Proxmox VE** på en **Dell PowerEdge R630**.

---

## 1. Topologi- og Arkitekturvalg

Netværksarkitekturen bygger på en robust **Collapsed Core** topologi, hvor inter-VLAN routing, redundans og sikkerhedsegregering er samlet i to centrale **Cisco Catalyst 3650 (L3)**.

```
                              +--------------------+
                              |  Cisco 4331 (WAN)  |
                              +----------+---------+
                                         | (Gig0/0/0 - VLAN 200)
                                         |
                       +-----------------+-----------------+
                       |                                   |
             +---------+----------+              +---------+----------+
             | FortiGate 60F (HA) |==============| FortiGate 60F (HA) | (Active/Passive Cluster)
             +---------+----------+              +---------+----------+
                       | (Intf4 - Trunk/VLAN 101)          |
                       +-----------------+-----------------+
                                         |
                                         | (L2 Trunk Link)
                       +-----------------+-----------------+
                       |                                   |
             +---------+----------+   L2 Transit   +---------+----------+
             |    core-sw01       |===============|    core-sw02       | (Cisco 3650 Core / VRF-Lite)
             |   (HSRP Active     |  VLAN 100/101 |  (HSRP Active      |
             |   VLAN 10 & 20)    |               |   VLAN 30 & 40)    |
             +----+-----------+---+               +----+-----------+---+
                  |           |                        |           |
                  | (LACP)    \                       /            | (LACP)
                  |            \                     /             |
                  |             \                   /              |
             +----+-----------+---+               +----+-----------+---+
             |    acc-sw01    |===================|    acc-sw02    | (Cisco 2960X Access)
             +----------------+    L2 Trunk       +----------------+
                    |                                     |
              [ Klienter ]                        [ Dell R630 Proxmox ]
```

---

## 2. Redundans og Spanning Tree (STP)

*   **Rapid-PVST+** (Rapid Per-VLAN Spanning Tree Plus) anvendes for optimal loop-prevention og lastfordeling (load sharing):
    *   `core-sw01` er primær root bridge for VLAN 10 (Alfa), 20 (Bravo) og 99 (Management).
    *   `core-sw02` er primær root bridge for VLAN 30 (Charlie) og 40 (Delta).
*   **HSRP v2** leverer redundant gateway (VIP) til kunderne. HSRP dekrementerer prioritet via interface tracking mod FortiGate-firewallen, så en switch automatisk overdrager gateway-rollen, hvis dens uplink fejler.

---

## 3. Statisk VRF Route Leaking Design

I denne version anvender vi **Statisk VRF Route Leaking** (VRF-Lite uden MP-BGP). Det er en ekstremt pålidelig og ressourcebesparende metode til at dele specifikke ruter mellem de isolerede VRF-routingtabeller og **Global Routing Table (GRT)**.

### Konceptet bag Statisk Leaking:
1.  **Vej ud af VRF (Kunde til Global/Firewall):**
    *   For at give kunderne adgang til internettet (som findes i Global Routing Table via transit-VLAN 101 og FortiGate), tilføjer vi en statisk default-route inde i kundens VRF.
    *   Denne rute peger på FortiGates transit-IP, men vi tilføjer nøgleordet `global`. Dette fortæller routeren, at den skal kigge i den globale routingtabel for at finde næste hop:
        *   `ip route vrf VRF_ALFA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global`
2.  **Vej ind (Returruter):**
    *   Returtrafikken lander i Global Routing Table på core-switchen. For at finde tilbage to kunden, tilføjes en statisk rute i Global Routing Table, der peger ind i kundens VRF-interface:
        *   `ip route 192.168.10.0 255.255.255.0 Vlan10 vrf VRF_ALFA`

---

## 4. Dell PowerEdge R630 & Proxmox VE Design

Den fysiske server er en **Dell PowerEdge R630** udstyret med et integreret Network Daughter Card (NDC), som leverer:
*   **2 x 10 Gbit/s RJ45** kobber-porte (typisk Intel X540-T2)
*   **2 x 1 Gbit/s RJ45** kobber-porte (typisk Intel I350-T2)

I Proxmox VE (Debian Linux) navngives disse integrerede onboard-porte som henholdsvis:
*   `eno1` (10 Gbit/s RJ45 - Port 1)
*   `eno2` (10 Gbit/s RJ45 - Port 2)
*   `eno3` (1 Gbit/s RJ45 - Port 3)
*   `eno4` (1 Gbit/s RJ45 - Port 4)

### Fysisk Forbindelsesdesign (Cabling):
1.  **Kunde/Data Forbindelse (10 Gbit/s RJ45):**
    *   **`eno1` (10G)** forbindes til `core-sw01` (f.eks. port `Te1/0/1`).
    *   **`eno2` (10G)** forbindes til `core-sw02` (f.eks. port `Te1/0/1`).
    *   Disse to 10G kobber-porte konfigureres i Proxmox som et **LACP (802.3ad) Bond** og opsættes som en **VLAN-Aware trunk** mod Core-switchene. Dette sikrer 20 Gbit/s aggregeret båndbredde samt komplet switch-redundans for alle kundernes VM'er (VLAN 10, 20, 30, 40).
2.  **Management / Vært Forbindelse (1 Gbit/s RJ45):**
    *   **`eno3` (1G)** forbindes til access-switchen `acc-sw01` (port konfigureret som **Access VLAN 99**).
    *   **`eno4` (1G)** forbindes til access-switchen `acc-sw02` (port konfigureret som **Access VLAN 99**).
    *   Disse to 1G porte konfigureres som en **Active-Backup Bond** i Proxmox for at sikre redundant administrationsadgang til hypervisoren på **VLAN 99 (Management)**.
3.  **Out-of-Band (Dell iDRAC Enterprise):**
    *   Dell R630 har en **dedikeret fysisk iDRAC-port** placeret på bagsiden (markeret med en skruenøgle).
    *   Denne port forbindes direkte til en af dine Cisco 2960X access-switche på en port konfigureret som **Access VLAN 99**. 
    *   Dette giver dig fuld remote-konsol og hardware-overvågning (iDRAC GUI) uafhængigt af, om Proxmox kører eller ej.

### Logisk Netværkskonfiguration i Proxmox:

```
                                  +------------------------------+
                                  |     Dell PowerEdge R630      |
                                  |                              |
  +------------------+            |  +------------------------+  |
  |  Management-Net  |------------+--| vmbr99 (SVI/Host Mgmt) |  | <-- Proxmox Web GUI (:8006)
  |    (VLAN 99)     | (1G Links) |  | IP: 192.168.99.100/24  |  |
  +------------------+            |  +------------------------+  |
                                  |        (eno3 + eno4 Bond)    |
                                  |                              |
  +------------------+            |  +------------------------+  |
  |  Kunde VLAN-Trunk|============+==| vmbr0 (VLAN Aware LACP)|  |
  |  VLAN 10,20,30,40| (10G Links)|  | Trunk mod Core 3650    |  |
  +------------------+            |  +------------------------+  |
                                  |        (eno1 + eno2 Bond)    |
                                  |                              |
                                  |    +---------+---------+     |
                                  |    |         |         |     |
                                  |  [VM 1]    [VM 2]    [VM 3]  |
                                  | (VLAN 10) (VLAN 20) (VLAN 10)| <-- Virtuelle maskiner tildeles VLANs
                                  +------------------------------+
```

1.  **`vmbr99` (Host Management Bridge):**
    *   Proxmox-værtens administrations-IP tildeles her: `192.168.99.100/24` (Gateway: `192.168.99.1`).
    *   Da denne IP bor i `VRF_MGMT`, er administrationsinterfacet på port 8006 helt usynligt og utilgængeligt for de virtuelle maskiner i kundenetværkene.
2.  **`vmbr0` (Kunde Data Bridge - VLAN Aware):**
    *   `eno1` og `eno2` (10G) samles i en LACP bond.
    *   Bridge-vlan-aware aktiveres, så vi kan køre Kunde Alfa (VLAN 10), Kunde Bravo (VLAN 20), Kunde Charlie (VLAN 30) og Kunde Delta (VLAN 40) virtuelt isoleret direkte ned på portene.
