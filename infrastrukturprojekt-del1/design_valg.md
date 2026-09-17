# Netværksdesign, Redundans og VRF-Lite Designvalg

Dette dokument beskriver de arkitektoniske valg, overvejelser og tekniske designprincipper bag opbygningen af den fælles netværksplatform for **Infrastrukturprojekt – Del 1**. 

---

## 1. Topologi- og Arkitekturvalg

Netværksarkitekturen er designet ud fra en **Collapsed Core** model, som integrerer Core- og Distributionslagene i de to **Cisco Catalyst 3650 (L3)** switche. Dette valg er truffet for at opnå optimal performance og robusthed på en omkostningseffektiv måde.

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
              [ Klienter ]                           [ Server ]
```

### Enhedernes Roller:
1.  **Cisco Catalyst 3650 (Core/Distribution):** Fungerer som inter-VLAN gateway (SVI). Switchene huser alle kunde-VRF'er samt management-VRF, og det er her, den interne Layer 3 adskillelse og route-leaking foregår.
2.  **Cisco Catalyst 2960X (Access):** Leverer fysisk tilslutning (access-porte) til klienter, testmaskiner og servere på de korrekte VLANs.
3.  **FortiGate 60F (Edge/Firewall):** Placeret som et redundant par i **Active/Passive HA cluster**. Den agerer "gatekeeper" mellem det interne netværk (Global Routing Table på 3650) og WAN-miljøet. Det er her, der laves sikkerhedspolitikker (firewall rules), som kontrollerer, hvilken trafik der må forlade kundenetværkene og ramme omverdenen.
4.  **Cisco ISR 4331 (WAN Router):** Simulerer en ekstern internetudbyder (ISP) eller eksterne Shared Services i Global Routing Table (GRT).

---

## 2. Layer 2 Redundans og Loop Prevention

For at forhindre Layer 2-løkker og sikre lynhurtig konvergens i tilfælde af kabelfejl, konfigureres følgende teknologier:

### Spanning Tree Protocol (STP) - Rapid PVST+ / MSTP
*   Vi anvender **Rapid-PVST+** (Rapid Per-VLAN Spanning Tree Plus) for optimal kontrol per VLAN.
*   **Root Bridge allokering:**
    *   `core-sw01` konfigureres som primær root bridge (`priority 4096`) for VLAN 10, 20 og 99, og sekundær root bridge (`priority 8192`) for VLAN 30 og 40.
    *   `core-sw02` konfigureres som primær root bridge (`priority 4096`) for VLAN 30 og 40, og sekundær root bridge (`priority 8192`) for VLAN 10, 20 og 99.
    *   Dette sikrer aktiv **load sharing** over de fysiske uplinks.
*   **STP Sikkerhed (PortFast og BPDU Guard):**
    *   Konfigureres på alle access-porte mod klienter og den fysiske server. 
    *   **PortFast** overspringer STP-lyttestatus, så porte kommer online med det samme.
    *   **BPDU Guard** deaktiverer automatisk porten (`err-disable`), hvis en bruger forsøger at tilslutte en switch og derved sender STP BPDU-pakker ind i netværket.

### EtherChannel (LACP)
*   **Mellem Core og Access:** Vi konfigurerer cross-switch EtherChannels ved brug af **LACP (IEEE 802.3ad)**. Links fra `acc-sw01` forbindes redundant til både `core-sw01` og `core-sw02` (hvis de er stakket). Hvis switchene er uafhængige, samles uplinks i standard LACP EtherChannels mellem switchene for at øge båndbredden og eliminere single-links som fejlkilder.

---

## 3. Layer 3 Redundans med HSRP

Kunderne har brug for en redundant standard-gateway (Default Gateway). Dette løses med **HSRP v2 (Hot Standby Router Protocol)** konfigureret på SVI-niveau (Switched Virtual Interface) på de to Cisco 3650:

*   HSRP tildeler en **Virtual IP (VIP)** og en **Virtual MAC** til hver kundes VLAN. Klienterne peger på denne VIP som gateway.
*   **Load Sharing Design:**
    *   For **VLAN 10 (Kunde A)** og **VLAN 20 (Kunde B)** er `core-sw01` den aktive gateway (HSRP `priority 110`), og `core-sw02` er standby (HSRP `priority 100`).
    *   For **VLAN 30 (Kunde C)** og **VLAN 40 (Kunde D)** er `core-sw02` den aktive gateway (HSRP `priority 110`), og `core-sw01` er standby (HSRP `priority 100`).
*   **HSRP Preemption og Tracking:**
    *   **Preempt** aktiveres, så den primære switch automatisk overtager rollen som aktiv gateway igen, når den kommer online efter et strømudfald.
    *   **Interface Tracking** opsættes på Core-switchene, så hvis en switch mister sin uplink-forbindelse mod FortiGate Edge-firewallen, sænkes dens HSRP-prioritet automatisk med 20. Herved overtager den anden Core-switch gateway-rollen proaktivt, så klienterne ikke ender i en "black hole" situation uden WAN-forbindelse.

---

## 4. VRF-Lite og MP-BGP Route Leaking

Multi-tenancy (multi-kundemiljøer) understøttes sikkert via **VRF-Lite** på Cisco 3650.

### VRF Isolation (Virtual Routing and Forwarding)
*   Der oprettes fem separate VRF-routingtabeller på Core-switchene:
    *   `VRF_A` (Kunde A)
    *   `VRF_B` (Kunde B)
    *   `VRF_C` (Kunde C)
    *   `VRF_D` (Kunde D)
    *   `VRF_MGMT` (Administration)
*   Hvert kundenetværk og tilhørende SVI tildeles sin respektive VRF. Routing-tabellerne er 100% isolerede. En route i `VRF_A` eksisterer ikke i `VRF_B` eller i **Global Routing Table (GRT)**.

### Route Leaking via Global Routing Table (MP-BGP)
Opgaven stiller krav om, at kunderne skal være isolerede, men at der skal etableres kontrolleret deling (route leaking) af udvalgte routes ved brug af **Global Routing Table (GRT)** som formidler.

Vi designer dette ved hjælp af **MP-BGP (Multiprotocol BGP) med Route Targets (RT)** på Cisco 3650:

1.  **BGP i GRT:** Vi kører en lokal BGP-proces (f.eks. `router bgp 65001`) på Cisco 3650.
2.  **Route Distinguishers (RD) & Route Targets (RT):**
    *   Hver VRF tildeles en unik RD for at adskille prefixes (f.eks. `65001:10` for VRF_A).
    *   **Route Targets (RT)** bruges til at styre import/export.
3.  **Leaking Logik:**
    *   **Fra VRF til Global (GRT):** For de kunder, der skal have WAN-adgang eller adgang til Shared Services i GRT, eksporterer vi deres prefixes fra VRF'en med en specifik RT (f.eks. `route-target export 65001:999`). Global Routing Table importerer denne RT.
    *   **Fra Global (GRT) til VRF:** Default-routen (`0.0.0.0/0`), som 3650-switchene modtager fra FortiGate Edge-firewallen (placeret i GRT), eksporteres fra GRT og importeres ind i de specifikke kunders VRF'er via Route Targets (f.eks. `route-target import 65001:999`).
4.  **Alternativ (Static VRF Leaking):** Hvis MP-BGP ikke understøttes af switch-licensen, anvender vi statisk route leaking direkte i CLI via next-hop-VRF syntaks:
    *   `ip route vrf VRF_A 0.0.0.0 0.0.0.0 Vlan 101 10.101.0.1 global` (Default route ud af VRF_A til GRT gateway på FortiGate).
    *   `ip route 10.10.0.0 255.255.255.0 Vlan 10 10.10.0.10 vrf VRF_A` (Returrute i GRT ind i VRF_A).

---

## 5. Management Netværksdesign

Management-netværket (VLAN 99) er hjørnestenen i sikker administration.
*   **Komplet VRF Isolering:** Management placeres i sin egen `VRF_MGMT`. Derved er administrationsinterfacerne på switches og routere overhovedet ikke synlige eller pingbare fra kundernes netværk.
*   **Adgangskontrol (VTY Access-Lists):** På Cisco-switchene og routerne implementeres en Access Control List (ACL) på VTY-linjerne (SSH adgang). Kun IP-adresser, der tilhører det autoriserede administrative sub-net, tillades SSH-forbindelse. Alt andet blokeres.
*   **FortiGate Management:** FortiGates administreres via et dedikeret Management-interface (typisk `mgmt` eller en dedikeret port), som forbindes direkte til VLAN 99.

---

## 6. Fysisk Server Integration

Netværksplatformen forberedes til den fysiske server med dens 4x1G interfaces samt 2x10G interfaces:

*   **2 x 10 Gbit/s Interfaces (Kunde/Data):**
    *   Disse forbindes direkte til de to Cisco 3650 Core switches (1 kabel til `core-sw01` og 1 kabel til `core-sw02`).
    *   Portene konfigureres som en **LACP EtherChannel (Trunk)** på switches.
    *   Dette gør det muligt for serveren (via f.eks. en hypervisor som VMware ESXi eller Proxmox VE) at terminere trunkede VLANs fra Kunde A, B, C og D med 10G hastighed, mens der er fuld redundans, hvis en af 3650-switchene genstartes.
*   **4 x 1 Gbit/s Interfaces (Management & backup):**
    *   To interfaces forbindes til Cisco 2960X access-switchene på **VLAN 99 (Management)** for out-of-band hypervisor/server management (iLO/iDRAC/Management IP).
    *   De resterende to interfaces kan allokeres til dedikerede backup-netværk eller isolerede DMZ-miljøer i fremtidige faser.
