#!/bin/bash
# =============================================================================
# lib/common.sh — hàm dùng chung cho các script TN1..TN4 (Phase 7)
# Nguồn: source "$(dirname "$0")/lib/common.sh"
# =============================================================================

# Repo root = 3 cấp trên thư mục chứa file này (scripts/benchmark/lib -> root)
BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="${ENV_FILE:-$BENCH_ROOT/configs/variables.env}"
RAW_DIR="${RAW_DIR:-$BENCH_ROOT/data/raw}"

# --- Logging ---
log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

# --- Nạp cấu hình ---
load_env() {
  [ -f "$ENV_FILE" ] || die "Không thấy $ENV_FILE — copy từ configs/variables.env.example"
  set -a; # shellcheck disable=SC1090
  . "$ENV_FILE"; set +a
  : "${CENTRAL_IP:?CENTRAL_IP chưa đặt trong $ENV_FILE}"
  : "${INFLUXDB_PASSWORD:?INFLUXDB_PASSWORD chưa đặt trong $ENV_FILE}"
  PING_COUNT="${PING_COUNT:-100}"
  PING_INTERVAL="${PING_INTERVAL:-0.2}"
  REPEATS="${REPEATS:-3}"
  WARMUP="${WARMUP:-1}"   # số lần chạy warm-up (bỏ, không tính vào kết quả)
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Thiếu lệnh: $1"; }

# --- Key path: tương đối thì hiểu theo repo root, ~ thì expand ---
_resolve_key() {
  case "$1" in
    /*|~*) eval echo "$1" ;;
    *) echo "$BENCH_ROOT/$1" ;;
  esac
}

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=12 -o LogLevel=ERROR)

ssh_vma()     { ssh -i "$(_resolve_key "${VMA_SSH_KEY:-$HOME/.ssh/id_rsa}")" "${SSH_OPTS[@]}" "${VMA_USER:-ubuntu}@${VMA_HOST}" "$@"; }
ssh_vmb()     { ssh -i "$(_resolve_key "${VMB_SSH_KEY}")" "${SSH_OPTS[@]}" "${VMB_USER:-ubuntu}@${VMB_PUBLIC_IP}" "$@"; }
ssh_central() { ssh -i "$(_resolve_key "${CENTRAL_SSH_KEY}")" "${SSH_OPTS[@]}" "${CENTRAL_USER:-azureuser}@${CENTRAL_IP}" "$@"; }

# ssh theo tên node logic: vma | vmb | central
ssh_node() {
  local node="$1"; shift
  case "$node" in
    vma|vm-a|a) ssh_vma "$@" ;;
    vmb|vm-b|b) ssh_vmb "$@" ;;
    central|azure) ssh_central "$@" ;;
    *) die "Node không hợp lệ: $node (dùng: vma|vmb|central)" ;;
  esac
}

# --- Lặp N lần một lệnh, ghi raw output vào <outdir>/<name>-run<k>.txt ---
# usage: do_repeat <outdir> <name> <n> <cmd...>
do_repeat() {
  local outdir="$1" name="$2" n="$3"; shift 3
  mkdir -p "$outdir"
  local k f
  if [ "${WARMUP:-0}" -ge 1 ]; then
    log "  (warm-up: $WARMUP lần, bỏ kết quả)"
    "$@" >/dev/null 2>&1 || true
  fi
  for k in $(seq 1 "$n"); do
    f="$outdir/${name}-run${k}.txt"
    log "  → $(basename "$f")"
    if ! "$@" >"$f" 2>&1; then warn "lệnh lỗi ở run $k (xem $f)"; fi
  done
}

# --- Đảm bảo thư mục output của một TN ---
tn_outdir() { local d="$RAW_DIR/$1"; mkdir -p "$d"; echo "$d"; }
