#!/bin/bash
# =============================================================================
# Script: Setup Central VM (Azure) — Docker + TICK Stack
# Mục đích: Cài Docker + Compose V2 + chạy InfluxDB + Chronograf + Kapacitor
# Yêu cầu: Ubuntu 22.04 trên Azure VM, user có sudo
# =============================================================================

set -euo pipefail

echo "======================================================"
echo "Setting up Central VM (Azure) — TICK Stack"
echo "======================================================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "ERROR: Do not run this script as root. Run as normal user with sudo privileges."
   exit 1
fi

# Update system (non-interactive để tránh treo do popup kernel upgrade)
echo "[1/4] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && sudo apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# Install Docker + Docker Compose Plugin
echo "[2/4] Installing Docker and dependencies..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    echo "✓ Docker & Docker Compose V2 installed."
else
    echo "✓ Docker already installed"
fi

# Support tools
echo "[3/4] Installing support tools..."
sudo apt-get install -y curl wget net-tools mtr-tiny

# Create directory structure
PROJECT_DIR="$HOME/hybrid-cloud-monitoring"
mkdir -p "$PROJECT_DIR/kapacitor/tick"

echo "[4/4] Preparing Docker Compose configuration..."

# Tạo mật khẩu ngẫu nhiên an toàn nếu file .env chưa có
RANDOM_PASS=$(openssl rand -hex 12)
if [ ! -f "$PROJECT_DIR/.env" ]; then
cat > "$PROJECT_DIR/.env" <<EOF
INFLUXDB_PASSWORD=${RANDOM_PASS}
EOF
fi

cat > "$PROJECT_DIR/docker-compose.yml" <<'EOF'
services:
  influxdb:
    image: influxdb:1.8
    container_name: influxdb
    restart: always
    ports:
      - "8086:8086"
    environment:
      - INFLUXDB_DB=monitoring
      - INFLUXDB_ADMIN_USER=admin
      - INFLUXDB_ADMIN_PASSWORD=${INFLUXDB_PASSWORD}
      - INFLUXDB_HTTP_AUTH_ENABLED=true
    volumes:
      - influxdb-data:/var/lib/influxdb
    networks:
      - monitoring

  chronograf:
    image: chronograf:1.10
    container_name: chronograf
    restart: always
    ports:
      - "8888:8888"
    environment:
      - INFLUXDB_URL=http://influxdb:8086
      - INFLUXDB_USERNAME=admin
      - INFLUXDB_PASSWORD=${INFLUXDB_PASSWORD}
    volumes:
      - chronograf-data:/var/lib/chronograf
    networks:
      - monitoring
    depends_on:
      - influxdb

  kapacitor:
    image: kapacitor:1.7
    container_name: kapacitor
    restart: always
    ports:
      - "9092:9092"
    environment:
      - KAPACITOR_HOSTNAME=kapacitor
      - KAPACITOR_INFLUXDB_0_URLS_0=http://influxdb:8086
      - KAPACITOR_INFLUXDB_0_USERNAME=admin
      - KAPACITOR_INFLUXDB_0_PASSWORD=${INFLUXDB_PASSWORD}
    volumes:
      - kapacitor-data:/var/lib/kapacitor
      - ./kapacitor/tick:/etc/kapacitor/tick:ro
    networks:
      - monitoring
    depends_on:
      - influxdb

volumes:
  influxdb-data:
  chronograf-data:
  kapacitor-data:

networks:
  monitoring:
    driver: bridge
EOF

# Copy Kapacitor tasks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/../../docker/kapacitor" ]; then
    cp -r "$SCRIPT_DIR/../../docker/kapacitor/"* "$PROJECT_DIR/kapacitor/" 2>/dev/null || true
    chmod +x "$PROJECT_DIR/kapacitor/deploy-kapacitor-tasks.sh" 2>/dev/null || true
    echo "✓ Copied Kapacitor tasks → $PROJECT_DIR/kapacitor/"
else
    echo "⚠ Không tìm thấy docker/kapacitor — copy thủ công TICKscripts sau"
fi

PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo '<AZURE-PUBLIC-IP>')

echo ""
echo "======================================================"
echo "Central VM setup completed!"
echo "======================================================"
echo "Next steps:"
echo "  1. Áp dụng quyền Docker group (chạy không cần sudo):"
echo "     newgrp docker"
echo "  2. Đi đến thư mục dự án:"
echo "     cd $PROJECT_DIR"
echo "  3. Khởi động TICK stack:"
echo "     docker compose up -d"
echo "  4. Kiểm tra trạng thái containers:"
echo "     docker compose ps"
echo ""
echo "Access URLs:"
echo "  - Chronograf: http://$PUBLIC_IP:8888"
echo "  - InfluxDB:   http://$PUBLIC_IP:8086"
echo "  - Kapacitor:  http://$PUBLIC_IP:9092"
echo "======================================================"