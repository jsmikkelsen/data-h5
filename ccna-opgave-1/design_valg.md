# Netværksdesign, Redundans og Sikkerhed (Designvalg)

Denne sektion dækker de strategiske og arkitektoniske designvalg for netværket, hvilket dækker **Del 1, 4, 6, 7 og 8** i opgavebeskrivelsen. 

Det fysiske og logiske design er fuldstændig synkroniseret med dit Packet Tracer-diagram (`opgave-1.pkt`) med i alt 9 netværksenheder.

---

## 🏛️ 1. Netværksarkitektur og Topologi (Del 1)

Vi har valgt et **klassisk Cisco 3-Tier Enterprise Design** (Core, Distribution og Access lag) tilpasset virksomhedens skalerbarhedsbehov. Dette sikrer fuld fysisk og logisk redundans overalt.

### Netværkskomponenter:
1. **Kant-router (`Router0` / R1):** Cisco ISR 4331. Håndterer ekstern routing (WAN), NAT/PAT og agerer sikkerhedsbarriere mod internettet. Den er **dual-homed** med uafhængige gigabit-links til begge Core-switche for fuld L3 redundans.
2. **Kerne-lag (`Multilayer Switch0` / core-01 & `Multilayer Switch1` / core-02):** To Cisco Catalyst 3650 (Layer 3 switches). Dette er netværkets "hjerne". Her udføres hardware-baseret Inter-VLAN routing (line-rate), default gateways (SVI) er placeret her, og det er her, HSRP, adgangsbegrænsninger (ACLs), OSPFv2 og de redundante DHCP Split-Scope pools konfigureres.
3. **Distributions-lag (`Multilayer Switch2` / ds-01 & `Multilayer Switch3` / ds-02):** To Cisco Catalyst 3650 switches konfigureret i Layer 2 tilstand. De fungerer som høj-densitets aggregations-switche, der samler de redundante links fra access-switchene og sender dem samlet (via EtherChannels) op til Core-laget.
4. **Access-lag (`Switch0` til `Switch4` / AS-01 til AS-05):** Fem Cisco Catalyst 2960 (Layer 2 switches). Her tilsluttes slutbrugere, produktionsudstyr, trådløse adgangspunkter (WAPs) og management interfaces. Hver switch er dedikeret til en logisk afdeling:
   * **`Switch0` (AS-01):** Administration (VLAN 10)
   * **`Switch1` (AS-02):** Produktion (VLAN 20)
   * **`Switch2` (AS-03):** IT (VLAN 30)
   * **`Switch3` (AS-04):** Gæster / WAPs (VLAN 40)
   * **`Switch4` (AS-05):** Dedicated Management / Isolated (VLAN 99)

```
                       +-------------------+
                       |    Internet       |
                       +---------+---------+
                                 |
                                 | R1 WAN Link (Gi0/0/2)
                       +---------+---------+
                       |  Edge Router R1   | (ISR 4331 NAT & WAN)
                       +----+-----------+--+
                           /             \
       Transit A (Gi0/0/0) /               \ Transit B (Gi0/0/1)
                          /                 \
                 +-------+---------+   +-----+-----------+
                 |     core-01     +---+     core-02     | (L3 Catalyst 3650s)
                 |  (DHCP Primary) |   |  (DHCP Backup)  | (HSRP, SVIs, ACLs)
                 +----+-------+----+   +----+-------+----+
                     /|       |             |       |\
        EtherChannel  |       \             /       |  EtherChannel
          (Port-Ch11) |        \           /        |    (Port-Ch12)
                     \|         \         /         |/
                 +----+----------+---+   +----------+----+
                 |      ds-01        |   |      ds-02        | (L2 Catalyst 3650s)
                 |    (Dist Left)    |   |    (Dist Right)   | (Aggregation Layer)
                 +--+-+--+-+--+-+--+-+   +-+-+--+-+--+-+--+-+
                    | |  | |  | |  | |     | |  | |  | |  | |
                    | |  | |  | |  +-------|-+  | |  | |  | |
                    | |  | |  +------------|----+ |  | |  | |
                    | |  +-----------------|------+ |  | |  | |
                    +----------------------|--------+ |  | |
                                           +----------+--+ |
                                                      +----+
    +------------+-------+-----------+------------+-------+
    |            |       |           |            |
+---+----+   +---+----+--+----+  +---+----+   +---+----+
| Switch0|   | Switch1|  Switch2|  | Switch3|   | Switch4| (L2 Catalyst 2960s)
+--------+   +--------+---------+  +--------+   +--------+
Admin (10)   Prod (20)  IT (30)    Guest (40)   Mgmt (99)
```

### VLAN Design:
Netværket opdeles i 5 funktionelle VLANs for at isolere broadcast-domæner og højne sikkerheden:
* **VLAN 10 (Administration):** Kontorarbejdspladser.
* **VLAN 20 (Produktion):** Kritiske maskiner og IoT-udstyr.
* **VLAN 30 (IT):** IT-medarbejdere, DNS, og lokale servere.
* **VLAN 40 (Gæster):** Trådløst og kablet gæstenetværk.
* **VLAN 99 (Management):** Krypteret admin-netværk til switches og router.
* **VLAN 999 (Blackhole):** Alle ubrugte porte placeres her i `shutdown` tilstand.

---

## 🔁 2. Redundans, STP og EtherChannel (Del 4)

Netværket er designet uden *Single Point of Failure*. Hvis et kabel klippes over, eller en switch dør, konvergerer netværket automatisk på under 2 sekunder.

### EtherChannel (LACP) Konfigurationer:
We anvender 802.3ad LACP EtherChannels på alle kritiske inter-switch forbindelser:
1. **Core-to-Core Trunk (Gi1/0/23):** Forbinder `core-01` (`Multilayer Switch0`) og `core-02` (`Multilayer Switch1`) for lynhurtig inter-core synkronisering, HSRP-kommunikation og OSPF dynamic update propagation.
2. **Core-to-Distribution Port-Channel 11:** Forbinder `core-01` (ports `Gi1/0/1-2`) og `ds-01` (ports `Gi1/0/21-22`).
3. **Core-to-Distribution Port-Channel 12:** Forbinder `core-02` (ports `Gi1/0/1-2`) og `ds-02` (ports `Gi1/0/21-22`).

### Full-Mesh Cross-Links (Trunks):
For at opnå fuldstændig mesh-redundans mellem Core- og Distributionslagene, har vi etableret cross-links (enkeltlinje-trunks):
* `core-01` port `Gi1/0/22` <---> `ds-02` port `Gi1/0/22`
* `core-02` port `Gi1/0/22` <---> `ds-01` port `Gi1/0/22`
* `core-01` port `Gi1/0/21` <---> `ds-02` port `Gi1/0/21` (eller tilsvarende mesh iflg. diagram)

### Spanning Tree Protocol (Rapid PVST+):
Rapid PVST+ (802.1w) sikrer, at uønskede loops blokeres, og at backup-veje aktiveres øjeblikkeligt ved link-nedbrud. Vi foretager **aktiv belastningsfordeling (STP Load Sharing)**:
* **`core-01` konfigureres som STP Root Primary** for VLANs **10, 20, 30 og 99** (og Root Secondary for VLAN 40).
* **`core-02` konfigureres som STP Root Primary** for **VLAN 40** (og Root Secondary for VLAN 10, 20, 30, 99).

---

## 🔒 3. Port Security og Access-Port Sikkerhed (Del 6)

Vi anvender en differentieret sikkerhedspolitik på alle bruger-porte i access-laget for at forhindre uautoriseret adgang:

| VLAN / Switch | Max MACs | MAC Metode | Violation Mode | Begrundelse |
| :--- | :---: | :---: | :---: | :--- |
| **Admin (Switch0 / VLAN 10)** | **2** | `sticky` | `shutdown` | Understøtter IP-telefoner med daisy-chained PC (computeren er tilsluttet gennem telefonen). |
| **Produktion (Switch1 / VLAN 20)** | **1** | `sticky` | `shutdown` | Kritiske maskiner. Kun 1 godkendt MAC. Lukker porten med det samme ved overtrædelse. |
| **IT (Switch2 / VLAN 30)** | **5** | Dynamic | `restrict` | IT-medarbejdere skal kunne teste forskelligt udstyr. Porten blokeres for uautoriserede, men lukker ikke helt. |
| **Gæster (Switch3 / VLAN 40)** | **Ingen** | N/A | Ingen Port Sec | **Deaktiveret på WAP-porte!** Da trådløse adgangspunkter videresender mange hundrede gæste-MACs over samme port. |

---

## 🛡️ 4. Layer 2 Beskyttelse (Del 7)

For at beskytte Spanning Tree topologien mod manipulation anvender vi:
* **PortFast:** Aktiveres på alle bruger-porte på `Switch0` til `Switch4`. Det sikrer, at pc'er går direkte i forwarding state og modtager DHCP med det samme uden timeout.
* **BPDU Guard:** Aktiveres på alle bruger-porte. Hvis en medarbejder tilslutter en switch til et vægstik, vil BPDU Guard opdage det og straks lukke porten (`err-disable`) for at beskytte netværket mod loops.
* **Sikring af ubrugte porte:** Alle ubrugte porte på samtlige 9 switche er deaktiveret med `shutdown` og lagt i **VLAN 999 (Blackhole)**.

---

## 🚦 5. Adgangskontrol via ACLs (Del 8)

Da vi har Inter-VLAN routing på de to L3 Core-switche, placerer vi **Extended ACLs** direkte på Core-switchenes **SVIs (Switch Virtual Interfaces)**. Dette sikrer hardware-baseret filtrering ved gatewayen.

### Sikkerhedskrav:
1. **IT (VLAN 30)** har fuld adgang til **Management (VLAN 99)** (SSH/HTTPS) for administration.
2. **Interne klienter (VLAN 10, 20)** må overhovedet ikke kunne tilgå Management (VLAN 99).
3. **Gæster (VLAN 40)** tillades udelukkende DHCP (UDP 67/68) og DNS (UDP 53) til Core-switchene (`10.20.1.195` og `10.20.1.196`) for internet-navneopløsning. Alt andet trafik til virksomhedens private netværk (RFC 1918) blokeres fuldstændigt.

---

## ⚡ 6. Redundant DHCP Design: Split-Scope (80/20 Reglen) (Del 5)

DHCP-tjenesten er integreret direkte i hardwaren på dine to L3 Core switches (`Multilayer Switch0` og `Multilayer Switch1`) for maksimal oppetid.

* **`Multilayer Switch0` (HSRP Active)** uddeler **80%** af IP-adresserne i hvert subnet.
* **`Multilayer Switch1` (HSRP Standby / VLAN 40 Active)** uddeler de resterende **20%** som backup.
* **HSRP Integration:** DHCP-pools på begge switche peger altid på den **virtuelle HSRP Gateway IP** (f.eks. `10.20.1.129` for VLAN 10). Dette gør failover fuldstændig transparent for brugerne.

---

## 🚦 7. Dynamisk Routing med OSPFv2 (Area 0) (Del 1, 4)

Statiske ruter er ufleksible og upålidelige i redundante netværk. Vi har derfor implementeret **OSPFv2 (Open Shortest Path First)** i en enkelt, højtydende **Area 0 (Backbone)** konfiguration mellem vores Edge Router (`Router0`) og de to Core Layer 3 switches.

### Konfigurationsegenskaber:
1. **OSPF Process-ID:** `1` kører på alle deltagende enheder.
2. **Entydige Router-ID'er (RID):**
   * **`Router0`:** `1.1.1.1`
   * **`Multilayer Switch0` (core-01):** `2.2.2.1`
   * **`Multilayer Switch1` (core-02):** `2.2.2.2`
3. **OSPF Transit Netværk:**
   * Transit Link A (R1 Gi0/0/0 <---> `core-01` Gi1/0/24): `10.20.254.0/30`
   * Transit Link B (R1 Gi0/0/1 <---> `core-02` Gi1/0/24): `10.20.254.4/30`
   * Disse transit-links deltager i OSPF Area 0, hvilket lader routeren og begge switche etablere OSPF naboskaber (**Adjacency**) dynamisk.

### Enterprise Sikkerhed: Passive Interfaces
Som standard sender OSPF multicast-pakker ud af alle interfaces (inklusive alle medarbejder- og gæstenetværk). Dette udgør en enorm sikkerhedsrisiko, da en hacker på gæstenetværket kunne lytte på opdateringer eller sende falske ruter (route poisoning).
* **Vores Løsning:** Vi konfigurerer `passive-interface default` på både `Multilayer Switch0` og `Multilayer Switch1`. Herefter aktiverer vi eksplicit kun OSPF på de faktiske transit-porte mod routeren via `no passive-interface`. Klienter modtager ingen OSPF-opdateringer, men deres netværk annonceres stadig fuldt ud til routeren.

### Dynamisk Default Route Injektion (Dynamic Route Propagation):
Kant-routeren `Router0` har en statisk standardrute, der peger mod internettet (ISP). I stedet for manuelt at konfigurere standardruter på Core-switchene, benytter vi kommandoen:
```ios
R1(config-router)# default-information originate
```
Dette instruerer `Router0` i at udsende en dynamisk standardrute (`0.0.0.0/0`) via OSPF til Core-switchene. 
* **Høj Tilgængelighed (HA):** Hvis `Multilayer Switch0` mister strømmen, vil `Router0` og `Multilayer Switch1` lynhurtigt opdage, at naboskabet til `Multilayer Switch0` er dødt. OSPF omdirigerer automatisk al trafik til de interne VLANs igennem `Multilayer Switch1` (`10.20.254.6`) på under 3-5 sekunder. Failover sker helt uden menneskelig indgriben!
