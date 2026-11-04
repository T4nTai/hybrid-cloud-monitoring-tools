#!/bin/bash
# Script đầy đủ cho VM-A (on-prem TP.HCM)
# Chạy: TN1-P4 (ping public không VPN), TN3 (overhead), TN4 (compute), iperf3 to Azure
# Kết quả lưu ~/benchmark-results/
set -uo pipefail

OUT="$HOME/benchmark-results"
mkdir -p "$OUT"

VMB_PUBLIC="18.139.136.124"
VMB_VPN="10.200.200.1"
AZURE_PUBLIC="52.175.59.167"

echo "===== VM-A BENCHMARK SUITE ====="
echo "Thời gian: $(date)"
echo "Host: $(hostname)"
nproc | tee "$OUT/specs.txt"
free -m | head -2 | tee -a "$OUT/specs.txt"
df -h / | tail -1 | tee -a "$OUT/specs.txt"
lscpu 2>/dev/null | grep -E "Model name|^CPU\(s\)|Architecture" | tee -a "$OUT/specs.txt"

echo ""
echo "===== KIỂM TRA TOOLS ====="
MISSING=""
for t in sysbench fio iperf3 ab nginx mtr ping; do
  if ! command -v "$t" >/dev/null 2>&1; then MISSING="$MISSING $t"; fi
done
if [ -n "$MISSING" ]; then
  echo "Thiếu tools:$MISSING — cài đặt..."
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    sysbench fio iperf3 apache2-utils nginx mtr-tcp 2>&1 | tail -5
else
  echo "Tất cả tools đã cài."
fi

echo ""
echo "########## TN1-P4 — Ping public (không VPN) vs VPN ##########"
echo "=== Ping VM-B public (3 vòng × 100) ===" | tee "$OUT/tn1-p4-ping-public.txt"
for i in 1 2 3; do
  echo "--- Vòng $i ---" | tee -a "$OUT/tn1-p4-ping-public.txt"
  ping -c 100 -i 0.2 -W 2 "$VMB_PUBLIC" 2>&1 | tail -2 | tee -a "$OUT/tn1-p4-ping-public.txt"
done

echo "=== mtr VM-B public ===" | tee "$OUT/tn1-p4-mtr-public.txt"
sudo mtr -rwc 20 --no-dns "$VMB_PUBLIC" | tee -a "$OUT/tn1-p4-mtr-public.txt"

echo "=== VPN overhead = RTT(VPN) - RTT(public) ===" | tee "$OUT/tn1-p4-overhead.txt"
ping -c 50 -i 0.2 "$VMB_VPN" 2>&1 | tail -2 | tee -a "$OUT/tn1-p4-overhead.txt"

echo ""
echo "########## TN1 — iperf3 VM-A → Azure (qua Internet) ##########"
echo "=== iperf3 to Azure public (3 bài) ===" | tee "$OUT/tn1-iperf-azure.txt"
echo "Lưu ý: cần bật iperf3 server trên Azure: iperf3 -s -4"
read -p "Nhấn Enter khi Azure đã bật iperf3 server..." dummy

for i in 1 2 3; do
  echo "--- Bài $i: TCP upload 30s ---" | tee -a "$OUT/tn1-iperf-azure.txt"
  iperf3 -c "$AZURE_PUBLIC" -t 30 2>&1 | tee -a "$OUT/tn1-iperf-azure.txt" | tail -3
done

echo ""
echo "########## TN3 — Overhead Telegraf ##########"
CONF=/etc/telegraf/telegraf.conf
BACKUP=/tmp/telegraf.conf.bak-vma
sudo cp "$CONF" "$BACKUP"
sudo systemctl start nginx 2>/dev/null || echo "nginx not installed, skip"

for level in off 30s 15s 5s; do
  echo "=== Level $level ===" | tee "$OUT/tn3-$level.txt"
  
  if [ "$level" = "off" ]; then
    sudo systemctl stop telegraf
    sleep 2
  else
    sudo sed -i "s/^  interval = \"[0-9]*s\"/  interval = \"$level\"/" "$CONF"
    sudo sed -i 's/^  count = 20/  count = 5/' "$CONF"
    sudo systemctl restart telegraf
    sleep 15
  fi

  for run in 1 2 3; do
    echo "--- Run $run ---" | tee -a "$OUT/tn3-$level.txt"
    ab -n 20000 -c 100 http://127.0.0.1/ 2>&1 \
      | tee -a "$OUT/tn3-$level.txt" \
      | grep -E "Requests per second|Time per request|^ *99%"
  done
done

sudo cp "$BACKUP" "$CONF"
sudo systemctl restart telegraf

echo ""
echo "########## TN4 — Compute Benchmark ##########"
for run in 1 2 3; do
  echo "=== Run $run ===" | tee "$OUT/tn4-run$run.txt"
  
  sysbench cpu --cpu-max-prime=25000 --threads=1 --time=60 run 2>&1 \
    | tee -a "$OUT/tn4-cpu-1t-run$run.txt" \
    | grep -E "events per second|total number"
  
  sysbench cpu --cpu-max-prime=25000 --threads=2 --time=60 run 2>&1 \
    | tee -a "$OUT/tn4-cpu-2t-run$run.txt" \
    | grep -E "events per second|total number"
  
  sysbench memory --memory-total-size=1G --threads=2 run 2>&1 \
    | tee -a "$OUT/tn4-mem-run$run.txt" \
    | grep -E "transferred|MiB/sec"
  
  fio --name=randread --ioengine=libaio --direct=1 --rw=randread --bs=4k \
      --size=1G --runtime=60 --iodepth=32 --group_reporting 2>&1 \
    | tee -a "$OUT/tn4-fio-randread-run$run.txt" \
    | grep -E "read: IOPS|clat.*avg"
  
  fio --name=randwrite --ioengine=libaio --direct=1 --rw=randwrite --bs=4k \
      --size=1G --runtime=60 --iodepth=32 --group_reporting 2>&1 \
    | tee -a "$OUT/tn4-fio-randwrite-run$run.txt" \
    | grep -E "write: IOPS|clat.*avg"
  
  fio --name=seqread --ioengine=libaio --direct=1 --rw=read --bs=1M \
      --size=1G --runtime=60 --group_reporting 2>&1 \
    | tee -a "$OUT/tn4-fio-seqread-run$run.txt" \
    | grep -E "read: IOPS|BW="
done

echo ""
echo "########## HOÀN TẤT ##########"
echo "Kết quả tại: $OUT"
ls -lh "$OUT"
