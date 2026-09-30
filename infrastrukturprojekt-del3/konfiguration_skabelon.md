# Konfigurationsskabeloner for Logging og Monitorering (Del 3)

Dette dokument indeholder komplette, afprøvede konfigurationsskabeloner for **Cisco Catalyst 3650 & 2960X**, **FortiGate 60F HA**, **Proxmox VE**, **Linux Webservere** samt **LibreNMS & Netdata**.

---

## 1. Cisco Switches (Catalyst 3650 & 2960X)

### A. SNMPv2c og Sikker SNMPv3 Konfiguration
Konfigurationen udrulles på `ds-01`, `ds-02` og `ms-01`:

```cisco
! ==============================================================================
! CISCO IOS / IOS-XE: SNMPv2c og SNMPv3 KONFIGURATION
! ==============================================================================

! 1. Tidsstempler (Kritisk for præcise logs og traps)
service timestamps debug datetime msec localtime show-timezone
service timestamps log datetime msec localtime show-timezone

! 2. SNMPv2c (Kompatibilitet med restriktiv Access-List)
ip access-list standard ACL-SNMP-NMS
 permit 192.168.100.150
 permit 192.168.99.100
 deny any log

snmp-server community public RO ACL-SNMP-NMS
snmp-server location "Datacenter Rack 1"
snmp-server contact "admin@elev-lab.dk"

! 3. SNMPv3 (Enterprise Hærdning - authPriv med SHA & AES)
! Definer SNMP View (tillad adgang til standard MIB-træ)
snmp-server view VIEW-LIBRENMS iso included

! Opret SNMPv3 Gruppe med authPriv sikkerhedsniveau
snmp-server group GRP-LIBRENMS v3 priv read VIEW-LIBRENMS access ACL-SNMP-NMS

! Opret SNMPv3 Bruger med SHA autentificering og AES-128 kryptering
snmp-server user snmpadmin GRP-LIBRENMS v3 auth sha AuthPassWord2026! priv aes 128 PrivPassWord2026! access ACL-SNMP-NMS

! 4. SNMP Traps mod LibreNMS NMS
snmp-server enable traps
snmp-server host 192.168.100.150 version 3 priv snmpadmin
```

---

### B. Central Syslog Konfiguration
Switchene sender alle loghændelser fra Severity 0 (Emergency) til Severity 5 (Notifications) til LibreNMS:

```cisco
! ==============================================================================
! CISCO IOS / IOS-XE: CENTRAL SYSLOG KONFIGURATION
! ==============================================================================

! Vælg source-interface til logging (VLAN 100 for direkte transit)
logging source-interface Vlan100

! Central Syslog Server (LibreNMS)
logging host 192.168.100.150 transport udp port 514

! Logning niveau (Notifications og værre fanges)
logging trap notifications
logging facility local7

! Logning af login-forsøg og konfigurationsændringer
archive
 log config
  logging enable
  notify syslog contenttype plaintext
  hidekeys
```

---

### C. Network Time Protocol (NTP)
Sikrer at switchene altid har millisekund-præcis tid:

```cisco
! ==============================================================================
! CISCO IOS / IOS-XE: NTP TIDSSYNKRONISERING
! ==============================================================================
clock timezone CET 1 0
clock summer-time CEST recurring last Sun Mar 2:00 last Sun Oct 3:00

ntp source Vlan100
ntp server 192.168.100.1 prefer
ntp server 192.168.200.2
```

---

### D. Cisco Flexible NetFlow (FNF på Cisco Catalyst 3650)
Opsætning af flow-overvågning for at eksportere datastrømme mod LibreNMS/NetFlow collector:

```cisco
! ==============================================================================
! CISCO CATALYST 3650: FLEXIBLE NETFLOW (FNF)
! ==============================================================================

! 1. Flow Record (Definerer hvilke felter der matches og indsamles)
flow record FNF-RECORD-IPV4
 match ipv4 tos
 match ipv4 protocol
 match ipv4 source address
 match ipv4 destination address
 match transport source-port
 match transport destination-port
 match interface input
 collect routing source as
 collect routing destination as
 collect routing next-hop address ipv4
 collect transport tcp flags
 collect counter bytes long
 collect counter packets long
 collect timestamp sys-uptime first
 collect timestamp sys-uptime last

! 2. Flow Exporter (Definerer modtageren - LibreNMS på UDP port 2055)
flow exporter FNF-EXPORTER-LIBRENMS
 destination 192.168.100.150
 source Vlan100
 transport udp 2055
 template data timeout 60

! 3. Flow Monitor (Knytter Record og Exporter sammen med cache)
flow monitor FNF-MONITOR-IPV4
 record FNF-RECORD-IPV4
 exporter FNF-EXPORTER-LIBRENMS
 cache timeout active 60
 cache timeout inactive 15

! 4. Anvend på relevante interfaces (Core uplinks og kunde trunks)
interface Port-channel3
 ip flow monitor FNF-MONITOR-IPV4 input

interface Port-channel1
 ip flow monitor FNF-MONITOR-IPV4 input
```

---

## 2. FortiGate 60F HA Cluster

Konfigurationen tilføjes på FortiGate i global/management kontekst:

```fortinet
# ==============================================================================
# FORTIGATE 60F: SNMP, SYSLOG OG NETFLOW
# ==============================================================================

# 1. SNMP Agent & v3 Konfiguration
config system snmp sysinfo
    set status enable
    set description "FortiGate-60F HA Cluster"
    set location "Datacenter Rack 1"
    set contact-info "admin@elev-lab.dk"
end

config system snmp user
    edit "snmpadmin"
        set status enable
        set security-level auth-priv
        set auth-proto sha256
        set auth-pwd "AuthPassWord2026!"
        set priv-proto aes256
        set priv-pwd "PrivPassWord2026!"
    next
end

# 2. Central Syslog Videresendelse til LibreNMS
config log syslogd setting
    set status enable
    set server "192.168.100.150"
    set mode udp
    set port 514
    set facility local7
    set format default
end

# 3. NetFlow Eksport
config system netflow
    set collector-ip 192.168.100.150
    set collector-port 2055
    set active-flow-timeout 1
    set inactive-flow-timeout 15
end
```

---

## 3. Proxmox VE & Linux Kundeserverne (Host-Niveau)

### A. Net-SNMP Daemon Konfiguration (`/etc/snmp/snmpd.conf`)
Installeres på Proxmox hosten (`pve`) og webserverne:
```bash
sudo apt update && sudo apt install -y snmpd snmp libsnmp-dev
```

Filen `/etc/snmp/snmpd.conf`:
```ini
# ==============================================================================
# /etc/snmp/snmpd.conf - Net-SNMP Konfiguration
# ==============================================================================
# Lyt på alle IPv4 interfaces
agentAddress udp:161

# System Information
sysLocation    Datacenter Dell R630
sysContact     admin@elev-lab.dk

# SNMPv2c Community (Restrikteret til LibreNMS IP)
rocommunity public 192.168.100.150
rocommunity public 127.0.0.1

# Tillad fuld system- og diskmonitering
includeAllDisks 10%
load 12 10 8
```
Genstart servicen: `sudo systemctl restart snmpd`

---

### B. Rsyslog Forwarding (`/etc/rsyslog.d/60-librenms.conf`)
Videresender alle Linux systemhændelser og Nginx access/error logs til LibreNMS:
```ini
# ==============================================================================
# /etc/rsyslog.d/60-librenms.conf - Forward til central Syslog
# ==============================================================================
*.* @192.168.100.150:514
```
Genstart rsyslog: `sudo systemctl restart rsyslog`

---

### C. Netdata Installation og Konfiguration
På Proxmox host og webserverne udrulles Netdata til 1-sekunds realtidsmetrik:
```bash
# Hurtig udrulning via officiel kickstart
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh --stable-channel --disable-telemetry
```

Konfiguration i `/etc/netdata/netdata.conf`:
```ini
[global]
    run as user = netdata
    web files owner = root
    web files group = netdata
    bind socket to IP = 0.0.0.0
    default port = 19999
    update every = 1
    memory mode = dbengine
```
Netdata UI kan herefter tilgås direkte på `http://<server-ip>:19999`.

---

## 4. LibreNMS Konfiguration (Server-Niveau)

### A. Tilføjelse af Enheder via CLI
På LibreNMS serveren (`192.168.100.150`) tilføjes enhederne nemt via CLI:
```bash
# Tilføj Cisco Core Switche med SNMPv3
./addhost.php -v3 -u snmpadmin -a SHA -A "AuthPassWord2026!" -x AES -X "PrivPassWord2026!" -l authPriv 192.168.100.2
./addhost.php -v3 -u snmpadmin -a SHA -A "AuthPassWord2026!" -x AES -X "PrivPassWord2026!" -l authPriv 192.168.100.3

# Tilføj Cisco Access Switch med SNMPv2c
./addhost.php -v2c -c public 192.168.99.21

# Tilføj Proxmox Hypervisor
./addhost.php -v2c -c public 192.168.99.100
```

### B. HTTP Service Monitorering af Kunde Webservere
I LibreNMS under **Services -> Add Service** oprettes en HTTP check for hver kunde:
*   **Service:** `HTTP`
*   **Target IP:** `192.168.10.10` (Alfa), `192.168.20.10` (Bravo), `192.168.30.10` (Charlie), `192.168.40.10` (Delta).
*   **Parameters:** `-u / -p 80 -e "HTTP/1.1 200 OK"`
*   **Check Interval:** 60 sekunder.
*   **Alert:** Udløses hvis statuskoden ikke er 200 OK inden for 5 sekunder.
