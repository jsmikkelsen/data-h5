# Cisco IOS Konfigurationsskabelon (Fuld 9-Enheders Topologi Med OSPFv2)

Dette dokument indeholder de komplette, kommenterede Cisco IOS-konfigurationsskabeloner, der passer **præcist** med din udrullede Packet Tracer-topologi (`opgave-1.pkt`) bestående af 9 netværksenheder (rt01, core-1, core-2, ds-1, ds-2 og as-1 til as-5) med **dynamisk OSPFv2 routing**.

---

## 🗺️ Fysiske og Logiske Forbindelser (Port Mapping)

For at sikre, at konfigurationerne virker med det samme, skal du forbinde portene præcis som angivet herunder (og som ses i dit screenshot):

* **`rt01` (Router):**
  * `Gi0/0/0` <---> **`core-1` Gi1/0/24** (Transit Link A: `10.20.254.0/30`)
  * `Gi0/0/1` <---> **`core-2` Gi1/0/24** (Transit Link B: `10.20.254.4/30`)
* **Kerne / L3 Switche (`core-1` & `core-2`):**
  * **Inter-Core Link (Trunk):** `core-1 [Gi1/0/23]` <---> `core-2 [Gi1/0/23]`
  * **Uplink til ds-1 (EtherChannel Po11):** `core-1 [Gi1/0/1-2]` <---> `ds-1 [Gi1/0/1-2]`
  * **Uplink til ds-2 (EtherChannel Po12):** `core-2 [Gi1/0/1-2]` <---> `ds-2 [Gi1/0/1-2]`
  * **Cross-Links (Trunks):**
    * `core-1 [Gi1/0/22]` <---> `ds-2 [Gi1/0/22]`
    * `core-2 [Gi1/0/22]` <---> `ds-1 [Gi1/0/22]`
    * `core-1 [Gi1/0/21]` <---> `ds-2 [Gi1/0/21]`
* **Distribution / L2 Switche (`ds-1` & `ds-2`) til Access Switche (`as-1` til `as-5`):**
  * Hver access-switch har redundante trunks til både `ds-1` (venstre) og `ds-2` (højre):
    * **`as-1` (Admin):** `Gi0/2` <---> `ds-1 Gi1/0/3` | `Gi0/1` <---> `ds-2 Gi1/0/3`
    * **`as-2` (Prod):**  `Gi0/1` <---> `ds-1 Gi1/0/4` | `Gi0/2` <---> `ds-2 Gi1/0/4`
    * **`as-3` (IT):**    `Gi0/2` <---> `ds-1 Gi1/0/5` | `Gi0/1` <---> `ds-2 Gi1/0/5`
    * **`as-4` (Guest):** `Gi0/1` <---> `ds-1 Gi1/0/6` | `Gi0/2` <---> `ds-2 Gi1/0/6`
    * **`as-5` (Mgmt):**  `Gi0/2` <---> `ds-1 Gi1/0/7` | `Gi0/1` <---> `ds-2 Gi1/0/7`

---

## 🌐 1. Kant-Router: `rt01` (Cisco ISR 4331)

Ansvar: WAN-routing, NAT/PAT, og dynamisk udrulning af default route (`0.0.0.0/0`) via OSPF.

```ios
enable
configure terminal
hostname rt01

! --- 1. WAN Interface (Internet Simulation) ---
interface GigabitEthernet0/0/2
 description WAN-Connection-To-ISP
 ip address dhcp
 ip nat outside
 no shutdown

! --- 2. LAN Interface to core-1 ---
interface GigabitEthernet0/0/0
 description Transit-Link-To-CORE-1
 ip address 10.20.254.1 255.255.255.252
 ip nat inside
 no shutdown

! --- 3. LAN Interface to core-2 ---
interface GigabitEthernet0/0/1
 description Transit-Link-To-CORE-2
 ip address 10.20.254.5 255.255.255.252
 ip nat inside
 no shutdown

! --- 4. NAT/PAT Konfiguration ---
access-list 1 permit 10.20.0.0 0.0.255.255
ip nat inside source list 1 interface GigabitEthernet0/0/2 overload

! --- 5. Statisk Default Route mod Internettet ---
ip route 0.0.0.0 0.0.0.0 dhcp

! --- 6. OSPFv2 Dynamisk Routing ---
router ospf 1
 router-id 1.1.1.1
 ! Reklamer transit-netværkene ind i Area 0 (Backbone)
 network 10.20.254.0 0.0.0.3 area 0
 network 10.20.254.4 0.0.0.3 area 0
 ! Injicer standardruten dynamisk til Core-switchene
 default-information originate
exit

! --- 7. Grundlæggende Sikkerhed & SSH ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 4
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## 🧠 2. Core Switch Primary: `core-1` (Catalyst 3650 - L3)

Ansvar: SVIs, HSRP Active (VLAN 10,20,30,99), STP Root Primary, **Primary DHCP (80% pulje)** og OSPFv2.

```ios
enable
configure terminal
hostname core-1

! --- 1. Aktiver L3 Routing ---
ip routing

! --- 2. Opret VLANs ---
vlan 10
 name Administration
vlan 20
 name Produktion
vlan 30
 name IT
vlan 40
 name Gaester
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 3. Spanning Tree (STP) Design ---
spanning-tree mode rapid-pvst
spanning-tree vlan 10,20,30,99 root primary
spanning-tree vlan 40 root secondary

! --- 4. EtherChannel (LACP) Konfigurationer ---
! EtherChannel 11 (LACP) til ds-1
interface range GigabitEthernet1/0/1-2
 description EtherChannel-Link-To-DS-1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 channel-group 11 mode active
no shutdown

interface Port-Channel 11
 description Logical-Trunk-To-DS-1
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! --- 5. Fysiske Cross-Links & Routed Ports ---
! Cross-link Trunk til core-2
interface GigabitEthernet1/0/23
 description Trunk-To-CORE-2-CrossLink
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! Cross-link Trunk til ds-2
interface GigabitEthernet1/0/22
 description Trunk-To-DS-2-CrossLink
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

interface GigabitEthernet1/0/21
 description Trunk-To-DS-2-CrossLink-2
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! Routed Port til Router rt01 (Transit Link A)
interface GigabitEthernet1/0/24
 description Routed-Link-To-rt01-Gi0/0/0
 no switchport
 ip address 10.20.254.2 255.255.255.252
 no shutdown

! --- 6. OSPFv2 Dynamisk Routing ---
router ospf 1
 router-id 2.2.2.1
 ! --- SIKKERHED: Blokerer OSPF på alle klient-VLANs som standard ---
 passive-interface default
 ! Tillad KUN OSPF på det fysiske link op mod routeren
 no passive-interface GigabitEthernet1/0/24
 ! Reklamer transit-linket
 network 10.20.254.0 0.0.0.3 area 0
 ! Reklamer alle vores interne VLAN-områder (SVI-netværk) til rt01
 network 10.20.1.128 0.0.0.63 area 0
 network 10.20.1.0 0.0.0.127 area 0
 network 10.20.1.192 0.0.0.31 area 0
 network 10.20.0.0 0.0.0.255 area 0
 network 10.20.1.224 0.0.0.15 area 0
exit

! --- 7. Redundant Split-Scope DHCP (80% Pulje) ---
! VLAN 10 (Admin) Ekskluderinger
ip dhcp excluded-address 10.20.1.129 10.20.1.134
ip dhcp excluded-address 10.20.1.176 10.20.1.191  ! Ekskluderer core-2's 20% pulje

! VLAN 20 (Prod) Ekskluderinger
ip dhcp excluded-address 10.20.1.1 10.20.1.9
ip dhcp excluded-address 10.20.1.100 10.20.1.127  ! Ekskluderer core-2's 20% pulje

! VLAN 30 (IT) Ekskluderinger
ip dhcp excluded-address 10.20.1.193 10.20.1.199
ip dhcp excluded-address 10.20.1.216 10.20.1.223  ! Ekskluderer core-2's 20% pulje

! VLAN 40 (Gæster) Ekskluderinger
ip dhcp excluded-address 10.20.0.1 10.20.0.9
ip dhcp excluded-address 10.20.0.200 10.20.0.254  ! Ekskluderer core-2's 20% pulje

! Opret DHCP Pools for core-1 (80% af IP-scopet)
ip dhcp pool VLAN10_Admin_Primary
 network 10.20.1.128 255.255.255.192
 default-router 10.20.1.129
 dns-server 10.20.1.195

ip dhcp pool VLAN20_Prod_Primary
 network 10.20.1.0 255.255.255.128
 default-router 10.20.1.1
 dns-server 10.20.1.195

ip dhcp pool VLAN30_IT_Primary
 network 10.20.1.192 255.255.255.224
 default-router 10.20.1.193
 dns-server 10.20.1.195

ip dhcp pool VLAN40_Gaester_Primary
 network 10.20.0.0 255.255.255.0
 default-router 10.20.0.1
 dns-server 10.20.1.195

! --- 8. SVI Gateways & HSRP ---
interface vlan 10
 description Gateway-Administration
 ip address 10.20.1.130 255.255.255.192
 standby 10 ip 10.20.1.129
 standby 10 priority 110
 standby 10 preempt
no shutdown

interface vlan 20
 description Gateway-Produktion
 ip address 10.20.1.2 255.255.255.128
 standby 20 ip 10.20.1.1
 standby 20 priority 110
 standby 20 preempt
no shutdown

interface vlan 30
 description Gateway-IT
 ip address 10.20.1.195 255.255.255.224
 standby 30 ip 10.20.1.193
 standby 30 priority 110
 standby 30 preempt
no shutdown

interface vlan 40
 description Gateway-Gaester
 ip address 10.20.0.2 255.255.255.0
 standby 40 ip 10.20.0.1
 standby 40 priority 100
 standby 40 preempt
 ip access-group GUEST_ACL in
no shutdown

interface vlan 99
 description Gateway-Management
 ip address 10.20.1.226 255.255.255.240
 standby 99 ip 10.20.1.225
 standby 99 priority 110
 standby 99 preempt
 ip access-group MGMT_ACL in
no shutdown

! --- 9. Access Control Lists (ACLs) ---
ip access-list extended GUEST_ACL
 permit udp any any eq bootpc
 permit udp any any eq bootps
 permit udp any host 10.20.1.195 eq domain
 permit udp any host 10.20.1.196 eq domain
 deny ip any 10.20.1.0 0.0.0.127
 deny ip any 10.20.1.128 0.0.0.63
 deny ip any 10.20.1.192 0.0.0.31
 deny ip any 10.20.1.224 0.0.0.15
 permit ip any any
exit

ip access-list extended MGMT_ACL
 permit tcp 10.20.1.192 0.0.0.31 any eq 22
 permit tcp 10.20.1.192 0.0.0.31 any eq 443
 deny ip any any
exit

! --- 10. SSH Administration & DNS Service ---
ip domain name netic.dk
ip dns server
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 15
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## 🧠 3. Core Switch Backup: `core-2` (Catalyst 3650 - L3)

Ansvar: SVIs, HSRP Backup (VLAN 40 Active), STP Root Secondary, **Backup DHCP (20% pulje)** og OSPFv2.

```ios
enable
configure terminal
hostname core-2

! --- 1. Aktiver L3 Routing ---
ip routing

! --- 2. Opret VLANs ---
vlan 10
 name Administration
vlan 20
 name Produktion
vlan 30
 name IT
vlan 40
 name Gaester
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 3. Spanning Tree (STP) Design ---
spanning-tree mode rapid-pvst
spanning-tree vlan 40 root primary
spanning-tree vlan 10,20,30,99 root secondary

! --- 4. EtherChannel (LACP) Konfigurationer ---
! EtherChannel 12 (LACP) til ds-2
interface range GigabitEthernet1/0/1-2
 description EtherChannel-Link-To-DS-2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 channel-group 12 mode active
no shutdown

interface Port-Channel 12
 description Logical-Trunk-To-DS-2
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! --- 5. Fysiske Cross-Links & Routed Ports ---
! Cross-link Trunk til core-1
interface GigabitEthernet1/0/23
 description Trunk-To-CORE-1-CrossLink
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! Cross-link Trunk til ds-1
interface GigabitEthernet1/0/22
 description Trunk-To-DS-1-CrossLink
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! Routed Port til Router rt01 (Transit Link B)
interface GigabitEthernet1/0/24
 description Routed-Link-To-rt01-Gi0/0/1
 no switchport
 ip address 10.20.254.6 255.255.255.252
 no shutdown

! --- 6. OSPFv2 Dynamisk Routing ---
router ospf 1
 router-id 2.2.2.2
 ! --- SIKKERHED: Blokerer OSPF på alle klient-VLANs som standard ---
 passive-interface default
 ! Tillad KUN OSPF på det fysiske link op mod routeren
 no passive-interface GigabitEthernet1/0/24
 ! Reklamer transit-linket
 network 10.20.254.4 0.0.0.3 area 0
 ! Reklamer alle vores interne VLAN-områder (SVI-netværk) til rt01
 network 10.20.1.128 0.0.0.63 area 0
 network 10.20.1.0 0.0.0.127 area 0
 network 10.20.1.192 0.0.0.31 area 0
 network 10.20.0.0 0.0.0.255 area 0
 network 10.20.1.224 0.0.0.15 area 0
exit

! --- 7. Redundant Split-Scope DHCP (20% Pulje) ---
! VLAN 10 (Admin) Ekskluderinger
ip dhcp excluded-address 10.20.1.129 10.20.1.175  ! Gateways, Switche & core-1's 80% pulje

! VLAN 20 (Prod) Ekskluderinger
ip dhcp excluded-address 10.20.1.1 10.20.1.99    ! Gateways, Switche & core-1's 80% pulje

! VLAN 30 (IT) Ekskluderinger
ip dhcp excluded-address 10.20.1.193 10.20.1.215  ! Gateways, Switche & core-1's 80% pulje

! VLAN 40 (Gæster) Ekskluderinger
ip dhcp excluded-address 10.20.0.1 10.20.0.199    ! Gateways, APs & core-1's 80% pulje

! Opret DHCP Pools for core-2 (20% af IP-scopet - Backup)
ip dhcp pool VLAN10_Admin_Backup
 network 10.20.1.128 255.255.255.192
 default-router 10.20.1.129
 dns-server 10.20.1.196

ip dhcp pool VLAN20_Prod_Backup
 network 10.20.1.0 255.255.255.128
 default-router 10.20.1.1
 dns-server 10.20.1.196

ip dhcp pool VLAN30_IT_Backup
 network 10.20.1.192 255.255.255.224
 default-router 10.20.1.193
 dns-server 10.20.1.196

ip dhcp pool VLAN40_Gaester_Backup
 network 10.20.0.0 255.255.255.0
 default-router 10.20.0.1
 dns-server 10.20.1.196

! --- 8. SVI Gateways & HSRP ---
interface vlan 10
 description Gateway-Administration-Backup
 ip address 10.20.1.131 255.255.255.192
 standby 10 ip 10.20.1.129
 standby 10 priority 100
 standby 10 preempt
no shutdown

interface vlan 20
 description Gateway-Produktion-Backup
 ip address 10.20.1.3 255.255.255.128
 standby 20 ip 10.20.1.1
 standby 20 priority 100
 standby 20 preempt
no shutdown

interface vlan 30
 description Gateway-IT-Backup
 ip address 10.20.1.196 255.255.255.224
 standby 30 ip 10.20.1.193
 standby 30 priority 100
 standby 30 preempt
no shutdown

interface vlan 40
 description Gateway-Gaester-Active
 ip address 10.20.0.3 255.255.255.0
 standby 40 ip 10.20.0.1
 standby 40 priority 110                          ! Gæster kører aktivt over core-02 for load sharing
 standby 40 preempt
 ip access-group GUEST_ACL in
no shutdown

interface vlan 99
 description Gateway-Management-Backup
 ip address 10.20.1.227 255.255.255.240
 standby 99 ip 10.20.1.225
 standby 99 priority 100
 standby 99 preempt
 ip access-group MGMT_ACL in
no shutdown

! --- 9. Access Control Lists (ACLs) (Identiske med core-1) ---
ip access-list extended GUEST_ACL
 permit udp any any eq bootpc
 permit udp any any eq bootps
 permit udp any host 10.20.1.195 eq domain
 permit udp any host 10.20.1.196 eq domain
 deny ip any 10.20.1.0 0.0.0.127
 deny ip any 10.20.1.128 0.0.0.63
 deny ip any 10.20.1.192 0.0.0.31
 deny ip any 10.20.1.224 0.0.0.15
 permit ip any any
exit

ip access-list extended MGMT_ACL
 permit tcp 10.20.1.192 0.0.0.31 any eq 22
 permit tcp 10.20.1.192 0.0.0.31 any eq 443
 deny ip any any
exit

! --- 10. SSH Administration & DNS Service ---
ip domain name netic.dk
ip dns server
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 15
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## ⚙️ 4. Distribution Switch Left: `ds-1` (Catalyst 3650 - L2)

Ansvar: Aggregerer de redundante links fra alle access-switche og sender dem op til `core-1` via LACP.

```ios
enable
configure terminal
hostname ds-1

! --- 1. Opret VLANs ---
vlan 10
 name Administration
vlan 20
 name Produktion
vlan 30
 name IT
vlan 40
 name Gaester
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 2. Spanning Tree ---
spanning-tree mode rapid-pvst

! --- 3. EtherChannel Trunk til core-1 ---
interface range GigabitEthernet1/0/1-2
 description EtherChannel-Link-To-CORE-1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 channel-group 11 mode active
no shutdown

interface Port-Channel 11
 description Logical-Trunk-To-CORE-1
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! --- 4. Cross-Link Trunk til core-2 ---
interface GigabitEthernet1/0/22
 description Trunk-To-CORE-2-CrossLink
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! --- 5. Redundante Trunks til Access-switche (as-1 til as-5) ---
interface range GigabitEthernet1/0/3 - 7
 description Redundant-Trunks-Down-To-Access-Layer
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40,99
no shutdown

! --- 6. Management Interface ---
interface vlan 99
 description Switch-Management-IP
 ip address 10.20.1.228 255.255.255.240
 no shutdown
ip default-gateway 10.20.1.225

! --- 7. Sikring af ubrugte porte ---
interface range GigabitEthernet1/0/8 - 20
 description Unused-Ports-Blackhole
 switchport mode access
 switchport access vlan 999
 shutdown

! --- 8. SSH Administration ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 15
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## ⚙️ 5. Distribution Switch Right: `ds-2` (Catalyst 3650 - L2)

Ansvar: Aggregerer de redundante links fra alle access-switche og sender dem op til `core-2` via LACP.

```ios
enable
configure terminal
hostname ds-2

! --- 1. Opret VLANs ---
vlan 10
 name Administration
vlan 20
 name Produktion
vlan 30
 name IT
vlan 40
 name Gaester
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 2. Spanning Tree ---
spanning-tree mode rapid-pvst

! --- 3. EtherChannel Trunk til core-2 ---
interface range GigabitEthernet1/0/1-2
 description EtherChannel-Link-To-CORE-2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 channel-group 12 mode active
no shutdown

interface Port-Channel 12
 description Logical-Trunk-To-CORE-2
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! --- 4. Cross-Link Trunk til core-1 ---
interface GigabitEthernet1/0/22
 description Trunk-To-CORE-1-CrossLink
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

interface GigabitEthernet1/0/21
 description Trunk-To-CORE-1-CrossLink-2
 switchport trunk encapsulation dot1q
 switchport mode trunk
no shutdown

! --- 5. Redundante Trunks til Access-switche (as-1 til as-5) ---
interface range GigabitEthernet1/0/3 - 7
 description Redundant-Trunks-Down-To-Access-Layer
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40,99
no shutdown

! --- 6. Management Interface ---
interface vlan 99
 description Switch-Management-IP
 ip address 10.20.1.229 255.255.255.240
 no shutdown
ip default-gateway 10.20.1.225

! --- 7. Sikring af ubrugte porte ---
interface range GigabitEthernet1/0/8 - 20
 description Unused-Ports-Blackhole
 switchport mode access
 switchport access vlan 999
 shutdown

! --- 8. SSH Administration ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 15
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## 🔌 6. Access Switch 1: `as-1` (Catalyst 2960 - Administration)

Ansvar: Tilslutning af administrations-arbejdspladser (VLAN 10). Port Security tillader op til 2 MAC-adresser for at understøtte kablede pc'er connected bag om IP-telefoner.

```ios
enable
configure terminal
hostname as-1

! --- 1. Opret VLANs ---
vlan 10
 name Administration
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 2. Spanning Tree Mode ---
spanning-tree mode rapid-pvst

! --- 3. Uplink Trunks til ds-1 & ds-2 ---
interface range GigabitEthernet0/1 - 2
 description Redundant-Uplink-Trunks
 switchport mode trunk
 switchport trunk allowed vlan 10,99
 no shutdown

! --- 4. Administrationsporte (VLAN 10) ---
interface range FastEthernet0/1 - 20
 description Admin-Workstations-VLAN10
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
 spanning-tree bpduguard enable
 ! Port Security Aktivering (Max 2 pga. IP-telefon + PC)
 switchport port-security
 switchport port-security maximum 2
 switchport port-security mac-address sticky
 switchport port-security violation shutdown
 no shutdown

! --- 5. Management IP ---
interface vlan 99
 description Switch-Management-IP
 ip address 10.20.1.230 255.255.255.240
 no shutdown
ip default-gateway 10.20.1.225

! --- 6. Sikring af ubrugte porte ---
interface range FastEthernet0/21 - 24
 description Unused-Ports-Blackhole
 switchport mode access
 switchport access vlan 999
 shutdown

! --- 7. SSH Administration ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 4
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## 🔌 7. Access Switch 2: `as-2` (Catalyst 2960 - Produktion)

Ansvar: Forbinder produktionen (VLAN 20). Port Security tillader strictly kun 1 MAC og lukker porten med det samme ved uautoriserede forsøg.

```ios
enable
configure terminal
hostname as-2

! --- 1. Opret VLANs ---
vlan 20
 name Produktion
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 2. Spanning Tree Mode ---
spanning-tree mode rapid-pvst

! --- 3. Uplink Trunks til ds-1 & ds-2 ---
interface range GigabitEthernet0/1 - 2
 description Redundant-Uplink-Trunks
 switchport mode trunk
 switchport trunk allowed vlan 20,99
 no shutdown

! --- 4. Produktionsporte (VLAN 20) ---
interface range FastEthernet0/1 - 20
 description Production-Devices-VLAN20
 switchport mode access
 switchport access vlan 20
 spanning-tree portfast
 spanning-tree bpduguard enable
 ! Port Security Aktivering (Max 1)
 switchport port-security
 switchport port-security maximum 1
 switchport port-security mac-address sticky
 switchport port-security violation shutdown
 no shutdown

! --- 5. Management IP ---
interface vlan 99
 description Switch-Management-IP
 ip address 10.20.1.231 255.255.255.240
 no shutdown
ip default-gateway 10.20.1.225

! --- 6. Sikring af ubrugte porte ---
interface range FastEthernet0/21 - 24
 description Unused-Ports-Blackhole
 switchport mode access
 switchport access vlan 999
 shutdown

! --- 7. SSH Administration ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 4
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## 🔌 8. Access Switch 3: `as-3` (Catalyst 2960 - IT-Afdeling)

Ansvar: Forbinder IT (VLAN 30). Port Security tillader op til 5 MACs for at lade it-folk teste udstyr uden besvær. Violation sat til restrict.

```ios
enable
configure terminal
hostname as-3

! --- 1. Opret VLANs ---
vlan 30
 name IT
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 2. Spanning Tree Mode ---
spanning-tree mode rapid-pvst

! --- 3. Uplink Trunks til ds-1 & ds-2 ---
interface range GigabitEthernet0/1 - 2
 description Redundant-Uplink-Trunks
 switchport mode trunk
 switchport trunk allowed vlan 30,99
 no shutdown

! --- 4. IT Porte (VLAN 30) ---
interface range FastEthernet0/1 - 20
 description IT-Workstations-VLAN30
 switchport mode access
 switchport access vlan 30
 spanning-tree portfast
 spanning-tree bpduguard enable
 ! Port Security Aktivering (Max 5, Restrict mode til testborde)
 switchport port-security
 switchport port-security maximum 5
 switchport port-security violation restrict
 no shutdown

! --- 5. Management IP ---
interface vlan 99
 description Switch-Management-IP
 ip address 10.20.1.232 255.255.255.240
 no shutdown
ip default-gateway 10.20.1.225

! --- 6. Sikring af ubrugte porte ---
interface range FastEthernet0/21 - 24
 description Unused-Ports-Blackhole
 switchport mode access
 switchport access vlan 999
 shutdown

! --- 7. SSH Administration ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 4
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## 🔌 9. Access Switch 4: `as-4` (Catalyst 2960 - Gæster & WAPs)

Ansvar: Forbinder kablede gæsteborde og trådløse Access Points (VLAN 40). Port Security er deaktiveret på WAP-porte for ikke at blokere gæster.

```ios
enable
configure terminal
hostname as-4

! --- 1. Opret VLANs ---
vlan 40
 name Gaester
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 2. Spanning Tree Mode ---
spanning-tree mode rapid-pvst

! --- 3. Uplink Trunks til ds-1 & ds-2 ---
interface range GigabitEthernet0/1 - 2
 description Redundant-Uplink-Trunks
 switchport mode trunk
 switchport trunk allowed vlan 40,99
 no shutdown

! --- 4. WAP Tilslutninger (Ports 1-10) ---
! Ingen Port Security her, da many klienter forbinder over samme port.
interface range FastEthernet0/1 - 10
 description WAP-Uplinks-VLAN40
 switchport mode access
 switchport access vlan 40
 spanning-tree portfast
 spanning-tree bpduguard enable
 no shutdown

! --- 5. Kablede Gæsteborde (Ports 11-20) ---
! Her kan vi bruge Port Security, da der kun forventes 1 PC pr. kabelstik.
interface range FastEthernet0/11 - 20
 description Wired-Guest-Desks-VLAN40
 switchport mode access
 switchport access vlan 40
 spanning-tree portfast
 spanning-tree bpduguard enable
 switchport port-security
 switchport port-security maximum 1
 switchport port-security violation shutdown
 no shutdown

! --- 6. Management IP ---
interface vlan 99
 description Switch-Management-IP
 ip address 10.20.1.233 255.255.255.240
 no shutdown
ip default-gateway 10.20.1.225

! --- 7. Sikring af ubrugte porte ---
interface range FastEthernet0/21 - 24
 description Unused-Ports-Blackhole
 switchport mode access
 switchport access vlan 999
 shutdown

! --- 8. SSH Administration ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 4
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```

---

## 🔌 10. Access Switch 5: `as-5` (Catalyst 2960 - Management & Isolated)

Ansvar: Placeret i serverrummet/IT-kontoret og tilsluttet i det sikrede Management-netværk (VLAN 99) for kablet console/lokal adgang, samt isolering.

```ios
enable
configure terminal
hostname as-5

! --- 1. Opret VLANs ---
vlan 99
 name Management
vlan 999
 name Blackhole
exit

! --- 2. Spanning Tree Mode ---
spanning-tree mode rapid-pvst

! --- 3. Uplink Trunks til ds-1 & ds-2 ---
interface range GigabitEthernet0/1 - 2
 description Redundant-Uplink-Trunks
 switchport mode trunk
 switchport trunk allowed vlan 99
 no shutdown

! --- 4. Management / Secure IT kontor-porte (VLAN 99) ---
interface range FastEthernet0/1 - 20
 description Secure-Management-Ports-VLAN99
 switchport mode access
 switchport access vlan 99
 spanning-tree portfast
 spanning-tree bpduguard enable
 switchport port-security
 switchport port-security maximum 1
 switchport port-security mac-address sticky
 switchport port-security violation shutdown
 no shutdown

! --- 5. Management IP ---
interface vlan 99
 description Switch-Management-IP
 ip address 10.20.1.234 255.255.255.240
 no shutdown
ip default-gateway 10.20.1.225

! --- 6. Sikring af ubrugte porte ---
interface range FastEthernet0/21 - 24
 description Unused-Ports-Blackhole
 switchport mode access
 switchport access vlan 999
 shutdown

! --- 7. SSH Administration ---
ip domain name netic.dk
crypto key generate rsa
2048
username admin privilege 15 secret NeticPassword123!
line vty 0 4
 login local
 transport input ssh
exit
enable secret EnablePassword123!
end
write memory
```
