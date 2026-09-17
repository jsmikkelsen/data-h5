# Testplan og Verifikationsdokumentation (v2 - Statisk VRF Leaking)

Dette dokument beskriver testprocedurerne, forventede resultater og faktiske verifikationskommandoer, der anvendes til systematisk at kontrollere, at den etablerede netværksplatform for **Infrastrukturprojekt – Del 1 (v2)** fungerer fuldstændigt fejlfrit og sikkert ved brug af **Statisk VRF Leaking**.

---

## 1. Test- og Verifikationsmatrix

Følgende testscenarier dækker alle opgavens krav til Layer 2 segmentering, gateway-redundans, VRF-isolering, kontrolleret statisk route-leaking, management-beskyttelse og edge-failover.

| Test ID | Kategori | Testscenarie / Formål | Testmetode & CLI-kommandoer | Forventet Resultat | Status |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Layer 2 | Verificer LACP EtherChannel status mellem Core og Access | Kør `show etherchannel summary` på `core-sw01` og `acc-sw01`. | Port-channel status skal vise `SU` (Switched, Up) og de fysiske porte skal vise `P` (In Port-channel). | [Godkendt] |
| **TC-02** | Layer 2 | Kontroller Spanning Tree (STP) status og Root Bridge design | Kør `show spanning-tree active` eller `show spanning-tree vlan 10` på Core-switchene. | `core-sw01` skal være root bridge for VLAN 10 (Alfa), 20 (Bravo) og 99 (Management). `core-sw02` for VLAN 30 (Charlie) og 40 (Delta). | [Godkendt] |
| **TC-03** | Layer 3 | Verificer HSRP status og Gateway redundans | Kør `show standby brief` på begge Core switches. | `core-sw01` skal vise `Active` for VLAN 10 og 20, og `Standby` for VLAN 30 og 40. `core-sw02` omvendt. | [Godkendt] |
| **TC-04** | Layer 3 | HSRP Failover test ved kontrolleret linkafbrydelse | Start en kontinuerlig ping fra en Kunde Alfa klient til VIP (`192.168.10.1`). Deaktiver port `Gi1/1/1` (uplink) på `core-sw01`. | Port tracking slår igennem. `core-sw01` dekrementerer sin prioritet. `core-sw02` overtager rollen som active gateway. Max 1-2 tabte ping. | [Godkendt] |
| **TC-05** | VRF | Verificer komplet isolation mellem kundemiljøer | Kør ping fra en pc på Kunde Alfa (`192.168.10.10`) mod en pc på Kunde Bravo (`192.168.20.10`). | Pings skal fejle fuldstændigt, da routingtabellerne `VRF_ALFA` og `VRF_BRAVO` er isolerede. | [Godkendt] |
| **TC-06** | VRF | Kontroller adskilte routingtabeller på Cisco 3650 | Kør `show ip route vrf VRF_ALFA` og `show ip route vrf VRF_BRAVO`. | Tabellerne skal være uafhængige og kun indeholde deres egne netværks-prefixes samt de statiske ruter. | [Godkendt] |
| **TC-07** | Leaking | Verificer statisk route leaking til Global Routing Table (GRT) | Kør `show ip route vrf VRF_ALFA static` på `core-sw01` og bekræft global next-hop. | Der skal være en statisk default-rute `0.0.0.0/0` via Global-Transit gateway (`192.168.101.1 global`). | [Godkendt] |
| **TC-08** | Leaking | Ping test fra kunde-VRF til ydre WAN-ressource (leaking) | Ping `8.8.8.8` (Cisco 4331 Loopback) fra en Kunde Alfa pc (`192.168.10.10`). | Ping skal lykkes. Trafikken matches af den statiske default-rute og routes ud via GRT til FortiGate, som derefter NAT'er mod WAN-routeren. | [Godkendt] |
| **TC-09** | Leaking | Verificer at route leaking IKKE bryder isolation mellem kunder | Ping fra pc på Kunde Alfa (`192.168.10.10`) mod Kunde Bravo (`192.168.20.10`) efter leaking er aktiveret. | Pings skal fortsat fejle. Kun trafik til GRT/WAN må routes via leaking, og der tillades ikke kryds-routing mellem VRF'erne. | [Godkendt] |
| **TC-10** | Security| Bekræft isolation af Management-netværket | Ping management IP'en `192.168.99.2` (core-sw01) fra Kunde Alfa pc (`192.168.10.10`). | Pings fejler, da Kunde Alfa ikke har adgang til `VRF_MGMT`. | [Godkendt] |
| **TC-11** | Security| Proxmox Management Isolation (VLAN 99) | Prøv at tilgå Proxmox Web GUI på `https://192.168.99.100:8006` fra Kunde Alfa pc. | Forbindelsen skal fejle fuldstændigt. Kun maskiner forbundet til VLAN 99 (Management) må kunne åbne siden. | [Godkendt] |
| **TC-12** | Security| FortiGate HA failover test (Ingen SPOF i edge) | Start en kontinuerlig ping fra en pc til `8.8.8.8`. Genstart den aktive FortiGate 60F. | Den passive FortiGate overtager trafikken umiddelbart. Pings fortsætter med minimalt tab (under 2 sekunder). | [Godkendt] |

---

## 2. Gennemgang af Verifikations-CLI-kommandoer (Cisco & FortiGate)

### A. Verifikation af Statisk VRF Route Leaking (Vej ud)
For at bekræfte, at Kunde Alfa har en statisk rute, der peger ud i Global Routing Table (GRT):
```cisco
core-sw01# show ip route vrf VRF_ALFA static
Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area 

S*    0.0.0.0/0 [1/0] via 192.168.101.1 (global)
```
*Tolkning:* Ruten `0.0.0.0/0` er en statisk default-rute, som peger på FortiGate-firewallen (`192.168.101.1`) i den globale routingtabel (`global`). Det bekræfter den statiske route leaking-mekanisme ud af VRF'en.

### B. Verifikation af Statisk VRF Route Leaking (Returrute ind)
For at bekræfte, at Global Routing Table ved, hvordan returtrafikken sendes ind i Kunde Alfas VRF:
```cisco
core-sw01# show ip route static | include VRF_ALFA
S     192.168.10.0/24 is directly connected, Vlan10 (vrf VRF_ALFA)
```
*Tolkning:* Ruten viser, at trafik til `192.168.10.0/24` (Kunde Alfas netværk) i Global Routing Table er mappet direkte til `Vlan10` interface i `VRF_ALFA`. Returtrafikken kan dermed routes sikkert og direkte tilbage til kunden.

### C. Verifikation af HSRP (Gateway Redundans)
```cisco
core-sw01# show standby brief
                     P indicates configured to preempt.
                     |
Interface   Grp  Prio P State    Active          Standby         Virtual IP
Vl10        10   110  P Active   local           192.168.10.3    192.168.10.1
Vl20        20   110  P Active   local           192.168.20.3    192.168.20.1
Vl30        30   100  P Standby  192.168.30.3    local           192.168.30.1
Vl40        40   100  P Standby  192.168.40.3    local           192.168.40.1
Vl99        99   110  P Active   local           192.168.99.3    192.168.99.1
```

### D. Verifikation af Proxmox Management Forbindelse (fra administrationspc i VLAN 99)
Fra din admin-pc i VLAN 99, bekræft ping mod Proxmox-værtens administrationsgrænseflade:
```cmd
C:\Users\Admin> ping 192.168.99.100

Pinging 192.168.99.100 with 32 bytes of data:
Reply from 192.168.99.100: bytes=32 time<1ms TTL=64
Reply from 192.168.99.100: bytes=32 time<1ms TTL=64

Ping statistics for 192.168.99.100:
    Packets: Sent = 2, Received = 2, Lost = 0 (0% loss)
```
*Tolkning:* Proxmox administrationsinterfacer er fuldt pingbare og klar til sikker administration på `https://192.168.99.100:8006`.
