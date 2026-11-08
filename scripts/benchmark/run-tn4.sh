#!/bin/bash
# =============================================================================
# TN4 — Scalability của pipeline giám sát (Telegraf -> InfluxDB -> Kapacitor)
#
# Tăng tải bằng cách giảm interval [agent] của Telegraf trên một node, rồi đo:
#   - số điểm ghi được trong 60s vs kỳ vọng  => % mất dữ liệu
#   - %CPU của InfluxDB (Central)
#   - độ trễ truy vấn InfluxDB
#
# Bản compute benchmark cũ đã chuyển sang: scripts/benchmark/run-baseline-compute.sh
# (dùng làm baseline nút đo ở Chương 3).
#
# Usage: bash scripts/benchmark/run-tn4.sh
#   TN4_NODE=vmb TN4_LEVELS="30s 15s 10s 5s 1s" TN4_WINDOW=60 bash ...
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

OUT="$(tn_outdir tn4)"
NODE="${TN4_NODE:-vmb}"
LEVELS="${TN4_LEVELS:-30s 15s 10s 5s 1s}"
WINDOW="${TN4_WINDOW:-60}"
STAB="${TN4_STAB:-20}"
CONF=/etc/telegraf/telegraf.conf

log "=== TN4 scalability — node=$NODE, window=${WINDOW}s, levels: $LEVELS ==="
ssh_node "$NODE" "sudo cp $CONF /tmp/telegraf.tn4.bak"
echo "level,interval_s,window_s,expected_pts,actual_pts,loss_pct,influx_cpu_pct,query_ms" >"$OUT/levels.csv"

set_interval() {
  local lvl="$1"
  # chỉ đổi interval của section [agent] (lần xuất hiện đầu tiên) để tránh overrun inputs.ping
  ssh_node "$NODE" "sudo sed -i '0,/^  interval = \"[0-9]*s\"/s//  interval = \"$lvl\"/' $CONF; sudo systemctl restart telegraf; sleep $STAB"
}

measure_level() {
  local lvl="$1" secs="$2"
  local expect=$(( WINDOW / secs ))
  sleep "$WINDOW"
  local actual cpu qms loss
  actual=$(ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -execute \"SELECT count(usage_user) FROM cpu WHERE host='vm-b' AND time > now()-${WINDOW}s\" -format csv" | tail -1 | awk -F, '{print $NF}' | tr -d '\r')
  case "$actual" in ''|*[!0-9]*) actual=0 ;; esac
  cpu=$(ssh_central "sudo docker stats --no-stream --format '{{.CPUPerc}}' influxdb 2>/dev/null" | tr -d '%' | head -1)
  qms=$(ssh_central "curl -s -o /dev/null -w '%{time_total}' 'http://localhost:8086/query?u=admin&p=$INFLUXDB_PASSWORD&db=monitoring&q=SELECT%20count(usage_user)%20FROM%20cpu%20WHERE%20time%3Enow()-10m'" | awk '{printf "%.0f", $1*1000}')
  loss=$(awk -v e="$expect" -v a="$actual" 'BEGIN{ if(e>0) printf "%.1f", (e-a)/e*100; else print 0 }')
  echo "$lvl,$secs,$WINDOW,$expect,$actual,$loss,${cpu:-NA},${qms:-NA}" >>"$OUT/levels.csv"
  log "  level=$lvl expect=$expect actual=$actual loss=${loss}% cpu_influx=${cpu}% query=${qms}ms"
}

for lvl in $LEVELS; do
  secs=$(echo "$lvl" | tr -d 's')
  log "[level] $lvl (interval ${secs}s)"
  set_interval "$lvl"
  measure_level "$lvl" "$secs"
done

log "[restore] khôi phục telegraf.conf trên $NODE"
ssh_node "$NODE" "sudo cp /tmp/telegraf.tn4.bak $CONF; sudo systemctl restart telegraf; sleep 3; systemctl is-active telegraf"

log "=== TN4 xong. Dữ liệu: $OUT/levels.csv ==="
log "Phân tích: python analysis/tn4_analysis.py"
