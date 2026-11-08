#!/bin/bash
# =============================================================================
# TN4 — Compute Benchmark (CPU / Memory / I/O) trên từng node
#
# Chạy sysbench (cpu 1&2 thread, memory) và fio (randread, randwrite, seqread)
# trên mỗi node, REPEATS lần, lưu raw output.
#
# Usage: bash scripts/benchmark/run-tn4.sh [node ...]
#        node: vma | vmb | central     (mặc định: cả ba)
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
load_env
require_cmd ssh

REPEATS="${REPEATS:-3}"
if [ "$#" -gt 0 ]; then NODES=("$@"); else NODES=(vma vmb central); fi
OUT="$(tn_outdir tn4)"

# sysbench + fio (JSON)
SB_CPU1="sysbench cpu --cpu-max-prime=25000 --threads=1 --time=60 run"
SB_CPU2="sysbench cpu --cpu-max-prime=25000 --threads=2 --time=60 run"
SB_MEM="sysbench memory --memory-total-size=1G --threads=2 run"
FIO_COMMON="--ioengine=libaio --direct=1 --size=1G --runtime=60 --group_reporting --output-format=json"
FIO_RR="fio --name=randread  --rw=randread  --bs=4k $FIO_COMMON --iodepth=32"
FIO_RW="fio --name=randwrite --rw=randwrite --bs=4k $FIO_COMMON --iodepth=32"
FIO_SR="fio --name=seqread   --rw=read      --bs=1M $FIO_COMMON"

ensure_tools() {
  local node="$1"
  ssh_node "$node" "command -v sysbench >/dev/null && command -v fio >/dev/null && echo OK || { echo INSTALLING; sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sysbench fio; }"
}

log "=== TN4 bắt đầu — nodes: ${NODES[*]}, repeats=$REPEATS, output: $OUT ==="

for node in "${NODES[@]}"; do
  ndir="$OUT/$node"; mkdir -p "$ndir"
  log "[$node] kiểm tra tools"
  ensure_tools "$node" || warn "$node: cài tools thất bại"
  ssh_node "$node" "nproc; free -m | head -2; df -h / | tail -1; lscpu 2>/dev/null | grep -E 'Model name|^CPU\(s\)'" >"$ndir/specs.txt" 2>&1

  for k in $(seq 1 "$REPEATS"); do
    rdir="$ndir/run$k"; mkdir -p "$rdir"
    log "[$node] run $k/$REPEATS"
    ssh_node "$node" "$SB_CPU1" >"$rdir/sysbench-cpu-1t.txt" 2>&1 || warn "$node cpu1t run$k lỗi"
    ssh_node "$node" "$SB_CPU2" >"$rdir/sysbench-cpu-2t.txt" 2>&1 || warn "$node cpu2t run$k lỗi"
    ssh_node "$node" "$SB_MEM"  >"$rdir/sysbench-mem.txt"  2>&1 || warn "$node mem run$k lỗi"
    ssh_node "$node" "$FIO_RR"  >"$rdir/fio-randread.json"  2>&1 || warn "$node fio randread run$k lỗi"
    ssh_node "$node" "$FIO_RW"  >"$rdir/fio-randwrite.json" 2>&1 || warn "$node fio randwrite run$k lỗi"
    ssh_node "$node" "$FIO_SR"  >"$rdir/fio-seqread.json"   2>&1 || warn "$node fio seqread run$k lỗi"
  done
done

cat >"$OUT/LIMITATIONS.txt" <<'EOT'
GIỚI HẠN CẦN NÊU TRONG BÁO CÁO (TN4 — compute benchmark)
========================================================
1. Noisy neighbor: VM chạy trên hạ tầng chia sẻ; hàng xóm cùng host có thể
   làm sai lệch CPU/mem/IO. Cần chạy nhiều lần, báo cáo độ lệch chuẩn cao.
2. Burst credit: t3.small (AWS) và dòng B-series (Azure) là "burstable" —
   chỉ giữ được hiệu năng đỉnh trong thời gian ngắn, sau đó bị throttle.
   => benchmark 60s có thể chịu ảnh hưởng credit đã tiêu thụ; nên ghi lại
   trạng thái credit (CPU Credit Balance) trước/sau nếu có thể.
3. Ảo hoá KVM (on-prem) vs Nitro (AWS) vs Hyper-V (Azure): lớp ảo hoá khác
   nhau -> so sánh là "thực nghiệm" không phải "chuẩn hoá phần cứng".
4. I/O cloud (EBS/Azure Disk Standard_LRS) có độ trễ phụ thuộc tải mạng;
   kết quả fio có thể dao động mạnh giữa các lần.
5. Nên chạy >=3 lần và báo cáo mean ± std; loại bỏ outlier rõ rệt.
EOT

log "=== TN4 xong. Dữ liệu thô: $OUT ==="
log "  (Xem giới hạn phương pháp luận: $OUT/LIMITATIONS.txt)"
log "Phân tích:  python analysis/tn4_analysis.py"
