# Netværksdesign, Redundans og Statisk VRF Leaking (v2)

Dette dokument beskriver de arkitektoniske valg, overvejelser og tekniske designprincipper bag opbygningen af den fælles netværksplatform for **Infrastrukturprojekt – Del 1 (v2)**, med særligt fokus på **Direkte WAN-forbindelse**, **Statisk VRF Route Leaking** samt integration og administration af **Proxmox VE** på en **Dell PowerEdge R630**.

---

## 1. Topologi- og Arkitekturvalg

Netværksarkitekturen bygger på en robust **Collapsed Core** topologi, hvor inter-VLAN routing, redundans og sikkerhedsegregering er samlet i to centrale **Cisco Catalyst 3650 (L3)**.

```
                            [ Skole/Hjemme-LAN (Internet) ]
                                          |
                                          | (DHCP / NAT Outside)
                                  [ Gi0/0/1 ]
                             [ Cisco 4331 wan-rt01 ]
                                  [ Gi0/0/0 ]       [ Gi0/0/2 ]  (L2 Bridged via BDI1)
                                       |                 |
                                       | (192.168.200.2) |
                                       |                 |
                                    [ wan1 ]          [ wan1 ]
                             [ FortiGate 60F - 1 ]==========HA (Port a & b)==========[ FortiGate 60F - 2 ]
                                   [ port4 ]                                           [ port4 ]
                                       |                                                   |
                                       | (192.168.101.2 /29)                               | (192.168.101.3 /29)
                                       |                                                   |
                                 [ Gi1/1/1 ]                                         [ Gi1/1/1 ]
                             [ Cisco 3650 core-sw01 ]====Inter-Core L3 (Gi1/1/2)====[ Cisco 3650 core-sw02 ]
                                 [ Port-Channel 1 ]                                  [ Port-Channel 1 ]
                                       ||                                                  ||
                                       || (LACP Trunk VLAN 10,20,30,40,99)                 ||
                                       ||                                                  ||
                                 [ Port-Channel 1 ]                                  [ Port-Channel 1 ]
                                 [ Cisco 2960X-1  ]==================================[ Cisco 2960X-2  ]
                                   [ Gi0/10 ]                                          [ Gi0/10 ]
                                       | (1G Management VLAN 99 Active/Backup)             |
                                       +-------------------+   +---------------------------+
                                                           |   |
                                                        [ eno3 | eno4 ] (1G Onboard)
                                                     [ Dell PowerEdge R630 ]
                                                        [ eno1 | eno2 ] (10G Onboard)
                                                           |   |
                                       +-------------------+   +---------------------------+
                                       | (10G Customer Trunk LACP)                         |
                                 [ Te1/0/1 ]                                         [ Te1/0/1 ]
                             [ Cisco 3650 core-sw01 ]                                [ Cisco 3650 core-sw02 ]
```

### Enhedernes Roller:
1.  **Cisco Catalyst 3650 (Core/Distribution):** Fungerer som inter-VLAN gateway (SVI). Switchene huser alle kunde-VRF'er samt management-VRF, og det er her, den interne Layer 3 adskillelse og route-leaking foregår.
2.  **Cisco Catalyst 2960X (Access):** Leverer fysisk tilslutning (access-porte) til klienter, testmaskiner og servere på de korrekte VLANs (VLAN 10, 20, 30, 40 og 99). WAN-trafikken (VLAN 200) er fjernet fra access-switchene, hvilket isolerer internet-trafikken fuldstændigt til kant-enhederne.
3.  **FortiGate 60F (Edge/Firewall):** Placeret som et redundant par i **Active/Passive HA cluster** (FGCP). De kører synkronisering (heartbeat) direkte mellem deres fysiske **FortiLink-porte `a` og `b`**.
4.  **Cisco ISR 4331 (WAN Router):** Forbundet direkte til WAN1-interfacerne på begge FortiGates. Den agerer din fysiske internet-forbindelse og simulerer din ISP.

---

## 2. Direkte WAN-kabling og Cisco BDI-bridging

At forbinde en enkelt routerport til to firewalls i en Active/Passive HA-konfiguration kræver normalt en ekstern switch for at skabe et fælles Layer 2 netværk, så firewalls'ne kan dele den eksterne HA IP (`192.168.200.1`).

For at fjerne behovet for eksterne switche på WAN-siden og kable routeren **direkte** til firewalls'ne, har vi implementeret en yderst professionel **Bridge Domain Interface (BDI)** løsning på Cisco 4331:

### BDI-løsningens opbygning:
*   Vi konfigurerer to af routerens fysiske porte, **`GigabitEthernet0/0/0`** og **`GigabitEthernet0/0/2`**, som Layer 2 bridged interfaces.
*   De to porte tildeles til **`bridge-domain 1`** via Service Instances i Cisco IOS-XE.
*   Vi opretter et virtuelt **Bridge Domain Interface (`BDI1`)**, som tildeles WAN-gateway IP'en `192.168.200.2/29`.
*   Dette omdanner routerens to porte til en indbygget Layer 2 switch. `Gi0/0/0` forbindes direkte til `fg-ha-01` (`wan1`), og `Gi0/0/2` forbindes direkte til `fg-ha-02` (`wan1`).
*   Når FortiGate-clusteret laver et failover og flytter den virtuelle eksterne MAC-adresse, fanges det øjeblikkeligt af Cisco-routerens integrerede bro-tabel, og trafikken flyttes automatisk uden tab af sessioner eller ping-forbindelse.

---

## 3. Statisk VRF Route Leaking Design

I denne version anvender vi **Statisk VRF Route Leaking** (VRF-Lite uden MP-BGP). Det er en ekstremt pålidelig og ressourcebesparende metode til at dele specifikke ruter mellem de isolerede VRF-routingtabeller og **Global Routing Table (GRT)**.

### Konceptet bag Statisk Leaking:
1.  **Vej ud af VRF (Kunde til Global/Firewall):**
    *   For at give kunderne adgang til internettet (som findes i Global Routing Table via transit-VLAN 101 og FortiGate), tilføjer vi en statisk default-route inde i kundens VRF.
    *   Denne rute peger på FortiGates transit-IP, men vi tilføjer nøgleordet `global`. Dette fortæller routeren, at den skal kigge i den globale routingtabel for at finde næste hop:
        *   `ip route vrf VRF_ALFA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global`
2.  **Vej ind (Returruter):**
    *   Returtrafikken lander i Global Routing Table på core-switchen. For at finde tilbage til kunden, tilføjes en statisk rute i Global Routing Table, der peger ind i kundens VRF-interface:
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
    *   **`eno1` (10G)** forbindes til `core-sw01` (Te1/0/1).
    *   **`eno2` (10G)** forbindes til `core-sw02` (Te1/0/1).
    *   Disse to 10G kobber-porte konfigureres i Proxmox som et **LACP (802.3ad) Bond** og opsættes som en **VLAN-Aware trunk** mod Core-switchene. Dette sikrer 20 Gbit/s aggregeret båndbredde samt komplet switch-redundans for alle kundernes VM'er (VLAN 10, 20, 30, 40).
2.  **Management / Vært Forbindelse (1 Gbit/s RJ45):**
    *   **`eno3` (1G)** forbindes til access-switchen `acc-sw01` (port `Gi0/10` - VLAN 99).
    *   **`eno4` (1G)** forbindes til access-switchen `acc-sw02` (port `Gi0/10` - VLAN 99).
    *   Disse to 1G-porte konfigureres som en **Active-Backup Bond** i Proxmox for at sikre redundant administrationsadgang til hypervisoren på **VLAN 99 (Management)**.
3.  **Out-of-Band (Dell iDRAC Enterprise):**
    *   Dell R630 har en **dedikeret fysisk iDRAC-port** placeret på bagsiden (markeret med en skruenøgle).
    *   Denne port forbindes direkte til `acc-sw01` (`Gi0/12` - VLAN 99).
    *   Dette giver dig fuld remote-konsol og hardware-overvågning (iDRAC GUI) uafhængigt af, om Proxmox kører eller ej.
