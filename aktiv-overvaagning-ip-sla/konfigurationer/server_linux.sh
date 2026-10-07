#!/bin/bash
# ========================================================
# Server Konfiguration (Linux - Dual-homed: ens4 mod R2, ens5 mod R3)
# ========================================================

# 1. Konfigurer ens4 (Mod R2 - Primaer vej)
sudo ip addr flush dev ens4
sudo ip addr add 10.1.24.4/30 dev ens4
sudo ip link set ens4 up

# 2. Konfigurer ens5 (Mod R3 - Backup vej)
sudo ip addr flush dev ens5
sudo ip addr add 10.1.34.4/30 dev ens5
sudo ip link set ens5 up

# 3. Opret Ekstern Test Destination paa Loopback (172.16.1.1/32)
sudo ip addr add 172.16.1.1/32 dev lo 2>/dev/null || true

# 4. Deaktiver strict reverse path filtering (RP_Filter)
# Noedvendigt for at Linux modtager og svarer paa pakker via backup-vejen (asymmetrisk routing)
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.default.rp_filter=0
sudo sysctl -w net.ipv4.conf.ens4.rp_filter=0
sudo sysctl -w net.ipv4.conf.ens5.rp_filter=0

# 5. Routing mod virksomhedens LAN (192.168.10.0/24)
# Primaer vej via R2 (metric 100), Backup via R3 (metric 200)
sudo ip route del 192.168.10.0/24 2>/dev/null || true
sudo ip route add 192.168.10.0/24 via 10.1.24.2 dev ens4 metric 100
sudo ip route append 192.168.10.0/24 via 10.1.34.3 dev ens5 metric 200

# 6. Start letvaegts webserver paa port 80 til Del 11 (TCP Connect test)
# Koeres i baggrunden hvis ikke allerede koerende
if ! pgrep -f "python3 -m http.server 80" > /dev/null; then
    sudo python3 -m http.server 80 >/dev/null 2>&1 &
    echo "Python HTTP server startet paa port 80."
fi

echo "Server netværk konfigureret:"
ip -br addr show
ip route show
