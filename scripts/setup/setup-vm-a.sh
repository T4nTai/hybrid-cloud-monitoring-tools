#!/bin/bash
# =============================================================================
# Setup VM-A (on-premise) — WireGuard client + Telegraf agent
# Chạy trên VM-A bằng user thường (script tự dùng sudo):
#   bash setup-vm-a.sh
# =============================================================================

set -euo pipefail

CENTRAL_IP="52.175.59.167"
INFLUX_PASS="Hybrid2024SecurePass!"
WG_SERVER_PUBKEY="5TbvV6/fw2cSxCJdyxYhaYo8wboj5ExGzlTf3qNjaSU="
WG_SERVER_ENDPOINT="18.139.136.124:51820"
WG_CLIENT_PRIVKEY="AK/g3uo+6Jd+nO6HhcZ0ewdqta6EDj0a6AoF7X4Lu28="
WG_CLIENT_IP="10.200.200.2/24"
WG_SERVER_IP="10.200.200.1"

if [[ $EUID -eq 0 ]]; then
   echo "ERROR: Đừng chạy bằng root. Chạy: bash setup-vm-a.sh"
   exit 1
fi

echo "======================================================"
echo "SETUP VM-A — WireGuard client + Telegraf"
echo "======================================================"

# ---------------------------------------------------------------- WireGuard --
echo "[1/6] Cài WireGuard..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard wireguard-tools

echo "[2/6] Ghi cấu hình WireGuard..."
sudo mkdir -p /etc/wireguard
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
Address = ${WG_CLIENT_IP}
PrivateKey = ${WG_CLIENT_PRIVKEY}

[Peer]
PublicKey = ${WG_SERVER_PUBKEY}
Endpoint = ${WG_SERVER_ENDPOINT}
AllowedIPs = 10.200.200.0/24
PersistentKeepalive = 25
EOF
sudo chmod 600 /etc/wireguard/wg0.conf

echo "[3/6] Khởi động WireGuard..."
sudo systemctl enable wg-quick@wg0 >/dev/null 2>&1
sudo systemctl restart wg-quick@wg0
sleep 3
sudo wg show || true

echo ""
echo "[4/6] Test kết nối VPN tới VM-B (${WG_SERVER_IP})..."
if ping -c 4 -W 2 ${WG_SERVER_IP} >/dev/null 2>&1; then
    echo "✅ VPN OK — ping được VM-B"
    ping -c 4 ${WG_SERVER_IP} | tail -2
else
    echo "⚠️  Chưa ping được ${WG_SERVER_IP}."
    echo "   Kiểm tra: sudo wg show (có latest handshake?), sudo systemctl status wg-quick@wg0"
fi

# ----------------------------------------------------------------- Telegraf --
echo "[5/6] Cài Telegraf + benchmark tools..."
if ! command -v telegraf &> /dev/null; then
    cd /tmp
    wget -q https://dl.influxdata.com/telegraf/releases/telegraf_1.32.2-1_amd64.deb
    sudo dpkg -i telegraf_1.32.2-1_amd64.deb
    cd - >/dev/null
fi
sudo setcap cap_net_raw+ep /usr/bin/telegraf

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sysbench fio iperf3 apache2-utils mtr-tiny nginx curl wget net-tools

echo "[6/6] Ghi cấu hình Telegraf (host=vm-a → ${CENTRAL_IP})..."
sudo tee /etc/telegraf/telegraf.conf > /dev/null <<EOF
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "2s"
  flush_interval = "10s"
  hostname = "vm-a"
  omit_hostname = false

[[outputs.influxdb]]
  urls = ["http://${CENTRAL_IP}:8086"]
  database = "monitoring"
  username = "admin"
  password = "${INFLUX_PASS}"
  timeout = "10s"

[[inputs.cpu]]
  percpu = false
  totalcpu = true
  collect_cpu_time = true
  report_active = false

[[inputs.mem]]

[[inputs.disk]]
  mount_points = ["/"]

[[inputs.net]]

[[inputs.system]]

[[inputs.ping]]
  urls = ["${WG_SERVER_IP}", "${CENTRAL_IP}", "8.8.8.8"]
  count = 20
  interval = "10s"
  ping_interval = 0.2
  method = "native"
  deadline = 10
EOF

sudo systemctl enable telegraf >/dev/null 2>&1
sudo systemctl restart telegraf
sleep 5
echo ""
echo "Telegraf: $(systemctl is-active telegraf)"

echo ""
echo "======================================================"
echo "✅ VM-A SETUP XONG"
echo "======================================================"
echo "VPN:      ${WG_CLIENT_IP} <-> ${WG_SERVER_IP}"
echo "Telegraf: host=vm-a → http://${CENTRAL_IP}:8086"
echo ""
echo "Kiểm tra:"
echo "  sudo wg show"
echo "  ping -c 4 ${WG_SERVER_IP}"
echo "  sudo journalctl -u telegraf -n 20 --no-pager"
echo "======================================================"
