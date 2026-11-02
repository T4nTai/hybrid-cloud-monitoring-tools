#!/bin/bash
# =============================================================================
# Script: Health check cho toàn bộ hệ thống monitoring
# Mục đích: Kiểm tra InfluxDB, Telegraf, kết nối mạng, dữ liệu
# Usage: ./check-health.sh <CENTRAL-IP> <INFLUX-PASSWORD>
# =============================================================================

set -uo pipefail

CENTRAL_IP="${1:-}"
INFLUX_PASS="${2:-admin123}"

if [[ -z "$CENTRAL_IP" ]]; then
    echo "Usage: ./check-health.sh <CENTRAL-IP> [INFLUX-PASSWORD]"
    exit 1
fi

PASS=0
FAIL=0

check() {
    local desc="$1"
    local cmd="$2"
    printf "%-50s" "$desc"
    if eval "$cmd" &>/dev/null; then
        echo "[PASS]"
        ((PASS++))
    else
        echo "[FAIL]"
        ((FAIL++))
    fi
}

echo "======================================================"
echo "Health Check — Hybrid Cloud Monitoring"
echo "Central (Azure): $CENTRAL_IP"
echo "======================================================"

echo ""
echo "--- Network Connectivity ---"
check "Ping Central VM" "ping -c 2 -W 3 $CENTRAL_IP"
check "InfluxDB port 8086 reachable" "timeout 5 bash -c '</dev/tcp/$CENTRAL_IP/8086'"
check "Chronograf port 8888 reachable" "timeout 5 bash -c '</dev/tcp/$CENTRAL_IP/8888'"

echo ""
echo "--- InfluxDB ---"
check "InfluxDB ping endpoint" "curl -sf http://$CENTRAL_IP:8086/ping"
check "Database 'monitoring' exists" "curl -sf -G http://$CENTRAL_IP:8086/query --data-urlencode 'u=admin' --data-urlencode 'p=$INFLUX_PASS' --data-urlencode 'q=SHOW DATABASES' | grep -q monitoring"

echo ""
echo "--- Telegraf (local agent) ---"
if command -v telegraf &>/dev/null; then
    check "Telegraf installed" "command -v telegraf"
    check "Telegraf service active" "systemctl is-active telegraf"
    check "Telegraf raw socket capability" "getcap /usr/bin/telegraf | grep -q cap_net_raw"
else
    echo "Telegraf not installed on this host (OK if running from admin machine)"
fi

echo ""
echo "--- Data Flow (measurements in InfluxDB) ---"
for measurement in cpu mem disk net ping; do
    check "Measurement '$measurement' has data" \
        "curl -sf -G http://$CENTRAL_IP:8086/query --data-urlencode 'u=admin' --data-urlencode 'p=$INFLUX_PASS' --data-urlencode 'db=monitoring' --data-urlencode 'q=SELECT * FROM $measurement LIMIT 1' | grep -q values"
done

echo ""
echo "======================================================"
echo "Results: $PASS passed, $FAIL failed"
echo "======================================================"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "Troubleshooting tips:"
    echo "  - Port unreachable? Check Azure NSG rules (8086, 8888)"
    echo "  - No data? Check: sudo journalctl -u telegraf -n 50"
    echo "  - Ping 100% loss? Check ICMP rules + setcap cap_net_raw"
    echo "  - Auth failed? Verify INFLUXDB password matches"
    exit 1
fi

echo "All checks passed! System healthy."
