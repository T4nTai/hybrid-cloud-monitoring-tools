#!/bin/bash
# WireGuard Client Setup Script for VM-A (On-premise)
# Run this on VM-A with: sudo bash setup-wireguard-client.sh

set -e

echo "=== WireGuard Client Setup (VM-A) ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

# Install WireGuard
echo "[1/4] Installing WireGuard..."
apt update -qq
apt install -y wireguard wireguard-tools >/dev/null 2>&1

# Check for config file
if [[ ! -f /tmp/wg-client.conf ]]; then
    echo "Error: Client configuration not found at /tmp/wg-client.conf"
    echo ""
    echo "Please copy the client config from VM-B:"
    echo "  scp ubuntu@47.131.178.196:/root/vm-a-client.conf /tmp/wg-client.conf"
    echo ""
    echo "Or paste the configuration manually:"
    echo "  sudo nano /tmp/wg-client.conf"
    exit 1
fi

# Copy config
echo "[2/4] Installing client configuration..."
cp /tmp/wg-client.conf /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

# Start WireGuard
echo "[3/4] Starting WireGuard..."
systemctl enable wg-quick@wg0 >/dev/null 2>&1
systemctl start wg-quick@wg0

# Test connection
echo "[4/4] Testing VPN connection..."
sleep 2

echo ""
echo "✅ WireGuard Client Setup Complete!"
echo ""
echo "========================================"
echo "Client Information:"
echo "========================================"
echo "Client VPN IP: 10.200.200.2"
echo "Server VPN IP: 10.200.200.1"
echo ""
echo "WireGuard Status:"
wg show
echo ""
echo "========================================"
echo "Testing connectivity..."
echo "========================================"
if ping -c 3 -W 2 10.200.200.1 >/dev/null 2>&1; then
    echo "✅ SUCCESS: Can ping VM-B at 10.200.200.1"
    ping -c 3 10.200.200.1
else
    echo "⚠️  WARNING: Cannot ping VM-B yet"
    echo "   Check firewall rules on AWS Security Group"
fi
echo ""
