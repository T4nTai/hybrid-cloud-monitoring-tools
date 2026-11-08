#!/bin/bash
# =============================================================================
# TN1-Interference — Đo ảnh hưởng của chính Telegraf lên đường truyền đang đo.
#
# So sánh RTT khi Telegraf ĐANG chạy (lưu lượng thu thập metrics đi trên đường
# đo) so với khi TẮT Telegraf trên VM-A. Chênh lệch = mức self-interference.
#
#   ON  : telegraf chạy (mặc định)   -> interference-on-*.txt
#   OFF : dừng telegraf trên VM-A    -> interference-off-*.txt
#
# Usage: bash scripts/benchmark/run-tn1-interference.sh [repeats]
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

REPEATS="${1:-$REPEATS}"
OUT="$(tn_outdir tn1)"
PING="ping -c $PING_COUNT -i $PING_INTERVAL -W 2"

log "=== TN1-Interference — repeats=$REPEATS, output: $OUT ==="
log "Bật Telegraf trên VM-A (đảm bảo trạng thái ON) + đợi ổn định"
ssh_vma "sudo systemctl start telegraf; sleep 20; systemctl is-active telegraf"

log "[ON] VM-A telegraf=ON"
do_repeat "$OUT" "interference-on-p1-vmb"     "$REPEATS" ssh_vma "$PING $VPN_SERVER_IP"
do_repeat "$OUT" "interference-on-p2-central" "$REPEATS" ssh_vma "$PING $CENTRAL_IP"

log "[OFF] Dừng Telegraf trên VM-A"
ssh_vma "sudo systemctl stop telegraf; systemctl is-active telegraf || true"
do_repeat "$OUT" "interference-off-p1-vmb"     "$REPEATS" ssh_vma "$PING $VPN_SERVER_IP"
do_repeat "$OUT" "interference-off-p2-central" "$REPEATS" ssh_vma "$PING $CENTRAL_IP"

log "Khôi phục Telegraf trên VM-A"
ssh_vma "sudo systemctl start telegraf; systemctl is-active telegraf"

log "=== Xong. Phân tích: python analysis/tn1_analysis.py ==="
