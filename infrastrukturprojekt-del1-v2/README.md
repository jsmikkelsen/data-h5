# Infrastrukturprojekt – Del 1: Fælles Netværksplatform v2 (192.168.x.x Design med Direkte WAN & VRF)

Velkommen til projektportfoliet for **Infrastrukturprojekt – Del 1: Netværksplatform v2**. Denne version af platformen er opbygget med en ny IP-plan baseret på `192.168.x.x` netværksadresser og navngivet efter de nye kundebetegnelser (**Alfa**, **Bravo**, **Charlie** og **Delta**). 

Designet bygger på dit avancerede, fuldt redundante **Custom Cross-Mesh LAN-kablingsdesign**, hvor dine to firewalls (**`fg-01`** og **`fg-02`**) er cross-connected direkte til begge dine Layer 3 switches (**`ds-01`** og **`ds-02`**). Cisco 4331 routeren (**`wan-rt01`**) leverer direkte WAN-opkobling til begge firewalls vha. Layer 2 software-bridging (**BDI**).

Dette portfolio dækker det komplette design, IP-planlægning, konfigurationer og testscenarier for det udleverede hardware-udstyr:
*   **2 x FortiGate 60F** (Edge Firewalls i High Availability)
*   **1 x Cisco ISR 4331** (WAN/ISP Router med BDI software bridging)
*   **2 x Cisco Catalyst 3650** (Layer 3 switches, der kører VRF-Lite og HSRP)
*   **2 x Cisco Catalyst 2960X** (Layer 2 access-switche)

---

## 📂 Mappestruktur og Indhold

Dokumentationen er opdelt i præcise, faglige moduler, der følger standarderne for H5-niveau:

1. **[Netværksdesign og Redundans (`design_valg.md`)](./design_valg.md)**
   * Overvejelser bag valg af **Collapsed Core** topologi ved brug af Cisco 3650.
   * Redundans på Layer 2 (MSTP/Rapid-PVST+ og EtherChannel/LACP) mod access-laget.
   * Redundans på Layer 3 (HSRP på SVI-niveau).
   * Edge-sikkerhed og redundans via **FortiGate HA Clustering (FGCP Active/Passive)** med direkte WAN-kabling og cross-mesh LAN-forbindelser.
   * **VRF-Lite & Route Leaking Design:** Detaljeret arkitektur for logisk adskillelse af Kunde Alfa, Bravo, Charlie, Delta og Management samt kontrolleret statisk route-leaking til Global Routing Table (GRT).

2. **[IP- og VLAN-Plan (`ip_plan.md`)](./ip_plan.md)**
   * Struktureret IP-adresseplan med brug af private `192.168.x.x` IPv4-adresser.
   * VLAN-allokeringer, herunder dedikerede kundenetværk, management-netværk samt interne transit- og WAN-netværk.
   * Gateway, HSRP Virtual IP (VIP), og individuelle fysiske IP-adresser for Core-switchene.

3. **[Konfigurationsskabeloner (`konfiguration_skabelon.md`)](./konfiguration_skabelon.md)**
   * Produktionsklare, udeladelsesfrie og kommenterede konfigurationer til alle enheder:
     * **`ds-01` & `ds-02` (Cisco 3650):** Gateways, VRF'er, HSRP, statisk leaking og inter-switch LACP EtherChannel.
     * **`acc-sw01` (Cisco 2960X):** LACP EtherChannels, VLAN trunks og access-porte.
     * **`fg-01` & `fg-02` (FortiGate 60F HA Cluster):** HA sync på FortiLink-porte `a` & `b` samt redundant LAN mesh-konfiguration.
     * **`wan-rt01` (Cisco 4331):** BDI-bridging og fuld NAT-opsætning mod rigtigt internet på `Gi0/0/2`.
     * **Proxmox VE på Dell R630:** Redundant `/etc/network/interfaces` netværksfil.

4. **[Testplan og Verifikationsdokumentation (`test_dokumentation.md`)](./test_dokumentation.md)**
   * Komplet verifikationsmatrix til systematisk test af platformen.
   * Specifikke tests for L2 STP, HSRP gateway failover, VRF-isolering, route-leaking, firewall-politikker, administrationssikkerhed og HA failover.

5. **[Fysisk Kablingsplan (`kablings_plan.md`)](./kablings_plan.md)**
   * Komplet kablingsplan dækkende alle direkte og cross-mesh forbindelser mellem Dell R630, FortiGates, L3/L2 switche og WAN-routeren.
   * Fysisk tjekliste og farvekodningsguide til rackopsætning i labbet.

---

## 🛠️ Overordnet Systemarkitektur

Netværket er designet med et ufravigeligt krav om **ingen single-points-of-failure (SPOF)**, komplet fysisk redundans på alle niveauer, samt streng logisk segmentering.

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

### Hovedprincipper i Arkitekturen:
* **Direkte WAN-forbindelse:** Cisco 4331 WAN-routeren er kablet direkte til WAN1-porten på begge FortiGates. For at lade Active/Passive HA-clusteret dele den samme eksterne IP (`192.168.200.1`), kører Cisco-routeren en lokal Layer 2 Bridge Domain Interface (`BDI1`) mellem de to hosliggende porte **`Gi0/0/0`** og **`Gi0/0/1`**, som giver dem en fælles L2-kontekst. Den fysiske internetforbindelse routes ud af **`Gi0/0/2`** (NAT Outside).
* **Fuld Redundant Cross-Mesh LAN:** For at eliminere single points of failure er hver FortiGate kablet direkte til begge Layer 3 switches. For at forhindre Layer 3 loops samler FortiGate alle fire interfaces i et enkelt logisk **Redundant Interface** (`internal-transit`). Det betyder, at kun de aktive interfaces på den aktive firewall bærer trafikken, mens de øvrige porte blokeres, hvilket sikrer fuldautomatisk og lynhurtigt failover.
* **Logisk Adskillelse (VRF-Lite):** Hver kunde placeres i sin egen VRF (Virtual Routing and Forwarding) kontekst på Core-switchene (`VRF_ALFA`, `VRF_BRAVO`, `VRF_CHARLIE`, `VRF_DELTA`). En kunde kan under ingen omstændigheder se eller kommunikere med andre kunders routingtabeller, medmindre der specifikt opsættes route-leaking.
* **Kontrolleret Route Leaking (Statisk VRF Leaking):** For at muliggøre kontrolleret internetadgang (via Global Routing Table mod FortiGate), anvendes Cisco's indbyggede statiske VRF leaking. Hver kunde-VRF har en statisk default route, der peger på FortiGates ydre IP i den globale routingtabel (`global`), mens Global Routing Table har præcise returruter, der peger direkte ind i kundenetværkenes VRF-interfaces. Alt andet forbliver isoleret.
* **Redundans på alle lag:**
  * **Gateway Redundans:** Leveres med **HSRP (Hot Standby Router Protocol)** på Cisco 3650 switches. Hver kunde har en fælles HSRP Virtual IP (VIP), som automatisk flytter mellem switche ved nedbrud.
  * **Sikkerhed og Edge:** FortiGate 60F kører i **FGCP Active/Passive Clustering**. Hvis den primære firewall fg-01 fejler, overtager den sekundære fg-02 umiddelbart IP- og MAC-adresser uden tab af sessioner.
  * **Layer 2 Redundans:** LACP EtherChannels forhindrer links-fejl, og Rapid-PVST+ eller MSTP sikrer lynhurtig loop-prevention.
