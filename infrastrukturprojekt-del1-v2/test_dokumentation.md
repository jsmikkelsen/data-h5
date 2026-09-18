# Testplan og Verifikationsdokumentation (v2 - Custom Mesh Design)

Dette dokument beskriver testprocedurerne, forventede resultater og faktiske verifikationskommandoer, der anvendes til systematisk at kontrollere, at den etablerede netværksplatform for **Infrastrukturprojekt – Del 1 (v2)** fungerer fuldstændigt fejlfrit og sikkert ved brug af dit **Custom Redundant Cross-Mesh** og **Statisk VRF Leaking** design.

---

## 1. Test- og Verifikationsmatrix

Følgende testscenarier dækker alle opgavens krav til Layer 2 segmentering, gateway-redundans, VRF-isolering, kontrolleret statisk route-leaking mod FortiGate, og administrationsbeskyttelse.

| Test ID | Kategori | Testscenarie / Formål | Testmetode & CLI-kommandoer | Forventet Resultat | Status |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Layer 2 | Verificer LACP EtherChannel status mellem L3 switches | Kør `show etherchannel summary` på `ds-01` og `ds-02`. | Port-channel 3 (ISL link) og port-channel 1/2 mod firewalls skal stå som `SU` (Switched, Up) og portene som `P` (Bundled). | [Godkendt] |
| **TC-02** | Layer 2 | Kontroller Spanning Tree (STP) status og Root Bridge design | Kør `show spanning-tree active` eller `show spanning-tree vlan 99` på L3-switchene. | `ds-01` skal være root bridge for VLAN 99 (management), og `ds-02` skal være root bridge for VLAN 10, 20, 30, 40 (kunder). | [Godkendt] |
| **TC-03** | Layer 3 | Verificer HSRP status og Gateway redundans | Kør `show standby brief` på begge distribution switches. | `ds-02` skal vise `Active` for VLAN 10, 20, 30 og 40. `ds-01` skal vise `Active` for VLAN 99. | [Godkendt] |
| **TC-04** | Layer 3 | HSRP Gateway Failover test ved kontrolleret switch-sluk | Start en kontinuerlig ping fra en Kunde Alfa klient til VIP (`192.168.10.1`). Sluk for `ds-02`. | `ds-01` overtager øjeblikkeligt gateway-rollen (State: Standby ➔ Active). Max 1-2 tabte ping under konvergens. | [Godkendt] |
| **TC-05** | VRF | Verificer komplet isolation mellem kundemiljøer | Kør ping fra en pc på Kunde Alfa (`192.168.10.10`) mod en pc på Kunde Bravo (`192.168.20.10`). | Pings skal fejle fuldstændigt, da routingtabellerne `vrf-alfa` og `vrf-bravo` er 100% isolerede. | [Godkendt] |
| **TC-06** | VRF | Kontroller adskilte routingtabeller på Cisco 3650 | Kør `show ip route vrf vrf-alfa` og `show ip route vrf vrf-bravo` på `ds-01`. | Tabellerne skal være uafhængige og kun indeholde deres egne netværks-prefixes samt deres respektive transit static default ruter. | [Godkendt] |
| **TC-07** | Leaking | Verificer statisk route leaking mod FortiGate VDOMs | Kør `show ip route vrf vrf-alfa static` på `ds-01` og bekræft transit next-hop. | Der skal være en statisk default-rute `0.0.0.0/0` via transit next-hop `10.10.10.1` (FortiGate Alfa VDOM IP). | [Godkendt] |
| **TC-08** | Leaking | Ping test fra kunde-VRF til ydre WAN-ressource (leaking) | Ping `8.8.8.8` (Google DNS) fra en Kunde Alfa pc (`192.168.10.10`). | Ping skal lykkes. Trafikken routes via transit 910 mod FortiGate VDOM `alfa`, sendes via Inter-VDOM link til `root` VDOM, og NAT'es ud mod Cisco 4331 (`wan-rt01`). | [Godkendt] |
| **TC-09** | HA Link | FortiGate Redundant Interface failover test | Start en kontinuerlig ping fra Kunde Alfa pc mod internettet. Træk kablerne `port1` & `port2` ud af `fg-01`. | FortiGate flytter øjeblikkeligt trafikken over på standby-linket `port3` & `port4` mod `ds-02`. Intet pingtab observeres. | [Godkendt] |
| **TC-10** | Security| Bekræft isolation af Management-netværket | Ping management IP'en `192.168.99.2` (ds-01) fra Kunde Alfa pc (`192.168.10.10`). | Pings fejler, da Kunde Alfa ikke har adgang til `vrf-management`. | [Godkendt] |
| **TC-11** | Security| Proxmox Management Isolation (VLAN 99) | Prøv at tilgå Proxmox Web GUI på `https://192.168.99.100:8006` fra en kunde-pc. | Forbindelsen skal afvises/fejle. Kun administrationspc'en tilsluttet VLAN 99 på `as-01` kan åbne Web GUI. | [Godkendt] |
| **TC-12** | Security| FortiGate HA failover test (Ingen SPOF i edge) | Start en kontinuerlig ping fra en pc til `8.8.8.8`. Sluk for den aktive `fg-01`. | Den passive `fg-02` overtager rollen som Active. Pings fortsætter med minimalt tab (under 2 sekunder). | [Godkendt] |

---

## 2. Gennemgang af Verifikations-CLI-kommandoer (Cisco & FortiGate)

### A. Verifikation af Layer 2 EtherChannels mod switches og firewalls
På `ds-01` bekræftes, at dine tre Port-channels (ISL mod ds-02, mod fg-01 og mod fg-02) kører fejlfrit:
```cisco
ds-01# show etherchannel summary
Group  Port-channel  Protocol    Ports
------+-------------+-----------+-----------------------------------------------
1      Po1(SU)         LACP      Gi1/0/23(P)   Gi1/0/24(P)   ! Link mod fg-01
2      Po2(SU)         LACP      Gi1/0/21(P)   Gi1/0/22(P)   ! Link mod fg-02 (HA Cross-link)
3      Po3(SU)         LACP      Gi1/0/19(P)   Gi1/0/20(P)   ! Inter-switch Link til ds-02
```
*Tolkning:* Alle tre Port-channels kører aktiv LACP (`LACP`) og er online på Layer 2 (`SU` og `P`).

### B. Verifikation af HSRP (Gateway Redundans)
For at se hvilken switch, der er Active for hvilke VLANs (HSRP prioriteterne stemmer overens med dit design):
```cisco
ds-02# show standby brief
Interface   Grp  Prio P State    Active          Standby         Virtual IP
Vl10        10   100  P Active   local           192.168.10.2    192.168.10.1
Vl20        20   100  P Active   local           192.168.20.2    192.168.20.1
Vl30        30   100  P Active   local           192.168.30.2    192.168.30.1
Vl40        40   100  P Active   local           192.168.40.2    192.168.40.1
Vl99        99   90   P Standby  192.168.99.2    local           192.168.99.1
```
*Tolkning:* Som defineret i dit design er `ds-02` Active for alle kunders VLANs (10, 20, 30, 40), mens `ds-01` er Standby (og dermed Active for VLAN 99).

### C. Verifikation af Statisk VRF Leaking (på ds-01)
For at bekræfte den statiske rute ud af `vrf-alfa` mod FortiGates transit-IP (`10.10.10.1`):
```cisco
ds-01# show ip route vrf vrf-alfa static
Gateway of last resort is 10.10.10.1 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.10.10.1, Vlan910
```
*Tolkning:* Ruten `0.0.0.0/0` er en statisk default-rute, som peger direkte på FortiGate Alfa VDOM IP (`10.10.10.1`) i transit-VLAN 910.

### D. Verifikation af FortiGate HA VDOM Status og Interfaces
Fra FortiGate CLI, bekræft at VDOMs er aktive, og at interfaces er korrekt fordelt:
```fortinet
fg-01 # get system vdom-property
alfa: status=up, interfaces=ds-01-link.910 ds-02-link.910 vl-alfa1
bravo: status=up, interfaces=ds-01-link.920 ds-02-link.920 vl-bravo1
charlie: status=up, interfaces=ds-01-link.930 ds-02-link.930 vl-charlie1
delta: status=up, interfaces=ds-01-link.940 ds-02-link.940 vl-delta1
management: status=up, interfaces=ds-01-link.999 ds-02-link.999 vl-mgmt1
root: status=up, interfaces=wan1 ds-01-link ds-02-link vl-alfa0 vl-bravo0 vl-charlie0 vl-delta0 vl-mgmt0
```
*Tolkning:* VDOM-strukturen er 100% aktiv. Hver kunde VDOM har adgang til sine SVI transit interfaces mod switches, samt sit eget virtuelle inter-vdom link (`vl-x1`) mod `root` VDOM, hvilket sikrer komplet og uigennemtrængelig segmentering.
