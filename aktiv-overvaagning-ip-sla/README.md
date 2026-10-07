# Dagsopgave: Aktiv Overvågning med Cisco IP SLA og Object Tracking

Dette modul indeholder den samlede tekniske dokumentation, netværksdesign, konfigurationer og testrapporter for dagsopgaven **"Aktiv overvågning med IP SLA"** på Hovedforløb 5 (H5).

---

## 📑 Indholdsfortegnelse
1. [Problemstilling & Formål](#1-problemstilling--formål)
2. [Del 1 – Topologi & IP-adresseringsplan](#del-1--topologi--ip-adresseringsplan)
3. [Del 2 – Grundlæggende Routing & Floating Static Route](#del-2--grundlæggende-routing--floating-static-route)
4. [Del 3 – Test af Direkte Linkfejl](#del-3--test-af-direkte-linkfejl)
5. [Del 4 – Fejl Længere Ude i Netværket (Det Blinde Punkt)](#del-4--fejl-længere-ude-i-netværket-det-blinde-punkt)
6. [Del 5 – Opret Aktiv Test med Cisco IP SLA](#del-5--opret-aktiv-test-med-cisco-ip-sla)
7. [Del 6 – Test af IP SLA under Fejl (UP vs. FAIL)](#del-6--test-af-ip-sla-under-fejl-up-vs-fail)
8. [Del 7 – Object Tracking med Dampening/Hysterese](#del-7--object-tracking-med-dampeninghysterese)
9. [Del 8 – Knyt Tracking til Routing](#del-8--knyt-tracking-til-routing)
10. [Del 9 – Test af Automatisk Failover](#del-9--test-af-automatisk-failover)
11. [Del 10 – Test af Automatisk Recovery](#del-10--test-af-automatisk-recovery)
12. [Del 11 – Service-monitorering: TCP Connect vs. ICMP Echo](#del-11--service-monitorering-tcp-connect-vs-icmp-echo)
13. [Del 12 – Performance & RTT Målinger](#del-12--performance--rtt-målinger)
14. [Del 13 – Samlet Teknisk Dokumentation (Afleveringsrapport)](#del-13--samlet-teknisk-dokumentation-afleveringsrapport)

---

## 1. Problemstilling & Formål

I traditionel statisk routing evaluerer en Cisco router udelukkende en rutes gyldighed ud fra, om det udgående interface mod next-hop er **UP/UP**.

### Det blinde punkt:
Hvis en upstream-forbindelse længere ude i netværket afbrydes (f.eks. hos en ISP eller på et transitlink mellem R2 og destinationen), forbliver routerens eget lokale interface UP/UP. Routeren vil fortsætte med at sende trafik ind i et sort hul (*black hole*), selvom der findes en fuldt funktionel alternativ backup-vej via R3.

### Løsningen:
Ved at kombinere **Cisco IP SLA (Service Level Agreement)** og **Enhanced Object Tracking** kan routeren aktivt probe destinationen (Layer 3 ICMP eller Layer 4/7 TCP/HTTP). Så længe målingen er en succes, holdes den primære rute aktiv. Hvis målingen fejler, trækkes ruten dynamisk ud af routingtabellen, hvorefter den forberedte **Floating Static Route** automatisk overtager trafikken.

---

## Del 1 – Topologi & IP-adresseringsplan

### Netværkstopologi (GNS3 / Lab Miljø)

```text
                     [ R2 ] (Primær transit)
                   .12.2    .24.2
             Gi0/1 /            \ Gi0/0
                  /              \ 
       .12.1     /                \ ens4 .24.4
[ Client (Linux) ] --- [ R1 ]              [ Server (Linux) ] (lo: 172.16.1.1/32)
ens4: 192.168.10.50   Gi0/0   Gi0/2 \            / ens5 .34.4
                               \          /
                         .13.1  \        / Gi0/0
                           Gi0/2 \      /
                                 [ R3 ] (Backup transit)
                               .13.3    .34.3
```

- **Client:** Linux klient-maskine (`ens4`: `192.168.10.50/24`, Gateway: `192.168.10.1`).
- **R1:** Cisco edge-router / default gateway.
- **R2:** Primær upstream transit-router.
- **R3:** Sekundær upstream transit-router (backup).
- **Server:** Dual-homed Linux server (`ens4` mod R2, `ens5` mod R3) med loopback IP `172.16.1.1/32` som ekstern test-destination og integreret Python HTTP webserver.

### IP-adresseringsplan

| Enhed | Interface | IP-adresse | Prefix / Maske | Forbundet mod | Beskrivelse |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Client (Linux)** | `ens4` | `192.168.10.50` | `/24` (`255.255.255.0`) | R1 `Gi0/0` | Klient / LAN (Gateway: `192.168.10.1`) |
| **R1** | `Gi0/0` | `192.168.10.1` | `/24` (`255.255.255.0`) | Client `ens4` | LAN Gateway |
| **R1** | `Gi0/1` | `10.1.12.1` | `/30` (`255.255.255.252`) | R2 `Gi0/1` | Mod R2 (Primær sti) |
| **R1** | `Gi0/2` | `10.1.13.1` | `/30` (`255.255.255.252`) | R3 `Gi0/2` | Mod R3 (Backup sti) |
| **R2** | `Gi0/1` | `10.1.12.2` | `/30` (`255.255.255.252`) | R1 `Gi0/1` | Mod R1 |
| **R2** | `Gi0/0` | `10.1.24.2` | `/30` (`255.255.255.252`) | Server `ens4` | Mod Server (Primær vej) |
| **R3** | `Gi0/2` | `10.1.13.3` | `/30` (`255.255.255.252`) | R1 `Gi0/2` | Mod R1 |
| **R3** | `Gi0/0` | `10.1.34.3` | `/30` (`255.255.255.252`) | Server `ens5` | Mod Server (Backup vej) |
| **Server (Linux)** | `ens4` | `10.1.24.4` | `/30` (`255.255.255.252`) | R2 `Gi0/0` | Mod R2 (Primær vej) |
| **Server (Linux)** | `ens5` | `10.1.34.4` | `/30` (`255.255.255.252`) | R3 `Gi0/0` | Mod R3 (Backup vej) |
| **Server (Linux)** | `lo` | `172.16.1.1` | `/32` (`255.255.255.255`) | Lokal loopback | Ekstern test-destination & webserver |

### Linux Node Opsætning

#### Client Setup (Kommandoer):
```bash
sudo ip addr flush dev ens4
sudo ip addr add 192.168.10.50/24 dev ens4
sudo ip link set ens4 up
sudo ip route add default via 192.168.10.1 dev ens4
```

#### Server Setup (Kommandoer):
```bash
# Interfaces:
sudo ip addr add 10.1.24.4/30 dev ens4 && sudo ip link set ens4 up
sudo ip addr add 10.1.34.4/30 dev ens5 && sudo ip link set ens5 up
sudo ip addr add 172.16.1.1/32 dev lo

# Routing mod LAN: Primær via R2 (metric 100), Backup via R3 (metric 200):
sudo ip route add 192.168.10.0/24 via 10.1.24.2 dev ens4 metric 100
sudo ip route append 192.168.10.0/24 via 10.1.34.3 dev ens5 metric 200

# Deaktiver strict reverse path filtering for asymmetrisk svar:
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.ens4.rp_filter=0
sudo sysctl -w net.ipv4.conf.ens5.rp_filter=0

# Start HTTP webserver til Del 11:
python3 -m http.server 80 &
```

---

## Del 2 – Grundlæggende Routing & Floating Static Route

### Konfiguration på R1
Den primære rute peger på R2 med standard Administrative Distance (AD 1). Backup-ruten konfigureres som en *Floating Static Route* med en højere AD (AD 200):

```cisco
! Primær rute via R2 (AD = 1):
ip route 0.0.0.0 0.0.0.0 10.1.12.2

! Backup rute via R3 (AD = 200):
ip route 0.0.0.0 0.0.0.0 10.1.13.3 200
```

### Verifikation af routingtabel under normal drift:
```cisco
R1# show ip route static
Codes: S - static, ...
Gateway of last resort is 10.1.12.2 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.1.12.2
```
*Observation:* Ruten via R3 fremgår ikke af routingtabellen, fordi Cisco IOS altid foretrækker den rute, der har den laveste Administrative Distance.

---

## Del 3 – Test af Direkte Linkfejl

En kontinuerlig ping startes fra LAN-klienten mod `172.16.1.1`:
```bash
ping 172.16.1.1 -t
```

På R1 lukkes interfacet mod R2:
```cisco
R1(config)# interface GigabitEthernet0/1
R1(config-if)# shutdown
```

### Observation:
```cisco
%LINK-5-CHANGED: Interface GigabitEthernet0/1, changed state to administratively down
%LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet0/1, changed state to down

R1# show ip route static
Gateway of last resort is 10.1.13.3 to network 0.0.0.0

S*    0.0.0.0/0 [200/0] via 10.1.13.3
```
Da linket går fysisk ned, trækker routerens Routing Information Base (RIB) automatisk ruten via 10.1.12.2 ud. Backup-ruten [200/0] installeres øjeblikkeligt. Ping genetableres efter 1-2 tabte pakker.

Når interfacet genaktiveres (`no shutdown`), installeres ruten med AD 1 igen.

---

## Del 4 – Fejl Længere Ude i Netværket (Det Blinde Punkt)

Nu simuleres en upstream-fejl ved at lukke forbindelsen **efter R2 mod destinationen**:
```cisco
R2(config)# interface GigabitEthernet0/0
R2(config-if)# shutdown
```

### Kontrol på R1:
```cisco
R1# show ip interface brief
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet0/0     192.168.10.1    YES NVRAM  up                    up      
GigabitEthernet0/1     10.1.12.1       YES NVRAM  up                    up      
GigabitEthernet0/2     10.1.13.1       YES NVRAM  up                    up      

R1# show ip route static
Gateway of last resort is 10.1.12.2 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.1.12.2
```

### Resultat:
- R1's interface `Gi0/1` er fortsat **UP/UP**.
- Ruten via `10.1.12.2` forbliver aktiv i routingtabellen.
- Ping fra klienten fejler med `Request timed out`!
- **Konklusion:** Almindelig statisk routing er blind over for upstream-fejl, og backup-vejen aktiveres aldrig.

*(Genaktiver herefter R2 Gi0/0 med `no shutdown`).*

---

## Del 5 – Opret Aktiv Test med Cisco IP SLA

R1 konfigureres til proaktivt at sende ICMP Echo anmodninger til testdestinationen `172.16.1.1`.

> ⚠️ **KRITISK DESIGNNOTE: Forebyggelse af Route Flapping Loop**
> Hvis testdestinationen (`172.16.1.1`) routes dynamisk via den fallback standardrute, vil IP SLA under en fejl pludselig begynde at sende sine testprober via backup-ruten (R3). Hvis destinationen kan nås via R3, vil IP SLA igen melde "SUCCESS", track bliver UP, den primære rute geninstalleres mod R2, hvorefter proberne igen fejler. Dette skaber et uendeligt flap-loop!
> 
> **Løsning:** Der konfigureres en specifik `/32` host-rute mod R2, så IP SLA proberne *udelukkende* kan transmitteres over den primære forbindelse.

### Konfiguration på R1:
```cisco
! 1. Fastlås rute til måledestinationen via den primære next-hop:
ip route 172.16.1.1 255.255.255.255 10.1.12.2

! 2. Opret IP SLA operation 10:
ip sla 10
 icmp-echo 172.16.1.1 source-interface GigabitEthernet0/1
 frequency 5
 timeout 2000
 threshold 2000
exit

! 3. Start overvågningen:
ip sla schedule 10 life forever start-time now
```

### Verifikation under normal drift:
```cisco
R1# show ip sla statistics 10
IPSLAs Latest Operation Statistics
IPSLA operation id: 10
    Type of operation: icmp-echo
        Latest RTT: 2 milliseconds
        Latest operation start time: 14:02:11 UTC
        Latest operation return code: OK
        Number of successes: 24
        Number of failures: 0
        Operation time to live: Forever
```

---

## Del 6 – Test af IP SLA under Fejl (UP vs. FAIL)

Vi afbryder igen forbindelsen efter R2:
```cisco
R2(config)# interface GigabitEthernet0/0
R2(config-if)# shutdown
```

### Sammenligning på R1:

#### 1. Fysisk/Logisk lag:
```cisco
R1# show ip interface brief Gi0/1
Interface              IP-Address      OK? Method Status   Protocol
GigabitEthernet0/1     10.1.12.1       YES NVRAM  up       up      
```
👉 Interfacet er fortsat **UP/UP**.

#### 2. Aktiv overvågning (IP SLA):
```cisco
R1# show ip sla statistics 10
IPSLAs Latest Operation Statistics
IPSLA operation id: 10
    Type of operation: icmp-echo
        Latest RTT: NoConnection/Busy/Timeout
        Latest operation start time: 14:04:16 UTC
        Latest operation return code: Timeout
        Number of successes: 24
        Number of failures: 6
        Operation time to live: Forever
```
👉 IP SLA registrerer øjeblikkeligt fejlen og melder **Timeout / FAIL**.

*(Genaktiver linket på R2 med `no shutdown`).*

---

## Del 7 – Object Tracking med Dampening/Hysterese

For at routingtabellen kan reagere på IP SLA målingen, oprettes et tracking-objekt. Der tilføjes en `delay` for at undgå rute-flapping ved transiente udfald.

### Konfiguration på R1:
```cisco
track 10 ip sla 10 reachability
 delay down 10 up 15
exit
```
- `delay down 10`: Routeren venter 10 sekunder med gentagne fejl, før track sættes til DOWN. Dette forhindrer falsk alarm ved enkelte tabte pakker.
- `delay up 15`: Når forbindelsen genetableres, venter routeren 15 sekunder på en stabil forbindelse, før track sættes til UP.

### Verifikation af tracking status:
```cisco
R1# show track 10
Track 10
  IP SLA 10 reachability
  Reachability is Up
  1 change, last change 00:05:22
  Delay up 15 secs, down 10 secs
  Latest sub-oper state: OK
```

Når fejlen på R2 fremkaldes, ændrer status sig:
```text
%TRACKING-5-STATE: 10 ip sla 10 reachability Up->Down
```

---

## Del 8 – Knyt Tracking til Routing

Den primære default route bindes nu op på `track 10`:

```cisco
! Fjern den utracked primære rute:
no ip route 0.0.0.0 0.0.0.0 10.1.12.2

! Indsæt primær rute med tracking:
ip route 0.0.0.0 0.0.0.0 10.1.12.2 track 10

! Sikr at backup-ruten er til stede med AD 200:
ip route 0.0.0.0 0.0.0.0 10.1.13.3 200
```

### Routingtabel under normal drift:
```cisco
R1# show ip route static
Gateway of last resort is 10.1.12.2 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.1.12.2
```

---

## Del 9 – Test af Automatisk Failover

1. Klienten pinger kontinuerligt: `ping 172.16.1.1 -t`.
2. På R2 lukkes interfacet mod R4:
   ```cisco
   R2(config)# interface GigabitEthernet0/0
   R2(config-if)# shutdown
   ```

### Hændelseskæde på R1:
```text
1. IP SLA 10 registrerer manglende ICMP Echo svar (Timeout)
   ↓
2. Efter 10 sekunder skifter Track 10:
   %TRACKING-5-STATE: 10 ip sla 10 reachability Up->Down
   ↓
3. Cisco RIB invaliderer ruten "0.0.0.0/0 via 10.1.12.2"
   ↓
4. Den flydende rute med AD 200 installeres automatisk i FIB/RIB
```

### Verifikation af routingtabellen under failover:
```cisco
R1# show ip route static
Gateway of last resort is 10.1.13.3 to network 0.0.0.0

S*    0.0.0.0/0 [200/0] via 10.1.13.3
```

**Resultat:** Klientens pingtab begrænses til ca. 2-3 pakker under transitionen, hvorefter trafikken flyder fejlfrit igennem backup-routeren R3!

---

## Del 10 – Test af Automatisk Recovery

1. Forbindelsen på R2 genetableres:
   ```cisco
   R2(config)# interface GigabitEthernet0/0
   R2(config-if)# no shutdown
   ```

### Hændelseskæde på R1:
```text
1. IP SLA 10 modtager igen ICMP Reply (Return Code: OK)
   ↓
2. Track 10 starter timer "delay up 15" for at sikre linkstabilitet
   ↓
3. Efter 15 sekunder skifter Track 10:
   %TRACKING-5-STATE: 10 ip sla 10 reachability Down->Up
   ↓
4. Den primære rute via 10.1.12.2 (AD 1) genindsættes
   ↓
5. Backup-ruten via 10.1.13.3 (AD 200) fortrænges til standby
```

### Verifikation:
```cisco
R1# show ip route static
Gateway of last resort is 10.1.12.2 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.1.12.2
```
Trafikken vender helt automatisk og transparent tilbage til den primære højhastighedsforbindelse.

---

## Del 11 – Service-monitorering: TCP Connect vs. ICMP Echo

### Teoretisk Sammenligning

| Parameter | ICMP Echo (Ping) | TCP Connect |
| :--- | :--- | :--- |
| **OSI-lag** | Layer 3 (Network) | Layer 4 (Transport) / Layer 7 (Application) |
| **Mekanisme** | Sender ICMP Type 8 (Echo Request) | Udfører fuldt TCP 3-way handshake (SYN ➔ SYN-ACK ➔ ACK) |
| **Hvad testes?** | Om IP-stakken og routingvejen er aktiv | Om den specifikke applikationsproces (f.eks. Nginx, IIS, HTTP) lytter og svarer på porten |
| **Svaghed** | Serveren kan svare på ping, selvom webserveren er crashet | Kræver at destinationen har en aktiv TCP-tjeneste kørende |

### Konfiguration på R1 (TCP Port 80 Check):
```cisco
ip sla 20
 tcp-connect 172.16.1.1 80 source-ip 10.1.12.1
 threshold 2000
 timeout 2000
 frequency 5
exit
ip sla schedule 20 life forever start-time now
```
*(Bemærk: I Cisco IOS valideres parametrene i realtid mod reglen `Frequency >= Timeout >= Threshold`. Da standard-timeout for TCP er 60 sekunder, skal `threshold` og `timeout` sættes ned før `frequency 5` kan accepteres).*
### Testscenarie:
På R4 deaktiveres HTTP-tjenesten:
```cisco
R4(config)# no ip http server
```

**Observeret resultat på R1:**
- `show ip sla statistics 10` (ICMP Echo): **Return code: OK** (Serveren svarer stadig på ping).
- `show ip sla statistics 20` (TCP Connect): **Return code: Connection refused / Timeout** (Applikationen er nede!).

Dette demonstrerer fordelen ved Layer 4/7 monitorering, hvis virksomhedens forretningskritiske applikation er en webservice.

---

## Del 12 – Performance & RTT Målinger

Cisco IP SLA indsamler løbende Round Trip Time (RTT) data i millisekunder:

```cisco
R1# show ip sla statistics 10
    Type of operation: icmp-echo
        Latest RTT: 2 milliseconds
        Round Trip Time (RTT) for Index 10
                Latest RTT: 2 ms
                Latest Operation Result: OK
```

### Simulering af degraderet linje i GNS3:
I GNS3 indsættes kunstig forsinkelse og jitter på linket R1–R2 via link-egenskaber:
- **Delay:** `150 ms`
- **Packet Loss:** `10 %`

### Måling efter ændring:
```cisco
R1# show ip sla statistics 10
    Type of operation: icmp-echo
        Latest RTT: 154 milliseconds
        Latest Operation Result: OK
```

### Konklusion på Del 12:
Selvom forbindelsen er **UP/UP** og destinationen er **REACHABLE**, kan brugeroplevelsen være ubrugelig på grund af høj latency eller pakketab.
Med Cisco IP SLA kan man benytte `ip sla reaction-configuration` til at udløse et skifte, hvis RTT overstiger en fastsat tærskelværdi (f.eks. > 100 ms).

---

## Del 13 – Samlet Teknisk Dokumentation (Afleveringsrapport)

### Dokumenteret Sammenhæng

```text
+-------------------------------------------------------------+
|                     AKTIV OVERVÅGNING                       |
|  R1 sender periodiske ICMP / TCP testprober mod 172.16.1.1  |
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|                     CISCO IP SLA 10                         |
|  Evaluerer svaret: OK (Success) eller Timeout (Failure)     |
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|                   OBJECT TRACKING 10                        |
|  Status UP hvis SLA er OK; DOWN hvis SLA fejler             |
|  Indbygget dampening delay (down 10s, up 15s) mod flapping  |
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|                      ROUTINGTABEL                           |
|  ip route 0.0.0.0 0.0.0.0 10.1.12.2 track 10               |
|  ip route 0.0.0.0 0.0.0.0 10.1.13.3 200                    |
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|                  AUTOMATISK FAILOVER                        |
|  Track UP   ➔ Primær rute (AD 1 via R2) er aktiv           |
|  Track DOWN ➔ Primær rute fjernes ➔ Backup rute (AD 200)   |
+-------------------------------------------------------------+
```

### Komplette Konfigurationsfiler og Scripts
De fuldstændige konfigurationer og scripts er placeret i mappen `konfigurationer/`:
- **[R1.cfg](./konfigurationer/R1.cfg)** (Cisco Edge Router med IP SLA 10/20, Object Tracking og Floating Route)
- **[R2.cfg](./konfigurationer/R2.cfg)** (Cisco Primær Transit Router)
- **[R3.cfg](./konfigurationer/R3.cfg)** (Cisco Backup Transit Router)
- **[server_linux.sh](./konfigurationer/server_linux.sh)** (Linux Server: dual-homed `ens4`/`ens5`, `lo: 172.16.1.1`, rp_filter fix & HTTP server)
- **[client_linux.sh](./konfigurationer/client_linux.sh)** (Linux Client: `ens4` IP og default gateway)
- **[R4_server.cfg](./konfigurationer/R4_server.cfg)** (Alternativ Cisco IOS konfiguration hvis serveren i stedet bygges som Cisco router)
