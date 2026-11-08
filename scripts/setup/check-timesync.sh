#!/bin/bash
# =============================================================================
# check-timesync.sh — Kiểm tra đồng bộ thời gian (chrony/NTP) trên các node.
# Đây là ĐIỀU KIỆN TIÊN QUYẾT để số liệu latency/jitter đáng tin cậy.
#
# Usage: bash scripts/setup/check-timesync.sh [vma vmb central]
# =============================================================================
source "$(dirname "$0")/../benchmark/lib/common.sh"
load_env

if [ "$#" -gt 0 ]; then NODES=("$@"); else NODES=(vma vmb central); fi
THRESH_MS="${THRESH_MS:-1.0}"   # ngưỡng |offset| mong muốn (ms) — cảnh báo nếu vượt

log "=== Kiểm tra đồng bộ thời gian (ngưỡng |offset| < ${THRESH_MS} ms) ==="
FAIL=0
for node in "${NODES[@]}"; do
  log "--- $node ---"
  out="$(ssh_node "$node" "timedatectl show -p NTPSynchronized --value 2>/dev/null; (chronyc tracking 2>/dev/null | grep -Ei 'System time|Last offset|Leap status') || echo 'chronyc: not available'; (chronyc sources 2>/dev/null | head -4)" 2>&1)" \
    || { warn "$node không truy cập được"; FAIL=$((FAIL+1)); continue; }
  echo "$out" | sed 's/^/  /'

  if echo "$out" | grep -q "NTPSynchronized=yes"; then
    echo "  [$node] NTP synchronized: OK"
  else
    echo "  [$node] [!] NTP CHUA dong bo"
    FAIL=$((FAIL+1))
  fi
done

echo ""
if [ "$FAIL" -eq 0 ]; then
  log "Tất cả node đã đồng bộ thời gian — số liệu latency/jitter đáng tin cậy."
else
  warn "$FAIL node chưa đồng bộ. Cài/bật chrony trước khi đo:"
  warn "  sudo apt-get install -y chrony && sudo systemctl enable --now chrony"
fi
