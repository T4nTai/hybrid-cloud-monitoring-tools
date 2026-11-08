#!/bin/bash
# =============================================================================
# Script: Deploy Kapacitor tasks (TICKscripts) cho hybrid cloud monitoring
# Mục đích: Nạp các .tick script vào Kapacitor và kích hoạt chúng
# Yêu cầu: Kapacitor đang chạy (docker-compose up -d kapacitor)
#
# Usage:
#   ./deploy-kapacitor-tasks.sh              # dùng localhost
#   KAPACITOR_HOST=52.175.59.167 ./deploy-kapacitor-tasks.sh
# =============================================================================

set -euo pipefail

HOST="${KAPACITOR_HOST:-localhost}"
PORT="${KAPACITOR_PORT:-9092}"
TICK_DIR="${TICK_DIR:-$(dirname "$0")/tick}"

echo "======================================================"
echo "Deploy Kapacitor tasks"
echo "======================================================"
echo "  Target : http://${HOST}:${PORT}"
echo "  Scripts: ${TICK_DIR}"
echo ""

# Kiểm tra Kapacitor có sống không
if ! curl -fsS "http://${HOST}:${PORT}/kapacitor/v1/ping" >/dev/null 2>&1; then
    echo "ERROR: Không kết nối được Kapacitor tại ${HOST}:${PORT}"
    echo "       Kiểm tra: docker-compose ps | grep kapacitor"
    exit 1
fi

# Tạo database cho output nếu chưa có
echo "[1/2] Đảm bảo database 'monitoring' tồn tại trong Kapacitor..."
curl -fsS -X POST "http://${HOST}:${PORT}/kapacitor/v1/databases" \
    -H 'Content-Type: application/json' \
    -d '{"name":"monitoring"}' >/dev/null 2>&1 || true
echo "      ✓ OK"

echo ""
echo "[2/2] Nạp và kích hoạt TICKscripts..."

count=0
for script in "${TICK_DIR}"/*.tick; do
    name=$(basename "$script" .tick)
    echo ""
    echo "  → ${name}.tick"

    # Xóa task cũ nếu có (idempotent — có thể deploy lại nhiều lần)
    curl -fsS -X DELETE "http://${HOST}:${PORT}/kapacitor/v1/tasks/${name}" >/dev/null 2>&1 || true

    # Tạo task ở trạng thái enabled luôn (status=enabled ngay khi POST)
    payload=$(python3 -c "
import json
script = open('${script}').read()
print(json.dumps({
    'id': '${name}',
    'type': 'stream',
    'status': 'enabled',
    'script': script,
    'dbrps': [{'db': 'monitoring', 'rp': 'autogen'}]
}))
")
    if ! curl -fsS -X POST "http://${HOST}:${PORT}/kapacitor/v1/tasks" \
        -H 'Content-Type: application/json' \
        -d "$payload" >/dev/null 2>&1; then
        echo "      ✗ LỖI khi nạp script (kiểm tra cú pháp TICKscript)"
        continue
    fi
    echo "      ✓ Đã nạp + kích hoạt (enabled)"
    count=$((count + 1))
done

echo ""
echo "======================================================"
echo "✓ Hoàn tất — ${count} task đang hoạt động"
echo "======================================================"
echo ""
echo "Kiểm tra:"
echo "  curl -s http://${HOST}:${PORT}/kapacitor/v1/tasks | python3 -m json.tool"
echo ""
echo "Xem alert đã ghi (Chronograf → Alert History hoặc InfluxDB):"
echo "  curl -s -G 'http://${HOST}:8086/query' \\"
echo "    --data-urlencode 'db=monitoring' \\"
echo "    --data-urlencode 'q=SELECT * FROM /alerts_.*/' \\"
echo "    -u admin:'\${INFLUXDB_PASSWORD}'"
echo ""
