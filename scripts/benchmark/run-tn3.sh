#!/bin/bash
# =============================================================================
# TN3 — Overhead của Telegraf lên throughput mạng
#
# nginx chạy trên VM-A. Client `ab` chạy TỪ VM-B đánh vào nginx VM-A qua VPN
# (10.200.200.2) => lưu lượng đi qua NIC thật, KHÔNG dùng loopback.
# Thay đổi interval Telegraf trên VM-A ở 4 mức: off / 30s / 15s / 5s.
#
# Usage: bash scripts/benchmark/run-tn3.sh [repeats]
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

REPEATS="${1:-$REPEATS}"
OUT="$(tn_outdir tn3)"
CONF=/etc/telegraf/telegraf.conf
BACKUP=/tmp/telegraf.conf.tn3.bak
URL="http://${VPN_CLIENT_IP}/"     # nginx trên VM-A
AB="ab -n 20000 -c 100 $URL"

log "=== TN3 bắt đầu — repeats=$REPEATS, output: $OUT ==="

log "[setup] Chuẩn bị nginx trên VM-A + backup telegraf.conf"
ssh_vma "sudo cp $CONF $BACKUP 2>/dev/null || true; sudo systemctl start nginx; sudo systemctl is-active nginx; echo 'TN3 nginx' | sudo tee /var/www/html/index.html >/dev/null"
ssh_vma "curl -s -o /dev/null -w 'nginx_local_http=%{http_code}\n' http://localhost/" || warn "nginx VM-A chưa trả lời"
ssh_vmb "curl -s -o /dev/null -w 'nginx_via_vpn_http=%{http_code}\n' $URL"       || warn "nginx VM-A không tới được từ VM-B qua VPN"

set_level() {
  # $1 = off | 30s | 15s | 5s
  local lvl="$1"
  if [ "$lvl" = "off" ]; then
    ssh_vma "sudo systemctl stop telegraf"
  else
    ssh_vma "sudo sed -i 's/^  interval = \"[0-9]*s\"/  interval = \"$lvl\"/' $CONF; sudo systemctl restart telegraf; sleep 15"
  fi
  log "  [level=$lvl] telegraf: $(ssh_vma 'systemctl is-active telegraf')"
}

for lvl in off 30s 15s 5s; do
  log "[level] $lvl"
  set_level "$lvl"
  ssh_vmb "$AB" >/dev/null 2>&1 || true   # warm-up (bỏ)
  for k in $(seq 1 "$REPEATS"); do
    f="$OUT/$lvl-run$k.txt"
    log "  → $(basename "$f")"
    {
      echo "# TN3 level=$lvl run=$k"
      ssh_vmb "$AB" 2>&1
      echo "# telegraf CPU/MEM trên VM-A (sau run):"
      ssh_vma "ps -C telegraf -o %cpu=,%mem= 2>/dev/null || echo 'telegraf not running'"
    } >"$f" 2>&1
  done
done

log "[restore] Khôi phục telegraf.conf + restart"
ssh_vma "sudo cp $BACKUP $CONF 2>/dev/null; sudo systemctl restart telegraf; systemctl is-active telegraf"

log "=== TN3 xong. Dữ liệu thô: $OUT ==="
log "Phân tích:  python analysis/tn3_analysis.py"
