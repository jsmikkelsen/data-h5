# Fysisk Kablingsplan (v2 - Custom Mesh Design)

Dette dokument indeholder den komplette, fysiske kablingsplan for **Infrastrukturprojekt – Del 1 (v2)**, tilpasset dit specifikke lab-kablingsdesign. 

Kablingsplanen anvender et avanceret, fuldt redundant cross-mesh (maskenetværk) på LAN-siden, hvor hver FortiGate er forbundet direkte til begge de centrale Layer 3 switches (**`ds-01`** og **`ds-02`**). Dette sikrer, at netværket forbliver fuldt operationelt, selv hvis en hel switch eller en hel firewall skulle fejle.

---

## 1. Overordnet Netværkskablings-Logik

1.  **Direkte WAN-forbindelse:**
    *   WAN-routeren **`wan-rt01`** forbindes direkte til WAN1-porten på begge FortiGates (`fg-01` og `fg-02`). 
    *   Cisco-routeren kører Layer 2 software-bridging via **BDI1** (Bridge Domain Interface) på de to hosliggende porte `Gi0/0/0` og `Gi0/0/1`, hvilket overflødiggør eksterne switches på WAN-siden.
    *   `Gi0/0/2` på routeren kables direkte til vægstikket mod det rigtige internet.
2.  **Redundant Cross-Mesh LAN-kabling:**
    *   **`fg-01` (Active)** har to porte (`port1` & `port2`) forbundet til `ds-01` og to porte (`port3` & `port4`) forbundet til `ds-02`.
    *   **`fg-02` (Passive)** har to porte (`port1` & `port2`) forbundet til `ds-02` og to porte (`port3` & `port4`) forbundet til `ds-01`.
    *   Dette tillader, at den aktive firewall altid kan sende trafik til begge switches. I FortiOS konfigureres disse fire porte som et enkelt **Redundant Interface**, hvilket forhindrer Layer 3 loops og sikrer automatisk failover.
3.  **Inter-Switch Link (ISL Trunk):**
    *   De to L3 switches er forbundet direkte med hinanden med to links på `Gi1/0/19` og `Gi1/0/20`. Disse konfigureres i en **LACP EtherChannel (Port-channel 1)** for optimal båndbredde og loop-prevention.

---

## 2. Detaljeret Kablings-Tabel

| Kilde Enhed | Kilde Port | Destination Enhed | Destination Port | Kabeltype | Funktion / VLAN | Noter |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **wan-rt01** (4331) | `Gi0/0/2` | **Væg-stik / SkoleLAN** | RJ45 Internetstik | Cat6 RJ45 (Grå) | NAT Outside / Internet | Leverer internetadgang til din WAN-router |
| **wan-rt01** (4331) | `Gi0/0/0` | **fg-01** (FG60F) | `wan1` | Cat6 RJ45 (Hvid) | Direkte WAN Link 1 | Forbinder router direkte til primær firewall WAN1 |
| **wan-rt01** (4331) | `Gi0/0/1` | **fg-02** (FG60F) | `wan1` | Cat6 RJ45 (Hvid) | Direkte WAN Link 2 | Forbinder router direkte til sekundær firewall WAN1 |
| **fg-01** (FG60F) | `a` | **fg-02** (FG60F) | `a` | Cat6 RJ45 (Hvid) | Heartbeat 1 (HA Sync)| HA synkroniserings-kabel (Fysisk FortiLink Port A) |
| **fg-01** (FG60F) | `b` | **fg-02** (FG60F) | `b` | Cat6 RJ45 (Hvid) | Heartbeat 2 (HA Sync)| Sekundært HA synkroniserings-kabel (Fysisk FortiLink Port B) |
| **fg-01** (FG60F) | `port1` | **ds-01** (3650) | `Gi1/0/24` | Cat6 RJ45 (Gul) | Intern Transit 1A | Forbinder primær firewall til switch 1 |
| **fg-01** (FG60F) | `port2` | **ds-01** (3650) | `Gi1/0/23` | Cat6 RJ45 (Gul) | Intern Transit 1B | Forbinder primær firewall til switch 1 |
| **fg-02** (FG60F) | `port1` | **ds-02** (3650) | `Gi1/0/24` | Cat6 RJ45 (Rød) | Intern Transit 2A | Forbinder sekundær firewall til switch 2 |
| **fg-02** (FG60F) | `port2` | **ds-02** (3650) | `Gi1/0/23` | Cat6 RJ45 (Rød) | Intern Transit 2B | Forbinder sekundær firewall til switch 2 (Rettet port1-dublet) |
| **fg-01** (FG60F) | `port3` | **ds-02** (3650) | `Gi1/0/22` | Cat6 RJ45 (Rød) | Intern Transit Cross 1A| Forbinder primær firewall til switch 2 |
| **fg-01** (FG60F) | `port4` | **ds-02** (3650) | `Gi1/0/21` | Cat6 RJ45 (Rød) | Intern Transit Cross 1B| Forbinder primær firewall til switch 2 |
| **fg-02** (FG60F) | `port3` | **ds-01** (3650) | `Gi1/0/22` | Cat6 RJ45 (Gul) | Intern Transit Cross 2A| Forbinder sekundær firewall til switch 1 |
| **fg-02** (FG60F) | `port4` | **ds-01** (3650) | `Gi1/0/21` | Cat6 RJ45 (Gul) | Intern Transit Cross 2B| Forbinder sekundær firewall til switch 1 |
| **ds-01** (3650) | `Gi1/0/20` | **ds-02** (3650) | `Gi1/0/20` | Cat6 RJ45 (Hvid) | Inter-switch Link 1 | LACP EtherChannel (Port-channel 1) |
| **ds-01** (3650) | `Gi1/0/19` | **ds-02** (3650) | `Gi1/0/19` | Cat6 RJ45 (Hvid) | Inter-switch Link 2 | LACP EtherChannel (Port-channel 1) |
| **ds-01** (3650) | `Te1/0/1` | **Dell R630** | `eno1` (10G Port 1) | Cat6a RJ45 (Sort) | Kunde VLAN Trunk | LACP 10G Data-Trunk til Proxmox (vmbr0) |
| **ds-02** (3650) | `Te1/0/1` | **Dell R630** | `eno2` (10G Port 2) | Cat6a RJ45 (Sort) | Kunde VLAN Trunk | LACP 10G Data-Trunk til Proxmox (vmbr0) |
| **ds-01** (3650) | `Gi1/0/10` | **Dell R630** | `eno3` (1G Port 3) | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Active-Backup Mgmt Link til Proxmox Host |
| **ds-02** (3650) | `Gi1/0/10` | **Dell R630** | `eno4` (1G Port 4) | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Active-Backup Mgmt Link til Proxmox Host |
| **ds-01** (3650) | `Gi1/0/12` | **Dell R630** | `iDRAC port` | Cat6 RJ45 (Gul) | VLAN 99 (Management) | Out-of-band konsol og hardware monitorering |
| **ds-01** (3650) | `Gi1/0/15` | **Admin-PC** | RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 99 (Management) | Din administrations computer |
| **ds-01** (3650) | `Gi1/0/1` | **Alfa-PC** | RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 10 (Kunde Alfa) | Klient-pc til test af Kunde Alfa |
| **ds-01** (3650) | `Gi1/0/2` | **Bravo-PC**| RJ45 Netværkskort | Cat6 RJ45 (Hvid) | VLAN 20 (Kunde Bravo)| Klient-pc til test af Kunde Bravo |

---

## 3. Farvekodnings-anbefaling i dit Rack

For at gøre fejlfinding og vedligeholdelse ekstremt let og overskueligt, anbefales det at følge denne farvestandard for patchkablerne:
*   🔴 **Røde kabler:** Alle kabler tilsluttet **`ds-02`** (herunder `fg-02` primære links, og `fg-01` cross-links).
*   🟡 **Gule kabler:** Alle kabler tilsluttet **`ds-01`** (herunder `fg-01` primære links, `fg-02` cross-links, og management SVI'er/iDRAC).
*   ⚪ **Hvide kabler:** WAN forbindelser, inter-switch LACP links samt klient-forbindelser (pc'er til test).
*   ⚫ **Sorte kabler:** High-speed 10 Gbit/s kobber (Cat6a/Cat7) mellem Proxmox-værtens NDC og Core-switchene.
