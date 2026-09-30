Gå til hovedindhold
Krav for gennemførelse
Del 3 – Logging og monitorering

Jeres hostingmiljø er nu opbygget med netværksinfrastruktur, segmentering og virtuelle kundemiljøer.

Når et miljø sættes i drift, er det ikke tilstrækkeligt, at det fungerer på installationstidspunktet. En administrator skal kunne opdage fejl, følge belastningen på infrastrukturen og undersøge hændelser.

I denne del skal I derfor etablere en central løsning til logging og monitorering med PRTG Network Monitor.

Løsningen skal give jer overblik over både den fysiske netværksinfrastruktur og de virtuelle kundemiljøer.

Arbejdet understøtter fagets mål omkring logging, NetFlow og andre teknologier til overvågning og fejlfinding.

1. PRTG-server

Opret en dedikeret virtuel maskine til PRTG Network Monitor.

PRTG-serveren skal placeres på et passende management-netværk og skal kunne kommunikere med de systemer, der skal overvåges.

Installer og konfigurer PRTG.

Dokumentér:

Serverens placering i netværket
IP-adresse
DNS-konfiguration
Hvilke netværk PRTG skal kunne kommunikere med
Eventuelle nødvendige firewall-regler
PRTG skal kunne overvåge infrastrukturen uden at ændre den isolation mellem kunderne, som I etablerede tidligere i projektet.

2. Design jeres monitorering

Inden I tilføjer enheder til PRTG, skal I overveje, hvad der faktisk er relevant at overvåge.

Som minimum skal relevante dele af følgende indgå:

Proxmox-server
Routere
Layer 3-switches
Layer 2-switches
Kundernes webservere
I skal selv vælge, hvilke sensorer der giver mening på de forskellige enheder.

Det kan eksempelvis være:

Ping
Uptime
CPU-belastning
RAM-forbrug
Diskforbrug
Interface-status
Interface-trafik
Interface errors
HTTP/HTTPS
Målet er ikke at oprette flest mulige sensorer.

Sensorerne skal give information, som faktisk er relevant for driften og fejlfindingen af jeres miljø.

3. SNMP

Konfigurer SNMP på de netværksenheder, hvor det er relevant, og tilføj dem til PRTG.

PRTG skal som minimum kunne overvåge relevante interfaces og deres trafik.

Undersøg hvilke yderligere informationer jeres forskellige enheder kan levere via SNMP.

Det kan eksempelvis være:

CPU-belastning
Hukommelsesforbrug
Uptime
Interface utilization
Interface errors
Interface status
Hardwarestatus
I skal kunne forklare sammenhængen mellem:

PRTG → SNMP → enhed → MIB/OID

I skal desuden undersøge forskellen mellem SNMPv2c og SNMPv3 og kunne forklare de sikkerhedsmæssige forskelle.

SNMP indgår direkte i fagets mål for fejlfinding.

4. Monitorering af kundemiljøerne

De fire kundemiljøer fra Del 2 skal inddrages i monitoreringen.

Monitoreringen skal gøre det muligt at opdage problemer med kundernes services.

For hver kunde skal I som minimum kunne afgøre:

Om serveren er tilgængelig
Om webserveren svarer
Om relevante ressourcer er belastede
Om der er problemer med netværksforbindelsen
Kunderne skal fortsat være logisk adskilt.

PRTG må ikke anvendes som en genvej til at fjerne eller omgå den isolation, der tidligere er etableret.

5. Central logging

PRTG skal anvendes som central modtager af Syslog fra relevante netværksenheder.

Konfigurer jeres udstyr til at sende logs til PRTG.

I skal blandt andet kunne finde hændelser som:

Interface up/down
Login-forsøg
Systemfejl
Advarsler
Routing-relaterede hændelser
Andre relevante hændelser fra infrastrukturen
Alle relevante systemer skal anvende korrekt tid.

Konfigurer derfor NTP, så timestamps fra forskellige enheder kan sammenlignes.

I skal kunne bruge de centrale logs aktivt i forbindelse med fejlfinding.

Dette understøtter direkte målet om anvendelse af lokal logging, Syslog og debug til fejlfinding.

6. Alarmer og grænseværdier

En monitoreringsløsning skal kunne gøre administratoren opmærksom på problemer uden konstant manuel kontrol.

Konfigurer relevante alarmer og grænseværdier i PRTG.

Det kan eksempelvis være:

En server bliver utilgængelig
En webservice stopper
Et interface går down
Høj CPU-belastning
Højt RAM-forbrug
Lav diskplads
Høj netværksbelastning
Packet loss
I skal selv vælge relevante grænseværdier.

Det er ikke nødvendigvis en fordel at have flest mulige alarmer. Overvej hvilke hændelser der faktisk kræver en administrators opmærksomhed.

7. Dashboard

Opret et PRTG-dashboard, der giver et samlet overblik over jeres miljø.

Dashboardet skal gøre det muligt hurtigt at se:

Infrastrukturens generelle status
Netværksenheder
Proxmox
Kundeserverne
Kritiske services
Aktive fejl og alarmer
Dashboardet skal være designet, så en administrator hurtigt kan besvare spørgsmålet:

Er infrastrukturen sund lige nu?

8. NetFlow – hvor det er muligt

NetFlow er kun en mindre del af denne opgave.

Undersøg om en eller flere af de netværksenheder, I anvender, understøtter NetFlow, Flexible NetFlow eller NetFlow-Lite.

Hvis I har en understøttet enhed, skal I konfigurere én relevant NetFlow-eksport til PRTG og undersøge de indsamlede trafikdata.

I skal eksempelvis undersøge:

Source og destination
Protokoller
Porte
Trafikmængder
Hvilke systemer der genererer trafik
I skal kunne forklare den grundlæggende forskel mellem:

SNMP
Viser blandt andet status, belastning og interface-statistik.

Syslog
Viser hændelser rapporteret af systemerne.

NetFlow
Giver information om de trafikflows, der bevæger sig gennem en understøttet netværksenhed.

Hvis jeres udstyr ikke understøtter NetFlow

Hvis de enheder, I arbejder med, ikke understøtter en relevant NetFlow-teknologi, skal I ikke konfigurere NetFlow.

I skal heller ikke udskifte udstyr eller ændre jeres netværksdesign alene for at kunne anvende NetFlow.

I skal blot kunne forklare, hvad NetFlow bruges til, og hvordan det adskiller sig fra SNMP og Syslog.

NetFlow indgår i fagmålet sammen med andre teknologier til overvågning af netværket.

9. Test monitoreringsløsningen

Når løsningen er etableret, skal I kontrollere, om den faktisk kan bruges til fejlfinding.

Fremprovokér forskellige fejl i jeres miljø.

Det kan eksempelvis være:

Stop en webserver
Luk et interface
Stop en VM
Skab høj CPU-belastning
Skab høj netværkstrafik
Stop en service
Fjern forbindelsen til en VM
Observer hvordan hændelserne registreres i PRTG.

Brug:

Sensorer → grafer → alarmer → Syslog

til at undersøge problemet.

I skal kunne bruge monitoreringen til at afgøre:

Hvad er fejlen?

Hvor befinder fejlen sig?

Hvornår opstod den?

Hvilke systemer eller kunder er påvirket?

10. Dokumentation

Dokumentér jeres monitoreringsløsning som en del af den samlede projektdokumentation.

Dokumentationen skal som minimum indeholde:

PRTG-serverens placering
Overvågede enheder
Valgte sensorer
SNMP-konfiguration
Syslog-konfiguration
NTP
Alarmer og grænseværdier
Dashboard
Eksempel på registrering og fejlfinding af en hændelse
NetFlow-konfiguration, hvis det anvendes
Afslut med en kort vurdering af, om jeres monitoreringsløsning giver de nødvendige informationer til at kunne drifte det miljø, I har bygget.

