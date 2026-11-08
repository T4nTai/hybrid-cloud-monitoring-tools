#!/bin/bash
# =============================================================================
# export-influxdb.sh — Xuất dữ liệu thô từ InfluxDB (Central) ra CSV
# Usage: bash scripts/analysis/export-influxdb.sh
# Kết quả: data/raw/influx/<measurement>.csv
# =============================================================================
source "$(dirname "$0")/../benchmark/lib/common.sh"
load_env
require_cmd ssh

OUT="$RAW_DIR/influx"; mkdir -p "$OUT"
MEASUREMENTS="${MEASUREMENTS:-cpu mem disk net net_response http_response ping system}"

log "=== Export InfluxDB -> $OUT ==="
for m in $MEASUREMENTS; do
  log "  $m"
  ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -format csv -execute 'SELECT * FROM \"$m\"'" \
    >"$OUT/$m.csv" 2>&1 || warn "export $m lỗi"
done
ssh_central "sudo docker exec influxdb influx -username admin -password '$INFLUXDB_PASSWORD' -database monitoring -execute 'SHOW MEASUREMENTS'" \
  >"$OUT/_measurements.txt" 2>&1 || true

log "=== Xong. Files: $OUT ==="
