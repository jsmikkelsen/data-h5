# Infrastrukturprojekt – Del 3: Central Logging og Monitorering (LibreNMS & Netdata)

Velkommen til projektportfoliet for **Infrastrukturprojekt – Del 3: Logging og monitorering**. Dette modul afslutter opbygningen af virksomhedens komplette datacenter- og hostinginfrastruktur for **Del 1 (v2)** og **Del 2**.

For at sikre pålidelig drift, proaktiv fejlopdagelse, kapacitetsplanlægning og hurtig hændelsesundersøgelse (root-cause analysis) er der etableret en fuldt integreret, enterprise-standard monitorerings- og loggingsløsning baseret på **LibreNMS** og **Netdata**.

Løsningen dækker hele infrastrukturen: netværksswitches (Cisco Catalyst 3650 & 2960X), firewalls (FortiGate 60F HA), hypervisor (Proxmox VE på Dell R630) samt de fire virtuelle kundemiljøer (**Alfa**, **Bravo**, **Charlie** og **Delta**).

---

## 📂 Mappestruktur og Dokumentation for Del 3

Dokumentationen er opdelt i moduler efter H5-standarderne:

1. **[Designvalg og Monitoreringsarkitektur (`design_valg.md`)](./design_valg.md)**
   * Strategiske valg: Hvorfor kombinationen af **LibreNMS** (netværks-SNMP, Syslog, autodiscovery, alarmering og overbliksdashboards) og **Netdata** (ultra-højopløselig 1-sekunds systemmetrik på hypervisor og VM'er) overgår traditionelle løsninger som PRTG.
   * Placering i netværket: Integration på det fælles server-/shared-netværk (VLAN 100, IP `192.168.100.150`).
   * **Fagligt Dybdedyk i SNMP:**
     * Gennemgang af kæden: **Monitoreringssystem ➔ SNMP ➔ Enhed ➔ MIB ➔ OID**.
     * Sikkerhedsmæssig sammenligning af **SNMPv2c vs SNMPv3** (klartekst community strings vs USM autentificering/kryptering og VACM adgangskontrol).
   * **SNMP vs Syslog vs NetFlow:** Formål, arkitektur (pull vs push vs flow-cache) og praktisk anvendelse ved drift og fejlfinding.
   * Monitorering af kundemiljøer uden kompromittering af VRF-Lite isolationen.
   * Central tidssynkronisering med NTP som forudsætning for korrelation af logs.
   * Alarmeringsstrategi, grænseværdier og dashboard design ("Er infrastrukturen sund lige nu?").

2. **[Konfigurationsskabeloner (`konfiguration_skabelon.md`)](./konfiguration_skabelon.md)**
   * Cisco Catalyst 3650 (`ds-01`, `ds-02`) og 2960X (`ms-01`):
     * SNMPv2c og SNMPv3 konfiguration (Users, Groups, Views, SHA auth og AES privacy).
     * Central Syslog forwarding (`logging host 192.168.100.150`, traps og source-interfaces).
     * NTP server konfiguration (`ntp server 192.168.100.1`).
     * Cisco Flexible NetFlow (FNF) flow record, exporter og monitor opsætning.
   * FortiGate 60F HA Cluster:
     * SNMP agent, v2c/v3 konfiguration, Syslog eksport til LibreNMS og NetFlow eksport.
   * Proxmox VE og Linux Kundeserverne:
     * Net-SNMP daemon (`snmpd.conf`) opsætning.
     * Netdata agent installation og realtids streaming.
     * Rsyslog konfiguration mod central Syslog server.
     * Chrony NTP klientopsætning.
   * LibreNMS: Discovery, Syslog daemon integration, alert rules og dashboard widgets.

3. **[Testplan og Fejlfindingsdokumentation (`test_dokumentation.md`)](./test_dokumentation.md)**
   * Komplet testmatrix for monitorering og logging.
   * SNMP polling og walk verifikation (v2c og v3).
   * Syslog hændelsesverifikation (login, link up/down, konfigurationsændringer).
   * NTP tidsstempelsammenligning på tværs af platforme.
   * Gennemførte fejlfindingstests med kontrolleret fremprovokering af fejl:
     1. Webserver stop (Nginx nedbrud) ➔ HTTP service alarm aktiveret.
     2. Interface shutdown på switch ➔ Port Down alarm og Syslog link-state registrering.
     3. CPU stress-test ➔ Netdata realtids-alarm og LibreNMS threshold trigger.
     4. Proxmox VM nedlukning ➔ Host ping loss alarm og automatisk hændelseslog.
   * Root-Cause Analyse model: **Sensor ➔ Graf ➔ Alarm ➔ Syslog**.

---

## 🛠️ Overordnet Monitoreringsarkitektur

```
                            [ Skole/WAN Router (192.168.200.2) ]
                                            |
                         +------------------+------------------+
                         |                                     |
              [ FortiGate fg-01 (Active) ]         [ FortiGate fg-02 (HA) ]
              (SNMPv3 / Syslog / NetFlow)          (SNMPv3 / Syslog / NetFlow)
                         |                                     |
                         +------------------+------------------+
                                            |
                         +------------------+------------------+
                         |                                     |
                [ Cisco 3650 ds-01 ]                  [ Cisco 3650 ds-02 ]
                (SNMPv3 / Syslog / FNF)               (SNMPv3 / Syslog / FNF)
                         |                                     |
                         +------------------+------------------+
                                            |
                                  [ Cisco 2960X ms-01 ]
                                    (SNMPv2c / Syslog)
                                            |
             +------------------------------+------------------------------+
             | (VLAN 100 - Port Gi1/0/8-10)                                | (10G LACP Trunk)
             v                                                             v
+-------------------------------+                       +------------------------------------+
|  LibreNMS Central Monitorering |                       |   Dell PowerEdge R630 (Proxmox VE) |
|   (IP: 192.168.100.150/24)    |                       |   (IP: 192.168.99.100 / .100.100)  |
|                               |                       |   - Net-SNMP Daemon                |
| - SNMP Polling (v2c & v3)     |<====== SNMP / Syslog =|   - Netdata System Monitor         |
| - Central Syslog Receiver     |<====== Flow Data =====|                                    |
| - Alerting Engine             |                       |   +----------------------------+   |
| - NetFlow Collector           |                       |   | Kunde Alfa VM (192.168.10.10)|
| - Network Health Dashboard    |                       |   | - Nginx / HTTP Health      |   |
+-------------------------------+                       |   | - Netdata Child Agent      |   |
             ^                                          |   +----------------------------+   |
             |                                          |   | Kunde Bravo VM (.20.10)    |   |
             |                                          |   | Kunde Charlie VM (.30.10)  |   |
             +============= HTTP / ICMP Health Checks ==|   | Kunde Delta VM (.40.10)    |   |
                                                        |   +----------------------------+   |
                                                        +------------------------------------+
```

### Hvorfor LibreNMS og Netdata er det optimale valg:
* **LibreNMS:** Fungerer som den overordnede **Network Management Station (NMS)**. Den håndterer automatisk opdagelse af topologi via LLDP/CDP, grafer over samtlige switchporte og interfaces, BGP/HSRP overvågning, indbygget Syslog-server og avancerede alert rules.
* **Netdata:** Leverer **realtids per-sekund telemetri** direkte på serverne og hypervisoren. Hvor traditionelle NMS-systemer som PRTG poller med 60 sekunders intervaller og dermed misser kortvarige micro-bursts og CPU-spikes, fanger Netdata anomalier i det øjeblik, de opstår.
