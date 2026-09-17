# Infrastrukturprojekt – Del 1: Fælles Netværksplatform v2 (192.168.x.x Design med VRF & Firewalls)

Velkommen til projektportfoliet for **Infrastrukturprojekt – Del 1: Netværksplatform v2**. Denne version af platformen er opbygget med en ny IP-plan baseret på `192.168.x.x` netværksadresser og navngivet efter de nye kundebetegnelser (**Alfa**, **Bravo**, **Charlie** og **Delta**).

Dette portfolio dækker det komplette design, IP-planlægning, konfigurationer og testscenarier for det udleverede hardware-udstyr:
*   **2 x FortiGate 60F** (Edge Firewalls i High Availability)
*   **1 x Cisco ISR 4331** (WAN/ISP Router)
*   **2 x Cisco Catalyst 3650** (Layer 3 switches, der kører VRF-Lite og HSRP)
*   **2 x Cisco Catalyst 2960X** (Layer 2 access-switche)

---

## 📂 Mappestruktur og Indhold

Dokumentationen er opdelt i præcise, faglige moduler, der følger standarderne for H5-niveau:

1. **[Netværksdesign og Redundans (`design_valg.md`)](./design_valg.md)**
   * Overvejelser bag valg af **Collapsed Core** topologi ved brug af Cisco 3650.
   * Redundans på Layer 2 (MSTP/Rapid-PVST+ og EtherChannel/LACP) mod access-laget.
   * Redundans på Layer 3 (HSRP på SVI-niveau).
   * Edge-sikkerhed og redundans via **FortiGate HA Clustering (FGCP Active/Passive)**.
   * **VRF-Lite & Route Leaking Design:** Detaljeret arkitektur for logisk adskillelse af Kunde Alfa, Bravo, Charlie, Delta og Management samt kontrolleret route-leaking til Global Routing Table (GRT).

2. **[IP- og VLAN-Plan (`ip_plan.md`)](./ip_plan.md)**
   * Struktureret IP-adresseplan med brug af private `192.168.x.x` IPv4-adresser.
   * VLAN-allokeringer, herunder dedikerede kundenetværk, management-netværk samt interne transit- og WAN-netværk.
   * Gateway, HSRP Virtual IP (VIP), og individuelle fysiske IP-adresser for Core-switchene.

3. **[Konfigurationsskabeloner (`konfiguration_skabelon.md`)](./konfiguration_skabelon.md)**
   * Produktionsklare, testede og kommenterede konfigurationer til alle infrastrukturelementer:
     * **`core-sw01` (Cisco 3650):** Primær gateway, VRF-definitioner, HSRP Active, Static/iBGP route-leaking.
     * **`core-sw02` (Cisco 3650):** Sekundær gateway, VRF-definitioner, HSRP Standby (Active for udvalgte VLANs til load-sharing).
     * **`acc-sw01` & `acc-sw02` (Cisco 2960X):** LACP EtherChannels, VLAN trunks og access-porte.
     * **`fg-ha` (FortiGate 60F HA Cluster):** VDOM/Interface opsætning, HA configuration, og sikkerhedspolitikker.
     * **`wan-rt01` (Cisco 4331):** Simulering af ydre WAN-forbindelse.

4. **[Testplan og Verifikationsdokumentation (`test_dokumentation.md`)](./test_dokumentation.md)**
   * Komplet verifikationsmatrix til systematisk test af platformen.
   * Specifikke tests for L2 STP, HSRP gateway failover, VRF-isolering, route-leaking funktionalitet, firewall-politikker og administrationsovervågning.

5. **[Fysisk Kablingsplan (`kablings_plan.md`)](./kablings_plan.md)**
   * Komplet kablingsplan dækkende alle forbindelser mellem Dell R630, FortiGates, L3/L2 switche og WAN-routeren.
   * Fysisk tjekliste og farvekodningsguide til rackopsætning i labbet.

---

## 🛠️ Overordnet Systemarkitektur

Netværket er designet med et ufravigeligt krav om **ingen single-points-of-failure (SPOF)**, komplet fysisk redundans, samt streng logisk segmentering.

```
                            [ Skole/Hjemme-LAN (Internet) ]
                                          |
                                          | (DHCP / NAT Outside)
                                  [ Gi0/0/1 ]
                             [ Cisco 4331 wan-rt01 ]
                                  [ Gi0/0/0 ]
                                      |
                                      | (192.168.200.2 /29)
                                      |
                         +------------+ (VLAN 200 WAN Transit)
                         |
                 [ Cisco 2960X-1 ]========Trunk (VLAN 200 & 99)========[ Cisco 2960X-2 ]
                 [   Gi0/24      ]                                     [   Gi0/24      ]
                       |                                                   |
                   [ wan1 ]                                            [ wan1 ]
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

### Hovedprincipper i Arkitekturen:
* **Logisk Adskillelse (VRF-Lite):** Hver kunde placeres i sin egen VRF (Virtual Routing and Forwarding) kontekst på Core-switchene (`VRF_ALFA`, `VRF_BRAVO`, `VRF_CHARLIE`, `VRF_DELTA`). En kunde kan under ingen omstændigheder se eller kommunikere med andre kunders routingtabeller, medmindre der specifikt opsættes route-leaking.
* **Kontrolleret Route Leaking (Statisk VRF Leaking):** For at muliggøre kontrolleret internetadgang (via Global Routing Table mod FortiGate), anvendes Cisco's indbyggede statiske VRF leaking. Hver kunde-VRF har en statisk default route, der peger på FortiGates ydre IP i den globale routingtabel (`global`), mens Global Routing Table har præcise returruter, der peger direkte ind i kundenetværkenes VRF-interfaces. Alt andet forbliver isoleret.
* **Redundans på alle lag:**
  * **Gateway Redundans:** Leveres med **HSRP (Hot Standby Router Protocol)** på Cisco 3650 switches. Hver kunde har en fælles HSRP Virtual IP (VIP), som automatisk flytter mellem switche ved nedbrud.
  * **Sikkerhed og Edge:** FortiGate 60F kører i **FGCP Active/Passive Clustering**. Hvis den primære firewall fejler, overtager den sekundære umiddelbart IP- og MAC-adresser uden tab af sessioner.
  * **Layer 2 Redundans:** LACP EtherChannels forhindrer links-fejl, og Rapid-PVST+ eller MSTP sikrer lynhurtig loop-prevention.
