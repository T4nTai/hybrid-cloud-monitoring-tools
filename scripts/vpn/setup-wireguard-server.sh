#!/bin/bash
# WireGuard Server Setup for VM-B (AWS Singapore)
# Run this on VM-B: sudo bash setup-wireguard-server.sh

set -e

echo "=== WireGuard Server Setup on VM-B ==="

# Update and install WireGuard
echo "[1/6] Installing WireGuard..."
apt-get update -qq
apt-get install -y wireguard iptables

# Generate server keys
echo "[2/6] Generating server keys..."
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key

SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

echo "Server Public Key: $SERVER_PUBLIC_KEY"

# Create WireGuard config
echo "[3/6] Creating WireGuard config..."
cat > /etc/wireguard/wg0.conf << WGCONF
[Interface]
Address = 10.200.200.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client (VM-A) will be added after client setup
WGCONF

# Enable IP forwarding
echo "[4/6] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Open firewall port
echo "[5/6] Configuring firewall..."
ufw allow 51820/udp comment "WireGuard VPN"
ufw allow from 10.200.200.0/24 comment "WireGuard internal"

# Start WireGuard
echo "[6/6] Starting WireGuard..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo ""
echo "✅ WireGuard Server setup complete!"
echo ""
echo "======================================"
echo "Server Public Key (save this):"
echo "$SERVER_PUBLIC_KEY"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Copy this public key"
echo "2. Run setup-wireguard-client.sh on VM-A with this key"
echo "3. Get VM-A's public key"
echo "4. Run add-wireguard-peer.sh on VM-B with VM-A's public key"
echo ""
