# Designvalg, Virtualiseringsarkitektur og Sikkerhed (Del 2)

Dette dokument redegør for de arkitektoniske overvejelser, teknologivalg og sikkerhedsprincipper, der ligger til grund for etableringen af virksomhedens fælles virtualiseringsplatform for **Infrastrukturprojekt – Del 2: Virtualiseringsplatform**.

Platformen konsoliderer fire selvstændige kundemiljøer (**Alfa**, **Bravo**, **Charlie** og **Delta**) på en fælles fysisk **Dell PowerEdge R630** server under **Proxmox Virtual Environment (PVE)**, integreret direkte med den eksisterende redundante netværksinfrastruktur fra Del 1 (v2).

---

## 1. Fysisk Server og Netværksintegration

Virksomhedens server er en enterprise-grade **Dell PowerEdge R630** udrustet med:
*   **2 × 10 Gbit/s SFP+ Netværksinterfaces (`eno1` & `eno2`):** Dedikeret til kundetrafik og højtydende datatransit.
*   **4 × 1 Gbit/s RJ-45 Netværksinterfaces (`eno3`, `eno4`, `eno5`, `eno6`):** Dedikeret til out-of-band management, Proxmox klyngeadministration og backup.
*   **Dual Intel Xeon CPU'er & ECC RAM:** Giver rigelig regnekraft til samtidig afvikling af flere kundemiljøer.
*   **Hardware RAID (PERC H730):** Spejlede enterprise SAS SSD'er i RAID 1/10 for maksimal I/O ydeevne og fejltolerance.

### Fysisk Forbindelsesdesign mod Cisco Switche

For at sikre maksimal tilgængelighed og eliminere single-points-of-failure er kablingen designet som følger:

```
                      [ Dell PowerEdge R630 (Proxmox VE) ]
                      /                                  \
        eno1 (10G SFP+)                                  eno2 (10G SFP+)
               |                                                |
               v                                                v
    [ Cisco 3650 ds-01 ]                              [ Cisco 3650 ds-02 ]
         Te1/0/1                                           Te1/0/1
            \                                                 /
             +==== ISL EtherChannel (Gi1/0/19-20) ===========+
```

1.  **10G Kundetrunk (LACP Bond):**
    *   Interfaces `eno1` og `eno2` samles i en Linux Network Bond (`bond0`) konfigureret i **LACP mode (802.3ad)** med `layer2+3` hash-politik for optimal lastfordeling.
    *   `bond0` forbindes som 802.1Q VLAN trunk mod de to Cisco Catalyst 3650 switches (`ds-01` port `Te1/0/1` og `ds-02` port `Te1/0/1`).
    *   Dette sikrer, at serveren har en samlet båndbredde på op til 20 Gbit/s og kan overleve tabet af et 10G kabel, en SFP+ transceiver eller en hel Core-switch uden nedetid.
2.  **1G Management Link (VLAN 99 / 100):**
    *   Interfaces `eno3` og `eno4` forbindes til Cisco 2960X access-switchen (`ms-01` port `Gi1/0/8` og `Gi1/0/9`), konfigureret som active-backup bond (`bond1`) for serverens eget hypervisor-management (`vmbr99` / `vmbr100`).
    *   Dette sikrer, at hypervisorens management-interface er fysisk og logisk adskilt fra kundernes data-trafik.

---

## 2. Virtuelt Netværksdesign i Proxmox VE

I henhold til opgavekravene skal hver kunde have sit eget isolerede virtuelle netværk på Proxmox, realiseret via **separate Linux Bridges**:

| Kundemiljø | Proxmox Linux Bridge | Underliggende VLAN Interface | 802.1Q VLAN Tag | Subnet | Gateway (HSRP VIP) |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **Kunde Alfa** | `vmbr10` | `bond0.10` | 10 | `192.168.10.0/24` | `192.168.10.1` |
| **Kunde Bravo** | `vmbr20` | `bond0.20` | 20 | `192.168.20.0/24` | `192.168.20.1` |
| **Kunde Charlie**| `vmbr30` | `bond0.30` | 30 | `192.168.30.0/24` | `192.168.30.1` |
| **Kunde Delta** | `vmbr40` | `bond0.40` | 40 | `192.168.40.0/24` | `192.168.40.1` |
| **Management** | `vmbr99` | `bond1` (Native/Untagged) | 99 | `192.168.99.0/24` | `192.168.99.1` |

### Hvorfor separate Linux Bridges frem for én VLAN-aware bridge?
Proxmox understøtter både en fælles VLAN-aware bridge (`vmbr0` med VLAN tagging per VM-interface) og separate Linux Bridges for hvert VLAN. I dette enterprise-design er der valgt **separate Linux Bridges** af følgende tungtvejende faglige årsager:
1.  **Strengeste mulige isolation:** Hver bridge udgør et selvstændigt virtuelt Layer 2 broadcast domæne i Linux-kernen. Fejlkonfiguration af et VLAN-tag på en virtuel maskine kan dermed aldrig forårsage "VLAN hopping" eller utilsigtet lækage til en anden kundes netværk.
2.  **Direkte overensstemmelse med opgavekravet:** Opgavebeskrivelsen specificerer eksplicit: *"Der skal etableres en separat Linux Bridge for hvert kundemiljø."*
3.  **Gennemskuelig fejlfinding og overvågning:** Hver kundes samlede trafiktællere (TX/RX pakker, drops og fejl) kan overvåges direkte på bridge-niveau (`ip -s link show vmbr10`) uden filtrering.

---

## 3. End-to-End Trafikvej (Fra Virtuel Maskine til WAN)

For at sikre fuld sporbarhed og verificerbarhed i driften dokumenteres den præcise vej, som en datapakke følger fra en virtuel maskine til internettet:

```
[ Kunde Alfa Webserver (192.168.10.10) ]
        |
        | Virtuelt veth/tap interface
        v
[ Proxmox Linux Bridge: vmbr10 ]
        |
        | Kernel switching til VLAN subinterface
        v
[ 802.1Q Subinterface: bond0.10 ] (Påsætter 802.1Q Tag: 10)
        |
        | LACP Trunk over 2x 10G interfaces (eno1 & eno2)
        v
[ Cisco Catalyst 3650 Core Switche (ds-01 / ds-02) ]
        |
        | Modtages på 10G trunk port Te1/0/1
        v
[ Switch Virtual Interface: Interface Vlan10 ]
        |
        | Gateway VIP: 192.168.10.1 (HSRP Active på ds-02)
        v
[ VRF Routing Kontekst: vrf-alfa ]
        |
        | Forwardes baseret på statisk default-rute via transit VLAN 910
        v
[ SVI Interface Vlan910 (Transit Alfa: 10.10.10.0/29) ]
        |
        | Next-hop IP: 10.10.10.1 (FortiGate Alfa VDOM)
        v
[ FortiGate 60F HA Cluster (fg-01 / fg-02) ]
        |
        | Modtages i VDOM: alfa
        | Firewall Policy inspektion & SNAT mod Inter-VDOM link (vl-alfa1)
        v
[ FortiGate Inter-VDOM Link ➔ VDOM: root ]
        |
        | Routing til WAN1 interface (192.168.200.1)
        v
[ Cisco ISR 4331 (wan-rt01) via BDI1 (192.168.200.2) ]
        |
        | Dynamic PAT / Overload NAT på Gi0/0/2
        v
[ Offentligt Internet / Skolenetværk ]
```

---

## 4. Resource Pools og Ressourcestyring

For at forhindre, at én kundes ressourceforbrug forringer ydeevnen for de øvrige kunder, og for at muliggøre opdelt administration, anvendes Proxmox **Resource Pools**:

*   **`pool-alfa`:** Huser Kunde Alfa's servere (`vm-alfa-web01`, VMID `110`).
*   **`pool-bravo`:** Huser Kunde Bravo's servere (`vm-bravo-web01`, VMID `120`).
*   **`pool-charlie`:** Huser Kunde Charlie's servere (`vm-charlie-web01`, VMID `130`).
*   **`pool-delta`:** Huser Kunde Delta's servere (`vm-delta-web01`, VMID `140`).

### Ressourceallokering per Webserver:
*   **vCPU:** 2 vCPU kerner (kvm64/host optimeret).
*   **RAM:** 2048 MB (2 GB) dedikeret RAM uden memory ballooning overcommit.
*   **Disk:** 20 GB ZFS/LVM-Thin volumen (`local-lvm`).
*   **OS:** Ubuntu 24.04 LTS Minimal med Nginx webserver.

---

## 5. Bruger- og Rettighedsarkitektur (RBAC & Least Privilege)

Et afgørende krav i Del 2 er, at kunderne skal kunne tilgå Proxmox Web UI og administrere deres egne maskiner, **uden** at kunne se eller påvirke andre kunders maskiner eller hypervisorens underliggende infrastruktur.

### A. Autentificerings-realm
Vi anvender Proxmox' indbyggede **PVE Authentication Realm (`@pve`)** til kundebrugerne. Dette sikrer, at kunderne ikke har systembrugere (`/etc/passwd` / PAM) på hypervisorens Linux OS.

### B. Oprettede Brugere:
*   `kunde-alfa@pve`
*   `kunde-bravo@pve`
*   `kunde-charlie@pve`
*   `kunde-delta@pve`

### C. Custom Rolle: `CustomerVMAdmin`
I stedet for at tildele standardrollen `PVEAdmin` (som giver alt for vide beføjelser) har vi defineret en skræddersyet rolle: **`CustomerVMAdmin`**, der udelukkende indeholder de nødvendige rettigheder til daglig drift af egne virtuelle servere:
*   `VM.PowerMgmt` (Start, stop, reboot, shutdown)
*   `VM.Console` (Adgang til noVNC web-konsol)
*   `VM.Monitor` (Se CPU, RAM, disk og netværksgrafer for egen VM)
*   `VM.Audit` (Se konfiguration af egen VM)

Følgende farlige rettigheder er **udeladt**:
*   `VM.Allocate` / `VM.Config.*` (Kunden kan ikke ændre CPU/RAM eller tilføje nye netværksinterfaces til andre VLANs).
*   `Sys.Audit` / `Sys.Modify` (Kunden kan ikke se node-status, dmesg, hardware eller netværkskort).
*   `Datastore.Allocate` (Kunden kan ikke oprette eller slette virtuelle diske).

### D. Adgangskontrol (Access Control Lists - ACL)
Rettigheder tildeles udelukkende på stien for kundens specifikke Resource Pool:
*   `/pool/pool-alfa` ➔ `kunde-alfa@pve` ➔ Rolle: `CustomerVMAdmin`
*   `/pool/pool-bravo` ➔ `kunde-bravo@pve` ➔ Rolle: `CustomerVMAdmin`
*   `/pool/pool-charlie` ➔ `kunde-charlie@pve` ➔ Rolle: `CustomerVMAdmin`
*   `/pool/pool-delta` ➔ `kunde-delta@pve` ➔ Rolle: `CustomerVMAdmin`

Når f.eks. `kunde-alfa@pve` logger ind i Proxmox Web UI, præsenteres brugeren kun for træstrukturen for `pool-alfa` og `vm-alfa-web01`. Alle andre pools og maskiner er skjult for brugeren.

---

## 6. Proxmox Firewall Arkitektur

Proxmox Firewall aktiveres for at yde dybdegående beskyttelse direkte på hypervisor-niveau foran de virtuelle interfaces (Layer 4 filtrering via Linux `iptables` / `ebtables`).

### 3-Lags Sikkerhedsmodel:
1.  **Datacenter Niveau (`cluster.fw`):**
    *   Firewall aktiveres globalt (`enable: 1`).
    *   Input Policy: `DROP`.
    *   Output Policy: `ACCEPT`.
    *   Forward Policy: `ACCEPT` (for at lade broerne videresende trafik).
2.  **Node Niveau (`host.fw`):**
    *   Management-porte til Proxmox Host (Port 8006 Web GUI og Port 22 SSH) tillades **kun** fra Management-netværket (`192.168.99.0/24` og `192.168.100.0/24`).
    *   Al adgang fra kundenetværkene (`192.168.10.0/24`, `.20.0/24`, `.30.0/24`, `.40.0/24`) til port 8006 droppes ubetinget.
3.  **VM / Gæste-Niveau (`<vmid>.fw`):**
    *   Hver virtuel maskine har aktiveret firewall på sit netværksinterface (`firewall=1`).
    *   **IP-Filtrering (Anti-Spoofing):** `ipfilter: 1` aktiveres, hvilket binder VM'ens virtuelle interface til den specifikke tildelte IP-adresse. Hvis en kompromitteret VM forsøger at sende pakker med en anden IP (f.eks. for at spoofe en anden kunde), droppes pakkerne i kernen.
    *   **Tilladt Inbound Trafik:**
        *   TCP Port 80 (HTTP) - Offentlig webtrafik.
        *   TCP Port 443 (HTTPS) - Sikker webtrafik.
        *   ICMP Echo-Request (Ping) - Diagnostik.
        *   TCP Port 22 (SSH) - Kun tilladt fra Management IP-området.
    *   **Default Inbound Policy:** `DROP`.

Dermed er hver kundes webserver maksimalt hærdet mod angreb, og kundemiljøerne kan ikke scanne eller angribe hinanden på det lokale L2-domæne.
