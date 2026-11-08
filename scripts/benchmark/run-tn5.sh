#!/bin/bash
# =============================================================================
# TN5 — Hiệu quả giám sát end-to-end (phát hiện & cảnh báo sự cố)
#
# Cách chạy: từ máy admin (cần SSH tới VM-B và Central).
# Tiêm độ trễ (netem) lên VM-B, ghi mốc thời gian, rồi đo thời điểm cảnh báo
# Kapacitor (alerts_rtt / alerts_packet_loss) xuất hiện trong InfluxDB.
#
# Usage: bash scripts/benchmark/run-tn5.sh [duration_s] [delay_ms] [loss_pct]
#        mặc định: 180s, delay 300ms, loss 0
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

DURATION="${1:-180}"
DELAY="${2:-300}"
LOSS="${3:-0}"
OUT="$(tn_outdir tn5)"

IFACE="$(ssh_vmb "ip route | grep default | awk '{print \$5}' | head -1")"
T0="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "$T0" >"$OUT/t0.txt"
log "=== TN5 bắt đầu — t0=$T0, iface=$IFACE, delay=${DELAY}ms, loss=${LOSS}%, dur=${DURATION}s ==="

log "[baseline] RTT hiện tại"
ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -execute 'SELECT last(average_response_ms) FROM ping GROUP BY host,url'" >"$OUT/baseline_ping.txt" 2>&1

log "[inject] netem trên VM-B (tự gỡ sau ${DURATION}s)"
ssh_vmb "sudo tc qdisc del dev $IFACE root 2>/dev/null; sudo tc qdisc add dev $IFACE root netem delay ${DELAY}ms loss ${LOSS}%; nohup bash -c 'sleep $DURATION; sudo tc qdisc del dev $IFACE root' >/dev/null 2>&1 & sleep 1; tc qdisc show dev $IFACE" | tee "$OUT/inject_show.txt"

WAIT=$((DURATION + 150))
log "[wait] chờ ${WAIT}s cho Kapacitor phát hiện (window+evaluation)..."
sleep "$WAIT"

log "[collect] cảnh báo sau t0"
ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -execute \"SELECT * FROM alerts_rtt WHERE time >= '$T0'\" -format csv" >"$OUT/alerts_rtt.csv" 2>&1
ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -execute \"SELECT * FROM alerts_packet_loss WHERE time >= '$T0'\" -format csv" >"$OUT/alerts_packet_loss.csv" 2>&1
ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -execute \"SELECT mean(average_response_ms) FROM ping WHERE time >= '$T0' GROUP BY host,url\" -format csv" >"$OUT/ping_during.csv" 2>&1

log "[revert] gỡ netem trên VM-B"
ssh_vmb "sudo tc qdisc del dev $IFACE root 2>/dev/null; tc qdisc show dev $IFACE"

log "=== TN5 xong. Dữ liệu: $OUT ==="
echo "--- alerts_rtt.csv ---"; head -5 "$OUT/alerts_rtt.csv"
echo "--- alerts_packet_loss.csv ---"; head -5 "$OUT/alerts_packet_loss.csv"
