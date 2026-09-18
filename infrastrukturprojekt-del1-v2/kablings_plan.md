# Fysisk Kablingsplan (v2 - Symmetrisk Mesh Design)

Dette dokument indeholder den komplette, fysiske kablingsplan for **Infrastrukturprojekt – Del 1 (v2)**, fuldt tilpasset dine switch-konfigurationer og enhedsport-allokeringer.

---

## 1. Hvorfor Symmetrisk Kabling er påkrævet til FortiGate HA

I et **FortiGate Active/Passive HA Cluster (FGCP)** synkroniseres konfigurationen **1:1** (100% identisk) mellem den aktive firewall (`fg-01`) og den passive firewall (`fg-02`). 

Hvis kablingen er asymmetrisk (f.eks. hvis `fg-01` bruger `port1/port2` mod `ds-01`, mens `fg-02` bruger `port1/port2` mod `ds-02`), vil der opstå kritiske IP- og routing-fejl ved et failover:
*   Når `fg-02` bliver aktiv, vil dens `port1/port2` (som i den synkroniserede konfiguration bærer `ds-01` transit-IP: `10.10.x.1`) fysisk være tilsluttet `ds-02`, som forventer subnet `10.9.x.x`! Trafikken vil derfor dø.

### Løsningen: Symmetrisk Cross-Mesh
For at få dit cross-mesh til at fungere fejlfrit med HA, kables begge firewalls **symmetrisk**:
1.  **Mod `ds-01`:** Både `fg-01` og `fg-02` tilsluttes `ds-01` via deres respektive **`port1`** og **`port2`**.
2.  **Mod `ds-02`:** Både `fg-01` og `fg-02` tilsluttes `ds-02` via deres respektive **`port3`** og **`port4`**.

Dette sikrer, at uanset hvilken firewall der er aktiv, vil logisk aggregate `bond-ds01` (port 1/2) altid ramme `ds-01`, og aggregate `bond-ds02` (port 3/4) vil altid ramme `ds-02`!

---

## 2. Detaljeret Symmetrisk Kablings-Tabel

| Kilde Enhed | Kilde Port | Destination Enhed | Destination Port | Kabeltype | Funktion / VLAN | Noter |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **wan-rt01** (4331) | `Gi0/0/2` | **Væg-stik / SkoleLAN** | RJ45 Internetstik | Cat6 RJ45 (Grå) | NAT Outside / Internet | Forbinder din WAN-router direkte til det rigtige internet |
| **wan-rt01** (4331) | `Gi0/0/0` | **fg-01** (FG60F) | `wan1` | Cat6 RJ45 (Hvid) | Direkte WAN Link 1 | Forbinder router direkte til fg-01 WAN1 |
| **wan-rt01** (4331) | `Gi0/0/1` | **fg-02** (FG60F) | `wan1` | Cat6 RJ45 (Hvid) | Direkte WAN Link 2 | Forbinder router direkte til fg-02 WAN1 |
| **fg-01** (FG60F) | `a` | **fg-02** (FG60F) | `a` | Cat6 RJ45 (Hvid) | Heartbeat 1 (HA Sync)| HA synkroniserings-kabel (Fysisk FortiLink Port A) |
| **fg-01** (FG60F) | `b` | **fg-02** (FG60F) | `b` | Cat6 RJ45 (Hvid) | Heartbeat 2 (HA Sync)| Sekundært HA synkroniserings-kabel (Fysisk FortiLink Port B) |
| **fg-01** (FG60F) | `port1` | **ds-01** (3650) | `Gi1/0/24` | Cat6 RJ45 (Gul) | Transit `ds-01` A | Primær firewall mod switch 1 |
| **fg-01** (FG60F) | `port2` | **ds-01** (3650) | `Gi1/0/23` | Cat6 RJ45 (Gul) | Transit `ds-01` B | Primær firewall mod switch 1 |
| **fg-02** (FG60F) | `port1` | **ds-01** (3650) | `Gi1/0/22` | Cat6 RJ45 (Gul) | Transit `ds-01` C | Sekundær firewall mod switch 1 (Rettet til Symmetrisk HA) |
| **fg-02** (FG60F) | `port2` | **ds-01** (3650) | `Gi1/0/21` | Cat6 RJ45 (Gul) | Transit `ds-01` D | Sekundær firewall mod switch 1 (Rettet til Symmetrisk HA) |
| **fg-01** (FG60F) | `port3` | **ds-02** (3650) | `Gi1/0/22` | Cat6 RJ45 (Rød) | Transit `ds-02` A | Primær firewall mod switch 2 |
| **fg-01** (FG60F) | `port4` | **ds-02** (3650) | `Gi1/0/21` | Cat6 RJ45 (Rød) | Transit `ds-02` B | Primær firewall mod switch 2 |
| **fg-02** (FG60F) | `port3` | **ds-02** (3650) | `Gi1/0/24` | Cat6 RJ45 (Rød) | Transit `ds-02` C | Sekundær firewall mod switch 2 (Rettet til Symmetrisk HA) |
| **fg-02** (FG60F) | `port4` | **ds-02** (3650) | `Gi1/0/23` | Cat6 RJ45 (Rød) | Transit `ds-02` D | Sekundær firewall mod switch 2 (Rettet til Symmetrisk HA) |
| **ds-01** (3650) | `Gi1/0/20` | **ds-02** (3650) | `Gi1/0/20` | Cat6 RJ45 (Hvid) | Inter-switch Link 1 | LACP EtherChannel (Port-channel 3 i din config) |
| **ds-01** (3650) | `Gi1/0/19` | **ds-02** (3650) | `Gi1/0/19` | Cat6 RJ45 (Hvid) | Inter-switch Link 2 | LACP EtherChannel (Port-channel 3 i din config) |
| **ds-01** (3650) | `Te1/0/1` | **Dell R630** | `eno1` (10G Port 1) | Cat6a RJ45 (Sort) | Kunde VLAN Trunk | LACP 10G Data-Trunk til Proxmox (vmbr0) |
| **ds-02** (3650) | `Te1/0/1` | **Dell R630** | `eno2` (10G Port 2) | Cat6a RJ45 (Sort) | Kunde VLAN Trunk | LACP 10G Data-Trunk til Proxmox (vmbr0) |
| **ds-01** (3650) | `Gi1/0/10` | **Dell R630** | `eno3` (1G Port 3) | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Active-Backup Mgmt Link til Proxmox Host |
| **ds-02** (3650) | `Gi1/0/10` | **Dell R630** | `eno4` (1G Port 4) | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Active-Backup Mgmt Link til Proxmox Host |
| **ds-01** (3650) | `Gi1/0/12` | **Dell R630** | `iDRAC port` | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Out-of-band konsol og hardware monitorering |
| **as-01** (2960) | `Gi0/15` | **Admin-PC** | RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 99 (Management) | Din administrations computer |
| **as-01** (2960) | `Gi0/1` | **Alfa-PC** | RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 10 (Kunde Alfa) | Klient-pc til test af Kunde Alfa |
| **as-01** (2960) | `Gi0/2` | **Bravo-PC**| RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 20 (Kunde Bravo)| Klient-pc til test af Kunde Bravo |
