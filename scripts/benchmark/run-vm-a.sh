#!/bin/bash
# =============================================================================
# Benchmark VM-A (on-prem) — chạy trên VM-A bằng user thường (có sudo)
# Usage: bash run-vm-a.sh
# Kết quả in ra màn hình theo từng mục, copy toàn bộ paste lại để tổng hợp.
# =============================================================================
set -uo pipefail

echo "########## SPECS ##########"
nproc
free -m | head -2
df -h / | tail -1

echo ""
echo "########## SYSBENCH CPU ##########"
sysbench cpu --cpu-max-prime=20000 --time=30 run 2>&1 | tail -18

echo ""
echo "########## FIO RANDREAD 4k ##########"
fio --name=randread --ioengine=libaio --rw=randread --bs=4k --size=512M \
    --numjobs=4 --runtime=30 --time_based --group_reporting 2>&1 \
    | grep -E "read:|IOPS|clat|lat \(|cpu "

echo ""
echo "########## FIO RANDWRITE 4k ##########"
fio --name=randwrite --ioengine=libaio --rw=randwrite --bs=4k --size=512M \
    --numjobs=4 --runtime=30 --time_based --group_reporting 2>&1 \
    | grep -E "write:|IOPS|clat|lat \(|cpu "

echo ""
echo "########## NGINX + AB ##########"
sudo systemctl start nginx
sudo systemctl is-active nginx
echo "VM-A nginx benchmark" | sudo tee /var/www/html/index.html >/dev/null
ab -n 10000 -c 100 http://127.0.0.1/ 2>&1 \
    | grep -E "Requests per second|Time per request|Transfer rate|Complete requests|Failed requests|Concurrency"

echo ""
echo "########## AB QUA VPN (VM-A -> nginx VM-B 10.200.200.1) ##########"
ab -n 5000 -c 50 http://10.200.200.1/ 2>&1 \
    | grep -E "Requests per second|Time per request|Transfer rate|Complete requests|Failed requests|Concurrency"

echo ""
echo "########## DONE ##########"
