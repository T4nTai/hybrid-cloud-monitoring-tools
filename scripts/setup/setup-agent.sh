#!/bin/bash
# =============================================================================
# Script: Setup Agent VM (on-prem VM-A hoặc AWS VM-B/C/D)
# Mục đích: Cài Telegraf + benchmark tools trên agent VM
# Yêu cầu: Ubuntu 22.04, user có sudo
# =============================================================================

set -euo pipefail

echo "======================================================"
echo "Setting up Agent VM — Telegraf + Benchmark Tools"
echo "======================================================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "ERROR: Do not run this script as root. Run as normal user with sudo privileges."
   exit 1
fi

# Update system
echo "[1/4] Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Telegraf
echo "[2/4] Installing Telegraf..."
if ! command -v telegraf &> /dev/null; then
    # InfluxData APT repo GPG keys expired (Jan 2026), install from .deb directly
    echo "Downloading Telegraf 1.32.2 directly..."
    cd /tmp
    wget -q https://dl.influxdata.com/telegraf/releases/telegraf_1.32.2-1_amd64.deb
    sudo dpkg -i telegraf_1.32.2-1_amd64.deb
    cd -
    echo "✓ Telegraf installed"
else
    echo "✓ Telegraf already installed"
fi

# Grant raw socket capability for inputs.ping native mode
echo "[3/4] Granting raw socket capability to Telegraf..."
sudo setcap cap_net_raw+ep /usr/bin/telegraf

# Install benchmark tools
echo "[4/4] Installing benchmark tools..."
sudo apt install -y \
    sysbench \
    fio \
    iperf3 \
    apache2-utils \
    mtr-tiny \
    nginx \
    curl \
    wget \
    net-tools

echo ""
echo "======================================================"
echo "Agent VM setup completed!"
echo "======================================================"
echo "Installed:"
echo "  - Telegraf $(telegraf --version | head -1)"
echo "  - sysbench $(sysbench --version)"
echo "  - fio $(fio --version)"
echo "  - iperf3 $(iperf3 --version | head -1)"
echo "  - ab (Apache Bench)"
echo "  - mtr, nginx"
echo ""
echo "Next steps:"
echo "  1. Run configure-telegraf.sh to generate config"
echo "  2. sudo systemctl start telegraf"
echo "  3. sudo systemctl enable telegraf"
echo "  4. sudo journalctl -u telegraf -f  (check logs)"
echo ""
echo "Verify Telegraf ping capability:"
echo "  telegraf --config /etc/telegraf/telegraf.conf --test --input-filter ping"
echo "======================================================"
