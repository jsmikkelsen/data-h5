# IP- og VLAN-adresseplan (Version 2)

Dette dokument indeholder den fulde, strukturerede IP- og VLAN-plan for **Infrastrukturprojekt – Del 1 (v2)**. Planen anvender private `192.168.x.x` IPv4-adresser og er designet med stor fokus på overskuelighed og logisk segmentering af de nye kundemiljøer (**Alfa**, **Bravo**, **Charlie** og **Delta**).

---

## 1. Overordnet Allokeringsstrategi

Hvert kundemiljø tildeles sit eget dedikerede `/24` subnet. Dette sikrer tilstrækkeligt med adresser (op til 254 brugbare IP'er per netværk) til både klienter, administrationspc'er, printere og server-services.

*   **Kunde Alfa:** Allokeret `192.168.10.0/24`
*   **Kunde Bravo:** Allokeret `192.168.20.0/24`
*   **Kunde Charlie:** Allokeret `192.168.30.0/24`
*   **Kunde Delta:** Allokeret `192.168.40.0/24`
*   **Management:** Allokeret `192.168.99.0/24`
*   **Interne Transitter (GRT):** Allokeret under `192.168.100.0` - `192.168.255.0`

---

## 2. Detaljeret VLAN- og IP-Tabel

Nedenstående tabel viser de aktive netværk, tilhørende VLANs, VRF-kontekster og infrastrukturelle IP-adresser:

| Netværksnavn / Funktion | VLAN | Netværksadresse | Subnetmaske | VRF | Gateway VIP (HSRP) | core-sw01 IP (SVI) | core-sw02 IP (SVI) | Host Range (DHCP/Statisk) |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Kunde Alfa - LAN** | 10 | `192.168.10.0` | `255.255.255.0` (/24) | `VRF_ALFA` | `192.168.10.1` | `192.168.10.2` | `192.168.10.3` | `192.168.10.10 - .254` |
| **Kunde Bravo - LAN** | 20 | `192.168.20.0` | `255.255.255.0` (/24) | `VRF_BRAVO` | `192.168.20.1` | `192.168.20.2` | `192.168.20.3` | `192.168.20.10 - .254` |
| **Kunde Charlie - LAN** | 30 | `192.168.30.0` | `255.255.255.0` (/24) | `VRF_CHARLIE` | `192.168.30.1` | `192.168.30.2` | `192.168.30.3` | `192.168.30.10 - .254` |
| **Kunde Delta - LAN** | 40 | `192.168.40.0` | `255.255.255.0` (/24) | `VRF_DELTA` | `192.168.40.1` | `192.168.40.2` | `192.168.40.3` | `192.168.40.10 - .254` |
| **Management Netværk** | 99 | `192.168.99.0` | `255.255.255.0` (/24) | `VRF_MGMT` | `192.168.99.1` | `192.168.99.2` | `192.168.99.3` | Se infrastruktur-tabel nedenfor |

---

## 3. Infrastrukturelle IP-adresser og Transitter

Disse adresser anvendes til punkt-til-punkt transitforbindelser samt administration af netværkskomponenterne:

### Transitnetværk (Layer 3 forbindelser)

Disse adresser bor i **Global Routing Table (GRT)** eller i ydre WAN-zoner:

1.  **Transit Core til Edge (Mellem Cisco 3650 HSRP og FortiGate HA):**
    *   **Netværk (VLAN 101):** `192.168.101.0/29` (Subnetmaske: `255.255.255.248`)
    *   **FortiGate HA VIP (Intern):** `192.168.101.1`
    *   **core-sw01 IP:** `192.168.101.2`
    *   **core-sw02 IP:** `192.168.101.3`
    *   **Core VIP (HSRP i GRT):** `192.168.101.4` (bruges som default gateway for 3650-switchene til at sende uidentificeret trafik mod firewallen).

2.  **Transit Edge til WAN (Mellem FortiGate HA og Cisco 4331 WAN-router):**
    *   **Netværk:** `192.168.200.0/29` (Subnetmaske: `255.255.255.248`)
    *   *Bemærk: Vi anvender et `/29` subnet her for at give tilstrækkelig plads til, at både den delte HA VIP, de to fysiske FortiGate WAN-interfaces og Cisco 4331 kan bo på samme netværk.*
    *   **FortiGate HA VIP (Ekstern):** `192.168.200.1`
    *   **Cisco 4331 IP (WAN Interface Gi0/0/0):** `192.168.200.2`
    *   **FortiGate-01 Fysisk WAN-IP (Valgfri):** `192.168.200.3`
    *   **FortiGate-02 Fysisk WAN-IP (Valgfri):** `192.168.200.4`

3.  **L3 Link core-sw01 to core-sw02 (Backplane/Routing Sync):**
    *   **Netværk:** `192.168.255.0/30` (Subnetmaske: `255.255.255.252`)
    *   **core-sw01 IP (Routed Port/VLAN 100):** `192.168.255.1`
    *   **core-sw02 IP (Routed Port/VLAN 100):** `192.168.255.2`

---

## 4. Administrations- og Managementadresser (VLAN 99)

Følgende statiske IP-adresser er allokeret til udstyrets administrations-SVI'er inden for `VRF_MGMT`:

*   **Default Gateway VIP (HSRP):** `192.168.99.1`
*   **core-sw01 Management SVI:** `192.168.99.2`
*   **core-sw02 Management SVI:** `192.168.99.3`
*   **acc-sw01 (L2 Access) SVI:** `192.168.99.11`
*   **acc-sw02 (L2 Access) SVI:** `192.168.99.12`
*   **FortiGate 60F HA Management Port:** `192.168.99.254`
*   **Cisco 4331 Management Port (Out-of-band):** `192.168.99.250`
*   **Administrativ pc / Admin-klient:** `192.168.99.100`
