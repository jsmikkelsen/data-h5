# Infrastrukturprojekt – Del 2: Fælles Virtualiseringsplatform (Proxmox VE på Dell R630)

Velkommen til projektportfoliet for **Infrastrukturprojekt – Del 2: Virtualiseringsplatform**. Dette modul bygger direkte oven på den redundante fysiske og logiske netværksinfrastruktur, der blev etableret i **Del 1 (v2)**.

I denne del af projektet konsolideres virksomhedens servermiljøer på en fælles, højtydende fysisk virtualiseringsserver (**Dell PowerEdge R630**), som kører **Proxmox Virtual Environment (PVE)**. Platformen huser de fire uafhængige kundemiljøer (**Alfa**, **Bravo**, **Charlie** og **Delta**), så kunderne deler den fysiske hardware, men holdes strengt adskilt på alle niveauer: virtuelle netværk (Linux Bridges & VLANs), ressourceallokering (Resource Pools), brugerrettigheder (RBAC) og virtualiserings-firewall (Proxmox Firewall).

---

## 📂 Mappestruktur og Dokumentation for Del 2

Dokumentationen er struktureret i overensstemmelse med H5-fagets krav:

1. **[Designvalg og Arkitektur (`design_valg.md`)](./design_valg.md)**
   * Fysisk integration af Dell PowerEdge R630 (10G kunde-trunk mod Cisco 3650 Core og 1G redundant management mod Cisco 2960X).
   * Virtuelt netværksdesign: Linux Bridges (`vmbr10`, `vmbr20`, `vmbr30`, `vmbr40`, `vmbr99`) samt VLAN-tagging mod kundenetværk.
   * End-to-end trafikveje: Dokumentation af datastrømmen fra VM ➔ Linux Bridge ➔ Fysisk NIC ➔ Cisco 3650 SVI ➔ HSRP Gateway ➔ VRF-Lite ➔ FortiGate WAN.
   * Ressourcestyring via Proxmox **Resource Pools** (`pool-alfa`, `pool-bravo`, `pool-charlie`, `pool-delta`).
   * Bruger- og rettighedsstruktur (**RBAC**): Oprettelse af kundespecifikke brugere (`kunde-alfa@pve` osv.), custom roller efter *Least Privilege*-princippet samt isolation af administration.
   * **Proxmox Firewall Arkitektur:** 3-lags firewall-beskyttelse (Datacenter, Node og VM-niveau) med restriktiv port-politik.

2. **[Konfigurationsskabeloner (`konfiguration_skabelon.md`)](./konfiguration_skabelon.md)**
   * Komplet netværkskonfiguration for Proxmox (`/etc/network/interfaces`) med LACP bond og Linux Bridges.
   * Proxmox CLI / `pveum` kommandoer til oprettelse af pools, brugere, roller og tildeling af ACL rettigheder.
   * Proxmox Firewall regler (`cluster.fw`, `host.fw`, `<vmid>.fw`).
   * Nginx webserver-konfiguration og kundespecifikke HTML-identifikationssider for Kunde Alfa, Bravo, Charlie og Delta.
   * Ansible automation og Cloud-Init integration til hurtig udrulning.

3. **[Testplan og Verifikationsdokumentation (`test_dokumentation.md`)](./test_dokumentation.md)**
   * Komplet testmatrix for virtualiseringsplatformen.
   * Verifikation af VM-drift, netværkskonnektivitet mod HSRP default gateway.
   * Test af streng isolation mellem kundernes webservere (VRF og L2/L3 adskillelse).
   * Test af Proxmox Firewall (accept af HTTP/HTTPS/Ping, drop af uautoriserede porte).
   * Verifikation af brugerrettigheder: Test af adgangsbegrænsning i Proxmox Web GUI som kundebruger.

---

## 🛠️ Overordnet Systemarkitektur (Del 2 Integration)

```
                            +-----------------------------------------------+
                            |             Dell PowerEdge R630               |
                            |                 (Proxmox VE)                  |
                            |                                               |
  +------------------+      |  +-----------------------------------------+  |
  | Kunde Alfa VM    |      |  | Pool: pool-alfa (Bruger: kunde-alfa@pve)|  |
  | IP: 192.168.10.10|----->|  | Linux Bridge: vmbr10 (VLAN 10 Tag)      |  |
  +------------------+      |  +-----------------------------------------+  |
                            |                                               |
  +------------------+      |  +-----------------------------------------+  |
  | Kunde Bravo VM   |      |  | Pool: pool-bravo (Bruger: kunde-bravo@pve) |
  | IP: 192.168.20.10|----->|  | Linux Bridge: vmbr20 (VLAN 20 Tag)      |  |
  +------------------+      |  +-----------------------------------------+  |
                            |                                               |
  +------------------+      |  +-----------------------------------------+  |
  | Kunde Charlie VM |      |  | Pool: pool-charlie (Bruger: charlie@pve)|  |
  | IP: 192.168.30.10|----->|  | Linux Bridge: vmbr30 (VLAN 30 Tag)      |  |
  +------------------+      |  +-----------------------------------------+  |
                            |                                               |
  +------------------+      |  +-----------------------------------------+  |
  | Kunde Delta VM   |      |  | Pool: pool-delta (Bruger: kunde-delta@pve) |
  | IP: 192.168.40.10|----->|  | Linux Bridge: vmbr40 (VLAN 40 Tag)      |  |
  +------------------+      |  +-----------------------------------------+  |
                            |                        |                      |
                            |           [ bond0 (LACP 802.3ad) ]            |
                            |               |                 |             |
                            +---------------+-----------------+-------------+
                                     eno1 (10G)             eno2 (10G)
                                          |                     |
                                          |                     |
                                     [ Te1/0/1 ]           [ Te1/0/1 ]
                                    [ Cisco ds-01 ]======= [ Cisco ds-02 ]
                                    (VRF Alfa-Delta)      (VRF Alfa-Delta)
                                          \                     /
                                           \                   /
                                        [ FortiGate HA Cluster ]
                                                  |
                                             [ Internet ]
```

### Nøglepunkter i Virtualiseringsdesignet:
* **Fuld udnyttelse af 10 Gbit/s interfaces:** Serverens to 10G interfaces (`eno1` og `eno2`) samles i et redundant bond (`bond0`) med 802.3ad LACP, der føres som 802.1Q trunk direkte til Core-switchene (`ds-01` og `ds-02`).
* **Hardware-uafhængig kundeadskillelse:** Hver kunde har sin egen dedikerede Linux Bridge, der videresender trafik med kundens respektive VLAN-tag (VLAN 10, 20, 30, 40).
* **Multi-tenant isolation:** Kunderne har hver deres login til Proxmox Web GUI, hvor de udelukkende ser og kan betjene maskiner i deres egen Resource Pool.
* **Lagdelt sikkerhed:** Proxmox Firewall håndhæver strenge pakkefiltreringsregler direkte på hypervisor-niveau foran de virtuelle interfaces (veth/tap).
