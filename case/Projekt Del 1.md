Infrastrukturprojekt – Del 1: Netværksplatform
Case
En virksomhed skal etablere en ny netværksplatform, som senere skal danne grundlag for virksomhedens server- og kundemiljøer.

Platformen skal bygges på en fælles fysisk infrastruktur, men samtidig kunne understøtte flere logisk adskilte miljøer. Løsningen skal være struktureret, skalerbar og dokumenteret, så infrastrukturen senere kan udvides med nye funktioner og tjenester.

I får ikke udleveret en færdig topologi. Det fysiske og logiske netværksdesign skal udarbejdes som en del af opgaven.

Tilgængeligt udstyr
Til løsningen er følgende udstyr til rådighed:

3 routere

2 Layer 3-switches

2 Layer 2-switches

1 fysisk server med 4 separate netværksinterfaces samt 2 × 10 Gbit/s interfaces

klienter til test og administration

Det er ikke et krav, at alt udstyr anvendes. Valg og fravalg af udstyr skal være en del af det samlede design.

Netværksmiljøer
Platformen skal i første omgang understøtte fire separate kundemiljøer:

Kunde A

Kunde B

Kunde C

Kunde D

Kunderne anvender den samme fysiske netværksinfrastruktur, men deres Layer 3-miljøer skal være logisk adskilt.

Hver kunde skal have sit eget IP-netværk, gateway og routingmiljø. En kunde må ikke automatisk kunne kommunikere med eller se routes fra de øvrige kunders miljøer.

Ud over kundemiljøerne skal der etableres et separat managementnetværk til administration af infrastrukturen.

Fysisk og logisk design
Der skal udarbejdes et fysisk og logisk netværksdesign for den samlede platform.

Designet skal omfatte placering og funktion af routere, Layer 3-switches og Layer 2-switches samt forbindelserne mellem enhederne.

Layer 2- og Layer 3-funktioner skal placeres hensigtsmæssigt i infrastrukturen. Netværket skal designes, så trafikvejen gennem infrastrukturen er tydelig og kan dokumenteres og fejlfindes.

Designet skal samtidig tage højde for, at infrastrukturen senere skal kunne udvides uden en komplet ændring af den grundlæggende arkitektur.

IP-adressering
Der skal udarbejdes en samlet og struktureret IP-plan.

IP-planen skal indeholde kundernes netværk, managementnetværket samt nødvendige transitnetværk mellem Layer 3-enheder.

Planen skal som minimum dokumentere:

netværksnavn og funktion

netværksadresse

prefix/netmaske

gateway

infrastrukturelle adresser

adressering af Layer 3-forbindelser

Der anvendes private IPv4-adresser.

Adresseplanen skal give mulighed for senere udvidelse af infrastrukturen.

Layer 2
Hvor flere logiske netværk anvender den samme switchinginfrastruktur, skal trafikken segmenteres på Layer 2.

VLAN skal anvendes, hvor det er relevant for designet.

Trunk- og access-forbindelser skal konfigureres i overensstemmelse med den valgte topologi.

Redundante Layer 2-forbindelser skal håndteres, så der ikke opstår switching-loops. STP skal anvendes og konfigureres i forhold til den ønskede trafikvej gennem infrastrukturen.

Hvor flere fysiske forbindelser med fordel kan anvendes som én logisk forbindelse, kan EtherChannel anvendes.

Layer 3 og routing
Routing skal etableres mellem de dele af infrastrukturen, hvor Layer 3-kommunikation er nødvendig.

Kundernes routing skal holdes adskilt ved hjælp af VRF.

Der skal etableres en separat VRF for hvert kundemiljø.

Den enkelte VRF skal have sin egen routing table, og interfaces og netværk skal placeres i den korrekte routingkontekst.

Global Routing Table skal fortsat eksistere som en separat routingkontekst på de relevante Layer 3-enheder.

Løsningen skal gøre det muligt at dokumentere forskellen mellem routes placeret i Global Routing Table og routes placeret i de enkelte VRF-routingtabeller.

Route Leaking
Som udgangspunkt skal kundemiljøerne være isoleret fra hinanden.

Der skal efterfølgende etableres kontrolleret deling af udvalgte routes mellem routingmiljøerne.

Global Routing Table skal anvendes som en del af route-leaking-designet.

Kun de nødvendige routes skal deles. De øvrige kundemiljøer skal fortsat være adskilt.

Routing skal etableres i begge retninger, hvor dette er nødvendigt for fungerende kommunikation og returtrafik.

Route leaking skal kunne verificeres ved at sammenligne routingtabellerne før og efter implementeringen.

Management
Der skal etableres et separat managementnetværk til administration af infrastrukturen.

Relevante routere, switches og øvrige infrastrukturelementer skal kunne administreres gennem dette netværk.

Managementnetværket skal være adskilt fra kundernes almindelige trafik og må ikke være frit tilgængeligt fra kundemiljøerne.

Adgang til management skal begrænses til de systemer og netværk, der har et administrativt behov.

Fysisk server
Virksomheden har en fysisk server, som senere skal anvendes til virksomhedens server- og kundemiljøer.

Serveren har fire separate netværksinterfaces samt to 10 Gbit/s interfaces.

I denne del af projektet skal serveren ikke installeres eller konfigureres.

Netværksdesignet skal dog tage højde for, at serveren senere skal kunne forbindes til flere af de etablerede netværksmiljøer.

Den konkrete anvendelse og konfiguration af serveren introduceres i en senere del af projektet.

Redundans
Netværksdesignet skal så vidt muligt undgå unødvendige single points of failure.

Redundans skal implementeres på de steder, hvor det giver teknisk mening i den valgte arkitektur.

Redundante forbindelser og enheder skal konfigureres, så infrastrukturen fortsat kan fungere ved relevante link- eller enhedsfejl.

Redundans skal kunne testes ved kontrolleret at afbryde forbindelser eller enheder og observere netværkets reaktion.

Sikkerhed og adgang
Adgang mellem forskellige dele af infrastrukturen skal begrænses i forhold til deres funktion.

Kundernes netværk skal som udgangspunkt være isoleret fra hinanden.

Managementnetværket skal beskyttes mod adgang fra kundemiljøerne.

Hvor kommunikation mellem forskellige netværk er nødvendig, skal denne etableres kontrolleret og begrænses til den nødvendige trafik.

Verifikation og fejlfinding
Den færdige løsning skal verificeres systematisk.

Test skal både omfatte trafik, der forventes at fungere, og trafik, der forventes at blive afvist eller ikke være routbar.

Der skal blandt andet verificeres:

Layer 2-forbindelser

VLAN og trunks

Layer 3-forbindelser

IP-adressering

routing

VRF

separate routingtabeller

isolation mellem kundemiljøer

route leaking

managementadgang

redundans

Fejlfinding skal foretages systematisk gennem trafikvejen fra afsender til destination.

Relevante status-, routing-, interface- og logkommandoer skal anvendes til at identificere og dokumentere fejl.

Dokumentation
Den implementerede løsning skal dokumenteres løbende.

Dokumentationen skal som minimum indeholde:

fysisk netværksdiagram

logisk netværksdiagram

IP-plan

VLAN-plan

routingdesign

VRF-design

managementdesign

relevante konfigurationer

testresultater

dokumentation af væsentlige designvalg

Diagrammer og dokumentation skal afspejle den løsning, der faktisk er implementeret.

Aflevering af Del 1
Ved afslutningen af Del 1 skal der være etableret en fungerende fysisk og logisk netværksplatform.

Platformen skal have Layer 2- og Layer 3-segmentering, separate kundemiljøer, management, routing og kontrolleret route leaking.

Løsningen skal være testet og dokumenteret.

Den etablerede platform bevares og danner fundament for næste del af projektet, hvor infrastrukturen udvides med nye krav og funktioner.