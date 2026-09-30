# Designvalg, Monitoreringsarkitektur og Teori (Del 3)

Dette dokument beskriver de arkitektoniske valg, overvejelser og faglige dybdedyk bag den etablerede logging- og monitoreringsløsning for **Infrastrukturprojekt – Del 3: Logging og monitorering**.

Løsningen er implementeret med **LibreNMS** som centralt overvågningssystem (NMS) og Syslog-modtager samt **Netdata** som højfrekvent metrik-motor på server- og hypervisorniveau.

---

## 1. Monitoreringsarkitektur og Strategiske Valg

I opgavebeskrivelsen nævnes PRTG Network Monitor som en typisk baseline. I vores fysiske produktion i laboratoriet har vi valgt at implementere en enterprise open-source arkitektur baseret på **LibreNMS** og **Netdata**:

### Hvorfor LibreNMS og Netdata?
1.  **LibreNMS (Netværk, Topologi, SNMP & Syslog):**
    *   **Ingen sensorbegrænsninger:** PRTG begrænses typisk af sensor-licenser (f.eks. max 100 sensorer i gratisudgaven). LibreNMS overvåger ubegrænset tusindvis af interfaces, BGP-sessioner, VRF'er, SVI'er og miljøsensorer uden begrænsninger.
    *   **Automatisk Topologi-opdagelse (Autodiscovery):** Ved brug af CDP (Cisco Discovery Protocol) og LLDP kortlægger LibreNMS automatisk forbindelserne mellem `ds-01`, `ds-02`, `ms-01`, FortiGate og Dell R630.
    *   **Native Central Syslog Integration:** LibreNMS indeholder en integreret Syslog-parser, der mapper log-beskeder direkte til de berørte enheder og interfaces, hvilket gør korrelation lynhurtig.
2.  **Netdata (Realtids Server- og Container-Telemetri):**
    *   **1-sekunds opløsning vs. 60-sekunders polling:** Traditionel SNMP-overvågning poller typisk hvert 1-5 minut. Korte CPU-spikes, micro-bursts på netværket eller hurtige I/O-flaskehalse overses ofte. Netdata indsamler metrikker per sekund i realtid.
    *   **Zero-Configuration:** Registrerer automatisk alle virtuelle maskiner, Linux cgroups, Nginx webservere og disk-arrays.

---

## 2. Placering i Netværket og Sikring af Kundeadskillelse

Monitoreringsserverne er placeret på det dedikerede server/shared segment: **VLAN 100 (`192.168.100.0/24`)** med IP-adressen **`192.168.100.150`**:

*   **Fysisk tilslutning:** Forbundet via Cisco 2960X access-porte (`ms-01` port `Gi1/0/8`-`Gi1/0/10`) og routed via Cisco 3650 Core switchene (`ds-01` og `ds-02` SVI `Vlan100`).
*   **Kommunikation mod netværksinfrastrukturen:** Switche og firewalls sender SNMP og Syslog direkte over VLAN 100 eller transit-netværket via management-routing.

### Monitorering af kundemiljøer UDEN at bryde VRF-isolationen
Et centralt krav i opgaven er:
> *"PRTG / monitoreringen må ikke anvendes som en genvej til at fjerne eller omgå den isolation, der tidligere er etableret."*

For at overholde dette princip anvendes en kontrolleret **Unidirectional Monitoring Architecture**:
1.  **Ingen bridging mellem kunders netværk:** Kunderne er fortsat segmenteret i hver deres VRF (`vrf-alfa`, `vrf-bravo`, `vrf-charlie`, `vrf-delta`) på Cisco 3650 samt separate Linux Bridges på Proxmox (`vmbr10`, `vmbr20` osv.).
2.  **Overvågning via Service Health Checks (HTTP / ICMP):**
    *   LibreNMS udfører HTTP service-checks mod kundernes offentlige web-IP'er (`192.168.10.10`, `192.168.20.10`, etc.) ved at benytte den etablerede statiske default route-leaking mod Global Routing Table (GRT) på Cisco 3650.
    *   Trafikken følger præcis samme vej som en legitim klient: LibreNMS sender GET request ➔ Cisco 3650 router ind i kundens VRF ➔ Webserver svarer ➔ Retursvar sendes tilbage.
    *   Kunderne har **ingen ruter eller adgang** til at initiere trafik ind mod hinanden eller mod monitoreringsserveren.

---

## 3. Teoretisk Dybdedyk: SNMP (Simple Network Management Protocol)

### A. Kæden: NMS ➔ SNMP ➔ Enhed ➔ MIB ➔ OID
For at forstå hvordan overvågningen fungerer i praksis, skal sammenhængen mellem komponenterne forstås:

```
[ LibreNMS (NMS) ]
       |
       | 1. SNMP GET / GET-NEXT / WALK (UDP Port 161)
       v
[ SNMP Agent (Cisco 3650 / FortiGate / Linux) ]
       |
       | 2. Slår op i den lokale MIB-database efter forespurgt OID
       v
[ MIB (Management Information Base) ]  ===>  [ OID (Object Identifier) ]
       |                                      Eks: 1.3.6.1.2.1.2.2.1.10.1
       v                                      (ifInOctets for Interface 1)
[ Hardware / Kernetællere ]
       |
       | 3. Returnerer værdi (Eks: Counter64 = 48291048 bytes)
       v
[ LibreNMS (Beregner båndbredde og genererer grafer) ]
```

1.  **NMS (Network Management Station):** Den centrale server (LibreNMS), som sender periodiske forespørgsler (polling) og modtager asynkrone alarmer (SNMP Traps på UDP port 162).
2.  **SNMP Agent:** En baggrundsproces/service, der kører direkte på netværksenheden (f.eks. Cisco IOS processen eller `snmpd` på Linux), som vedligeholder systemets tællere.
3.  **MIB (Management Information Base):** En hierarkisk, struktureret tekstfil (database-skema), der beskriver hvilke data enheden stiller til rådighed, og hvad de betyder. Standard-MIB'er (f.eks. `RFC1213-MIB`, `IF-MIB`) er ens på tværs af alle producenter, mens Enterprise-MIB'er (f.eks. `CISCO-PROCESS-MIB`) indeholder producentspecifikke data.
4.  **OID (Object Identifier):** En unik numerisk sti i MIB-træet adskilt af punktummer. Eksempler:
    *   `.1.3.6.1.2.1.1.3.0` = `sysUpTime` (Enhedens oppetid).
    *   `.1.3.6.1.2.1.2.2.1.8.<ifIndex>` = `ifOperStatus` (Portens link-status: 1=up, 2=down).
    *   `.1.3.6.1.4.1.9.9.109.1.1.1.1.5.1` = Cisco 5-minutters CPU-belastning.

---

### B. Sammenligning: SNMPv2c vs. SNMPv3

| Egenskab | SNMPv2c | SNMPv3 |
| :--- | :--- | :--- |
| **Sikkerhedsmodel** | Community Strings (Klartekst adgangskode) | **USM** (User-based Security Model) |
| **Fortrolighed (Kryptering)** | **Ingen.** Al trafik inklusive community string sendes i klartekst over netværket. | **AES-128 / AES-256** kryptering af hele datapakken. |
| **Integritet & Autentificering** | **Ingen.** Ingen sikring mod ændring eller manipulation undervejs. | **HMAC-SHA256 / SHA-1** forhindrer manipulation og replay-angreb. |
| **Adgangskontrol (AC)** | Kun grov opdeling i Read-Only (RO) og Read-Write (RW). | **VACM** (View-based Access Control Model) – tillader præcis begrænsning til specifikke OID-undertræer. |
| **Sikkerhedsvurdering** | **Usikker.** Bør kun anvendes på lukkede, isolerede administrations-VLANs. | **Enterprise Sikker.** Kan anvendes sikkert i moderne netværk. |

I vores implementering er der konfigureret fuld **SNMPv3 med `authPriv`** (SHA autentificering og AES kryptering) på Core-switchene (`ds-01`, `ds-02`) og FortiGate, med fallback til SNMPv2c på ældre access-switche under restriktive access-lister.

---

## 4. Teoretisk Sammenligning: SNMP vs. Syslog vs. NetFlow

De tre teknologier udfylder vidt forskellige, men komplementære roller i netværksdriften:

```
+-------------------------------------------------------------------------------+
|                      TRE-BENET MONITORERINGSMODEL                             |
+-------------------------------------------------------------------------------+
|   TEKNOLOGI   | MODEL | HVAD VISER DET?           | DRIFTSMÆSSIG ANVENDELSE   |
+---------------+-------+---------------------------+---------------------------+
| **SNMP**      | Pull  | Metrikker, oppetid, CPU,  | "Hvor meget båndbredde    |
|               | (Poll)| RAM og interface-tællere. | bruges der lige nu?"      |
+---------------+-------+---------------------------+---------------------------+
| **Syslog**    | Push  | Konkrete hændelser, fejl, | "Hvorfor røg forbindelsen |
|               | (Trap)| logins og statusændringer.| kl. 14:02?"               |
+---------------+-------+---------------------------+---------------------------+
| **NetFlow**   | Push  | Samtaler, IP-flows, porte,| "HVEM bruger båndbredden, |
|               | (Flow)| protokoller og volumen.   | og til hvilken service?"  |
+---------------+-------+---------------------------+---------------------------+
```

1.  **SNMP (Pull-princip):** LibreNMS poller enheden hvert minut. Viser at interface `Te1/0/1` kører med 85% belastning, men kan *ikke* fortælle, hvilke brugere eller protokoller der forårsager belastningen.
2.  **Syslog (Push-princip):** Enheden sender en asynkron besked i det millisekund, en hændelse indtræffer. Eksempel: `%LINK-3-UPDOWN: Interface GigabitEthernet1/0/1, changed state to down`. Giver det præcise tidspunkt og årsag til et nedbrud.
3.  **NetFlow / IPFIX (Flow-cache eksport):** Routeren cacher statistik over alle aktive IP-flows baseret på 7 nøgleparametre (Source IP, Destination IP, Source Port, Destination Port, L3 Protocol, Ingress Interface, ToS). Viser præcist, at de 85% båndbredde skyldes en backup-strøm fra `192.168.10.10` mod en ekstern server på port 443.

---

## 5. Central Tidssynkronisering (NTP)

I et distribueret netværk med switches, firewalls, hypervisors og virtuelle servere er **NTP (Network Time Protocol)** en fundamental forudsætning for drift og sikkerhed:
*   **Log-korrelation:** Hvis Core-switchen registrerer et link-down kl. `11:14:02`, og webserveren logger en database-timeout kl. `11:18:22` pga. et usynkroniseret ur, er det umuligt at korrelere hændelserne under fejlfinding.
*   **Certifikatvalidering:** HTTPS og SSH er afhængige af præcis tid for at validere certifikaters gyldighedsperiode.
*   **Implementering:** Cisco 4331 WAN-routeren og Core-switchene fungerer som lokal pålidelig NTP-tidskilde for laboratoriet, synkroniseret mod officielle stratum-1 servere (`dk.pool.ntp.org`).

---

## 6. Alarmeringsstrategi og Grænseværdier

Målet med alarmering er proaktivitet uden at skabe "alert fatigue" (hvor administratorer ignorerer alarmer pga. konstante ligegyldige notifikationer). Følgende grænseværdier er konfigureret i LibreNMS og Netdata:

| Målepunkt | Advarsel (Warning) | Kritisk (Critical) | Hysterese / Forsinkelse | Begrundelse |
| :--- | :---: | :---: | :---: | :--- |
| **Ping Packet Loss** | > 20% | > 60% | Efter 3 mislykkede polls | Filtrerer enkeltstående tabte ICMP-pakker fra. |
| **Device Down** | - | 100% loss i 60 sek | Øjeblikkelig | Kritisk fejl på Core/Firewall/Host. |
| **Interface State** | - | OperState = `down` | Kun på uplinks & trunks | Triggers ikke på klientporte med almindelig sluk/tænd. |
| **CPU Belastning** | > 75% | > 90% | Vedvarende i > 5 minutter | Ignorerer korte legitime CPU-spikes ved opstart. |
| **RAM Forbrug** | > 80% | > 95% | Vedvarende i > 5 minutter | Forhindrer at Out-Of-Memory (OOM) killer dræber services. |
| **Diskforbrug** | > 85% | > 92% | Øjeblikkelig | Sikrer tid til udvidelse af diske før nedbrud. |
| **Web Service HTTP**| Status != 200 | Timeout > 5 sek | Efter 2 mislykkede requests | Sikrer at kunders webservere faktisk svarer. |

---

## 7. Dashboard Design ("Er infrastrukturen sund lige nu?")

LibreNMS dashboardet er designet som et **Single Pane of Glass** til den vagthavende tekniker:
1.  **Global Status Banner:** Viser øverst antallet af oppetidsenheder (f.eks. `8/8 Devices UP`) med grøn baggrund.
2.  **Critical Alerts Widget:** Viser øverst til venstre aktive fejl (aktive alarmer sorteret efter alvorlighed).
3.  **Core Uplink Traffic Graph:** Realtids-grafer for LACP trunks mellem `ds-01`, `ds-02` og Proxmox 10G interfaces.
4.  **Customer Web Services Status:** Fire tydelige grønne indikatorer for Kunde Alfa, Bravo, Charlie og Delta HTTP tilgængelighed.
5.  **Live Syslog Stream:** Filtreret visning af de seneste 15 hændelser med severity `Warning`, `Error` og `Critical`.
