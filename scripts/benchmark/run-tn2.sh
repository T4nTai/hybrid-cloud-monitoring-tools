#!/bin/bash
# =============================================================================
# TN2 — Geographic Distance vs Latency
#
# Từ mỗi "probe" (node ở một vị trí địa lý) ping tới Central, ghi lại RTT.
# Kết quả dùng để hồi quy:  RTT = a * khoang_cach_km + b
#
# Danh sách probe lấy theo thứ tự ưu tiên:
#   1) configs/probes.tsv  (nếu có) — mỗi dòng TAB: name <TAB> distance_km <TAB> ssh_user <TAB> ssh_host <TAB> ssh_key
#   2) mặc định: vm-a (on-prem) và vm-b (Singapore) theo configs/variables.env
#
# Usage: bash scripts/benchmark/run-tn2.sh [repeats]
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

REPEATS="${1:-$REPEATS}"
OUT="$(tn_outdir tn2)"
META="$OUT/probes.tsv"          # name <TAB> distance_km <TAB> raw-file-glob
: >"$META"

BASE_PING="ping -c $PING_COUNT -i $PING_INTERVAL -W 2"

probe_ping() {
  # $1=name $2=distance_km $3=ssh_user $4=ssh_host $5=key
  local name="$1" dist="$2" user="$3" host="$4" key="$5"
  local keypath; keypath="$(_resolve_key "$key")"
  log "  probe $name ($dist km) -> Central $CENTRAL_IP"
  local k
  for k in $(seq 1 "$REPEATS"); do
    local f="$OUT/${name}-run${k}.txt"
    if _is_local_host "$host"; then
      bash -c "$BASE_PING $CENTRAL_IP" >"$f" 2>&1 || warn "probe $name run $k lỗi (xem $f)"
    else
      ssh -i "$keypath" "${SSH_OPTS[@]}" "${user}@${host}" "$BASE_PING $CENTRAL_IP" >"$f" 2>&1 \
        || warn "probe $name run $k lỗi (xem $f)"
    fi
  done
  printf '%s\t%s\t%s\n' "$name" "$dist" "$OUT/${name}-run*.txt" >>"$META"
}

log "=== TN2 bắt đầu — repeats=$REPEATS, output: $OUT ==="

if [ -f "$BENCH_ROOT/configs/probes.tsv" ]; then
  log "Dùng configs/probes.tsv"
  while IFS=$'\t' read -r name dist user host key; do
    [ -z "${name:-}" ] && continue
    case "$name" in \#*) continue ;; esac
    probe_ping "$name" "$dist" "$user" "$host" "$key"
  done <"$BENCH_ROOT/configs/probes.tsv"
else
  log "Không có configs/probes.tsv — dùng mặc định vm-a, vm-b"
  warn "Khoảng cách mặc định là ƯỚC LƯỢNG tới Central (eastasia/Hong Kong) — chỉnh lại cho đúng!"
  probe_ping "vm-a" "${VMA_DISTANCE_KM:-1500}" "${VMA_USER:-ubuntu}" "${VMA_HOST}" "${VMA_SSH_KEY:-$HOME/.ssh/id_rsa}"
  probe_ping "vm-b" "${VMB_DISTANCE_KM:-2570}" "${VMB_USER:-ubuntu}" "${VMB_PUBLIC_IP}" "${VMB_SSH_KEY}"
fi

log "=== TN2 xong. Metadata: $META ==="
log "Phân tích:  python analysis/tn2_analysis.py"
