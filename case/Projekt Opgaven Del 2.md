Gå til hovedindhold
Krav for gennemførelse
Infrastrukturprojekt – Del 2: Virtualiseringsplatform

Case

Netværksinfrastrukturen fra Del 1 er etableret og skal nu danne grundlag for virksomhedens serverplatform.

Virksomheden ønsker at konsolidere kundernes servere på en fælles fysisk virtualiseringsplatform. Kunde A, B, C og D skal derfor kunne anvende den samme fysiske server, uden at kunderne får adgang til hinandens virtuelle maskiner, netværk eller administration.

Den eksisterende netværksstruktur fra Del 1 skal så vidt muligt genbruges. Virtualiseringsplatformen skal derfor integreres med de VLAN, IP-netværk og routingmiljøer, der allerede er etableret.

Virtualiseringsplatform

Den fysiske server skal installeres med Proxmox VE.

Installationen skal udføres, så serveren efterfølgende kan administreres gennem virksomhedens managementnetværk.

Serverens managementadresse, gateway, DNS og øvrige netværksindstillinger skal passe ind i den eksisterende IP-plan.

Installationen og den grundlæggende konfiguration skal dokumenteres.

Kundemiljøer

Virtualiseringsplatformen skal understøtte de samme fire kunder som netværksinfrastrukturen:

Kunde A
Kunde B
Kunde C
Kunde D
Hver kunde skal etableres som et selvstændigt miljø på Proxmox-platformen.

Der skal oprettes en Resource Pool for hver kunde, hvor kundens virtuelle maskiner og relevante ressourcer placeres.

Resource Pools skal anvendes, så kundernes ressourcer kan organiseres og administreres separat.

Virtuelle netværk

Hver kunde skal have sit eget virtuelle netværk på Proxmox.

Der skal etableres en separat Linux Bridge for hvert kundemiljø.

De virtuelle netværk skal forbindes til den eksisterende fysiske netværksinfrastruktur og kundernes eksisterende VLAN.

Strukturen skal følge princippet:

Kundens VM → Linux Bridge → fysisk netværksinterface → VLAN → fysisk netværk → kundens routingmiljø

Kunde A, B, C og D skal dermed kunne anvende den samme virtualiseringsplatform, samtidig med at deres netværkstrafik fortsat er segmenteret.

Proxmox-netværksdesignet skal dokumenteres, så sammenhængen mellem fysisk interface, bridge, VLAN og kundemiljø tydeligt fremgår.

Virtuelle maskiner

Hver kunde skal have mindst én virtuel server.

Der skal derfor oprettes minimum fire virtuelle maskiner:

Webserver Kunde A
Webserver Kunde B
Webserver Kunde C
Webserver Kunde D
Serverne kan etableres med et simpelt Linux-operativsystem.

På hver virtuel maskine skal der installeres en simpel webserver, som gør det muligt at identificere den enkelte kunde.

Webserverens indhold skal tydeligt vise, hvilket kundemiljø serveren tilhører.

De virtuelle maskiner skal placeres i den korrekte Resource Pool og tilsluttes kundens korrekte virtuelle netværk.

IP-adressering skal følge den eksisterende IP-plan fra Del 1.

Sammenhæng mellem fysisk og virtuelt netværk

Virtualiseringsplatformen bliver nu en del af den eksisterende netværksinfrastruktur.

Det virtuelle netværk skal derfor ikke behandles som et separat system.

For hver kunde skal hele trafikvejen kunne dokumenteres fra den virtuelle maskine gennem virtualiseringsplatformen og videre ud i det fysiske netværk.

Der skal være sammenhæng mellem:

VM-interface
Linux Bridge
fysisk serverinterface
VLAN
switchinfrastruktur
gateway
VRF
routing
Den eksisterende isolation mellem kunderne fra Del 1 skal bevares efter integrationen med Proxmox.

Brugere og rettigheder

Hver kunde skal have sin egen bruger på Proxmox-platformen.

Der skal etableres adgangskontrol, så en kunde kun har adgang til de ressourcer, der tilhører kundens eget miljø.

Kunde A må eksempelvis kunne administrere de ressourcer, der er placeret i Kunde A's Resource Pool, men må ikke kunne administrere eller se Kunde B, C eller D's virtuelle maskiner.

Rettigheder skal tildeles efter princippet om mindst nødvendige rettigheder.

Kundebrugere skal ikke have administrative rettigheder til selve Proxmox-platformen.

Der skal oprettes en passende rolle eller anvendes en eksisterende rolle, som giver kunderne de nødvendige VM-rettigheder uden at give adgang til den underliggende infrastruktur.

Rettighedsdesignet skal dokumenteres med brugere, roller, Resource Pools og tildelte permissions.

Proxmox Firewall

Proxmox Firewall skal aktiveres og anvendes som en del af platformens sikkerhedsdesign.

Firewallregler skal beskytte både virtualiseringsplatformen og de enkelte kundemiljøer.

Reglerne skal tage udgangspunkt i princippet om kun at tillade den trafik, som er nødvendig.

Kundernes webservere skal kunne modtage den nødvendige webtrafik.

Managementtrafik skal begrænses til relevante administrationsnetværk.

Trafik mellem kundemiljøerne skal som udgangspunkt ikke være tilladt.

Firewallkonfigurationen skal understøtte den eksisterende segmentering fra Del 1 og må ikke anvendes som erstatning for VLAN- og VRF-segmenteringen.

Isolation mellem kunderne

Kundeadskillelsen skal eksistere på flere niveauer.

På virtualiseringsplatformen skal kunderne være adskilt gennem:

Resource Pools
brugerrettigheder
virtuelle netværk
VLAN
firewallregler
På den eksisterende netværksinfrastruktur fortsætter segmenteringen gennem de teknologier, der blev etableret i Del 1.

En fejl eller forkert konfiguration på ét niveau må så vidt muligt ikke automatisk give en kunde adgang til en anden kundes ressourcer.

Test og verifikation

Den færdige platform skal testes både som administrator og som de enkelte kundebrugere.

Det skal verificeres, at alle fire virtuelle webservere fungerer på deres respektive netværk.

Netværkstest skal dokumentere korrekt VLAN-tilknytning, gateway, routing og kundeadskillelse.

Firewallregler skal testes med både trafik, der skal accepteres, og trafik, der skal afvises.

Brugerrettigheder skal testes ved at logge ind som de enkelte kundebrugere.

Det skal dokumenteres, at en kundebruger kan tilgå og administrere sine egne tildelte virtuelle ressourcer, men ikke kan administrere eller få adgang til de øvrige kunders virtuelle maskiner.

Testresultaterne skal dokumentere både forventet og faktisk resultat.

Dokumentation

Del 2 skal dokumenteres som en udvidelse af dokumentationen fra Del 1.

Dokumentationen skal som minimum indeholde:

installation og grundkonfiguration af Proxmox VE
managementkonfiguration
fysisk netværkstilknytning
Linux Bridges
VLAN-tilknytning
Resource Pools
virtuelle maskiner
IP-adresser
bruger- og rettighedsstruktur
firewallkonfiguration
testresultater
relevante konfigurationer
opdateret fysisk og logisk netværksdiagram
Dokumentationen skal vise sammenhængen mellem den fysiske netværksinfrastruktur fra Del 1 og den nye virtualiseringsplatform.

