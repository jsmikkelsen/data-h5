# Cisco IOS-XE & FortiOS Konfigurationsskabeloner (Version 2)

Dette dokument indeholder komplette, produktionsklare og grundigt kommenterede konfigurationsskabeloner for alle enheder i netværksplatformen. Alle parametre (IP-adresser, VLAN-numre, HSRP-prioriteter og VRF-kontekster) stemmer 100% overens med den godkendte v2 IP- og VLAN-plan.

---

## 1. core-sw01 (Cisco Catalyst 3650 - Primær Core)

Denne switch agerer Active Gateway for **VLAN 10 (Kunde Alfa)** og **VLAN 20 (Kunde Bravo)** samt **VLAN 99 (Management)**, og Standby Gateway for VLAN 30 (Charlie) og 40 (Delta).

```cisco
! --- SYSTEM & MANAGEMENT ---
hostname core-sw01
!
enable secret 5 $1$mERf$hx5g76Y1A1vL1v3fG4yv11
!
username admin privilege 15 secret admin123
!
ip domain-name netic.dk
ip ssh version 2
!
line con 0
 exec-timeout 5 0
 logging synchronous
line vty 0 15
 login local
 transport input ssh
 exec-timeout 5 0
 logging synchronous
!
! --- OPRET VRF'ER (VRF-LITE) ---
ip vrf VRF_ALFA
 rd 65001:10
 route-target export 65001:10
 route-target import 65001:10
 route-target export 65001:999   ! Eksporterer til Global (GRT)
 route-target import 65001:999   ! Importerer fra Global (GRT)
!
ip vrf VRF_BRAVO
 rd 65001:20
 route-target export 65001:20
 route-target import 65001:20
 route-target export 65001:999
 route-target import 65001:999
!
ip vrf VRF_CHARLIE
 rd 65001:30
 route-target export 65001:30
 route-target import 65001:30
 route-target export 65001:999
 route-target import 65001:999
!
ip vrf VRF_DELTA
 rd 65001:40
 route-target export 65001:40
 route-target import 65001:40
 route-target export 65001:999
 route-target import 65001:999
!
ip vrf VRF_MGMT
 rd 65001:99
 route-target export 65001:99
 route-target import 65001:99
!
! --- MULTILAYER SWITCHING ---
ip routing
!
! --- OPRET VLANS ---
vlan 10
 name Kunde_Alfa_LAN
vlan 20
 name Kunde_Bravo_LAN
vlan 30
 name Kunde_Charlie_LAN
vlan 40
 name Kunde_Delta_LAN
vlan 99
 name Management_Net
vlan 100
 name Transit_Core_L3
vlan 101
 name Transit_Edge_L3
!
! --- SPANNING TREE (RAPID-PVST+) ---
spanning-tree mode rapid-pvst
spanning-tree vlan 10,20,99 root primary
spanning-tree vlan 30,40 root secondary
!
! --- LAYER 3 INTERFACES (SVIs & VRF ALLOKERING) ---
interface Vlan10
 ip vrf forwarding VRF_ALFA
 ip address 192.168.10.2 255.255.255.0
 standby version 2
 standby 10 ip 192.168.10.1
 standby 10 priority 110
 standby 10 preempt
 standby 10 track GigabitEthernet1/1/1 20
!
interface Vlan20
 ip vrf forwarding VRF_BRAVO
 ip address 192.168.20.2 255.255.255.0
 standby version 2
 standby 20 ip 192.168.20.1
 standby 20 priority 110
 standby 20 preempt
 standby 20 track GigabitEthernet1/1/1 20
!
interface Vlan30
 ip vrf forwarding VRF_CHARLIE
 ip address 192.168.30.2 255.255.255.0
 standby version 2
 standby 30 ip 192.168.30.1
 standby 30 priority 100
 standby 30 preempt
!
interface Vlan40
 ip vrf forwarding VRF_DELTA
 ip address 192.168.40.2 255.255.255.0
 standby version 2
 standby 40 ip 192.168.40.1
 standby 40 priority 100
 standby 40 preempt
!
interface Vlan99
 ip vrf forwarding VRF_MGMT
 ip address 192.168.99.2 255.255.255.0
 standby version 2
 standby 99 ip 192.168.99.1
 standby 99 priority 110
 standby 99 preempt
!
! --- TRANSIT TIL EDGE (GLOBAL ROUTING TABLE) ---
interface Vlan101
 description Forbindelse mod FortiGate Edge Cluster
 ip address 192.168.101.2 255.255.255.248
 standby version 2
 standby 101 ip 192.168.101.4
 standby 101 priority 110
 standby 101 preempt
 standby 101 track GigabitEthernet1/1/1 20
!
! --- BACKPLANE LINK MOD CORE-SW02 (ROUTED PORT) ---
interface GigabitEthernet1/1/2
 description Inter-Core L3 link
 no switchport
 ip address 192.168.255.1 255.255.255.252
!
! --- UPLINK PORT MOD FORTIGATE (L2 TRUNK) ---
interface GigabitEthernet1/1/1
 description Uplink mod FortiGate Edge cluster Port 4
 switchport trunk allowed vlan 101
 switchport mode trunk
!
! --- TRUNK PORTE MOD ACCESS-SWITCHE (ETHERCHANNEL) ---
interface range GigabitEthernet1/0/1 - 2
 description LACP Trunk mod acc-sw01
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
 channel-group 1 mode active
!
interface Port-channel 1
 description Port-Channel mod acc-sw01
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
!
! --- ROUTE LEAKING & BGP ---
router bgp 65001
 bgp log-neighbor-changes
 ! Peering med core-sw02 i GRT
 neighbor 192.168.255.2 remote-as 65001
 neighbor 192.168.255.2 description Peering med core-sw02
 !
 address-family ipv4
  neighbor 192.168.255.2 activate
  network 192.168.101.0 mask 255.255.255.248
  ! Default route i GRT peger mod FortiGate Edge
  ip route 0.0.0.0 0.0.0.0 192.168.101.1
 exit-address-family
 !
 address-family ipv4 vrf VRF_ALFA
  redistribute connected
 exit-address-family
 !
 address-family ipv4 vrf VRF_BRAVO
  redistribute connected
 exit-address-family
 !
 address-family ipv4 vrf VRF_CHARLIE
  redistribute connected
 exit-address-family
 !
 address-family ipv4 vrf VRF_DELTA
  redistribute connected
 exit-address-family
!
! --- ALT. STATISK ROUTE LEAKING SNIPPET (Anvendes hvis BGP fravælges) ---
! ip route vrf VRF_ALFA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
! ip route vrf VRF_BRAVO 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
! ip route vrf VRF_CHARLIE 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
! ip route vrf VRF_DELTA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
! ip route 192.168.10.0 255.255.255.0 Vlan10 192.168.10.10 vrf VRF_ALFA
! ip route 192.168.20.0 255.255.255.0 Vlan20 192.168.20.10 vrf VRF_BRAVO
! ip route 192.168.30.0 255.255.255.0 Vlan30 192.168.30.10 vrf VRF_CHARLIE
! ip route 192.168.40.0 255.255.255.0 Vlan40 192.168.40.10 vrf VRF_DELTA
```

---

## 2. core-sw02 (Cisco Catalyst 3650 - Sekundær Core)

Denne switch agerer Active Gateway for **VLAN 30 (Kunde Charlie)** and **VLAN 40 (Kunde Delta)**, og Standby Gateway for VLAN 10 (Alfa), 20 (Bravo) og 99 (Management).

```cisco
! --- SYSTEM & MANAGEMENT ---
hostname core-sw02
!
enable secret 5 $1$mERf$hx5g76Y1A1vL1v3fG4yv11
!
username admin privilege 15 secret admin123
!
ip domain-name netic.dk
ip ssh version 2
!
line con 0
 exec-timeout 5 0
 logging synchronous
line vty 0 15
 login local
 transport input ssh
 exec-timeout 5 0
 logging synchronous
!
! --- OPRET VRF'ER ---
ip vrf VRF_ALFA
 rd 65001:10
 route-target export 65001:10
 route-target import 65001:10
 route-target export 65001:999
 route-target import 65001:999
!
ip vrf VRF_BRAVO
 rd 65001:20
 route-target export 65001:20
 route-target import 65001:20
 route-target export 65001:999
 route-target import 65001:999
!
ip vrf VRF_CHARLIE
 rd 65001:30
 route-target export 65001:30
 route-target import 65001:30
 route-target export 65001:999
 route-target import 65001:999
!
ip vrf VRF_DELTA
 rd 65001:40
 route-target export 65001:40
 route-target import 65001:40
 route-target export 65001:999
 route-target import 65001:999
!
ip vrf VRF_MGMT
 rd 65001:99
 route-target export 65001:99
 route-target import 65001:99
!
ip routing
!
! --- OPRET VLANS ---
vlan 10
 name Kunde_Alfa_LAN
vlan 20
 name Kunde_Bravo_LAN
vlan 30
 name Kunde_Charlie_LAN
vlan 40
 name Kunde_Delta_LAN
vlan 99
 name Management_Net
vlan 100
 name Transit_Core_L3
vlan 101
 name Transit_Edge_L3
!
! --- SPANNING TREE (RAPID-PVST+) ---
spanning-tree mode rapid-pvst
spanning-tree vlan 30,40 root primary
spanning-tree vlan 10,20,99 root secondary
!
! --- LAYER 3 INTERFACES (SVIs) ---
interface Vlan10
 ip vrf forwarding VRF_ALFA
 ip address 192.168.10.3 255.255.255.0
 standby version 2
 standby 10 ip 192.168.10.1
 standby 10 priority 100
 standby 10 preempt
!
interface Vlan20
 ip vrf forwarding VRF_BRAVO
 ip address 192.168.20.3 255.255.255.0
 standby version 2
 standby 20 ip 192.168.20.1
 standby 20 priority 100
 standby 20 preempt
!
interface Vlan30
 ip vrf forwarding VRF_CHARLIE
 ip address 192.168.30.3 255.255.255.0
 standby version 2
 standby 30 ip 192.168.30.1
 standby 30 priority 110
 standby 30 preempt
 standby 30 track GigabitEthernet1/1/1 20
!
interface Vlan40
 ip vrf forwarding VRF_DELTA
 ip address 192.168.40.3 255.255.255.0
 standby version 2
 standby 40 ip 192.168.40.1
 standby 40 priority 110
 standby 40 preempt
 standby 40 track GigabitEthernet1/1/1 20
!
interface Vlan99
 ip vrf forwarding VRF_MGMT
 ip address 192.168.99.3 255.255.255.0
 standby version 2
 standby 99 ip 192.168.99.1
 standby 99 priority 100
 standby 99 preempt
!
! --- TRANSIT TIL EDGE (GLOBAL ROUTING TABLE) ---
interface Vlan101
 description Forbindelse mod FortiGate Edge Cluster
 ip address 192.168.101.3 255.255.255.248
 standby version 2
 standby 101 ip 192.168.101.4
 standby 101 priority 100
 standby 10 preempt
!
! --- BACKPLANE LINK MOD CORE-SW01 (ROUTED PORT) ---
interface GigabitEthernet1/1/2
 description Inter-Core L3 link
 no switchport
 ip address 192.168.255.2 255.255.255.252
!
! --- UPLINK PORT MOD FORTIGATE (L2 TRUNK) ---
interface GigabitEthernet1/1/1
 description Uplink mod FortiGate Edge cluster Port 4
 switchport trunk allowed vlan 101
 switchport mode trunk
!
! --- TRUNK PORTE MOD ACCESS-SWITCHE (ETHERCHANNEL) ---
interface range GigabitEthernet1/0/1 - 2
 description LACP Trunk mod acc-sw02
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
 channel-group 1 mode active
!
interface Port-channel 1
 description Port-Channel mod acc-sw02
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
!
! --- ROUTE LEAKING & BGP ---
router bgp 65001
 neighbor 192.168.255.1 remote-as 65001
 neighbor 192.168.255.1 description Peering med core-sw01
 !
 address-family ipv4
  neighbor 192.168.255.1 activate
  network 192.168.101.0 mask 255.255.255.248
  ip route 0.0.0.0 0.0.0.0 192.168.101.1
 exit-address-family
 !
 address-family ipv4 vrf VRF_ALFA
  redistribute connected
 exit-address-family
 !
 address-family ipv4 vrf VRF_BRAVO
  redistribute connected
 exit-address-family
 !
 address-family ipv4 vrf VRF_CHARLIE
  redistribute connected
 exit-address-family
 !
 address-family ipv4 vrf VRF_DELTA
  redistribute connected
 exit-address-family
```

---

## 3. acc-sw01 (Cisco Catalyst 2960X - Access Switch)

Denne switch leverer L2-forbindelse til klienter og tilhørende VLAN-segmentering. Konfigurationen gælder ligeledes for `acc-sw02`.

```cisco
hostname acc-sw01
!
enable secret admin123
!
vlan 10
 name Kunde_Alfa_LAN
vlan 20
 name Kunde_Bravo_LAN
vlan 30
 name Kunde_Charlie_LAN
vlan 40
 name Kunde_Delta_LAN
vlan 99
 name Management_Net
!
spanning-tree mode rapid-pvst
!
! --- MANAGEMENT SVI ---
interface Vlan99
 ip address 192.168.99.11 255.255.255.0
 no shut
!
ip default-gateway 192.168.99.1
!
! --- TRUNK PORTE MOD CORE (ETHERCHANNEL) ---
interface range GigabitEthernet0/49 - 50
 description EtherChannel mod core-sw01
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
 channel-group 1 mode active
!
interface Port-channel 1
 description Trunk mod Core
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
!
! --- ACCESS PORTE TIL KUNDER ---
interface GigabitEthernet0/1
 description Forbindelse til Kunde Alfa Klient
 switchport access vlan 10
 switchport mode access
 spanning-tree portfast
 spanning-tree bpduguard enable
!
interface GigabitEthernet0/2
 description Forbindelse til Kunde Bravo Klient
 switchport access vlan 20
 switchport mode access
 spanning-tree portfast
 spanning-tree bpduguard enable
!
interface GigabitEthernet0/3
 description Forbindelse til Kunde Charlie Klient
 switchport access vlan 30
 switchport mode access
 spanning-tree portfast
 spanning-tree bpduguard enable
!
interface GigabitEthernet0/4
 description Forbindelse til Kunde Delta Klient
 switchport access vlan 40
 switchport mode access
 spanning-tree portfast
 spanning-tree bpduguard enable
!
! --- SERVER FORBEREDELSE (PORT CHANNEL) ---
interface range GigabitEthernet0/5 - 6
 description Redundant LACP Trunk til fysisk server (1G NICs)
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
 channel-group 2 mode active
!
interface Port-channel 2
 description Trunk til server data
 switchport trunk allowed vlan 10,20,30,40,99
 switchport mode trunk
```

---

## 4. fg-ha (FortiGate 60F - HA Active/Passive Cluster)

FortiGate CLI konfigurationen opsætter det redundante HA cluster (FGCP), tildeler IP-adresser på interfaces i Root/Global VDOM, definerer routing og grundlæggende firewall-regler med NAT (Port-Forwarding/Overload) til internettet.

```fortinet
# --- HA CONFIGURATION (UDFØRES PÅ BEGGE ENHEDER FØR SAMLING) ---
config system global
    set hostname "fg-ha-cluster"
end
config system ha
    set group-id 1
    set group-name "Netic-Core-HA"
    set mode a-p
    set hbdev "port5" 50 "port6" 50   # Port 5 & 6 allokeres til heartbeat
    set session-pickup enable          # Synkroniserer aktive TCP-forbindelser
    set priority 200                   # (Sæt til 100 på den sekundære firewall)
    set monitor "port4" "wan1"         # Monitorer interne og eksterne interfaces
end

# --- INTERFACES & IPS (SYNKRONSISERES AUTOMATISK VIA HA) ---
config system interface
    edit "port4"
        set vdom "root"
        set ip 192.168.101.1 255.255.255.248
        set allowaccess ping ssh https
        set description "Intern transit-interface mod Cisco 3650 Core"
    next
    edit "wan1"
        set vdom "root"
        set ip 192.168.200.1 255.255.255.252
        set allowaccess ping
        set description "WAN-interface mod Cisco 4331 ISP Router"
    next
    edit "port1"
        set vdom "root"
        set ip 192.168.99.254 255.255.255.0
        set allowaccess ping ssh https gui
        set description "Dedikeret ud-af-båndet management-port"
    next
end

# --- STATISK ROUTING ---
config router static
    edit 1
        set gateway 192.168.200.2
        set device "wan1"
        set comment "Default Route mod ISP (Cisco 4331)"
    next
    edit 2
        set dst 192.168.0.0 255.255.0.0
        set gateway 192.168.101.4       # Peger på Core-switchenes HSRP VIP i GRT
        set device "port4"
        set comment "Statisk rute til det samlede interne netværk"
    next
end

# --- ADRESSE OBJEKTER FOR SEGMENTER ---
config firewall address
    edit "Kunde-Alfa-LAN"
        set subnet 192.168.10.0 255.255.255.0
    next
    edit "Kunde-Bravo-LAN"
        set subnet 192.168.20.0 255.255.255.0
    next
    edit "Kunde-Charlie-LAN"
        set subnet 192.168.30.0 255.255.255.0
    next
    edit "Kunde-Delta-LAN"
        set subnet 192.168.40.0 255.255.255.0
    next
    edit "Management-Net"
        set subnet 192.168.99.0 255.255.255.0
    next
end

# --- FIREWALL POLICIES ---
config firewall policy
    # Tillad Kunde Alfa internetadgang
    edit 10
        set name "Kunde-Alfa-to-Internet"
        set srcintf "port4"
        set dstintf "wan1"
        set srcaddr "Kunde-Alfa-LAN"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set utm-status enable          # Aktiverer sikkerhedsscanning
        set ssl-ssh-profile "certificate-inspection"
        set ips-sensor "default"
        set nat enable                 # NAT aktiveres for WAN-overload (PAT)
    next
    # Tillad Kunde Bravo internetadgang
    edit 20
        set name "Kunde-Bravo-to-Internet"
        set srcintf "port4"
        set dstintf "wan1"
        set srcaddr "Kunde-Bravo-LAN"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set utm-status enable
        set ssl-ssh-profile "certificate-inspection"
        set ips-sensor "default"
        set nat enable
    next
    # Blokering fra Kunde-netværk til Management-netværk (Sikkerhedskrav)
    edit 90
        set name "Deny-Customers-to-Management"
        set srcintf "port4"
        set dstintf "port1"
        set srcaddr "all"
        set dstaddr "Management-Net"
        set action deny
        set schedule "always"
        set service "ALL"
    next
end
```

---

## 5. wan-rt01 (Cisco ISR 4331 - WAN/ISP Simulator)

Denne router modtager trafikken fra FortiGate WAN-interfacet og sender den videre til simuleret internet, eller agerer shared services server.

```cisco
hostname wan-rt01
!
enable secret admin123
!
interface GigabitEthernet0/0/0
 description WAN-forbindelse mod FortiGate HA wan1
 ip address 192.168.200.2 255.255.255.252
 no shutdown
!
interface Loopback0
 description Simuleret ekstern ressource (Shared Services / Google DNS)
 ip address 8.8.8.8 255.255.255.255
!
! --- ROUTING ---
! Rute tilbage til det samlede virksomhedsnetværk via FortiGate WAN VIP
ip route 192.168.0.0 255.255.0.0 192.168.200.1
```
