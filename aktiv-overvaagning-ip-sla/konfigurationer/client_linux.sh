#!/bin/bash
# ========================================================
# Client Konfiguration (Linux - ens4)
# ========================================================

# 1. Tildel IP-adresse til ens4
sudo ip addr flush dev ens4
sudo ip addr add 192.168.10.50/24 dev ens4
sudo ip link set ens4 up

# 2. Sæt R1 som default gateway
sudo ip route del default 2>/dev/null
sudo ip route add default via 192.168.10.1 dev ens4

echo "Client netværk konfigureret:"
ip -br addr show dev ens4
ip route show
