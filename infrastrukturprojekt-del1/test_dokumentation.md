# Testplan og Verifikationsdokumentation

Dette dokument beskriver testprocedurerne, forventede resultater og faktiske verifikationskommandoer, der anvendes til systematisk at kontrollere, at den etablerede netværksplatform for **Infrastrukturprojekt – Del 1** fungerer fuldstændigt fejlfrit og sikkert.

---

## 1. Test- og Verifikationsmatrix

Følgende testscenarier dækker alle opgavens krav til Layer 2 segmentering, gateway-redundans, VRF-isolering, kontrolleret route-leaking, management-beskyttelse og edge-failover.

| Test ID | Kategori | Testscenarie / Formål | Testmetode & CLI-kommandoer | Forventet Resultat | Status |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Layer 2 | Verificer LACP EtherChannel status mellem Core og Access | Kør `show etherchannel summary` på `core-sw01` og `acc-sw01`. | Port-channel status skal vise `SU` (Switched, Up) og de fysiske porte skal vise `P` (In Port-channel). | [Godkendt] |
| **TC-02** | Layer 2 | Kontroller Spanning Tree (STP) status og Root Bridge design | Kør `show spanning-tree active` eller `show spanning-tree vlan 10` på Core-switchene. | `core-sw01` skal være root bridge for VLAN 10, 20 og 99. `core-sw02` for VLAN 30 og 40. | [Godkendt] |
| **TC-03** | Layer 3 | Verificer HSRP status og Gateway redundans | Kør `show standby brief` på begge Core switches. | `core-sw01` skal vise `Active` for VLAN 10 og 20, og `Standby` for VLAN 30 og 40. `core-sw02` omvendt. | [Godkendt] |
| **TC-04** | Layer 3 | HSRP Failover test ved kontrolleret linkafbrydelse | Start en kontinuerlig ping fra en Kunde A klient til VIP (`10.10.0.1`). Deaktiver port `Gi1/1/1` (uplink) på `core-sw01`. | Port tracking slår igennem. `core-sw01` dekrementerer sin prioritet. `core-sw02` overtager rollen som active gateway. Max 1-2 tabte ping. | [Godkendt] |
| **TC-05** | VRF | Verificer komplet isolation mellem kundemiljøer | Kør ping fra en pc på Kunde A (`10.10.0.10`) mod en pc på Kunde B (`10.20.0.10`). | Pings skal fejle fuldstændigt, da routingtabellerne `VRF_A` og `VRF_B` er isolerede. | [Godkendt] |
| **TC-06** | VRF | Kontroller adskilte routingtabeller på Cisco 3650 | Kør `show ip route vrf VRF_A` og `show ip route vrf VRF_B`. | Tabellerne skal være uafhængige og kun indeholde deres egne netværks-prefixes. | [Godkendt] |
| **TC-07** | Leaking | Verificer route leaking til Global Routing Table (GRT) | Kør `show ip route vrf VRF_A` og kontroller tilstedeværelsen af default-routen mod GRT. | Der skal være en rute til `0.0.0.0/0` via Global/Transit-IP (`10.255.101.1`). | [Godkendt] |
| **TC-08** | Leaking | Ping test fra kunde-VRF til ydre WAN-ressource (leaking) | Ping `8.8.8.8` (Cisco 4331 Loopback) fra en Kunde A pc (`10.10.0.10`). | Ping skal lykkes. Trafikken sendes ud af VRF'en, ud via GRT mod FortiGate, som NAT'er trafikken mod 4331. | [Godkendt] |
| **TC-09** | Leaking | Verificer at route leaking IKKE bryder isolation mellem kunder | Ping fra pc på Kunde A (`10.10.0.10`) mod Kunde B (`10.20.0.10`) efter leaking er aktiveret. | Pings skal fortsat fejle. Kun trafik til GRT/WAN må lækkes, ikke direkte mellem VRF'erne. | [Godkendt] |
| **TC-10** | Security| Bekræft isolation af Management-netværket | Ping management IP'en `10.99.0.2` (core-sw01) fra Kunde A pc (`10.10.0.10`). | Pings fejler, da Kunde A ikke har adgang til `VRF_MGMT`. | [Godkendt] |
| **TC-11** | Security| SSH VTY adgangsbegrænsning (Access-List test) | Prøv at SSH til `core-sw01` fra en ikke-autoriseret IP (eller en anden kunde-VRF). | Forbindelsen skal afvises/times ud af switchens vty access-list. | [Godkendt] |
| **TC-12** | Security| FortiGate HA failover test (Ingen SPOF i edge) | Start en kontinuerlig ping fra en pc til `8.8.8.8`. Genstart den aktive FortiGate 60F. | Den passive FortiGate overtager trafikken umiddelbart. Pings fortsætter med minimalt tab (under 2 sekunder). | [Godkendt] |

---

## 2. Gennemgang af Verifikations-CLI-kommandoer (Cisco & FortiGate)

Følgende output-eksempler viser, hvad en systemadministrator skal se i terminalen ved korrekt konfiguration:

### A. Verifikation af Layer 2 EtherChannel
På `core-sw01` køres kommandoen for at bekræfte LACP-bundling:
```cisco
core-sw01# show etherchannel summary
Flags:  D - down        P - bundled in port-channel
        I - stand-alone s - suspended
        H - Hot-standby (LACP only)
        R - Layer3      S - Layer2
        U - in use      N - not in use
------------------------------------------------------------------------------
Group  Port-channel  Protocol    Ports
------+-------------+-----------+-----------------------------------------------
1      Po1(SU)         LACP      Gi1/0/1(P)   Gi1/0/2(P)
```
*Tolkning:* Flagene `SU` og `P` indikerer, at EtherChannel kører fejlfrit på Layer 2.

### B. Verifikation af HSRP (Gateway Redundans)
For at se hvilken switch, der er Active for hvilke VLANs:
```cisco
core-sw01# show standby brief
                     P indicates configured to preempt.
                     |
Interface   Grp  Prio P State    Active          Standby         Virtual IP
Vl10        10   110  P Active   local           10.10.0.3       10.10.0.1
Vl20        20   110  P Active   local           10.20.0.3       10.20.0.1
Vl30        30   100  P Standby  10.30.0.3       local           10.30.0.1
Vl40        40   100  P Standby  10.40.0.3       local           10.40.0.1
Vl99        99   110  P Active   local           10.99.0.3       10.99.0.1
```
*Tolkning:* Switchen er Active for VLAN 10, 20 og 99, men Standby for VLAN 30 og 40. Preempt er aktiveret (`P`).

### C. Verifikation af VRF Isolation (Adskilte routingtabeller)
For at se routingtabellen for en enkelt VRF (her Kunde A):
```cisco
core-sw01# show ip route vrf VRF_A

Routing Table: VRF_A
Gateway of last resort is 10.255.101.1 to network 0.0.0.0

B*    0.0.0.0/0 [200/0] via 10.255.101.1 (global), 00:14:22
C     10.10.0.0/24 is directly connected, Vlan10
L     10.10.0.2/24 is directly connected, Vlan10
```
*Tolkning:* Routingtabellen indeholder kun Kunde A's eget subnet (`10.10.0.0/24`) samt en default-rute (`0.0.0.0/0`) via Global Routing Table, som peger på FortiGate-firewallen (`10.255.101.1`). Den kan overhovedet ikke se Kunde B, C eller D's netværk.

### D. Verifikation af FortiGate HA Status
Fra FortiGate CLI bekræftes clustering-status:
```fortinet
fg-ha-cluster # get system ha status
HA Health Status: OK
Model: FortiGate-60F
Mode: a-p
Group: 1
HA Member Usage:
    fg-ha-01 (master): priority=200, status=up
    fg-ha-02 (slave): priority=100, status=up
```
*Tolkning:* Clusteret er sundt (`HA Health Status: OK`) og kører i Active/Passive (`a-p`). `fg-ha-01` er det aktive master-medlem på grund af dens højere prioritet.

### E. Trace af Trafikvej (Traceroute)
For at verificere trafikvejen fra Kunde A pc til WAN simulator (`8.8.8.8`):
```cmd
C:\Users\KundeA> tracert 8.8.8.8

Tracing route to 8.8.8.8 over a maximum of 30 hops:
  1    1 ms    1 ms    1 ms  10.10.0.1      (HSRP VIP på Cisco 3650)
  2    2 ms    1 ms    1 ms  10.255.101.1   (FortiGate Intern HA VIP)
  3    3 ms    2 ms    2 ms  10.255.200.2   (Cisco 4331 ISP Router Interface)
  4    4 ms    3 ms    3 ms  8.8.8.8        (Loopback interface på Cisco 4331)

Trace complete.
```
*Tolkning:* Trafikvejen er fuldstændig klar, dokumenteret og let at fejlfinde. Trafikken rammer HSRP-gatewayen på core-switchen, sendes ud af VRF'en via den lækkede route til FortiGate Edge-firewallen, og sendes herfra videre ud på internettet (WAN-routeren).
