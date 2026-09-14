# IP-planlægning og VLSM (Variable Length Subnet Masking)

Denne sektion dækker **Del 2 – IP-plan og VLSM** i opgavebeskrivelsen. Her gennemgås opdelingen af det tildelte adresseområde `10.20.0.0/16` baseret på virksomhedens nuværende behov og forventede vækst.

---

## 🎯 Planlægningskrav og Vækstprognoser

Virksomheden har tildelt adresseområdet **`10.20.0.0/16`** (subnetmaske `255.255.0.0`), hvilket giver i alt 65.536 IP-adresser. 

For at designe et professionelt og skalerbart netværk, tager vi udgangspunkt i det **forventede maksimale antal enheder** frem for de nuværende tal. Subnettene skal dimensioneres nøjagtigt ved brug af VLSM, så vi undgår spild, men samtidig har nok adresser til rådighed på hvert VLAN.

### Behovsanalyse (Sorteret efter størrelse, største først):

| Netværk / VLAN | Nuværende enheder | Forventet antal (inkl. vækst) | Minimum brugbare IP-adresser | Nærmeste binære potens ($2^n$) | Beregnet Subnet-størrelse |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Gæster (VLAN 40)** | 100 | 200 | 200 | $2^8 = 256$ | **`/24`** (254 brugbare) |
| **Produktion (VLAN 20)** | 80 | 120 | 120 | $2^7 = 128$ | **`/25`** (126 brugbare) |
| **Administration (VLAN 10)** | 35 | 50 | 50 | $2^6 = 64$ | **`/26`** (62 brugbare) |
| **IT (VLAN 30)** | 20 | 30 | 30 | $2^5 = 32$ | **`/27`** (30 brugbare) |
| **Management (VLAN 99)** | - | 10 | 10 | $2^4 = 16$ | **`/28`** (14 brugbare) |

---

## 🧮 VLSM Beregningsmetode og Trin-for-Trin Opdeling

Ved VLSM skal subnets altid tildeles i rækkefølge fra det **største** til det **mindste** for at undgå overlap og sikre, at netværksgrænserne (boundaries) flugter korrekt med binære adresser.

### Trin 1: Gæstenetværk (VLAN 40)
* **Krav:** 200 enheder.
* **Beregning:** Den mindste potens af 2, der kan dække dette, er $2^8 = 256$ adresser. En subnetmaske på `/24` giver $256 - 2 = 254$ brugbare IP-adresser.
* **Tildelt blok:** **`10.20.0.0/24`**
* **Maske:** `255.255.255.0`
* **Adresser:** `10.20.0.0` - `10.20.0.255`

### Trin 2: Produktion (VLAN 20)
* **Krav:** 120 enheder.
* **Beregning:** Den mindste potens af 2, der dækker dette, er $2^7 = 128$ adresser. En subnetmaske på `/25` giver $128 - 2 = 126$ brugbare IP-adresser.
* **Næste ledige adresse efter Trin 1:** `10.20.1.0`.
* **Tildelt blok:** **`10.20.1.0/25`**
* **Maske:** `255.255.255.128`
* **Adresser:** `10.20.1.0` - `10.20.1.127`

### Trin 3: Administration (VLAN 10)
* **Krav:** 50 enheder.
* **Beregning:** Den mindste potens af 2, der dækker dette, er $2^6 = 64$ adresser. En subnetmaske på `/26` giver $64 - 2 = 62$ brugbare IP-adresser.
* **Næste ledige adresse efter Trin 2:** `10.20.1.128`.
* **Tildelt blok:** **`10.20.1.128/26`**
* **Maske:** `255.255.255.192`
* **Adresser:** `10.20.1.128` - `10.20.1.191`

### Trin 4: IT (VLAN 30)
* **Krav:** 30 enheder.
* **Beregning:** Den mindste potens af 2, der dækker dette, er $2^5 = 32$ adresser. En subnetmaske på `/27` giver $32 - 2 = 30$ brugbare IP-adresser.
* **Næste ledige adresse efter Trin 3:** `10.20.1.192`.
* **Tildelt blok:** **`10.20.1.192/27`**
* **Maske:** `255.255.255.224`
* **Adresser:** `10.20.1.192` - `10.20.1.223`

### Trin 5: Management (VLAN 99)
* **Krav:** Ca. 10 netværksenheder (Core switches, Access switches, Router, etc.).
* **Beregning:** Den mindste potens af 2, der dækker dette, er $2^4 = 16$ adresser. En subnetmaske på `/28` giver $16 - 2 = 14$ brugbare IP-adresser.
* **Næste ledige adresse efter Trin 4:** `10.20.1.224`.
* **Tildelt blok:** **`10.20.1.224/28`**
* **Maske:** `255.255.255.240`
* **Adresser:** `10.20.1.224` - `10.20.1.239`

---

## 🗺️ Den Komplette IP-Plan (VLSM Tabel)

Herunder ses den færdige IP-plan for virksomheden, som skal konfigureres i udstyret. 

*Bemærk: Den **første brugbare IP-adresse** i hvert subnet er reserveret som **Default Gateway** (konfigureret på Core-switchene som den virtuelle HSRP Gateway IP).*

| VLAN-ID | Navn / Formål | Netværksadresse | Subnetmaske / CIDR | Første brugbare IP (Gateway) | Sidste brugbare IP | Broadcastadresse | Max brugbare Hosts |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **VLAN 40** | Gæster | `10.20.0.0` | `255.255.255.0` (`/24`) | `10.20.0.1` | `10.20.0.254` | `10.20.0.255` | 254 |
| **VLAN 20** | Produktion | `10.20.1.0` | `255.255.255.128` (`/25`) | `10.20.1.1` | `10.20.1.126` | `10.20.1.127` | 126 |
| **VLAN 10** | Administration | `10.20.1.128` | `255.255.255.192` (`/26`) | `10.20.1.129` | `10.20.1.190` | `10.20.1.191` | 62 |
| **VLAN 30** | IT | `10.20.1.192` | `255.255.255.224` (`/27`) | `10.20.1.193` | `10.20.1.222` | `10.20.1.223` | 30 |
| **VLAN 99** | Management | `10.20.1.224` | `255.255.255.240` (`/28`) | `10.20.1.225` | `10.20.1.238` | `10.20.1.239` | 14 |
| *Transit A* | *core-01 to R1* | `10.20.254.0` | `255.255.255.252` (`/30`) | `10.20.254.1` (R1) | `10.20.254.2` (core-01) | `10.20.254.3` | 2 |
| *Transit B* | *core-02 to R1* | `10.20.254.4` | `255.255.255.252` (`/30`) | `10.20.254.5` (R1) | `10.20.254.6` (core-02) | `10.20.254.7` | 2 |

---

## 📈 Skalerbarhed og Fremtidig Vækst

En af de helt store fordele ved dette design er den ekstreme skalerbarhed:

1. **Uudnyttet adresseplads:** Vores VLSM-planlægning bruger kun adresser i områderne `10.20.0.x` og `10.20.1.x`. Det betyder, at hele det resterende område fra **`10.20.2.0` til `10.20.255.255`** (svarende til over **98% af hele `/16`-netværket**) er fuldstændig frit og uberørt!
2. **Nem udvidelse:** Hvis virksomheden opretter en ny afdeling (f.eks. "Lager" med 60 enheder), kan vi nemt tildele et `/26` netværk startende fra `10.20.2.0/26` uden at skulle omstrukturere eller ændre på de eksisterende VLANs.
3. **OSPF Route Summarization:** Da alle vores aktive subnets ligger pænt samlet inden for `10.20.0.0` til `10.20.1.239`, kan Core-switchene lave en perfekt **route summarization** til `10.20.0.0/23` eller `10.20.0.0/22` op mod routeren i OSPF, hvilket optimerer routing-tabel ydeevnen markant.
