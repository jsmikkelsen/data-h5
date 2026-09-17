# Cisco IOS-XE, FortiOS & Proxmox VE Konfigurationsskabeloner (v2)

Dette dokument indeholder komplette, produktionsklare og kommenterede konfigurationsskabeloner for alle enheder i netværksplatformen. Alle parametre (IP-adresser, VLAN-numre, HSRP-prioriteter og VRF-kontekster) er baseret på **Statisk VRF Leaking** uden dynamic routing, hvilket gør designet robust og enkelt.

---

## 1. core-sw01 (Cisco Catalyst 3650 - Primær Core)

Denne switch agerer Active Gateway for **VLAN 10 (Kunde Alfa)**, **VLAN 20 (Kunde Bravo)** samt **VLAN 99 (Management)**.

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
!
ip vrf VRF_BRAVO
 rd 65001:20
!
ip vrf VRF_CHARLIE
 rd 65001:30
!
ip vrf VRF_DELTA
 rd 65001:40
!
ip vrf VRF_MGMT
 rd 65001:99
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
 description Forbindelse mod FortiGate Edge Cluster (GRT)
 ip address 192.168.101.2 255.255.255.248
 standby version 2
 standby 101 ip 192.168.101.4
 standby 101 priority 110
 standby 101 preempt
 standby 101 track GigabitEthernet1/1/1 20
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
! --- STATISK ROUTE LEAKING CONFIGURATION ---
! Vej ud: Statisk default route fra hver kunde VRF til det globale transit-vlan (FortiGate VIP)
ip route vrf VRF_ALFA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
ip route vrf VRF_BRAVO 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
ip route vrf VRF_CHARLIE 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
ip route vrf VRF_DELTA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
!
! Vej ind (Returruter): Ruter i Global Routing Table pegende ind i de respektive VRF-interfaces
ip route 192.168.10.0 255.255.255.0 Vlan10 vrf VRF_ALFA
ip route 192.168.20.0 255.255.255.0 Vlan20 vrf VRF_BRAVO
ip route 192.168.30.0 255.255.255.0 Vlan30 vrf VRF_CHARLIE
ip route 192.168.40.0 255.255.255.0 Vlan40 vrf VRF_DELTA
!
! Global Default-route mod FortiGate Edge-firewall
ip route 0.0.0.0 0.0.0.0 192.168.101.1
```

---

## 2. core-sw02 (Cisco Catalyst 3650 - Sekundær Core)

Denne switch agerer Active Gateway for **VLAN 30 (Kunde Charlie)** and **VLAN 40 (Kunde Delta)**.

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
!
ip vrf VRF_BRAVO
 rd 65001:20
!
ip vrf VRF_CHARLIE
 rd 65001:30
!
ip vrf VRF_DELTA
 rd 65001:40
!
ip vrf VRF_MGMT
 rd 65001:99
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
 description Forbindelse mod FortiGate Edge Cluster (GRT)
 ip address 192.168.101.3 255.255.255.248
 standby version 2
 standby 101 ip 192.168.101.4
 standby 101 priority 100
 standby 10 preempt
!
! --- UPLINK PORT MOD FORTIGATE ---
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
! --- STATISK ROUTE LEAKING CONFIGURATION ---
ip route vrf VRF_ALFA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
ip route vrf VRF_BRAVO 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
ip route vrf VRF_CHARLIE 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
ip route vrf VRF_DELTA 0.0.0.0 0.0.0.0 Vlan101 192.168.101.1 global
!
ip route 192.168.10.0 255.255.255.0 Vlan10 vrf VRF_ALFA
ip route 192.168.20.0 255.255.255.0 Vlan20 vrf VRF_BRAVO
ip route 192.168.30.0 255.255.255.0 Vlan30 vrf VRF_CHARLIE
ip route 192.168.40.0 255.255.255.0 Vlan40 vrf VRF_DELTA
!
ip route 0.0.0.0 0.0.0.0 192.168.101.1
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
! --- PORTE TIL PROXMOX HOST MANAGEMENT (VLAN 99) ---
interface range GigabitEthernet0/10 - 11
 description Redundant LACP Access-port til Proxmox Host Management (1G)
 switchport access vlan 99
 switchport mode access
 spanning-tree portfast
 spanning-tree bpduguard enable
```

---

## 4. fg-ha (FortiGate 60F - HA Active/Passive Cluster)

```fortinet
# --- HA CONFIGURATION ---
config system global
    set hostname "fg-ha-cluster"
end
config system ha
    set group-id 1
    set group-name "Netic-Core-HA"
    set mode a-p
    set hbdev "port5" 50 "port6" 50
    set session-pickup enable
    set priority 200
    set monitor "port4" "wan1"
end

# --- INTERFACES & IPS ---
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

# --- FIREWALL POLICIES ---
config firewall policy
    edit 10
        set name "Kunde-Alfa-to-Internet"
        set srcintf "port4"
        set dstintf "wan1"
        set srcaddr "Kunde-Alfa-LAN"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 20
        set name "Kunde-Bravo-to-Internet"
        set srcintf "port4"
        set dstintf "wan1"
        set srcaddr "Kunde-Bravo-LAN"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
end
```

---

## 5. Proxmox VE Netværkskonfigurationsfil (`/etc/network/interfaces`) på Dell R630

Dette er den faktiske konfigurationsfil, der skal installeres på din **Dell PowerEdge R630** fysiske server for at understøtte både ** redundant host-management** (1G - eno3/eno4) og ** redundant vlan-aware data-trunking** (10G - eno1/eno2).

```text
# Loopback interface
auto lo
iface lo inet loopback

# Dell NDC Intel X540/I350 Ethernet Interfaces:
# Port 1 & 2 (10 Gbit/s RJ45) -> eno1 & eno2
iface eno1 inet manual
iface eno2 inet manual

# Port 3 & 4 (1 Gbit/s RJ45) -> eno3 & eno4
iface eno3 inet manual
iface eno4 inet manual

# --- MANAGMENT NETVÆRK (VLAN 99) ---
# Vi samler de to onboard 1G kort i en redundant backup-forbindelse
auto bond1
iface bond1 inet manual
	bond-slaves eno3 eno4
	bond-miimon 100
	bond-mode active-backup

# Bridge til Proxmox Host Management IP. 
# Kun administrationspc'er i VLAN 99 kan tilgå Web GUI på port 8006
auto vmbr99
iface vmbr99 inet static
	address 192.168.99.100/24
	gateway 192.168.99.1
	bridge-ports bond1
	bridge-stp off
	bridge-fd 0
	comment "Proxmox Host Management IP - VLAN 99"

# --- KUNDE DATA TRUNK NETVÆRK ---
# Vi samler de to onboard 10G kobber-kort i en høj-hastigheds LACP bond
auto bond0
iface bond0 inet manual
	bond-slaves eno1 eno2
	bond-miimon 100
	bond-mode 802.3ad
	bond-xmit-hash-policy layer2+3

# VLAN Aware Bridge (Ingen IP-adresse på vært-niveau)
auto vmbr0
iface vmbr0 inet manual
	bridge-ports bond0
	bridge-stp off
	bridge-fd 0
	bridge-vlan-aware yes
	bridge-vids 10 20 30 40
	comment "Kunde-trafik Bridge (VLAN Tagging sker på VM-niveau)"
```
