#!/bin/bash
# =============================================================================
# cleanup.sh — Dọn process/file tạm sau khi chạy benchmark (KHÔNG xoá hạ tầng)
# Usage: bash scripts/analysis/cleanup.sh
# =============================================================================
source "$(dirname "$0")/../benchmark/lib/common.sh"
load_env

log "=== Cleanup sau benchmark ==="

log "[-] Tắt iperf3 server trên VM-B"
ssh_vmb "pkill -f 'iperf3 -s' 2>/dev/null; echo done" || warn "VM-B không truy cập được"

log "[-] Tắt nginx (load test) trên VM-A"
ssh_vma "sudo systemctl stop nginx 2>/dev/null; echo done" || warn "VM-A không truy cập được"

log "[-] Xoá file tạm trên các node"
ssh_vmb "rm -f /tmp/iperf3srv.log; echo done" || true
ssh_vma "rm -f /tmp/telegraf.conf.tn3.bak /tmp/telegraf.conf.bak*; echo done" || true

log "[-] Restart telegraf (nếu lỡ dừng khi chạy TN3)"
ssh_vma "sudo systemctl start telegraf 2>/dev/null; systemctl is-active telegraf" || true

log "=== Cleanup xong (hạ tầng vẫn nguyên vẹn) ==="
