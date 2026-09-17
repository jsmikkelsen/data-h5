# IP- og VLAN-adresseplan

Dette dokument indeholder den fulde, strukturerede IP- og VLAN-plan for **Infrastrukturprojekt – Del 1**. Planen anvender private IPv4-adresser og er designet med stor fokus på fremtidig skalering, således at hver kunde let kan udvide med flere netværk (f.eks. til servere, DMZ, osv.) uden at overlappe.

---

## 1. Overordnet Allokeringsstrategi

For at sikre maksimal skalerbarhed tildeles hver logiske enhed (kunde/administration) en hel `/16` blok (Klasse B). I denne fase af projektet aktiveres det første `/24` subnet til klient-trafik.

*   **Kunde A:** Allokeret `10.10.0.0/16` (Giver mulighed for 256 subnets af størrelsen `/24`)
*   **Kunde B:** Allokeret `10.20.0.0/16`
*   **Kunde C:** Allokeret `10.30.0.0/16`
*   **Kunde D:** Allokeret `10.40.0.0/16`
*   **Management:** Allokeret `10.99.0.0/16`
*   **Interne Transitter (GRT):** Allokeret under `10.255.0.0/16`
*   **Ydre WAN / ISP-miljø:** Allokeret under `192.168.1.0/24` (kan skalere til andre klasser om nødvendigt)

---

## 2. Detaljeret VLAN- og IP-Tabel

Nedenstående tabel viser de aktive netværk, tilhørende VLANs, VRF-kontekster og infrastrukturelle IP-adresser:

| Netværksnavn / Funktion | VLAN | Netværksadresse | Subnetmaske | VRF | Gateway VIP (HSRP) | core-sw01 IP (SVI) | core-sw02 IP (SVI) | Host Range (DHCP/Statisk) |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Kunde A - LAN** | 10 | `10.10.0.0` | `255.255.255.0` (/24) | `VRF_A` | `10.10.0.1` | `10.10.0.2` | `10.10.0.3` | `10.10.0.10 - .254` |
| **Kunde B - LAN** | 20 | `10.20.0.0` | `255.255.255.0` (/24) | `VRF_B` | `10.20.0.1` | `10.20.0.2` | `10.20.0.3` | `10.20.0.10 - .254` |
| **Kunde C - LAN** | 30 | `10.30.0.0` | `255.255.255.0` (/24) | `VRF_C` | `10.30.0.1` | `10.30.0.2` | `10.30.0.3` | `10.30.0.10 - .254` |
| **Kunde D - LAN** | 40 | `10.40.0.0` | `255.255.255.0` (/24) | `VRF_D` | `10.40.0.1` | `10.40.0.2` | `10.40.0.3` | `10.40.0.10 - .254` |
| **Management Netværk** | 99 | `10.99.0.0` | `255.255.255.0` (/24) | `VRF_MGMT` | `10.99.0.1` | `10.99.0.2` | `10.99.0.3` | Se infrastruktur-tabel nedenfor |

---

## 3. Infrastrukturelle IP-adresser og Transitter

Disse adresser anvendes til punkt-til-punkt transitforbindelser samt administration af netværkskomponenterne:

### Transitnetværk (Layer 3 forbindelser)

Disse adresser bor i **Global Routing Table (GRT)** eller i ydre WAN-zoner:

1.  **Transit Core til Edge (Mellem Cisco 3650 HSRP og FortiGate HA):**
    *   **Netværk (VLAN 101):** `10.255.101.0/29` (Subnetmaske: `255.255.255.248`)
    *   **FortiGate HA VIP (Intern):** `10.255.101.1`
    *   **core-sw01 IP:** `10.255.101.2`
    *   **core-sw02 IP:** `10.255.101.3`
    *   **Core VIP (HSRP i GRT):** `10.255.101.4` (bruges som default gateway for 3650-switchene til at sende uidentificeret trafik mod firewallen).

2.  **Transit Edge til WAN (Mellem FortiGate HA og Cisco 4331):**
    *   **Netværk:** `10.255.200.0/30` (Subnetmaske: `255.255.255.252`)
    *   **FortiGate HA VIP (Ekstern):** `10.255.200.1`
    *   **Cisco 4331 IP (WAN):** `10.255.200.2`

3.  **L3 Link core-sw01 to core-sw02 (Backplane/Routing Sync):**
    *   **Netværk:** `10.255.255.0/30` (Subnetmaske: `255.255.255.252`)
    *   **core-sw01 IP (Routed Port/VLAN 100):** `10.255.255.1`
    *   **core-sw02 IP (Routed Port/VLAN 100):** `10.255.255.2`

---

## 4. Administrations- og Managementadresser (VLAN 99)

Følgende statiske IP-adresser er allokeret til udstyrets administrations-SVI'er inden for `VRF_MGMT`:

*   **Default Gateway VIP (HSRP):** `10.99.0.1`
*   **core-sw01 Management SVI:** `10.99.0.2`
*   **core-sw02 Management SVI:** `10.99.0.3`
*   **acc-sw01 (L2 Access) SVI:** `10.99.0.11`
*   **acc-sw02 (L2 Access) SVI:** `10.99.0.12`
*   **FortiGate 60F HA Management Port:** `10.99.0.254`
*   **Cisco 4331 Management Port (Out-of-band):** `10.99.0.250`
*   **Administrativ pc / Admin-klient:** `10.99.0.100`

---

## 5. Fremtidig Skalering (Eksempel på udvidelse)

Takket være `/16` allokeringen, kan der let tilføjes nye subnetværk til f.eks. Kunde A:
*   `10.10.1.0/24` -> Kunde A - Server-miljø (VLAN 11)
*   `10.10.2.0/24` -> Kunde A - IP-Telefoni (VLAN 12)
*   `10.10.3.0/24` -> Kunde A - DMZ/Ekstern (VLAN 13)

Dette gøres simpelt ved blot at oprette det nye VLAN på switchene og tildele det til `VRF_A` på Core-switchene, helt uden at påvirke de øvrige kunders IP-planer.
