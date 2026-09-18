# IP- og VLAN-adresseplan (Version 2 - Custom Mesh Design)

Dette dokument indeholder den fulde, strukturerede IP- og VLAN-plan for **Infrastrukturprojekt – Del 1 (v2)**. Planen anvender private IPv4-adresser og integrerer dine **kunde VLANs**, **management-netværk** samt de **individuelle transit VLANs** til din avancerede redundant mesh-kabling mod de to FortiGates.

---

## 1. Overordnet Allokeringsstrategi

Hvert kundemiljø tildeles sit eget dedikerede `/24` subnet. Administrations- og transitnetværk konfigureres med optimerede prefixes for at minimere spild af adresser.

*   **Kunde Alfa:** Allokeret `192.168.10.0/24`
*   **Kunde Bravo:** Allokeret `192.168.20.0/24`
*   **Kunde Charlie:** Allokeret `192.168.30.0/24`
*   **Kunde Delta:** Allokeret `192.168.40.0/24`
*   **Management:** Allokeret `192.168.99.0/24`

---

## 2. Detaljeret Kunde- og Management VLAN-Tabel

Nedenstående tabel viser de aktive kundenetværk og administrationsadresser:

| Netværksnavn / Funktion | VLAN | Netværksadresse | Subnetmaske | VRF | Gateway VIP (HSRP) | ds-01 IP (SVI) | ds-02 IP (SVI) | Host Range (DHCP/Statisk) |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Kunde Alfa - LAN** | 10 | `192.168.10.0` | `255.255.255.0` | `vrf-alfa` | `192.168.10.1` | `192.168.10.2` | `192.168.10.3` | `192.168.10.10 - .254` |
| **Kunde Bravo - LAN** | 20 | `192.168.20.0` | `255.255.255.0` | `vrf-bravo` | `192.168.20.1` | `192.168.20.2` | `192.168.20.3` | `192.168.20.10 - .254` |
| **Kunde Charlie - LAN** | 30 | `192.168.30.0` | `255.255.255.0` | `vrf-charlie` | `192.168.30.1` | `192.168.30.2` | `192.168.30.3` | `192.168.30.10 - .254` |
| **Kunde Delta - LAN** | 40 | `192.168.40.0` | `255.255.255.0` | `vrf-delta` | `192.168.40.1` | `192.168.40.2` | `192.168.40.3` | `192.168.40.10 - .254` |
| **Management Netværk** | 99 | `192.168.99.0` | `255.255.255.0` | `vrf-management` | `192.168.99.1` | `192.168.99.2` | `192.168.99.3` | `192.168.99.10 - .254` |

---

## 3. L3 Transit VLANs (Mellem Cisco Switches og FortiGates)

Hver switch huser sine egne uafhængige transit-subnets mod FortiGate HA Clusteret. Dette muliggør, at ruterne kan pege på særskilte IP'er (`10.10.x.1` på `ds-01` og `10.9.x.1` på `ds-02`) på firewalls'ne, hvilket sikrer komplet adskillelse og uafhængig static routing per switch.

### A. Transit VLANs på `ds-01` (Subnet blok: `10.10.x.x/29`)

Disse IP'er placeres i `<>` i din `ds-01` switch konfiguration:

| Transit-Navn | VLAN | Netværksadresse | Subnetmaske | VRF | FortiGate HA IP | ds-01 IP (SVI) |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- |
| **transit-alfa** | 910 | `10.10.10.0/29` | `255.255.255.248` | `vrf-alfa` | `10.10.10.1` | `10.10.10.2` |
| **transit-bravo** | 920 | `10.10.20.0/29` | `255.255.255.248` | `vrf-bravo` | `10.10.20.1` | `10.10.20.2` |
| **transit-charlie** | 930 | `10.10.30.0/29` | `255.255.255.248` | `vrf-charlie` | `10.10.30.1` | `10.10.30.2` |
| **transit-delta** | 940 | `10.10.40.0/29` | `255.255.255.248` | `vrf-delta` | `10.10.40.1` | `10.10.40.2` |
| **transit-management** | 999 | `10.10.99.0/29` | `255.255.255.248` | `vrf-management` | `10.10.99.1` | `10.10.99.2` |

---

### B. Transit VLANs på `ds-02` (Subnet blok: `10.9.x.x/29`)

Disse IP'er placeres i `<>` i din `ds-02` switch konfiguration:

| Transit-Navn | VLAN | Netværksadresse | Subnetmaske | VRF | FortiGate HA IP | ds-02 IP (SVI) |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- |
| **transit-alfa** | 910 | `10.9.10.0/29` | `255.255.255.248` | `vrf-alfa` | `10.9.10.1` | `10.9.10.2` |
| **transit-bravo** | 920 | `10.9.20.0/29` | `255.255.255.248` | `vrf-bravo` | `10.9.20.1` | `10.9.20.2` |
| **transit-charlie** | 930 | `10.9.30.0/29` | `255.255.255.248` | `vrf-charlie` | `10.9.30.1` | `10.9.30.2` |
| **transit-delta** | 940 | `10.9.40.0/29` | `255.255.255.248` | `vrf-delta` | `10.9.40.1` | `10.9.40.2` |
| **transit-management** | 999 | `10.9.99.0/29` | `255.255.255.248` | `vrf-management` | `10.9.99.1` | `10.9.99.2` |

---

## 4. Ydre WAN-Transit (Mellem FortiGate HA og Cisco 4331 WAN Router)

Dette netværk forbinder dine firewalls direkte til din internet-gateway router (`wan-rt01`):

*   **Netværk:** `192.168.200.0/29` (Subnetmaske: `255.255.255.248`)
*   **FortiGate HA VIP (Ekstern):** `192.168.200.1`
*   **wan-rt01 IP (Gi0/0/0 og Gi0/0/1 - BDI1):** `192.168.200.2`
*   **Ydre Internet Uplink IP (Cisco 4331 Gi0/0/2):** DHCP (Modtager IP fra skolen/hjemmets netværk)
