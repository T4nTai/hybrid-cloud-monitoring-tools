#!/bin/bash
# WireGuard Server Setup Script for VM-B (AWS)
# Run this on VM-B with: sudo bash setup-wireguard-server.sh

set -e

echo "=== WireGuard Server Setup (VM-B) ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

# Install WireGuard
echo "[1/6] Installing WireGuard..."
apt update -qq
apt install -y wireguard wireguard-tools qrencode >/dev/null 2>&1

# Generate keys
echo "[2/6] Generating server keys..."
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIVATE=$(cat server_private.key)
SERVER_PUBLIC=$(cat server_public.key)

# Generate client keys
echo "[3/6] Generating client keys for VM-A..."
wg genkey | tee client_private.key | wg pubkey > client_public.key
CLIENT_PRIVATE=$(cat client_private.key)
CLIENT_PUBLIC=$(cat client_public.key)

# Get server public IP
SERVER_IP=$(curl -s ifconfig.me)

# Detect default network interface (AWS Ubuntu dùng ens5, không phải eth0)
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Detected interface: $IFACE"

# Create server config
echo "[4/6] Creating WireGuard server configuration..."
cat > /etc/wireguard/wg0.conf << EOL
[Interface]
Address = 10.200.200.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE

# VM-A (On-premise client)
[Peer]
PublicKey = $CLIENT_PUBLIC
AllowedIPs = 10.200.200.2/32
PersistentKeepalive = 25
EOL

# Enable IP forwarding
echo "[5/6] Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p >/dev/null

# Start WireGuard
echo "[6/6] Starting WireGuard..."
systemctl enable wg-quick@wg0 >/dev/null 2>&1
systemctl start wg-quick@wg0

# Display status
echo ""
echo "✅ WireGuard Server Setup Complete!"
echo ""
echo "========================================"
echo "Server Information:"
echo "========================================"
echo "Server Public IP: $SERVER_IP"
echo "Server VPN IP: 10.200.200.1"
echo "VPN Port: 51820/udp"
echo ""
echo "Server Public Key:"
echo "$SERVER_PUBLIC"
echo ""
echo "========================================"
echo "Client Configuration for VM-A:"
echo "========================================"
echo ""
cat > /root/vm-a-client.conf << EOL
[Interface]
Address = 10.200.200.2/24
PrivateKey = $CLIENT_PRIVATE
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $SERVER_IP:51820
AllowedIPs = 10.200.200.0/24
PersistentKeepalive = 25
EOL

cat /root/vm-a-client.conf
echo ""
echo "========================================"
echo ""
echo "📋 Next Steps:"
echo "1. Copy the client configuration above"
echo "2. Save it as /tmp/wg-client.conf on VM-A"
echo "3. Run setup-wireguard-client.sh on VM-A"
echo ""
echo "Or copy directly:"
echo "scp /root/vm-a-client.conf user@VM-A-IP:/tmp/wg-client.conf"
echo ""
echo "WireGuard Status:"
wg show
