# Cisco IOS-XE, FortiOS & Proxmox VE Konfigurationsskabeloner (v2 - Custom Design)

Dette dokument indeholder de komplette, udeladelsesfrie, produktionsklare og fuldt kommenterede konfigurationsskabeloner for alle enheder i din netværksplatform. Alle parametre (IP-adresser, VLAN-numre, HSRP-prioriteter, VRF'er og VDOMs) er synkroniserede 1:1 med din fysiske kablingsplan og dit avancerede design.

---

## 1. as-01 (Cisco Catalyst 2960X - Access Switch)

Denne switch leverer L2-forbindelse til administrationspc'en, klienter, servere og out-of-band management på VLAN 99.

```cisco
! --- SYSTEM & MANAGEMENT ---
hostname as-01
!
enable secret admin123
!
username admin privilege 15 secret admin123
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
 name mgmt-oob
!
spanning-tree mode rapid-pvst
!
! --- MANAGEMENT SVI ---
interface Vlan99
 description Management SVI for Access Switch
 ip address 192.168.99.11 255.255.255.0
 no shutdown
!
ip default-gateway 192.168.99.1
!
! --- CLIENT/HOST ACCESS INTERFACES ---
interface GigabitEthernet0/15
 description Management PC
 switchport mode access
 switchport access vlan 99
 spanning-tree portfast
 spanning-tree bpduguard enable
!
interface GigabitEthernet0/1
 description Alfa-PC (Testkunde Alfa)
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
 spanning-tree bpduguard enable
!
interface GigabitEthernet0/2
 description Bravo-PC (Testkunde Bravo)
 switchport mode access
 switchport access vlan 20
 spanning-tree portfast
 spanning-tree bpduguard enable
!
! --- UPLINKS TIL DISTRIBUTION SWITCHES (TRUNKS) ---
interface GigabitEthernet0/49
 description link-to-ds-01
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40,99
!
interface GigabitEthernet0/50
 description link-to-ds-02
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40,99
```

---

## 2. ds-01 (Cisco Catalyst 3650 - Distribution Switch 1)

Denne switch agerer Active Gateway for **VLAN 99 (Management)**, og Standby Gateway for VLAN 10 (Alfa), 20 (Bravo), 30 (Charlie) og 40 (Delta). Den huser L3 transit SVI'erne for subnets `10.10.x.x/29` (udfyldt i stedet for `<>`).

```cisco
! --- SYSTEM & VRF DEFINITIONER ---
hostname ds-01
!
enable secret admin123
!
username admin privilege 15 secret admin123
!
ip routing
!
vrf definition vrf-alfa
 address-family ipv4
!
vrf definition vrf-bravo
 address-family ipv4
!
vrf definition vrf-charlie
 address-family ipv4
!
vrf definition vrf-delta
 address-family ipv4
!
vrf definition vrf-management
 address-family ipv4
!
! --- OPRET VLANS ---
vlan 10
 name alfa
vlan 20
 name bravo
vlan 30
 name charlie
vlan 40
 name delta
vlan 99
 name management
vlan 910
 name transit-alfa
vlan 920
 name transit-bravo
vlan 930
 name transit-charlie
vlan 940
 name transit-delta
vlan 999
 name transit-management
!
! --- SPANNING TREE (RAPID-PVST+) ---
spanning-tree mode rapid-pvst
spanning-tree vlan 99 root primary 
spanning-tree vlan 10,20,30,40 root secondary
!
! --- KUNDE- OG MANAGEMENT INTERFACES (SVIs) ---
interface vlan 10
 vrf forwarding vrf-alfa
 ip address 192.168.10.2 255.255.255.0
 standby 10 ip 192.168.10.1
 standby 10 priority 90
 standby 10 preempt
 no shutdown
!
interface vlan 20
 vrf forwarding vrf-bravo
 ip address 192.168.20.2 255.255.255.0
 standby 20 ip 192.168.20.1
 standby 20 priority 90
 standby 20 preempt
 no shutdown
!
interface vlan 30
 vrf forwarding vrf-charlie
 ip address 192.168.30.2 255.255.255.0
 standby 30 ip 192.168.30.1
 standby 30 priority 90
 standby 30 preempt
 no shutdown
!
interface vlan 40
 vrf forwarding vrf-delta
 ip address 192.168.40.2 255.255.255.0
 standby 40 ip 192.168.40.1
 standby 40 priority 90
 standby 40 preempt
 no shutdown
!
interface vlan 99
 vrf forwarding vrf-management
 ip address 192.168.99.2 255.255.255.0
 standby 99 ip 192.168.99.1
 standby 99 priority 100
 standby 99 preempt
 no shutdown
!
! --- TRANSIT INTERFACES MOD FORTIGATES (Udfyldte `<>` felter) ---
interface vlan 910
 vrf forwarding vrf-alfa
 ip address 10.10.10.2 255.255.255.248
 no shutdown
!
interface vlan 920
 vrf forwarding vrf-bravo
 ip address 10.10.20.2 255.255.255.248
 no shutdown
!
interface vlan 930
 vrf forwarding vrf-charlie
 ip address 10.10.30.2 255.255.255.248
 no shutdown
!
interface vlan 940
 vrf forwarding vrf-delta
 ip address 10.10.40.2 255.255.255.248
 no shutdown
!
interface vlan 999
 vrf forwarding vrf-management
 ip address 10.10.99.2 255.255.255.248
 no shutdown
!
! --- SERVER FORBINDELSER (PROXMOX 10G LINKS) ---
interface GigabitEthernet1/0/5
 description link-to-srv1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40
 spanning-tree portfast trunk
!
interface GigabitEthernet1/0/6
 description link-to-srv2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40
 spanning-tree portfast trunk
!
interface GigabitEthernet1/0/7
 description link-to-srv3
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40
 spanning-tree portfast trunk
!
! --- MANAGEMENT LINK MOD ACCESS SWITCH ---
interface GigabitEthernet1/0/10
 description link-to-management
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 99
!
! --- INTERFACES MOD FORTIGATE FG-01 (PORT-CHANNEL 1) ---
interface range GigabitEthernet1/0/23 - 24
 description link-to-fg-01
 channel-group 1 mode active
 no shutdown
!
interface port-channel 1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 910,920,930,940,999
!
! --- INTERFACES MOD FORTIGATE FG-02 (PORT-CHANNEL 2) ---
interface range GigabitEthernet1/0/21 - 22
 description link-to-fg-02 (Rettet til Symmetrisk HA)
 channel-group 2 mode active
 no shutdown
!
interface port-channel 2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 910,920,930,940,999
!
! --- INTER-SWITCH LINK MOD DS-02 (PORT-CHANNEL 3) ---
interface range GigabitEthernet1/0/19 - 20
 description link-to-ds-02
 channel-group 3 mode active
 no shutdown
!
interface port-channel 3
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40,99,910,920,930,940,999
!
! --- STATISK VRF ROUTING (Default ruter mod FortiGate HA VIPs) ---
ip route vrf vrf-alfa 0.0.0.0 0.0.0.0 10.10.10.1 name alfa
ip route vrf vrf-bravo 0.0.0.0 0.0.0.0 10.10.20.1 name bravo
ip route vrf vrf-charlie 0.0.0.0 0.0.0.0 10.10.30.1 name charlie
ip route vrf vrf-delta 0.0.0.0 0.0.0.0 10.10.40.1 name delta
ip route vrf vrf-management 0.0.0.0 0.0.0.0 10.10.99.1 name management
```

---

## 3. ds-02 (Cisco Catalyst 3650 - Distribution Switch 2)

Denne switch agerer Active Gateway for **VLAN 10, 20, 30 og 40 (Kunder)**, og Standby Gateway for VLAN 99 (Management). Den huser L3 transit SVI'erne for subnets `10.9.x.x/29` (udfyldt i stedet for `<>`).

```cisco
! --- SYSTEM & VRF DEFINITIONER ---
hostname ds-02
!
enable secret admin123
!
username admin privilege 15 secret admin123
!
ip routing
!
vrf definition vrf-alfa
 address-family ipv4
!
vrf definition vrf-bravo
 address-family ipv4
!
vrf definition vrf-charlie
 address-family ipv4
!
vrf definition vrf-delta
 address-family ipv4
!
vrf definition vrf-management
 address-family ipv4
!
! --- OPRET VLANS ---
vlan 10
 name alfa
vlan 20
 name bravo
vlan 30
 name charlie
vlan 40
 name delta
vlan 99
 name management
vlan 910
 name transit-alfa
vlan 920
 name transit-bravo
vlan 930
 name transit-charlie
vlan 940
 name transit-delta
vlan 999
 name transit-management
!
! --- SPANNING TREE (RAPID-PVST+) ---
spanning-tree mode rapid-pvst
spanning-tree vlan 10,20,30,40 root primary 
spanning-tree vlan 99 root secondary
!
! --- KUNDE- OG MANAGEMENT INTERFACES (SVIs) ---
interface vlan 10
 vrf forwarding vrf-alfa
 ip address 192.168.10.3 255.255.255.0
 standby 10 ip 192.168.10.1
 standby 10 priority 100
 standby 10 preempt
 no shutdown
!
interface vlan 20
 vrf forwarding vrf-bravo
 ip address 192.168.20.3 255.255.255.0
 standby 20 ip 192.168.20.1
 standby 20 priority 100
 standby 20 preempt
 no shutdown
!
interface vlan 30
 vrf forwarding vrf-charlie
 ip address 192.168.30.3 255.255.255.0
 standby 30 ip 192.168.30.1
 standby 30 priority 100
 standby 30 preempt
 no shutdown
!
interface vlan 40
 vrf forwarding vrf-delta
 ip address 192.168.40.3 255.255.255.0
 standby 40 ip 192.168.40.1
 standby 40 priority 100
 standby 40 preempt
 no shutdown
!
interface vlan 99
 vrf forwarding vrf-management
 ip address 192.168.99.3 255.255.255.0
 standby 99 ip 192.168.99.1
 standby 99 priority 90
 standby 99 preempt
 no shutdown
!
! --- TRANSIT INTERFACES MOD FORTIGATES (Udfyldte `<>` felter) ---
interface vlan 910
 vrf forwarding vrf-alfa
 ip address 10.9.10.2 255.255.255.248
 no shutdown
!
interface vlan 920
 vrf forwarding vrf-bravo
 ip address 10.9.20.2 255.255.255.248
 no shutdown
!
interface vlan 930
 vrf forwarding vrf-charlie
 ip address 10.9.30.2 255.255.255.248
 no shutdown
!
interface vlan 940
 vrf forwarding vrf-delta
 ip address 10.9.40.2 255.255.255.248
 no shutdown
!
interface vlan 999
 vrf forwarding vrf-management
 ip address 10.9.99.2 255.255.255.248
 no shutdown
!
! --- SERVER FORBINDELSER (PROXMOX 10G LINKS) ---
interface GigabitEthernet1/0/5
 description link-to-srv1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40
 spanning-tree portfast trunk
!
interface GigabitEthernet1/0/6
 description link-to-srv2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40
 spanning-tree portfast trunk
!
interface GigabitEthernet1/0/7
 description link-to-srv3
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40
 spanning-tree portfast trunk
!
! --- MANAGEMENT LINK MOD ACCESS SWITCH ---
interface GigabitEthernet1/0/10
 description link-to-management
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 99
!
! --- INTERFACES MOD FORTIGATE FG-02 (PORT-CHANNEL 1) ---
interface range GigabitEthernet1/0/23 - 24
 description link-to-fg-02
 channel-group 1 mode active
 no shutdown
!
interface port-channel 1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 910,920,930,940,999
!
! --- INTERFACES MOD FORTIGATE FG-01 (PORT-CHANNEL 2 - CROSS-LINKS) ---
interface range GigabitEthernet1/0/21 - 22
 description link-to-fg-01 (Rettet til Symmetrisk HA)
 channel-group 2 mode active
 no shutdown
!
interface port-channel 2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 910,920,930,940,999
!
! --- INTER-SWITCH LINK MOD DS-01 (PORT-CHANNEL 3) ---
interface range GigabitEthernet1/0/19 - 20
 description link-to-ds-01
 channel-group 3 mode active
 no shutdown
!
interface port-channel 3
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40,99,910,920,930,940,999
!
! --- STATISK VRF ROUTING (Default ruter mod FortiGate HA VIPs) ---
ip route vrf vrf-alfa 0.0.0.0 0.0.0.0 10.9.10.1 name alfa
ip route vrf vrf-bravo 0.0.0.0 0.0.0.0 10.9.20.1 name bravo
ip route vrf vrf-charlie 0.0.0.0 0.0.0.0 10.9.30.1 name charlie
ip route vrf vrf-delta 0.0.0.0 0.0.0.0 10.9.40.1 name delta
ip route vrf vrf-management 0.0.0.0 0.0.0.0 10.9.99.1 name management
```

---

## 4. fg-01 & fg-02 (FortiGate 60F - HA VDOM, Aggregate & Inter-VDOM routing)

Dette er den komplette konfiguration for dine to FortiGates, opsat med **Multi-VDOM** til at matche Cisco VRF'erne. 

For at synkroniseringen fungerer fejlfrit, er de to fysiske LACP aggregate-forbindelser defineret symmetrisk:
*   `ds-01-aggregate` (port1 & port2) ➔ Forbundet til `ds-01`
*   `ds-02-aggregate` (port3 & port4) ➔ Forbundet til `ds-02`

Internet-adgang formidles via en central **`root` VDOM**, som har direkte kabling til WAN-routeren og modtager trafikken fra kunde-VDOM'erne via virtuelle **Inter-VDOM Links**.

```fortinet
# ==============================================================================
# DEL A: GLOBALE INDSTILLINGER & VDOMS (Udføres i Global kontekst)
# ==============================================================================

# --- AKTIVER MULTI-VDOM TILSTAND ---
config system global
    set vdom-mode multi-vdom
    set hostname "fg-01"               # Indtast "fg-02" på den sekundære enhed
end

# --- DEFINER KUNDE- OG MANAGEMENT VDOMS ---
config vdom
    edit "root"                        # Bruges til WAN, BDI internet og inter-vdom formidling
    next
    edit "alfa"
    next
    edit "bravo"
    next
    edit "charlie"
    next
    edit "delta"
    next
    edit "management"
    next
end

# --- DEFINE HA CLUSTERING ---
config global
config system ha
    set group-id 1
    set group-name "Core-HA"
    set mode a-p
    set hbdev "a" 50 "b" 50             # HA synkronisering trækkes på FortiLink a & b
    set session-pickup enable
    set priority 200                   # Sæt til 100 på den sekundære firewall fg-02
    set monitor "port1" "port2" "port3" "port4" "wan1"
end

# --- OPRET REDUNDANTE LACP LACP AGGREGATER MOD SWITCHES ---
config system interface
    edit "ds-01-link"
        set vdom "root"
        set type aggregate
        set member "port1" "port2"
        set lacp-mode active
    next
    edit "ds-02-link"
        set vdom "root"
        set type aggregate
        set member "port3" "port4"
        set lacp-mode active
    next
end

# --- OPRET INTER-VDOM LINKS (Virtuelle kabler på tværs af VDOMs) ---
config system vdom-link
    edit "vl-alfa"
        set type ethernet
    next
    edit "vl-bravo"
        set type ethernet
    next
    edit "vl-charlie"
        set type ethernet
    next
    edit "vl-delta"
        set type ethernet
    next
    edit "vl-mgmt"
        set type ethernet
    next
end

# --- ALLOKER INTERFACES TIL VDOMS ---
config system interface
    # WAN porten placeres i root VDOM
    edit "wan1"
        set vdom "root"
        set ip 192.168.200.1 255.255.255.248
        set allowaccess ping
    next
    # SVI Transit links mod ds-01 tilknyttes de respektive VDOMs
    edit "ds-01-link.910"
        set vdom "alfa"
        set ip 10.10.10.1 255.255.255.248
        set allowaccess ping
        set interface "ds-01-link"
        set vlanid 910
    next
    edit "ds-01-link.920"
        set vdom "bravo"
        set ip 10.10.20.1 255.255.255.248
        set allowaccess ping
        set interface "ds-01-link"
        set vlanid 920
    next
    edit "ds-01-link.930"
        set vdom "charlie"
        set ip 10.10.30.1 255.255.255.248
        set allowaccess ping
        set interface "ds-01-link"
        set vlanid 930
    next
    edit "ds-01-link.940"
        set vdom "delta"
        set ip 10.10.40.1 255.255.255.248
        set allowaccess ping
        set interface "ds-01-link"
        set vlanid 940
    next
    edit "ds-01-link.999"
        set vdom "management"
        set ip 10.10.99.1 255.255.255.248
        set allowaccess ping ssh https gui
        set interface "ds-01-link"
        set vlanid 999
    next
    # SVI Transit links mod ds-02 tilknyttes de respektive VDOMs
    edit "ds-02-link.910"
        set vdom "alfa"
        set ip 10.9.10.1 255.255.255.248
        set allowaccess ping
        set interface "ds-02-link"
        set vlanid 910
    next
    edit "ds-02-link.920"
        set vdom "bravo"
        set ip 10.9.20.1 255.255.255.248
        set allowaccess ping
        set interface "ds-02-link"
        set vlanid 920
    next
    edit "ds-02-link.930"
        set vdom "charlie"
        set ip 10.9.30.1 255.255.255.248
        set allowaccess ping
        set interface "ds-02-link"
        set vlanid 930
    next
    edit "ds-02-link.940"
        set vdom "delta"
        set ip 10.9.40.1 255.255.255.248
        set allowaccess ping
        set interface "ds-02-link"
        set vlanid 940
    next
    edit "ds-02-link.999"
        set vdom "management"
        set ip 10.9.99.1 255.255.255.248
        set allowaccess ping ssh https gui
        set interface "ds-02-link"
        set vlanid 999
    next
    # VDOM Link interfaces allokeres parvis
    edit "vl-alfa0"
        set vdom "root"
    next
    edit "vl-alfa1"
        set vdom "alfa"
        set ip 172.16.10.1 255.255.255.252
        set allowaccess ping
    next
    edit "vl-bravo0"
        set vdom "root"
    next
    edit "vl-bravo1"
        set vdom "bravo"
        set ip 172.16.20.1 255.255.255.252
        set allowaccess ping
    next
    edit "vl-charlie0"
        set vdom "root"
    next
    edit "vl-charlie1"
        set vdom "charlie"
        set ip 172.16.30.1 255.255.255.252
        set allowaccess ping
    next
    edit "vl-delta0"
        set vdom "root"
    next
    edit "vl-delta1"
        set vdom "delta"
        set ip 172.16.40.1 255.255.255.252
        set allowaccess ping
    next
    edit "vl-mgmt0"
        set vdom "root"
    next
    edit "vl-mgmt1"
        set vdom "management"
        set ip 172.16.99.1 255.255.255.252
        set allowaccess ping
    next
end
end

# ==============================================================================
# DEL B: VDOM ROUTING & SIKKERHEDSPOLITIKKER (Udføres i de enkelte VDOMs)
# ==============================================================================

# --- VDOM ALFA ---
config vdom
edit "alfa"
config router static
    # Default route peger på den anden ende af VDOM-linket i Root
    edit 1
        set gateway 172.16.10.2
        set device "vl-alfa1"
    next
    # Returruter ind mod switches (husk at dække begge transitter!)
    edit 2
        set dst 192.168.10.0 255.255.255.0
        set gateway 10.10.10.2
        set device "ds-01-link.910"
    next
    edit 3
        set dst 192.168.10.0 255.255.255.0
        set gateway 10.9.10.2
        set device "ds-02-link.910"
    next
end
config firewall policy
    # Tillad al udgående kildetrafik ud af VDOM-linket til internettet
    edit 1
        set name "Alfa-to-WAN-Link"
        set srcintf "ds-01-link.910" "ds-02-link.910"
        set dstintf "vl-alfa1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
end
next

# --- VDOM BRAVO ---
edit "bravo"
config router static
    edit 1
        set gateway 172.16.20.2
        set device "vl-bravo1"
    next
    edit 2
        set dst 192.168.20.0 255.255.255.0
        set gateway 10.10.20.2
        set device "ds-01-link.920"
    next
    edit 3
        set dst 192.168.20.0 255.255.255.0
        set gateway 10.9.20.2
        set device "ds-02-link.920"
    next
end
config firewall policy
    edit 1
        set name "Bravo-to-WAN-Link"
        set srcintf "ds-01-link.920" "ds-02-link.920"
        set dstintf "vl-bravo1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
end
next

# --- VDOM CHARLIE ---
edit "charlie"
config router static
    edit 1
        set gateway 172.16.30.2
        set device "vl-charlie1"
    next
    edit 2
        set dst 192.168.30.0 255.255.255.0
        set gateway 10.10.30.2
        set device "ds-01-link.930"
    next
    edit 3
        set dst 192.168.30.0 255.255.255.0
        set gateway 10.9.30.2
        set device "ds-02-link.930"
    next
end
config firewall policy
    edit 1
        set name "Charlie-to-WAN-Link"
        set srcintf "ds-01-link.930" "ds-02-link.930"
        set dstintf "vl-charlie1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
end
next

# --- VDOM DELTA ---
edit "delta"
config router static
    edit 1
        set gateway 172.16.40.2
        set device "vl-delta1"
    next
    edit 2
        set dst 192.168.40.0 255.255.255.0
        set gateway 10.10.40.2
        set device "ds-01-link.940"
    next
    edit 3
        set dst 192.168.40.0 255.255.255.0
        set gateway 10.9.40.2
        set device "ds-02-link.940"
    next
end
config firewall policy
    edit 1
        set name "Delta-to-WAN-Link"
        set srcintf "ds-01-link.940" "ds-02-link.940"
        set dstintf "vl-delta1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
end
next

# --- VDOM MANAGEMENT ---
edit "management"
config router static
    edit 1
        set gateway 172.16.99.2
        set device "vl-mgmt1"
    next
    edit 2
        set dst 192.168.99.0 255.255.255.0
        set gateway 10.10.99.2
        set device "ds-01-link.999"
    next
    edit 3
        set dst 192.168.99.0 255.255.255.0
        set gateway 10.9.99.2
        set device "ds-02-link.999"
    next
end
config firewall policy
    edit 1
        set name "Mgmt-to-WAN-Link"
        set srcintf "ds-01-link.999" "ds-02-link.999"
        set dstintf "vl-mgmt1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
    next
end
next

# ==============================================================================
# DEL C: CENTRAL ROOT VDOM (Formidling af NAT & WAN egress)
# ==============================================================================
edit "root"
# Sæt IPs på root-siden af VDOM-links
config system interface
    edit "vl-alfa0"
        set ip 172.16.10.2 255.255.255.252
        set allowaccess ping
    next
    edit "vl-bravo0"
        set ip 172.16.20.2 255.255.255.252
        set allowaccess ping
    next
    edit "vl-charlie0"
        set ip 172.16.30.2 255.255.255.252
        set allowaccess ping
    next
    edit "vl-delta0"
        set ip 172.16.40.2 255.255.255.252
        set allowaccess ping
    next
    edit "vl-mgmt0"
        set ip 172.16.99.2 255.255.255.252
        set allowaccess ping
    next
end
config router static
    # Default route i root peger direkte på Cisco 4331 WAN gateway over BDI
    edit 1
        set gateway 192.168.200.2
        set device "wan1"
    next
    # Returruter til kundenetværkene ind gennem de respektive VDOM-links
    edit 2
        set dst 192.168.10.0 255.255.255.0
        set device "vl-alfa0"
    next
    edit 3
        set dst 192.168.20.0 255.255.255.0
        set device "vl-bravo0"
    next
    edit 4
        set dst 192.168.30.0 255.255.255.0
        set device "vl-charlie0"
    next
    edit 5
        set dst 192.168.40.0 255.255.255.0
        set device "vl-delta0"
    next
    edit 6
        set dst 192.168.99.0 255.255.255.0
        set device "vl-mgmt0"
    next
end
config firewall policy
    # Tillad og NAT (PAT Overload) trafikken ud mod internettet for hver enkelt kunde VDOM
    edit 10
        set name "alfa-internet-egress"
        set srcintf "vl-alfa0"
        set dstintf "wan1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 20
        set name "bravo-internet-egress"
        set srcintf "vl-bravo0"
        set dstintf "wan1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 30
        set name "charlie-internet-egress"
        set srcintf "vl-charlie0"
        set dstintf "wan1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 40
        set name "delta-internet-egress"
        set srcintf "vl-delta0"
        set dstintf "wan1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 99
        set name "mgmt-internet-egress"
        set srcintf "vl-mgmt0"
        set dstintf "wan1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
end
end
```

---

## 5. wan-rt01 (Cisco ISR 4331 - Fuldstændig WAN/NAT Router med L2 Bridging)

Denne router agerer som din **fysiske internet gateway/ISP simulator**. Den er kablet **direkte** til WAN1-porten på begge dine firewalls via de to hosliggende porte **`Gi0/0/0`** og **`Gi0/0/1`**. De to porte er software-bridged på routeren via **Bridge Domain (BDI1)**, så den aktive firewall kan overtage den delte WAN VIP `192.168.200.1` øjeblikkeligt.

Den selvstændige port **`Gi0/0/2`** forbindes til dit rigtige internet (via DHCP) og udfører NAT (PAT Overload) for hele dit interne `192.168.0.0/16` netværk.

```cisco
! --- SYSTEM ---
hostname wan-rt01
!
enable secret admin123
!
username admin privilege 15 secret admin123
!
ip domain-name isp.dk
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
ip routing
!
! --- WAN INTERFACES & LAYER 2 BRIDGING (BDI) ---
!
! GigabitEthernet0/0/2 forbindes til skolens/labbets rigtige internet (router/væg-stik)
interface GigabitEthernet0/0/2
 description Uplink mod rigtigt internet (Fysisk uplink mod skole/hjemme-LAN)
 ip address dhcp                ! Modtager automatisk en IP-adresse og default route fra dit LAN
 ip nat outside                 ! Definerer dette som det ydre NAT interface
 no shutdown
!
! GigabitEthernet0/0/0 forbindes DIREKTE til fg-01 wan1 port
interface GigabitEthernet0/0/0
 description Forbindelse til fg-01 wan1 port
 no ip address
 negotiation auto
 service instance 1 ethernet
  encapsulation default
  bridge-domain 1
 no shutdown
!
! GigabitEthernet0/0/1 forbindes DIREKTE til fg-02 wan1 port
interface GigabitEthernet0/0/1
 description Forbindelse til fg-02 wan1 port
 no ip address
 negotiation auto
 service instance 1 ethernet
  encapsulation default
  bridge-domain 1
 no shutdown
!
! Det virtuelle Bridge Domain interface (BDI) der agerer gateway for firewalls
interface BDI1
 description Bridge Domain interface til FortiGate WAN netvaerk
 ip address 192.168.200.2 255.255.255.248  ! Fælles /29 IP i WAN netværket
 ip nat inside                             ! Definerer dette som det indre NAT interface
 no shutdown
!
! --- DUMMY INTERNET ADRESSE (TIL OFFSINE TEST) ---
interface Loopback0
 description Simuleret ekstern DNS-server (Google DNS)
 ip address 8.8.8.8 255.255.255.255
 ip nat inside
!
! --- NAT / PAT OVERLOAD OPSÆTNING ---
! Access-list der tillader NAT for hele dit interne Klasse-B/C netværksblok (192.168.0.0/16)
ip access-list standard NAT_ACL
 permit 192.168.0.0 0.0.255.255
!
! Etabler dynamisk NAT (PAT Overload) ud af din internet-forbundne port Gi0/0/2
ip nat inside source list NAT_ACL interface GigabitEthernet0/0/2 overload
!
! --- STATISK ROUTING ---
! Rute, der sender alt trafik til dit interne netværk tilbage mod FortiGate HA Clusterets VIP
ip route 192.168.0.0 255.255.0.0 192.168.200.1
```

---

## 6. Proxmox VE Netværkskonfigurationsfil (`/etc/network/interfaces`) på Dell R630

Dette er den faktiske, udeladelsesfrie konfigurationsfil, der skal installeres på din **Dell PowerEdge R630** fysiske server for at understøtte både **redundant host-management** (1G - eno3/eno4) og **redundant vlan-aware data-opening** (10G - eno1/eno2).

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
# Vi samler de to onboard 1G-porte i en redundant backup-forbindelse
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
# Vi samler de to onboard 10G kobber-porte i en høj-hastigheds LACP bond
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
