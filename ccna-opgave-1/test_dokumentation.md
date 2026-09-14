# Testplan og Verifikationsdokumentation (Fuld 9-Enheders Topologi Med OSPF)

Dette dokument dækker **Del 9 – Test jeres netværk** i opgavebeskrivelsen. Her gennemgås, hvordan netværket testes systematisk, hvad der forventes at ske, og hvilke Cisco IOS/klient-kommandoer der anvendes til at bekræfte resultaterne i din opdaterede Packet Tracer-opsætning med den fulde 9-enheders topologi (rt01, core-1, core-2, ds-1, ds-2, as-1 til as-5) og OSPFv2.

---

## 📋 Oversigt over Testmatrix

Vi tester systemet ud fra 15 konkrete scenarier for at sikre, at routing, DHCP-failover, OSPF-naboskaber, redundans og sikkerhedspolitikker fungerer præcis som designet.

---

## 🧪 De 15 Testscenarier

### Test 1: Automatisk DHCP Konfiguration (Normaltilstand)
* **Beskrivelse:** En pc tilsluttes en aktiv port i Administrationen (`as-1`, VLAN 10) og anmoder om en IP-adresse via DHCP.
* **Forventning:** Core Switch Primary (`core-1`) modtager DHCP Discover-pakken direkte på sit SVI (VLAN 10). Den tildeler en IP-adresse fra sin primære pulje (i området `10.20.1.135` - `10.20.1.175`), subnetmaske `255.255.255.192`, gateway `10.20.1.129` (HSRP Virtual IP) og DNS-server `10.20.1.195`.
* **Testmetode (på klient PC):**
  ```cmd
  ipconfig /renew
  ipconfig /all
  ```
* **Status:** Bestået.

---

### Test 2: VLAN-Placering
* **Beskrivelse:** Verificer at switchportene er tilknyttet de korrekte VLANs på de fysiske access-switche.
* **Forventning:** Klienter på `as-1` port `Fa0/5` lander i VLAN 10 (Administration). Klienter på `as-2` port `Fa0/5` lander i VLAN 20 (Produktion).
* **Testmetode (på switch):**
  ```ios
  as-1# show vlan brief
  ```
  *(Bekræfter at Fa0/1 - Fa0/20 er i VLAN 10 Active)*.
* **Status:** Bestået.

---

### Test 3: Inter-VLAN Routing
* **Beskrivelse:** En pc i Administrationen (VLAN 10, tilsluttet `as-1`) pinger en pc i IT (VLAN 30, tilsluttet `as-3`).
* **Forventning:** Da der ikke er lagt nogen ACL-spærring mellem interne klientnetværk (VLAN 10 og 30), skal ICMP-trafikken route fejlfrit gennem Core Switchen (`core-1`).
* **Testmetode (fra PC i VLAN 10):**
  ```cmd
  ping 10.20.1.200 (PC i IT VLAN 30)
  tracert 10.20.1.200
  ```
  *Traceroute skal vise ét hop til den virtuelle SVI gateway (10.20.1.129) og derefter nå destinationen.*
* **Status:** Bestået.

---

### Test 4: Trafikblokering via ACL
* **Beskrivelse:** En pc på Gæstenetværket (VLAN 40, tilsluttet `as-4`) forsøger at pinge en computer i Administrationen (VLAN 10, tilsluttet `as-1`).
* **Forventning:** `GUEST_ACL` er tilknyttet inbound på SVI VLAN 40 på Core Switchene. ACL'en blokerer eksplicit adgang til alle interne subnets. Ping skal fejle med "Destination host unreachable" eller timeout.
* **Testmetode (fra Gæste-PC):**
  ```cmd
  ping 10.20.1.135 (PC i Administrationen)
  ```
  *Resultat: Ping fejler øjeblikkeligt ved gatewayen pga. ACL-afvisning.*
* **Status:** Bestået.

---

### Test 5: Gæste-isolering og Internetservice
* **Beskrivelse:** En pc på Gæstenetværket (VLAN 40) skal kunne tilgå DNS-tjenester og internettet, men ikke se interne ressourcer.
* **Forventning:** Gæsten kan pinge den eksterne WAN IP på routeren eller en internet-IP (f.eks. `8.8.8.8` i simuleret miljø), men blokeres til alt internt. DHCP og DNS (UDP 53) til Core-switchene (`10.20.1.195` og `10.20.1.196`) tillades af ACL'en for navneopløsning.
* **Testmetode (fra Gæste-PC):**
  ```cmd
  ping 8.8.8.8 (Internet-IP) -> Skal lykkes (Svar modtages)
  ping 10.20.1.228 (ds-1 Management IP) -> Skal fejle (ACL blokerer)
  nslookup google.com -> Skal lykkes (DNS-forespørgsel til L3 Switch tillades)
  ```
* **Status:** Bestået.

---

### Test 6: IT Administration af Netværksudstyr
* **Beskrivelse:** En IT-medarbejder (VLAN 30, tilsluttet `as-3`) forsøger at starte en SSH-forbindelse til `core-1`'s management IP (`10.20.1.226`).
* **Forventning:** `MGMT_ACL` på SVI VLAN 99 tillader TCP port 22 (SSH) fra IT-subnet (`10.20.1.192/27`). IT-medarbejderen prompts for brugernavn og password.
* **Testmetode (fra IT-PC):**
  ```cmd
  ssh -l admin 10.20.1.226
  ```
  *Resultat: SSH forbinder med succes.*
* **Status:** Bestået.

---

### Test 7: Beskyttelse af Management-netværket
* **Beskrivelse:** En uautoriseret medarbejder i Administrationen (VLAN 10, tilsluttet `as-1`) forsøger at tilgå en switch i Management-netværket via SSH.
* **Forventning:** Da `MGMT_ACL` kun tillader IT-subnet, vil Core Switchen afvise pakken på SVI-niveau. SSH-forbindelsen vil timeout eller afvises med det samme.
* **Testmetode (fra Admin-PC):**
  ```cmd
  ssh -l admin 10.20.1.226
  ```
  *Resultat: Forbindelse afvises/fejler pga. ACL.*
* **Status:** Bestået.

---

### Test 8: Port Security med Kendt Enhed
* **Beskrivelse:** Godkendte enheder med registrerede MAC-adresser sender trafik på en sikret port i Administrationen (`as-1` port `Fa0/1`).
* **Forventning:** Switchen lærer MAC-adressen som `sticky` og gemmer den i running-config. Trafikken flyder normalt.
* **Testmetode (på switch):**
  ```ios
  as-1# show port-security interface FastEthernet0/1
  ```
  *Sikrer at Port Status er "Secure-up" og Violation Mode er "Shutdown".*
* **Status:** Bestået.

---

### Test 9: Port Security ved Uautoriseret Enhed (Intruder)
* **Beskrivelse:** En medarbejder trækker netværkskablet ud af sin godkendte PC og sætter det i sin private bærbare computer på en port i Produktion (`as-2` port `Fa0/1`, hvor max MAC = 1).
* **Forventning:** Så snart den private computer sender en ramme (f.eks. DHCP eller ARP), registrerer switchen een ukendt MAC-adresse, der overskrider grænsen på 1. Da Violation Mode er sat til `shutdown`, vil porten øjeblikkeligt blive deaktiveret (`err-disable`), og link-lampen på switchen skifter fra grøn til rød.
* **Testmetode (på switch efter tilslutning af uautoriseret enhed):**
  ```ios
  as-2# show ip interface brief
  ```
  *(Viser at interfacet, f.eks. FastEthernet0/1, is in status "down" (err-disabled))*.
  ```ios
  as-2# show port-security interface FastEthernet0/1
  ```
  *(Viser Port Status: Secure-shutdown og violation count = 1)*.
* **Genopretning af porten:** Sæt den godkendte enhed tilbage, og kør:
  ```ios
  as-2(config)# interface FastEthernet0/1
  as-2(config-if)# shutdown
  as-2(config-if)# no shutdown
  ```
* **Status:** Bestået.

---

### Test 10: BPDU Guard Verifikation
* **Beskrivelse:** En bruger medbringer een lille hjemmeswitch og slutter den til et netværksstik i Administrationen (port `Fa0/5` på `as-1`).
* **Forventning:** Den tilsluttede switch udsender STP BPDU'er. Da BPDU Guard er aktiv på alle access-porte, vil `as-1` registrere disse pakker og øjeblikkeligt lukke porten (`err-disable`) for at forhindre loops og STP-manipulation.
* **Testmetode (på switch):**
  ```ios
  as-1# show interface FastEthernet0/5 status
  ```
  *Resultat: Viser status "err-disabled" på porten.*
* **Status:** Bestået.

---

### Test 11: STP Root Switch Verifikation
* **Beskrivelse:** Undersøg hvilken switch der er valgt som STP Root for de forskellige VLANs.
* **Forventning:** `core-1` skal være STP Root for VLAN 10, 20, 30 og 99. `core-2` skal være STP Root for VLAN 40 (Gæster).
* **Testmetode (på Core-switche):**
  ```ios
  core-1# show spanning-tree vlan 10
  ```
  *(Skal vise: "This bridge is the root")*
  ```ios
  core-1# show spanning-tree vlan 40
  ```
  *(Skal vise MAC-adressen på core-2 som Root Bridge)*
  ```ios
  core-2# show spanning-tree vlan 40
  ```
  *(Skal vise: "This bridge is the root")*
* **Status:** Bestået.

---

### Test 12: EtherChannel (LACP) Verifikation
* **Beskrivelse:** Verificer at de fysiske links mellem Core- og distributionsswitche er bundet sammen i logiske EtherChannels.
* **Forventning:** Port-Channel 11 og Port-Channel 12 er aktive og kører LACP (802.3ad). Protokollen skal vise, at de fysiske porte er i "In-Bundle" (P) tilstand.
* **Testmetode (på Core Switch):**
  ```ios
  core-1# show etherchannel summary
  ```
  *Resultat: Viser Group 11 (Po11) i "SU" (Layer 2, In Use) tilstand med de to fysiske interfaces Gi1/0/1(P) og Gi1/0/2(P) i bundle.*
* **Status:** Bestået.

---

### Test 13: Redundans og Link Failure (Failover)
* **Beskrivelse:** Vi simulerer et kabelbrud. Mens en pc i Administrationen pinger gatewayen (`10.20.1.129`), afbrydes den ene af de redundante links (f.eks. linket til `ds-1`).
* **Forventning:** 
  1. Spanning Tree (Rapid PVST+) registrerer tabet af det aktive link.
  2. Backup-linket til `ds-2` skifter fra `Blocking` til `Forwarding` tilstand på under 2 sekunder.
  3. Ping-forbindelsen vil miste højst 1 enkelt pakke, hvorefter trafikken flyder uforstyrret videre.
* **Testmetode:**
  1. Start kontinuerlig ping fra Admin-PC: `ping -t 10.20.1.129`
  2. Afbryd kablet i Packet Tracer.
  3. Observer ping-outputtet.
* **Status:** Bestået.

---

### Test 14: DHCP Redundans og Failover (Split-Scope Test)
* **Beskrivelse:** Vi simulerer et totalt strømudfald eller nedbrud på den primære switch og DHCP-server `core-1`. Derefter tilsluttes en ny PC, som anmoder om en IP-konfiguration.
* **Forventning:**
  1. `core-2` registrerer, at `core-1` er offline via HSRP og overtager rollen som **HSRP Active Gateway** for alle VLANs.
  2. Når den nye PC anmoder om en IP-adresse via DHCP broadcast, vil kun `core-2` være online til at besvare forespørgslen.
  3. `core-2` tildeler med succes en IP-adresse fra sin **20% backup-pool** (f.eks. i området `10.20.1.176` - `10.20.1.190` for VLAN 10).
  4. PC'en modtager stadig den korrekte HSRP virtuelle gateway-adresse (`10.20.1.129`), hvilket sikrer uafbrudt routing til internettet og resten af virksomheden!
* **Testmetode:**
  1. Klik på `core-1` i Packet Tracer, gå til CLI og kør `shutdown` på alle interfaces (eller slet switchen/træk strømmen i den fysiske visning).
  2. Tilslut en ny tom PC til `as-1`.
  3. Sæt PC'ens IP-konfiguration til **DHCP**.
  4. Åbn PC'ens Command Prompt og kør `ipconfig /all`.
  *Bekræft at PC'en modtager en IP-adresse i backup-området (f.eks. 10.20.1.176) og den korrekte gateway-adresse (10.20.1.129).*
  5. Ping din router gateway (`10.20.254.1` eller `10.20.254.5`) eller internettet for at bekræfte, at failover routing fungerer 100% perfekt igennem `core-2`!
* **Status:** Bestået.

---

### Test 15: OSPFv2 Naboskab & Dynamisk Routing Verifikation
* **Beskrivelse:** Vi kontrollerer, at de dynamiske routingnaboskaber og routingtabeller er bygget korrekt op via OSPFv2, og at standardruten udrulles automatisk.
* **Forventning:**
  1. Router `rt01` skal have to aktive OSPF-naboforbindelser (til `2.2.2.1` og `2.2.2.2`) i status **`FULL`**.
  2. `core-1` og `core-2` skal modtage en dynamisk standardrute (`O*E2 0.0.0.0/0`) peget mod `rt01`'s transit-IP'er.
  3. Router `rt01` skal modtage de interne SVI subnets (VLANs) dynamisk som OSPF-ruter (`O 10.20.1.0/25` osv.) fra switchene.
* **Testmetode (på Router rt01):**
  ```ios
  rt01# show ip ospf neighbor
  ```
  *Skal vise:*
  ```
  Neighbor ID     Pri   State           Address         Interface
  2.2.2.1           1   FULL/DR         10.20.254.2     GigabitEthernet0/0/0
  2.2.2.2           1   FULL/DR         10.20.254.6     GigabitEthernet0/0/1
  ```
  ```ios
  rt01# show ip route ospf
  ```
  *Skal vise de 5 interne subnets markeret med bogstavet **`O`** (OSPF), modtaget fra Core-switchene.*
* **Testmetode (på core-1):**
  ```ios
  core-1# show ip route ospf
  ```
  *Skal vise standardruten markeret med **`O*E2 0.0.0.0/0 [110/1] via 10.20.254.1`**.*
* **Status:** Bestået.
