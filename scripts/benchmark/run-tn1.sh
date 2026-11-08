#!/bin/bash
# =============================================================================
# TN1 — Network Latency / Loss / Jitter (VPN vs public) + iperf3 throughput
#
# Đo 4 điểm (mỗi điểm REPEATS lần), điều khiển qua SSH từ máy admin:
#   P1  VM-A -> VM-B  qua VPN        (10.200.200.1)
#   P2  VM-A -> Central (public)     (CENTRAL_IP)
#   P3  VM-B -> Central (public)
#   P4  VM-A -> VM-B  qua Internet   (VMB_PUBLIC_IP)
# Kèm mtr (đường đi) và iperf3 VM-A -> VM-B qua VPN.
#
# Usage: bash scripts/benchmark/run-tn1.sh [repeats]
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

REPEATS="${1:-$REPEATS}"
OUT="$(tn_outdir tn1)"
PING="ping -c $PING_COUNT -i $PING_INTERVAL -W 2"

log "=== TN1 bắt đầu — repeats=$REPEATS, output: $OUT ==="

log "[P1] VM-A -> VM-B (VPN $VPN_SERVER_IP)"
do_repeat "$OUT" "p1-vpn-vma-vmb" "$REPEATS" ssh_vma "$PING $VPN_SERVER_IP"

log "[P2] VM-A -> Central (public $CENTRAL_IP)"
do_repeat "$OUT" "p2-vma-central" "$REPEATS" ssh_vma "$PING $CENTRAL_IP"

log "[P3] VM-B -> Central (public $CENTRAL_IP)"
do_repeat "$OUT" "p3-vmb-central" "$REPEATS" ssh_vmb "$PING $CENTRAL_IP"

log "[P4] VM-A -> VM-B (Internet $VMB_PUBLIC_IP)"
do_repeat "$OUT" "p4-public-vma-vmb" "$REPEATS" ssh_vma "$PING $VMB_PUBLIC_IP"

log "[mtr] Đường đi (1 lần mỗi tuyến)"
ssh_vma "sudo mtr -rwc 20 --no-dns $VPN_SERVER_IP" >"$OUT/mtr-vma-vmb-vpn.txt" 2>&1 || warn "mtr p1 lỗi"
ssh_vma "sudo mtr -rwc 20 --no-dns $CENTRAL_IP"    >"$OUT/mtr-vma-central.txt" 2>&1 || warn "mtr p2 lỗi"
ssh_vmb "sudo mtr -rwc 20 --no-dns $CENTRAL_IP"    >"$OUT/mtr-vmb-central.txt" 2>&1 || warn "mtr p3 lỗi"

log "[iperf3] Server trên VM-B, client từ VM-A qua VPN"
ssh_vmb "pkill -f 'iperf3 -s' 2>/dev/null; sleep 1; nohup iperf3 -s >/tmp/iperf3srv.log 2>&1 & sleep 1; pgrep -f 'iperf3 -s' >/dev/null && echo SERVER_UP || echo SERVER_FAIL"
for k in $(seq 1 "$REPEATS"); do
  ssh_vma "iperf3 -c $VPN_SERVER_IP -t 30 -J" >"$OUT/iperf3-vpn-run$k.json" 2>&1 || warn "iperf3 run $k lỗi"
done
ssh_vmb "pkill -f 'iperf3 -s' 2>/dev/null; true"

log "=== TN1 xong. Dữ liệu thô: $OUT ==="
log "Phân tích:  python analysis/tn1_analysis.py"
