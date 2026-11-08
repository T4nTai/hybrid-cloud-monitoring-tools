#!/bin/bash
# =============================================================================
# TN4-load — Sinh tải tổng hợp để đo capacity ghi của InfluxDB
#
# Với mỗi mức tốc độ (điểm/giây), sinh tải trong DUR giây bằng loadgen_influx.py
# (chạy từ máy admin tới InfluxDB công cộng), rồi đo:
#   - số điểm ghi được vs gửi đi  => % mất
#   - %CPU InfluxDB
#
# Usage: bash scripts/benchmark/run-tn4-load.sh
#   TN4_RATES="100 500 1000 2000 5000 10000" TN4_LOAD_DUR=30 bash ...
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

OUT="$(tn_outdir tn4)"
RATES="${TN4_RATES:-100 500 1000 2000 5000 10000}"
DUR="${TN4_LOAD_DUR:-30}"
GEN="$(cd "$(dirname "$0")" && pwd)/loadgen_influx.py"
URL="http://${CENTRAL_IP}:8086"

log "=== TN4-load — rates: $RATES, duration=${DUR}s, target=$URL ==="
echo "rate,points_s,duration_s,sent,written,loss_pct,influx_cpu_pct" >"$OUT/load.csv"

for r in $RATES; do
  sent=$(( r * DUR ))
  m="tn4load_${r}"
  log "[rate] $r pts/s trong ${DUR}s (measurement=$m)"
  python3 "$GEN" --url "$URL" --db monitoring --user admin --password "$INFLUXDB_PASSWORD" \
    --measurement "$m" --rate "$r" --duration "$DUR" >/dev/null 2>&1 || warn "loadgen lỗi ở rate=$r"
  sleep 2
  written=$(ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -execute 'SELECT count(value) FROM $m' -format csv" | tail -1 | awk -F, '{print $NF}' | tr -d '\r')
  case "$written" in ''|*[!0-9]*) written=0 ;; esac
  cpu=$(ssh_central "sudo docker stats --no-stream --format '{{.CPUPerc}}' influxdb 2>/dev/null" | tr -d '%' | head -1)
  loss=$(awk -v s="$sent" -v w="$written" 'BEGIN{ if(s>0) printf "%.1f",(s-w)/s*100; else print 0 }')
  echo "$r,$r,$DUR,$sent,$written,$loss,${cpu:-NA}" >>"$OUT/load.csv"
  log "  sent=$sent written=$written loss=${loss}% cpu_influx=${cpu}%"
done

log "=== TN4-load xong. Dữ liệu: $OUT/load.csv ==="
