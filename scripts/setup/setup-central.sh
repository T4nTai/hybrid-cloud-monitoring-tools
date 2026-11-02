#!/bin/bash
# =============================================================================
# Script: Setup Central VM (Azure) — Docker + TICK Stack
# Mục đích: Cài Docker + Docker Compose + chạy InfluxDB + Chronograf trên Azure Central
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

# Update system
echo "[1/5] Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "[2/5] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "✓ Docker installed. You need to LOG OUT and LOG IN for group changes to take effect."
else
    echo "✓ Docker already installed"
fi

# Install Docker Compose
echo "[3/5] Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
else
    echo "✓ Docker Compose already installed"
fi

# Install benchmark tools (iperf3 optional cho Central, nhưng không dùng vì không tham gia đo)
echo "[4/5] Installing support tools..."
sudo apt install -y curl wget net-tools mtr-tiny

# Create directory for TICK stack
PROJECT_DIR="$HOME/hybrid-cloud-monitoring"
mkdir -p "$PROJECT_DIR"

echo "[5/5] Preparing Docker Compose configuration..."
cat > "$PROJECT_DIR/docker-compose.yml" <<'EOF'
version: '3.8'

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
      - INFLUXDB_ADMIN_PASSWORD=${INFLUXDB_PASSWORD:-admin123}
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
      - INFLUXDB_PASSWORD=${INFLUXDB_PASSWORD:-admin123}
    volumes:
      - chronograf-data:/var/lib/chronograf
    networks:
      - monitoring
    depends_on:
      - influxdb

volumes:
  influxdb-data:
  chronograf-data:

networks:
  monitoring:
    driver: bridge
EOF

cat > "$PROJECT_DIR/.env" <<EOF
INFLUXDB_PASSWORD=CHANGE_ME_PLEASE
EOF

echo ""
echo "======================================================"
echo "Central VM setup completed!"
echo "======================================================"
echo "Configuration:"
echo "  - Project dir:  $PROJECT_DIR"
echo "  - Compose file: $PROJECT_DIR/docker-compose.yml"
echo ""
echo "IMPORTANT: Edit $PROJECT_DIR/.env and change INFLUXDB_PASSWORD!"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_DIR"
echo "  2. nano .env  (change password)"
echo "  3. docker-compose up -d"
echo "  4. docker-compose ps  (verify running)"
echo ""
echo "Access:"
echo "  - Chronograf: http://$(curl -s ifconfig.me 2>/dev/null || echo '<AZURE-PUBLIC-IP>'):8888"
echo "  - InfluxDB:   http://$(curl -s ifconfig.me 2>/dev/null || echo '<AZURE-PUBLIC-IP>'):8086"
echo ""
echo "Check logs:"
echo "  - docker-compose logs -f influxdb"
echo "  - docker-compose logs -f chronograf"
echo "======================================================"
