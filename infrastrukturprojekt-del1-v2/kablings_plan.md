# Fysisk Kablingsplan (v2)

Dette dokument indeholder den fulde fysiske kablingsplan for **Infrastrukturprojekt – Del 1 (v2)**. Kablingsplanen beskriver præcist, hvilke kabler der skal trækkes mellem din **Dell PowerEdge R630**, de to **FortiGates**, **Cisco 4331 WAN-routeren** og dine **switche** i labbet for at sikre fuldstændig redundans uden single points of failure (SPOF).

---

## 1. Overordnet Netværkskablings-Logik

For at forbinde det redundante **FortiGate HA Cluster (Active/Passive)** til den **enkelte Cisco 4331 WAN-router**, anvender vi en yderst professionel direkte forbindelsesmodel:
*   Vi fjerner WAN-trafikken fuldstændigt fra dine Cisco 2960X access-switche.
*   I stedet konfigureres et Layer 2 **Bridge Domain Interface (`BDI1`)** direkte på Cisco 4331 WAN-routeren.
*   Dette omdanner routerens to ydre porte, **`GigabitEthernet0/0/0`** og **`GigabitEthernet0/0/2`**, til en integreret software-switch, som derved tillader, at den aktive FortiGate altid har Layer 2 forbindelse til routeren under et failover, helt uden eksternt switchudstyr.

---

## 2. Detaljeret Kablings-Tabel

Brug denne tabel som din direkte tjekliste, når du står i serverrummet eller labbet og skal forbinde udstyret:

| Kilde Enhed | Kilde Port | Destination Enhed | Destination Port | Kabeltype | Funktion / VLAN | Noter |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **wan-rt01** (4331) | `Gi0/0/0` | **fg-ha-01** (FG60F) | `wan1` | Cat6 RJ45 (Grå) | Direkte WAN Link 1 | Direkte WAN link til primær firewall (BDI bridged på router) |
| **wan-rt01** (4331) | `Gi0/0/2` | **fg-ha-02** (FG60F) | `wan1` | Cat6 RJ45 (Grå) | Direkte WAN Link 2 | Direkte WAN link til sekundær firewall (BDI bridged på router) |
| **fg-ha-01** (FG60F) | `a` | **fg-ha-02** | `a` | Cat6 RJ45 (Rød) | Heartbeat 1 (HA Sync)| HA synkroniserings-kabel (Fysisk FortiLink Port A) |
| **fg-ha-01** (FG60F) | `b` | **fg-ha-02** | `b` | Cat6 RJ45 (Rød) | Heartbeat 2 (HA Sync)| Sekundært HA synkroniserings-kabel (Fysisk FortiLink Port B) |
| **fg-ha-01** (FG60F) | `port4` | **core-sw01** | `Gi1/1/1` | Cat6 RJ45 (Blå) | VLAN 101 (Int. Transit)| Forbinder primær firewall til Core 1 |
| **fg-ha-02** (FG60F) | `port4` | **core-sw02** | `Gi1/1/1` | Cat6 RJ45 (Blå) | VLAN 101 (Int. Transit)| Forbinder sekundær firewall to Core 2 |
| **fg-ha-01** (FG60F) | `port1` | **acc-sw01** | `Gi0/23` | Cat6 RJ45 (Gul) | VLAN 99 (Management) | administrationsadgang til primær firewall |
| **fg-ha-02** (FG60F) | `port1` | **acc-sw02** | `Gi0/23` | Cat6 RJ45 (Gul) | VLAN 99 (Management) | administrationsadgang til sekundær firewall |
| **core-sw01** (3650) | `Gi1/1/2` | **core-sw02** | `Gi1/1/2` | Cat6 RJ45 (Blå) | L3 Inter-Core Link | Routing synkronisering mellem Core-switche |
| **core-sw01** (3650) | `Gi1/0/23` | **core-sw02** | `Gi1/0/23` | Cat6 RJ45 (Gul) | VLAN 99/101 L2 Link | Backup sti for inter-core Layer 2 trafik |
| **core-sw01** (3650) | `Gi1/0/24` | **core-sw02** | `Gi1/0/24` | Cat6 RJ45 (Gul) | VLAN 99/101 L2 Link | Sekundær backup sti for L2 trafik |
| **core-sw01** (3650) | `Gi1/0/1` | **acc-sw01** | `Gi0/49` | Cat6 RJ45 (Blå) | Trunk (EtherChannel Po1)| LACP Trunk core-sw01 til acc-sw01 |
| **core-sw02** (3650) | `Gi1/0/1` | **acc-sw01** | `Gi0/50` | Cat6 RJ45 (Blå) | Trunk (EtherChannel Po1)| LACP Trunk core-sw02 til acc-sw01 |
| **core-sw01** (3650) | `Gi1/0/2` | **acc-sw02** | `Gi0/49` | Cat6 RJ45 (Blå) | Trunk (EtherChannel Po1)| LACP Trunk core-sw01 til acc-sw02 |
| **core-sw02** (3650) | `Gi1/0/2` | **acc-sw02** | `Gi0/50` | Cat6 RJ45 (Blå) | Trunk (EtherChannel Po1)| LACP Trunk core-sw02 til acc-sw02 |
| **acc-sw01** (2960) | `Gi0/47` | **acc-sw02** | `Gi0/47` | Cat6 RJ45 (Grøn) | Trunk (Inter-Access)| L2 synkronisering mellem Access-switche |
| **acc-sw01** (2960) | `Gi0/48` | **acc-sw02** | `Gi0/48` | Cat6 RJ45 (Grøn) | Trunk (Inter-Access)| Sekundær synkronisering Access-switche |
| **core-sw01** (3650) | `Te1/0/1` | **Dell R630** | `eno1` (10G Port 1) | Cat6a RJ45 (Sort) | Kunde VLAN Trunk | LACP 10G Data-Trunk til Proxmox (vmbr0) |
| **core-sw02** (3650) | `Te1/0/1` | **Dell R630** | `eno2` (10G Port 2) | Cat6a RJ45 (Sort) | Kunde VLAN Trunk | LACP 10G Data-Trunk til Proxmox (vmbr0) |
| **acc-sw01** (2960) | `Gi0/10` | **Dell R630** | `eno3` (1G Port 3) | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Active-Backup Mgmt Link til Proxmox Host |
| **acc-sw02** (2960) | `Gi0/10` | **Dell R630** | `eno4` (1G Port 4) | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Active-Backup Mgmt Link til Proxmox Host |
| **acc-sw01** (2960) | `Gi0/12` | **Dell R630** | `iDRAC port` | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Out-of-band konsol og hardware monitorering |
| **acc-sw01** (2960) | `Gi0/15` | **Admin-PC** | RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 99 (Management) | Din administrations computer |
| **acc-sw01** (2960) | `Gi0/1` | **Alfa-PC** | RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 10 (Kunde Alfa) | Klient-pc til test af Kunde Alfa |
| **acc-sw01** (2960) | `Gi0/2` | **Bravo-PC**| RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 20 (Kunde Bravo)| Klient-pc til test af Kunde Bravo |

---

## 3. Farvekodnings-anbefaling i dit Rack

For at gøre fejlfinding og vedligeholdelse ekstremt let og overskueligt, anbefales det at følge denne farvestandard for patchkablerne:
*   🔴 **Røde kabler:** HA Heartbeat (FG60F synkronisering). Må aldrig flyttes eller pilles ud under drift.
*   ⚪ **Hvide kabler:** Klient-forbindelser (pc'er til test).
*   🟡 **Gule kabler:** Management-netværk (VLAN 99), herunder switch SVI'er, iDRAC og Proxmox Host Management IP.
*   🔵 **Blå kabler:** Inter-switch links, trunks, og transitnetværk (VLAN 101) mellem firewall og switche.
*   ⚫ **Sorte kabler:** High-speed 10 Gbit/s kobber (Cat6a/Cat7) mellem Proxmox-værtens NDC og Core-switchene.
*   🟢 **Grønne kabler:** Inter-Access switch links for at synkronisere Spanning Tree og L2 VLANs.
*   ⚙️ **Grå kabler:** Direkte WAN-forbindelser (mellem router og firewalls).
