# Løsningsguide: Dag 2 – Fra konfiguration til packet flow
## Troubleshooting og Repetitionsopgaven fra Helvede (GNS3 vIOS-L3 udgave)

Denne løsningsguide er udarbejdet til Hovedforløb 5 (H5) Datatekniker med speciale i Infrastruktur. Den dækker alle teoretiske og praktiske aspekter af laboratorieøvelsen beskrevet i præsentationen `Tshoot - Routering Basics.pptx`, tilpasset til **GNS3** med Cisco vIOS-L3 (`vios-adventerprisek9-m.spa.159-3.m6.qcow2`) med 2-tier interfaces (`gi0/0` til `gi0/3`).

---

## Indholdsfortegnelse
1. [Overordnet Netværksdesign & IP-plan (VLSM)](#1-overordnet-netværksdesign--ip-plan-vlsm)
2. [Cisco IOS Konfigurationsskabeloner (Del 1 & 2)](#2-cisco-ios-konfigurationsskabeloner-del-1--2)
3. [Del 1: Hvad ved routerne allerede?](#3-del-1-hvad-ved-routerne-allerede)
4. [Del 2 & 3: Vejen frem og tilbage (Statiske ruter)](#4-del-2--3-vejen-frem-og-tilbage-statiske-ruter)
5. [Teoretisk dybdedyk: RIB vs. FIB](#5-teoretisk-dybdedyk-rib-vs-fib)
6. [Route Selection: Longest Prefix Match (LPM) vs. Administrative Distance (AD)](#6-route-selection-longest-prefix-match-lpm-vs-administrative-distance-ad)
7. [OSPF, Floating Static Routes og Redundans](#7-ospf-floating-static-routes-og-redundans)
8. [Recursive Lookup, ARP og Layer 2 Videresendelse](#8-recursive-lookup-arp-og-layer-2-videresendelse)
9. [Source-IP, Extended Ping og ECMP](#9-source-ip-extended-ping-og-ecmp)

---

## 1. Overordnet Netværksdesign & IP-plan (VLSM)

Vi har valgt IP-området **`10.50.0.0/16`** som fundament. Planen understøtter både den lineære topologi (Del 1-3) og den udvidede, redundante topologi (Del 4 og frem).

### IP-Adresseringstabel og GNS3 Interface Mapping

| Segment / Link | Netværksadresse | Subnetmaske | R1 Port | R2 Port | R3 Port | R4 Port | Klient IP / Gateway |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **LAN-A** (PC-A) | `10.50.10.0/24` | `255.255.255.0` | `gi0/0` | - | - | - | PC-A: `10.50.10.10` / GW: `10.50.10.1` |
| **LAN-C** (PC-C) | `10.50.30.0/24` | `255.255.255.0` | - | - | `gi0/0` | - | PC-C: `10.50.30.10` / GW: `10.50.30.1` |
| **LAN-D** (PC-D) | `10.50.40.0/24` | `255.255.255.0` | - | - | - | `gi0/0` | PC-D: `10.50.40.10` / GW: `10.50.40.1` |
| **Link R1-R2** | `10.50.12.0/30` | `255.255.255.252`| `gi0/1` | `gi0/0` | - | - | Transit / Point-to-Point |
| **Link R2-R3** | `10.50.23.0/30` | `255.255.255.252`| - | `gi0/1` | `gi0/1` | - | Transit / Point-to-Point |
| **Link R3-R4** | `10.50.34.0/30` | `255.255.255.252`| - | - | `gi0/2` | `gi0/1` | Transit / Point-to-Point |
| **Link R1-R3** *(Backup)*| `10.50.13.0/30` | `255.255.255.252`| `gi0/2` | - | `gi0/3` | - | Redundant Link |
| **Link R2-R4** *(Backup)*| `10.50.24.0/30` | `255.255.255.252`| - | `gi0/2` | - | `gi0/2` | Redundant Link |

---

## 2. Cisco IOS Konfigurationsskabeloner (Del 1 & 2)

Herunder er basisskabeloner til de fire vIOS routere i GNS3 med forkortede port-navne (`gi0/0` osv.), lige til at copy-paste ind i din Putty/SecureCRT terminal.

### R1 (Router 1)
```ios
enable
configure terminal
hostname R1
!
interface gi0/0
 ip address 10.50.10.1 255.255.255.0
 no shutdown
 description LAN-A
!
interface gi0/1
 ip address 10.50.12.1 255.255.255.252
 no shutdown
 description Link-to-R2
!
interface gi0/2
 ip address 10.50.13.1 255.255.255.252
 shutdown
 description Redundant-Link-to-R3
!
end
write memory
```

### R2 (Router 2)
```ios
enable
configure terminal
hostname R2
!
interface gi0/0
 ip address 10.50.12.2 255.255.255.252
 no shutdown
 description Link-to-R1
!
interface gi0/1
 ip address 10.50.23.1 255.255.255.252
 no shutdown
 description Link-to-R3
!
interface gi0/2
 ip address 10.50.24.1 255.255.255.252
 shutdown
 description Redundant-Link-to-R4
!
end
write memory
```

### R3 (Router 3)
```ios
enable
configure terminal
hostname R3
!
interface gi0/0
 ip address 10.50.30.1 255.255.255.0
 no shutdown
 description LAN-C
!
interface gi0/1
 ip address 10.50.23.2 255.255.255.252
 no shutdown
 description Link-to-R2
!
interface gi0/2
 ip address 10.50.34.1 255.255.255.252
 no shutdown
 description Link-to-R4
!
interface gi0/3
 ip address 10.50.13.2 255.255.255.252
 shutdown
 description Redundant-Link-to-R1
!
end
write memory
```

### R4 (Router 4)
```ios
enable
configure terminal
hostname R4
!
interface gi0/0
 ip address 10.50.40.1 255.255.255.0
 no shutdown
 description LAN-D
!
interface gi0/1
 ip address 10.50.34.2 255.255.255.252
 no shutdown
 description Link-to-R3
!
interface gi0/2
 ip address 10.50.24.2 255.255.255.252
 shutdown
 description Redundant-Link-to-R2
!
end
write memory
```

---

## 3. Del 1: Hvad ved routerne allerede?

Når alle ovenstående interfaces er konfigureret og oppe (`up/up`), men inden der laves statiske ruter eller dynamisk routing:

### Besvarelse af spørgsmål
*   **Hvilke ruter findes allerede?**
    *   Kun de direkte forbundne netværk (**Connected**, markeret med `C`) og de specifikke host-ruter for routerens egne IP-adresser på interfaces (**Local**, markeret med `L` med en `/32` maske).
*   **Hvor kommer de fra?**
    *   De installeres automatisk af operativsystemet (Cisco IOS), når et interface tildeles en IP og status bliver `up/up`.
*   **Hvilke netværk kender R1?**
    *   Kun `10.50.10.0/24` og `10.50.12.0/30`.
*   **Hvilke netværk kender R4?**
    *   Kun `10.50.40.0/24` og `10.50.34.0/30`.
*   **Kender en router automatisk alle netværk i topologien?**
    *   Nej. En router er en isoleret enhed, som kun kender de elektriske kredsløb (interfaces), den fysisk er forbundet til, indtil den modtager yderligere information via statisk opsætning eller routing-protokoller.

---

### Første ping-test (Fra PC-A mod PC-D)

*   **Er PC-D (`10.50.40.10`) lokal eller remote set fra PC-A (`10.50.10.10`)?**
    *   Den er **remote**, da den ikke befinder sig på samme subnet (`10.50.10.0/24`).
*   **Hvad gør PC-A derfor med pakken?**
    *   PC-A indser, at pakken skal sendes til en anden lokation. Den sender den derfor til sin configured **Default Gateway** (`10.50.10.1` - R1).
    *   PC-A foretager et ARP-opslag efter MAC-adressen på `10.50.10.1`, pakker IP-pakken ind i en Ethernet-frame med R1's LAN-interface som destinations-MAC, og sender den afsted på mediet.
*   **Hvilken enhed modtager pakken først?**
    *   **R1** modtager framen på sit LAN-interface (`gi0/0`).
*   **Hvad gør denne enhed med destinationens IP-adresse?**
    *   R1 fjerner Ethernet-headeren (Layer 2) for at kigge på IP-pakken (Layer 3). Den læser destinations-IP'en (`10.50.40.10`) og foretager et opslag i sin routingtabel (RIB).
*   **Hvor langt kommer pakken, og hvorfor stopper den?**
    *   Pakken stopper øjeblikkeligt på **R1**. 
    *   R1 har **intet match** på netværket `10.50.40.0/24` i sin routingtabel, og da den heller ikke har nogen gateway of last resort (default route `0.0.0.0/0`), må den droppe pakken med det samme. Den sender en *ICMP Destination Unreachable* tilbage til PC-A.

---

## 4. Del 2 & 3: Vejen frem og tilbage (Statiske ruter)

### Del 2: Etablering af den fremadrettede vej (ICMP Echo Request)

Vi tilføjer en statisk rute på R1:
```ios
R1(config)# ip route 10.50.40.0 255.255.255.0 10.50.12.2
```

*   **Hvad har ændret sig?**
    *   Der er nu tilføjet en statisk rute markeret med `S` i R1's routingtabel for netværket `10.50.40.0/24`.
*   **Hvad betyder `<R2-NEXT-HOP>` (`10.50.12.2`)?**
    *   Det fortæller R1, at pakker mod `10.50.40.0/24` fysisk skal skubbes videre til R2 på IP'en `10.50.12.2`.
*   **Hvordan ved R1, hvordan den når dette next hop?**
    *   R1 slår `10.50.12.2` op og ser, at denne adresse hører under det direkte forbundne netværk `10.50.12.0/30` på interfacet `gi0/1`. Den ved derfor præcis, hvilket fysisk kabel pakken skal sendes ud af.
*   **Hvor langt kommer pakken nu?**
    *   Pakken når nu frem til **R2**. Men her stoppes den, da R2 mangler en rute til `10.50.40.0/24`.

#### Konfiguration af resten af den fremadrettede vej:
For at pakken kan nå PC-D, skal R2 og R3 også kende vejen frem:

```ios
! På R2:
R2(config)# ip route 10.50.40.0 255.255.255.0 10.50.23.2

! På R3:
R3(config)# ip route 10.50.40.0 255.255.255.0 10.50.34.2
```
*(R4 behøver ingen rute frem, da LAN-D er direkte forbundet via connected).*

---

### Del 3: Etablering af returvejen (ICMP Echo Reply)

Når Echo Request når PC-D, vil den svare med en **ICMP Echo Reply** (Source IP: `10.50.40.10`, Destination IP: `10.50.10.10`). For at denne pakke kan komme hele vejen tilbage til PC-A, skal vi etablere retur-routing:

```ios
! På R4:
R4(config)# ip route 10.50.10.0 255.255.255.0 10.50.34.1

! På R3:
R3(config)# ip route 10.50.10.0 255.255.255.0 10.50.23.1

! På R2:
R2(config)# ip route 10.50.10.0 255.255.255.0 10.50.12.1
```
*(R1 behøver ikke en returrute, da LAN-A er direkte forbundet).*

Når dette er konfigureret, vil ping fra PC-A til PC-D have fuld to-vejs succes!

---

## 5. Teoretisk dybdedyk: RIB vs. FIB

| Egenskab | RIB (Routing Information Base) | FIB (Forwarding Information Base) |
| :--- | :--- | :--- |
| **Plan** | **Control Plane** (Hjernen) | **Data Plane** / Forwarding Plane (Musklerne) |
| **Placering** | Primær hukommelse (RAM / CPU) | Hurtig cache / Hardware-kredsløb (ASIC) |
| **Format** | Komplet tabel med alle lærte ruter og protokol-metrikker. | En flad, optimeret lookup-tabel over aktive ruter klar til hardware forwarding. |
| **Kommando** | `show ip route` | `show ip cef` |
| **Opdatering** | Sker ved ændringer i statiske ruter eller dynamiske routing-protokoller. | Spejles og genereres automatisk ud fra den valgte bedste information i RIB. |

### Hvorfor har routeren brug for begge?
Control Plane (RIB) står for politikkerne og intelligensen; den finder ud af, hvilke veje der findes, og hvilke der er bedst. Dataplane (FIB) er bygget til hastighed; den tager beslutninger på mikrosekund-niveau for hver enkelt pakke, der passerer gennem routeren, uden at skulle køre igennem tunge algoritmer i CPU'en.

---

## 6. Route Selection: Longest Prefix Match (LPM) vs. Administrative Distance (AD)

Dette afsnit beskæftiger sig med den udvidede topologi, hvor der findes to veje:
```
       R2 (via link 10.50.12.2 på gi0/0)
     /    \
R1         R4 (LAN-D: 10.50.40.0/24)
     \    /
       R3 (via link 10.50.13.2 på gi0/3)
```

Vi konfigurerer to ruter på R1 med forskellige prefix-længder:
```ios
R1(config)# ip route 10.50.0.0 255.255.0.0 10.50.12.2    ! Større prefix (/16) via R2
R1(config)# ip route 10.50.40.0 255.255.255.0 10.50.13.2 ! Mere specifikt prefix (/24) via R3
```

### Hvilken route bruges?
Når R1 skal sende en pakke til `10.50.40.10`:
1.  **Matcher `10.50.0.0/16`?** Ja.
2.  **Matcher `10.50.40.0/24`?** Ja.
3.  **Hvilken rute vælges?** Ruten mod **R3** (`10.50.40.0/24`) vælges.
4.  **Hvorfor?** På grund af **Longest Prefix Match (LPM)**. En router vælger altid ruten med flest matchende netværksbits (det mest specifikke subnet-prefix / længste prefix). Da `/24` er mere specifikt end `/16`, vinder denne rute altid.

> **Vigtig regel:** LPM (Longest Prefix Match) evalueres **altid** før Administrative Distance (AD). AD is kun relevant, hvis der er to ruter med nøjagtig samme prefix-længde (fx to `/24` ruter), der konkurrerer om at blive installeret i routingtabellen.

---

## 7. OSPF, Floating Static Routes og Redundans

### OSPF-Konfiguration (Mellem alle fire routere)
Vi fjerner vores statiske ruter og aktiverer OSPF for at lade routerne finde hinanden dynamisk:

```ios
! På R1:
R1(config)# no ip route 10.50.40.0 255.255.255.0 10.50.12.2
R1(config)# router ospf 1
R1(config-router)# router-id 1.1.1.1
R1(config-router)# network 10.50.10.0 0.0.0.255 area 0
R1(config-router)# network 10.50.12.0 0.0.0.3 area 0
R1(config-router)# network 10.50.13.0 0.0.0.3 area 0

! På R2:
R2(config)# no ip route 10.50.40.0 255.255.255.0 10.50.23.2
R2(config)# router ospf 1
R2(config-router)# router-id 2.2.2.2
R2(config-router)# network 10.50.12.0 0.0.0.3 area 0
R2(config-router)# network 10.50.23.0 0.0.0.3 area 0

! På R3:
R3(config)# no ip route 10.50.40.0 255.255.255.0 10.50.34.2
R3(config)# router ospf 1
R3(config-router)# router-id 3.3.3.3
R3(config-router)# network 10.50.30.0 0.0.0.255 area 0
R3(config-router)# network 10.50.13.0 0.0.0.3 area 0
R3(config-router)# network 10.50.23.0 0.0.0.3 area 0
R3(config-router)# network 10.50.34.0 0.0.0.3 area 0

! På R4:
R4(config)# router ospf 1
R4(config-router)# router-id 4.4.4.4
R4(config-router)# network 10.50.40.0 0.0.0.255 area 0
R4(config-router)# network 10.50.34.0 0.0.0.3 area 0
```

### Konkurrence mellem OSPF og Static (Same Prefix)
Hvis R1 har lært `10.50.40.0/24` via OSPF, men vi manuelt tilføjer:
```ios
R1(config)# ip route 10.50.40.0 255.255.255.0 10.50.12.2
```
*   **Hvilken rute vinder?** Den statiske rute vinder.
*   **Hvorfor?** Fordi prefix-længden er præcis den samme (`/24`), og den statiske rute har en lavere **Administrative Distance** (AD = 1) end OSPF (AD = 110).

---

### Floating Static Route (Backup-rute)
Vi kan lave den statiske rute om til en backup-rute (Floating Static Route) ved at hæve dens AD over OSPF's AD (fx til AD 200):
```ios
R1(config)# ip route 10.50.40.0 255.255.255.0 10.50.12.2 200
```
*   **Adfærd:** Den statiske rute vil forsvinde fra routingtabellen (`show ip route`), og kun OSPF-ruten vil være aktiv.
*   **Failover-scenarie:** Hvis vi simulerer en fejl ved at lukke OSPF-forbindelsen (fx `shutdown` på R3's interfaces), vil OSPF-ruten blive revet ned og fjernet fra RIB. Da der ikke længere er en rute med AD 110, vil routeren straks installere den statiske rute med AD 200, og trafikken vil fortsætte uden større udfald.

---

## 8. Recursive Lookup, ARP og Layer 2 Videresendelse

### Recursive Lookup (Rekursivt opslag)
Hvis vi konfigurerer en statisk rute på R1, hvor next hop ikke er direkte forbundet:
```ios
R1(config)# ip route 10.50.40.0 255.255.255.0 10.50.23.2
```
Da `10.50.23.2` ikke findes på et netværk, som R1 direkte har et kabel i, vil routeren køre følgende rekursive proces for at videresende en pakke:
1.  Slå destinationen `10.50.40.10` op -> Matcher den statiske rute mod `10.50.23.2`.
2.  Slå `10.50.23.2` op i routingtabellen -> Finder ud af, at for at nå `10.50.23.0/30` skal pakken sendes til `10.50.12.2` (R2).
3.  Slå `10.50.12.2` op -> Matcher det direkte forbundne netværk på interfacet `gi0/1`.
4.  Pakken kan nu sendes ud af det fysiske interface mod R2.

---

### ARP & Ethernet Indpakning
Når pakken skal sendes ud af det fysiske Ethernet-interface:
*   **Skal Ethernet-framen adresseres til PC-D's MAC-adresse eller Next Hops MAC-adresse?**
    *   Den skal sendes til **Next Hops MAC-adresse** (R2's MAC).
*   **Hvorfor?**
    *   Ethernet (Layer 2) er kun lokalt signifikant på det enkelte kabel-link. IP-destinationen (Layer 3) forbliver `10.50.40.10` hele vejen igennem netværket, men Layer 2 Ethernet-headeren bliver flået af og omskrevet ved hvert eneste hop (router-overgang). Framen skal derfor sendes til R2, som derefter er ansvarlig for at pakke den ind i en ny frame mod R3 osv.

---

## 9. Source-IP, Extended Ping og ECMP

### Valg af Source-IP ved router-genereret trafik (Ping fra R1 selv)
Når du starter en ping direkte fra R1's CLI uden parametre mod PC-D (`ping 10.50.40.10`):
*   **Hvordan vælger routeren sin Source-IP?**
    *   Den kigger i sin FIB for at finde ud af, hvilket **egress interface** pakken skal forlade routeren igennem. Den vælger automatisk den IP-adresse, der er konfigureret på dette udgående interface, som pakkes Source-IP (fx `10.50.12.1`).

### Extended Ping
Hvis du bruger udvidet ping, kan du tvinge routeren til at bruge en anden Source-IP:
```ios
R1# ping
Protocol [ip]: 
Target IP address: 10.50.40.10
Repeat count [5]: 
Datagram size [100]: 
Timeout in seconds [2]: 
Extended commands [n]: y
Source address or interface: 10.50.10.1
...
```
Dette er et uundværligt værktøj til troubleshooting, da du kan simulere, at trafikken kommer fra selve LAN-A, hvilket tester om returvejen på de andre routere fungerer korrekt hele vejen tilbage til LAN-A.

---

### ECMP (Equal-Cost Multi-Path)
Hvis R1 lærer to fuldstændig identiske ruter (samme prefix, samme routing-kilde og samme metrik/cost) til LAN-D via henholdsvis R2 og R3:
*   Begge ruter vil blive installeret side om side i både RIB og FIB.
*   Routeren vil derefter foretage **Load Balancing** over begge links.
*   I moderne Cisco CEF-miljøer sker dette typisk pr. IP-flow (baseret på en hash af Source- og Destination IP), hvilket sikrer, at pakker tilhørende samme samtale/forbindelse tager den samme rute for at undgå "out-of-order" pakker.
