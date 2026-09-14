# CCNA Repetition - Opgave 1: Design og Opbygning af et Virksomhedsnetværk (Med OSPFv2)

Velkommen til det komplette projektportfolio for **Opgave 1 - Design og Opbygning af et Virksomhedsnetværk**. Dette projekt er udarbejdet som en del af Hovedforløb 5 (H5) for Datatekniker med speciale i Infrastruktur.

Dette portfolio er **fuldstændig tilpasset din opdaterede 9-enheders redundant cabled topologi** i Cisco Packet Tracer (`opgave-1.pkt`) og dækker alle opgavens krav til topkarakter, herunder **dynamisk OSPFv2 routing**, **redundant Split-Scope DHCP (80/20-reglen)**, **HSRP gateway redundans** og **L2 Port Security**.

---

## 📂 Mappestruktur og Indhold

Dokumentationen er opdelt i logiske moduler, som er nemme at navigere i og præsentere mundtligt til din eksamen:

1. **[IP-plan og VLSM-beregninger (`ip_plan_vlsm.md`)](./ip_plan_vlsm.md)**
   * Detaljeret gennemgang af adresseopdelingen af det tildelte `10.20.0.0/16` område ved brug af VLSM.
   * IP-tabeller for alle VLANs (Administration, Produktion, IT, Gæster, Management) inklusive gateways, subnetmasker, netværks- og broadcast-adresser.
   * Argumentation for valg af subnet-størrelser baseret på vækstprognoser.

2. **[Netværksdesign, Redundans og OSPF (`design_valg.md`)](./design_valg.md)**
   * Topologi-overvejelser i din nye 9-enheders 3-tier arkitektur (Core, Distribution, Access).
   * Spanning Tree Protocol (STP) design (Rapid PVST+ med aktiv load sharing).
   * Redundans, EtherChannel (LACP) og cross-links.
   * Layer 2 sikkerhed (Port Security, PortFast, BPDU Guard, isolering af ubrugte porte).
   * **OSPFv2 Routing Design:** Area 0, passive-interface default for optimal sikkerhed og dynamisk standardrute-injektion.
   * **DHCP Redundans Design:** Switch-integreret Split-Scope (80/20-reglen) parret med HSRP.
   * SVI-baseret adgangskontrol (ACLs) til adgangsbegrænsning (IT, Gæster, Management).

3. **[Cisco IOS Konfigurationsskabelon (`konfiguration_skabelon.md`)](./konfiguration_skabelon.md)**
   * Produktionsklare, fuldt kompatible Cisco IOS-konfigurationer til din **9-enheders topologi**:
     * **`rt01` (R1 / Router):** WAN/NAT, OSPFv2 Area 0, Default Route Distribution.
     * **`core-1` (Core Switch / L3):** SVI Gateways, HSRP Active, DHCP Primary (80%), EtherChannels, SVI ACLs, OSPFv2.
     * **`core-2` (Core Switch / L3):** SVI Gateways, HSRP Backup (VLAN 40 Active), DHCP Backup (20%), EtherChannels, SVI ACLs, OSPFv2.
     * **`ds-1` & `ds-2` (Distribution Switches / L2):** EtherChannel Bundles, trunking mod access og core.
     * **`as-1` til `as-5` (Access Switches / L2):** VLANs, Trunks, Access porte, Port Security, BPDU Guard, PortFast.
   * Alle kommandoer er grundigt kommenteret med de præcise enhedsnavne, så de nemt kan kopieres direkte ind i CLI.

4. **[Testplan og Verifikationsdokumentation (`test_dokumentation.md`)](./test_dokumentation.md)**
   * Komplet verifikationsmatrix for 15 testscenarier dækkende alle krav i opgaven (Del 9).
   * Specifikke tests for OSPF-naboskaber (`show ip ospf neighbor`), routingtabeller, HSRP/DHCP failover, L2 loop prevention (STP), Port Security og BPDU Guard.

---

## 🛠️ Overordnet Systemarkitektur

Netværket er designet ud fra en **hierarkisk Cisco 3-Tier Enterprise Model** tilpasset din opdaterede Packet Tracer topologi med fokus på høj tilgængelighed (HA), skalerbarhed og stærk sikkerhed.

* **Layer 3 Inter-VLAN Routing:** Placeret på de centrale Core/Distribution Switches (`core-1` & `core-2` / f.eks. Catalyst 3650) frem for Router-on-a-Stick. Dette sikrer line-rate routing (Gbps) for lokal netværkstrafik og minimerer belastningen på kant-routeren (`rt01`).
* **Sikker adskillelse:** Netværket opdeles i 5 funktionelle VLANs (VLAN 10, 20, 30, 40, 99).
* **Dynamisk Routing (OSPFv2):** Vi anvender OSPF Area 0 mellem `rt01`, `core-1` og `core-2`. `rt01` injicerer automatisk en default route (`0.0.0.0/0`) ned til Core-switchene, mens Core-switchene reklamerer de interne klient-VLANs op til routeren. For at sikre netværket er alle klientsubnets sat som `passive-interface`, så OSPF-pakker ikke kan opsnappes eller manipuleres af brugere.
* **Redundant DHCP-løsning:** DHCP kører direkte på vores L3 switches ved brug af en **Split-Scope (80/20-reglen)** arkitektur. `core-1` uddeler 80% af IP-adresserne, mens `core-2` har en backup-pool med de resterende 20%. Dette fjerner Single Point of Failure (SPOF) og overflødiggør eksterne DHCP-servere.
* **Redundans:** HSRP (Hot Standby Router Protocol), EtherChannel (LACP) og STP (Rapid PVST+) sikrer, at tab af en enkelt fysisk linje eller en hel Core Switch ikke afbryder driften.

---

## 🧑‍🏫 Mundtlig Præsentationsguide (Hurtigt overblik til eksamen)

Når du skal forklare dine valg mundtligt, kan du tage udgangspunkt i følgende røde tråde:
1. **Hvorfor VLSM?** "Vi startede med det største netværk (Gæster, 200 enheder) og arbejdede os nedad. Dette sparer over 98% af vores `/16`-adresseområde til fremtidig brug, hvilket gør designet ekstremt skalerbart."
2. **Hvorfor OSPF frem for statisk routing?** "In et redundant enterprise-netværk er statiske ruter for ufleksible. Med OSPF opbygger vores router og to Core-switche dynamiske naboskaber over transit-netværkene. Hvis den venstre Core Switch (`core-1`) dør, opdager OSPF dette med det samme, river naboskabet ned og omdirigerer lynhurtigt al trafik gennem `core-2`. Det sker fuldstændig automatisk."
3. **Hvorfor passive-interface default i OSPF?** "Det er en kritisk sikkerhedsforanstaltning. Som standard sender OSPF routing-opdateringer ud af alle interfaces. Ved at køre `passive-interface default` og kun slå det fra på de dedikerede transit-links mod routeren, forhindrer vi ondsindede brugere på gæste- eller medarbejdernetværket i at sende falske OSPF-opdateringer og overtage kontrollen med netværkets routingtabeller."
4. **Hvorfor Redundant Split-Scope DHCP på Core-switchene?** "Ved at køre DHCP direkte på vores L3 Core switches i en 80/20 split-konfiguration opnår vi fuld DHCP-redundans uden at skulle vedligeholde eksterne DHCP-servere. Hvis en switch dør, overtager den anden gateway-rollen via HSRP og begynder med det samme at svare på DHCP-forespørgsler fra sit eget uafhenderlige backup-område."
5. **Hvorfor Port Security med forskellige grænser?** "I administrationen tillader vi 2 MAC-adresser for at understøtte IP-telefoner med daisy-chained PC'er. I produktionen tillader vi kun 1 for maksimal sikkerhed. Gæste-WAP'er har Port Security helt slået fra, da de håndterer mange samtidige brugere."
