# Netværksdesign, Redundans og Statisk VRF Leaking (v2 - Custom Mesh Design)

Dette dokument beskriver de arkitektoniske valg, overvejelser og tekniske designprincipper bag opbygningen af den fælles netværksplatform for **Infrastrukturprojekt – Del 1 (v2)**, med særligt fokus på dit **Custom Cross-Mesh LAN-kablingsdesign**, **Statisk VRF Route Leaking** samt integration og administration af **Proxmox VE** på en **Dell PowerEdge R630**.

---

## 1. Topologi- og Arkitekturvalg

Netværksarkitekturen bygger på dit avancerede, fuldt redundante **Custom Cross-Mesh LAN-kablingsdesign**, som giver maksimal oppetid og eliminerer ethvert single point of failure (SPOF) på tværs af switche og firewalls:

```
                            [ Skole/Hjemme-LAN (Internet) ]
                                          |
                                          | (DHCP / NAT Outside)
                                  [ Gi0/0/2 ]
                             [ Cisco 4331 wan-rt01 ]
                                  [ Gi0/0/0 ]       [ Gi0/0/1 ]  (L2 Bridged via BDI1)
                                       |                 |
                                       | (192.168.200.2) |
                                       |                 |
                                    [ wan1 ]          [ wan1 ]
                             [ FortiGate fg-01 ]============HA (Port a & b)============[ FortiGate fg-02 ]
                             [ port1/2 ]   [ port3/4 ]                           [ port3/4 ]   [ port1/2 ]
                                 |             \                                     /             |
                                 |  (Gul)       \ (Rød)                       (Gul) /       (Rød)  |
                                 |               \                                 /               |
                            [ Gi1/0/24-23 ] [ Gi1/0/22-21 ]                   [ Gi1/0/22-21 ] [ Gi1/0/24-23 ]
                            [  Cisco 3650 ds-01   ]========ISL LACP (Gi1/0/20-19)========[  Cisco 3650 ds-02   ]
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
                             [  Cisco 3650 ds-01  ]                                  [  Cisco 3650 ds-02  ]
```

### Enhedernes Roller:
1.  **Cisco Catalyst 3650 (`ds-01` & `ds-02`):** De to Layer 3 distribution switches fungerer som netværkets centrale Collapsed Core. De huser alle gateways (SVI), HSRP og VRF'er og foretager inter-switch LACP EtherChannel-routing på `Gi1/0/19` og `Gi1/0/20`.
2.  **Cisco Catalyst 2960X (Access):** Leverer fysiske access-porte til klienter og management på VLAN 10, 20, 30, 40 og 99. De forbindes redundant til begge L3 switches med LACP trunks.
3.  **FortiGate 60F (`fg-01` & `fg-02`):** Trækker direkte parvise HA-heartbeat links på FortiLink-portene **`a`** og **`b`**. De kables redundant og mønstret direkte til begge L3 switches.
4.  **Cisco ISR 4331 (`wan-rt01`):** Internet/ISP gateway kablet direkte til firewalls vha. BDI software-bridging på port `Gi0/0/0` og `Gi0/0/1`, samt NAT på `Gi0/0/2`.

---

## 2. Direkte WAN-kabling og Cisco BDI-bridging

At forbinde en enkelt routerport til to firewalls i en Active/Passive HA-konfiguration kræver normalt en ekstern switch for at skabe et fælles Layer 2 netværk, så firewalls'ne kan dele den eksterne HA IP (`192.168.200.1`).

For at fjerne behovet for eksterne switche på WAN-siden og kable routeren **direkte** til firewalls'ne, har vi implementeret en yderst professionel **Bridge Domain Interface (BDI)** løsning på Cisco 4331:

### BDI-løsningens opbygning:
*   Vi konfigurerer de to hosliggende og fysisk grupperede porte, **`GigabitEthernet0/0/0`** og **`GigabitEthernet0/0/1`**, som Layer 2 bridged interfaces.
*   De to porte tildeles til **`bridge-domain 1`** via Service Instances i Cisco IOS-XE.
*   Vi opretter et virtuelt **Bridge Domain Interface (`BDI1`)**, som tildeles WAN-gateway IP'en `192.168.200.2/29`.
*   Dette omdanner routerens to porte til en indbygget Layer 2 switch. `Gi0/0/0` forbindes direkte til `fg-01` (`wan1`), og `Gi0/0/1` forbindes direkte til `fg-02` (`wan1`).
*   Den fysiske internetforbindelse (skolens/labbets netværk) routes ud af den selvstændige port **`GigabitEthernet0/0/2`** (NAT Outside via DHCP).
*   Når FortiGate-clusteret laver et failover og flytter den virtuelle eksterne MAC-adresse, fanges det øjeblikkeligt af Cisco-routerens integrerede bro-tabel, og trafikken flyttes automatisk uden tab af sessioner eller ping-forbindelse.

---

## 3. FortiGate Redundant Interface LAN Design

I dit avancerede kablingsdesign er hver firewall cross-connected direkte til begge distribution switches:
*   `fg-01` `port1` & `port2` ➔ `ds-01`
*   `fg-01` `port3` & `port4` ➔ `ds-02`
*   `fg-02` `port1` & `port2` ➔ `ds-02`
*   `fg-02` `port3` & `port4` ➔ `ds-01`

Siden `ds-01` og `ds-02` ikke kører stacking (hvilket ville tillade én tværgående LACP EtherChannel på tværs af kasserne), ville almindelig paralleltilkobling skabe gigantiske Layer 3 IP-konflikter og routing-løkker. 

Dette løses ekstremt elegant ved at oprette et **Redundant Interface** i FortiOS (f.eks. kaldet `internal-transit`):
1.  Vi samler de fire fysiske LAN-porte (`port1`, `port2`, `port3`, `port4`) under dette ene virtuelle interface.
2.  Et **Redundant Interface** i FortiOS fungerer i en stærk **Active-Backup** tilstand på MAC/port-niveau. Det betyder, at firewallen kun tillader aktiv trafik på ét/to af linkene ad gangen (f.eks. `port1` & `port2` mod `ds-01`), mens de resterende links (`port3` & `port4` mod `ds-02`) holdes i en varm standby-tilstand.
3.  Hvis kablet til `ds-01` trækkes ud, eller hvis `ds-01` slukkes, detekterer firewallen link-fejlen og aktiverer øjeblikkeligt sine standby-porte mod `ds-02`. Trafikken genoptages øjeblikkeligt helt uden afbrydelse.

---

## 4. Statisk VRF Route Leaking Design

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

## 5. Dell PowerEdge R630 & Proxmox VE Design

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
    *   **`eno1` (10G)** forbindes til `ds-01` (port `Te1/0/1`).
    *   **`eno2` (10G)** forbindes til `ds-02` (port `Te1/0/1`).
    *   Disse to 10G kobber-porte konfigureres i Proxmox som et **LACP (802.3ad) Bond** og opsættes som en **VLAN-Aware trunk** mod Core-switchene. Dette sikrer 20 Gbit/s aggregeret båndbredde samt komplet switch-redundans for alle kundernes VM'er (VLAN 10, 20, 30, 40).
2.  **Management / Vært Forbindelse (1 Gbit/s RJ45):**
    *   **`eno3` (1G)** forbindes til access-switchen `acc-sw01` (port `Gi0/10` - VLAN 99).
    *   **`eno4` (1G)** forbindes til access-switchen `acc-sw02` (port `Gi0/10` - VLAN 99).
    *   Disse to 1G-porte konfigureres som en **Active-Backup Bond** i Proxmox for at sikre redundant administrationsadgang til hypervisoren på **VLAN 99 (Management)**.
3.  **Out-of-Band (Dell iDRAC Enterprise):**
    *   Dell R630 har en **dedikeret fysisk iDRAC-port** placeret på bagsiden (markeret med en skruenøgle).
    *   Denne port forbindes direkte til `acc-sw01` (`Gi0/12` - VLAN 99).
    *   Dette giver dig fuld remote-konsol og hardware-overvågning (iDRAC GUI) uafhængigt af, om Proxmox kører eller ej.
