# Netværksdesign, Redundans og Statisk VRF Leaking (v2)

Dette dokument beskriver de arkitektoniske valg, overvejelser og tekniske designprincipper bag opbygningen af den fælles netværksplatform for **Infrastrukturprojekt – Del 1 (v2)**, med særligt fokus på **Statisk VRF Route Leaking** samt integration og administration af **Proxmox VE**.

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
              [ Klienter ]                           [ Proxmox VE ]
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
2.  **Vej tilbage til VRF (Global til Kunde):**
    *   Returtrafikken (f.eks. svar på internetsøgninger eller trafik fra Shared Services) lander i Global Routing Table på core-switchen. For at finde tilbage til kunden, tilføjes en statisk rute i Global Routing Table, der peger ind i kundens VRF:
        *   `ip route 192.168.10.0 255.255.255.0 Vlan10 192.168.10.2 vrf VRF_ALFA`
3.  **Hvorfor dette er sikkert:**
    *   Selvom Kunde Alfa og Kunde Bravo begge har en default route ud til Global Routing Table, tillader switchen *ikke* direkte routing mellem VRF'erne. Trafik fra `VRF_ALFA` kan kun sendes til interfaces, der eksisterer i dens egen VRF, eller specifikt til det angivne næste hop i GRT (`192.168.101.1` - FortiGate). Firewallen (FortiGate) kontrollerer derefter strengt, at trafikken ikke må routes på tværs af kundenetværkene.

---

## 4. Proxmox VE Netværks- og Administrationsdesign

Den fysiske server skal køre **Proxmox VE** hypervisor og fungere som vært for virtuelle maskiner (VM'er) og containere (LXC) for de forskellige kundemiljøer. Det er afgørende for sikkerheden, at hypervisorens eget administrationsinterface (GUI/API på port 8006) er fuldstændigt isoleret fra kundernes trafik.

### Fysisk Forbindelsesdesign (Cabling):
Serveren tilsluttes redundant for at undgå single points of failure:
1.  **2 x 10 Gbit/s Interfaces (Data/Kunde-Trunk):**
    *   Forbindes med 10G fiber/DAC-kabler direkte ind i Core-switchene:
        *   1 kabel til `core-sw01` (Port f.eks. Te1/0/1)
        *   1 kabel til `core-sw02` (Port f.eks. Te1/0/1)
    *   På switches konfigureres disse porte som en redundant trunk-port (fysiske porte, der tillader VLAN 10, 20, 30, 40).
2.  **4 x 1 Gbit/s Interfaces (Management & Out-of-Band):**
    *   To interfaces bruges til **Proxmox Host Management** og forbindes redundant til de to Cisco 2960X access-switche (port sat til **Access VLAN 99**).
    *   Et interface kan reserveres til serverens out-of-band management kort (f.eks. HP iLO / Dell iDRAC), som ligeledes placeres på en access-port i **VLAN 99 (Management)**.

### Logisk Netværkskonfiguration i Proxmox (Linux Bridges):

I Proxmox konfigureres to Linux Bridges via webgrænsefladen (`/etc/network/interfaces`):

```
                                  +------------------------------+
                                  |         Proxmox VE           |
                                  |                              |
  +------------------+            |  +------------------------+  |
  |  Management-Net  |------------+--| vmbr99 (SVI/Host Mgmt) |  | <-- Port 8006 (Kun tilgængelig her)
  |    (VLAN 99)     | (1G Link)  |  | IP: 192.168.99.100/24  |  |
  +------------------+            |  +------------------------+  |
                                  |                              |
                                  |  +------------------------+  |
                                  |  | vmbr0 (VLAN Aware LACP)|  |
  +------------------+            |  | Trunk mod Core 3650    |  |
  |  Kunde VLAN-Trunk|============+==| (LACP Bond - 2x10G)    |  |
  |  VLAN 10,20,30,40| (10G Links)|  +-----------+------------+  |
  +------------------+            |              |               |
                                  |    +---------+---------+     |
                                  |    |         |         |     |
                                  |  [VM 1]    [VM 2]    [VM 3]  |
                                  | (VLAN 10) (VLAN 20) (VLAN 10)| <-- Virtuelle maskiner tildeles VLANs
                                  +------------------------------+
```

1.  **`vmbr99` (Host Management Bridge):**
    *   Tilknyttes det fysiske 1G netværkskort (f.eks. `eno1`), som er forbundet til access-switchens VLAN 99 port.
    *   Proxmox-værtens administrations-IP tildeles her: `192.168.99.100/24`.
    *   Dette sikrer, at Proxmox host-operativsystemet (og Web GUI) kun kan nås fra administrationsnetværket (`VRF_MGMT`), og er fuldstændigt afskåret fra kundenetværkene.
2.  **`vmbr0` (Kunde Data Bridge - VLAN Aware):**
    *   De to fysiske 10G kort (f.eks. `ens1f0` og `ens1f1`) samles i en Linux Bond (`bond0`) med mode **LACP (802.3ad)**.
    *   Der oprettes en Linux Bridge (`vmbr0`) ovenpå `bond0`, og indstillingen **VLAN Aware** aktiveres.
    *   Broen tildeles *ingen* IP-adresse på Proxmox-vært-niveau. Den fungerer udelukkende som en virtuel Layer 2 switch.
3.  **VM/LXC Allokering:**
    *   Når der oprettes en virtuel maskine til f.eks. **Kunde Alfa**, tilknyttes dens netværkskort til `vmbr0`, og i feltet **VLAN Tag** indtastes `10`.
    *   Når maskinen starter, vil dens trafik automatisk blive tagget med VLAN 10 og sendt ud over 10G LACP-forbindelsen til Core-switchene, hvor den rammer `VRF_ALFA` og default gateway `192.168.10.1`.
    *   Kunderne kan således aldrig opsnappe eller se hinandens trafik inde i hypervisoren, da Proxmox' bridge-sikkerhed forhindrer pakke-leaking mellem VLANs.
