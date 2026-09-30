# Testplan og Fejlfindingsdokumentation for Monitorering og Logging (Del 3)

Dette dokument beskriver testprocedurerne, faktiske CLI-kommandoer, alarm-verifikationer og kontrollerede fejlfindingseksperimenter for **Infrastrukturprojekt – Del 3: Logging og monitorering**.

Formålet er at dokumentere, at **LibreNMS** og **Netdata** opsamler korrekte telemetri- og logdata, at tidsstempler er synkroniserede, samt at administratorer omgående adviseres og kan diagnosticere årsagen ved driftsforstyrrelser.

---

## 1. Test- og Verifikationsmatrix for Del 3

| Test ID | Kategori | Testscenarie / Formål | Testmetode & Kommando | Forventet Resultat | Status |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **TC-301** | SNMP | Verificer SNMPv2c polling mod Cisco switche | Kør `snmpwalk -v2c -c public 192.168.100.2 sysUpTime.0` fra LibreNMS. | Svar returneres med gyldig oppetidsværdi (`Timeticks: (XXXX) ...`). | [Godkendt] |
| **TC-302** | SNMP | Verificer sikker SNMPv3 `authPriv` polling | Kør `snmpwalk -v3 -l authPriv -u snmpadmin -a SHA -A ... -x AES -X ... 192.168.100.2 ifDescr`. | Krypteret session etableres. Liste over interfaces returneres fejlfrit. | [Godkendt] |
| **TC-303** | Syslog | Verificer modtagelse af Cisco Syslog-hændelser | Foretag login eller `conf t` på `ds-01`. Kontroller Syslog-view i LibreNMS. | Besked modtages øjeblikkeligt: `%SYS-5-CONFIG_I: Configured from console by admin`. | [Godkendt] |
| **TC-304** | NTP | Kontroller tidssynkronisering på tværs af enheder | Kør `show clock` på Cisco, `get system status` på FortiGate og `timedatectl` på Linux. | Alle enheder viser identisk tid inden for < 10 millisekunder (CET/CEST). | [Godkendt] |
| **TC-305** | Service | Overvåg kunders webservere uden brud på VRF | Kontroller HTTP-service sensorer for Alfa, Bravo, Charlie og Delta i LibreNMS. | Alle fire services viser `OK - HTTP/1.1 200 OK` med responstid under 5 ms. | [Godkendt] |
| **TC-306** | Telemetri | Verificer Netdata realtidsmetrik på Dell R630 | Åbn Netdata Web UI på `http://192.168.99.100:19999`. | 1-sekunds grafer for CPU, RAM, Disk I/O og netværkstrafik opdateres live. | [Godkendt] |
| **TC-307** | NetFlow | Verificer Cisco 3650 Flexible NetFlow eksport | Kør `show flow monitor FNF-MONITOR-IPV4 cache` på `ds-01`. | Aktive flows vises med IP-adresser, protokoller, porte og pakketællere. | [Godkendt] |
| **TC-308** | Fejlfinding | **Fejltest 1:** Simuleret Webserver Nedbrud | Stop Nginx på `vm-alfa-web01` (`systemctl stop nginx`). | LibreNMS udløser rød alarm for Kunde Alfa HTTP Service inden for 60 sekunder. | [Godkendt] |
| **TC-309** | Fejlfinding | **Fejltest 2:** Simuleret Interface Fejl | Luk en switchport på `ms-01` (`shutdown Gi1/0/10`). | Syslog `%LINK-3-UPDOWN` modtages straks. LibreNMS markerer porten som `DOWN`. | [Godkendt] |
| **TC-310** | Fejlfinding | **Fejltest 3:** Simuleret Høj CPU-belastning | Kør CPU-stress på VM (`stress-ng --cpu 2 --timeout 120s`). | Netdata advarer i realtid (gult/rødt badge), og LibreNMS CPU-graf viser stigningen. | [Godkendt] |
| **TC-311** | Fejlfinding | **Fejltest 4:** Simuleret VM Nedlukning | Sluk for Kunde Bravo VM via Proxmox (`qm stop 120`). | ICMP Ping alarm aktiveres i LibreNMS. Dashboard viser `Device DOWN`. | [Godkendt] |

---

## 2. Detaljeret Dokumentation af Fejlfindingsscenarier

I overensstemmelse med fagets mål skal monitoreringssystemet anvendes aktivt til hurtigt og præcist at besvare fire centrale spørgsmål:
1.  **Hvad er fejlen?**
2.  **Hvor befinder fejlen sig?**
3.  **Hvornår opstod den?**
4.  **Hvilke systemer eller kunder er påvirket?**

---

### Fejlscenarie 1: Webserver-nedbrud hos Kunde Alfa (TC-308)

#### A. Fremprovokering af Fejl:
På webserveren `vm-alfa-web01` standses webtjenesten bevidst:
```bash
admin@vm-alfa-web01:~$ sudo systemctl stop nginx
```

#### B. Registrering i Overvågningen (Tidslinje):
*   **Kl. 13:10:00:** Nginx stoppes.
*   **Kl. 13:10:35:** LibreNMS poller HTTP-servicen på `192.168.10.10:80`. Forespørgslen fejler med `Connection refused`.
*   **Kl. 13:10:36:** Alarm udløses: `Service Alert: HTTP down on vm-alfa-web01 (CRITICAL)`.
*   **Kl. 13:10:37:** Dashboard-widget for Kunde Alfa skifter fra grøn til blinkende rød.
*   **Syslog hændelse:** Netdata/systemd logger: `nginx.service: Deactivated successfully`.

#### C. Analyse og Svar på de fire spørgsmål:
*   **Hvad er fejlen?** HTTP-tjenesten (Nginx) er stoppet og afviser forbindelser på port 80.
*   **Hvor befinder fejlen sig?** Lokalt på den virtuelle maskine `vm-alfa-web01` (VMID 110) i Proxmox Resource Pool `pool-alfa`.
*   **Hvornår opstod den?** Kl. 13:10:00 (bekræftet af Syslog tidsstempel).
*   **Hvilke systemer eller kunder er påvirket?** Udelukkende **Kunde Alfa**. Kunde Bravo, Charlie og Delta kører fuldstændig uforstyrret videre.

#### D. Løsning og Normalisering:
```bash
admin@vm-alfa-web01:~$ sudo systemctl start nginx
```
LibreNMS poller servicen igen kl. 13:11:35, registrerer HTTP 200 OK og sender et `RECOVERY` varsel. Dashboard skifter tilbage til grøn status.

---

### Fejlscenarie 2: Fysisk Link-nedbrud på Switch (TC-309)

#### A. Fremprovokering af Fejl:
På Cisco Catalyst 2960X access-switchen lukkes port `Gi1/0/10` administrativt:
```cisco
ms-01(config)# interface GigabitEthernet1/0/10
ms-01(config-if)# shutdown
```

#### B. Registrering i Overvågningen:
1.  **Syslog (Push - Øjeblikkelig registrering):**
    LibreNMS modtager straks følgende besked via UDP 514:
    ```text
    Sep 30 13:22:14 ms-01 42: %LINK-3-UPDOWN: Interface GigabitEthernet1/0/10, changed state to administratively down
    Sep 30 13:22:15 ms-01 43: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet1/0/10, changed state to down
    ```
2.  **SNMP Trap & Polling:**
    Switchen afsender en `linkDown` SNMP trap til `192.168.100.150`.
3.  **LibreNMS Alarm:**
    Porten markeres med rød farve under `ms-01 -> Ports`.

#### C. Analyse:
*   **Hvad er fejlen?** Fysisk port `GigabitEthernet1/0/10` er taget ned (`administratively down`).
*   **Hvor befinder fejlen sig?** På Cisco 2960X access-switch `ms-01` i rack 1.
*   **Hvornår opstod den?** Kl. 13:22:14.
*   **Hvilke kunder er påvirket?** Ingen direkte kundepåvirkning, da Dell R630 kører redundant bond mod `Gi1/0/8` og `Gi1/0/9`.

---

### Fejlscenarie 3: Ressourceoverbelastning (CPU Stress) (TC-310)

#### A. Fremprovokering af Fejl:
For at simulere en proces, der løber løbsk eller et Denial-of-Service angreb, igangsættes en 2-kerne CPU-stress på `vm-bravo-web01`:
```bash
admin@vm-bravo-web01:~$ stress-ng --cpu 2 --timeout 120s
```

#### B. Registrering i Netdata og LibreNMS:
1.  **Netdata (1-sekunds opløsning):**
    *   Inden for 2 sekunder stiger CPU-grafen fra 1.2% til **100.0%**.
    *   Netdata udløser en gul advarsel: `10min_cpu_usage = 98.4%`.
    *   Netdata's per-process monitor viser, at processerne hedder `stress-ng-cpu`.
2.  **LibreNMS (SNMP Polling):**
    *   Ved næste 1-minuts polling opdateres CPU-grafen for Kunde Bravo til et synligt plateau på 100%.

#### C. Konklusion:
Kombinationen af Netdata og LibreNMS gør det muligt både at se den langsigtede historik (LibreNMS) og øjeblikkeligt identificere den specifikke synderproces på procesniveau (Netdata).

---

## 3. Vurdering af den Samlede Monitoreringsløsning

Den etablerede løsning med **LibreNMS** og **Netdata** opfylder og overgår alle krav i opgavebeskrivelsen:
1.  **Dækkende Overblik:** Løsningen overvåger netværksswitches, firewalls, hypervisorer og kundesystemer i ét samlet interface.
2.  **Sikker Adskillelse:** Monitoreringen overholder de etablerede VRF- og VLAN-adskillelser uden at kompromittere kundernes isolation.
3.  **Hurtig Fejlfinding:** Ved hjælp af korrelerede Syslog-beskeder, SNMP traps og realtids telemetri kan enhver fejl lokaliseres og diagnosticeres på under 2 minutter.
