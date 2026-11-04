# NHẬT KÝ THÍ NGHIỆM — Hybrid Cloud Monitoring

## Môi trường
- **VM-A** (on-prem TP.HCM): KVM guest Ubuntu 22.04, `192.168.122.146`; WireGuard client chạy trên host KVM (`votantai-Vostro-5568`, `10.200.200.2`).
- **VM-B** (AWS ap-southeast-1): `t3.small`, `i-05eade1a7ee9ca803`, public `18.139.136.124`, private `172.31.24.239`.
- **Central** (Azure eastasia / Hong Kong): `Standard_B2s_v2`, public `52.175.59.167`, private `10.0.1.4`.
- **Probe TN2** (t3.micro, chỉ bật khi đo):
  - Tokyo `ap-northeast-1` `i-0ee74acbc5e391332` `13.114.32.34`
  - Sydney `ap-southeast-2` `i-085de44595a4cc79c` `3.107.235.224`
  - Virginia `us-east-1` `i-08a39413eaeedcb54` `54.175.25.19`
  - Frankfurt `eu-central-1` `i-0109b0447fe23f7c1` `3.122.255.181`

## Stack
- TICK: InfluxDB 1.8 + Chronograf 1.10 (Docker Compose trên Azure Central)
- Telegraf 1.32.2 trên VM-A, VM-B — interval 10s
- DB `monitoring`, user `admin`
- WireGuard `10.200.200.0/24` (VM-B `.1` server, VM-A `.2` client)

---

## 2026-11-04 — Nhật ký chạy

### TN1 — Hybrid vs Cross-cloud
- Telegraf ping liên tục: vm-a (395 điểm), vm-b (772 điểm).
- iperf3 VM-A→VM-B qua VPN: TCP up 139/137 Mbps, reverse 136/135 Mbps, UDP 100M loss 0.011%.
- mtr từ VM-B: hop Tokyo 11, Sydney 11, Virginia 12, Frankfurt 12, Azure-HK 21, HCM-VPN 1.
- Kết quả: `data/raw/tn1-network.txt`, `data/raw/iperf3-vm-a-vm-b.txt`.
- **Còn thiếu:** P4 (ping public IP không VPN) + iperf3 VM-A→Azure → cần chạy trên VM-A.

### TN2 — Khoảng cách vs Latency
- Deploy 4 probe, ping 3 vòng × 100 gói từ VM-B, 0% loss toàn bộ.
- RTT: HCM(VPN) 31.4, HK 37.3, Tokyo 67.9, Sydney 164.9, Frankfurt 185.5, Virginia 223.0 ms.
- Hồi quy: RTT = 0.0144×km + 21.28, R² = 0.81. Sydney là outlier.
- Kết quả: `data/raw/tn2-distance-latency.txt`.

### TN3 — Overhead Telegraf (VM-B)
- 4 mức (off/30s/15s/5s) × 3 lần `ab -n 20000 -c 100`.
- Throughput ~12.4–12.7k req/s ở mọi mức (trong nhiễu). p99 = 9 ms không đổi.
- Băng thông monitoring tăng tuyến tính với 1/interval (~0.23/0.46/0.83 KB/s).
- Kết quả: `data/raw/tn3-overhead.txt`.
- **Còn thiếu:** chạy trên VM-A.

### TN4 — Compute AWS vs Azure
- 3 lần × 60s, direct=1 iodepth=32.
- AWS t3.small: CPU 1T 302, 2T 476 ev/s; randread 3048 IOPS; randwrite 3010 IOPS; seqread 138 MB/s.
- Azure B2s_v2: CPU 1T 843, 2T 877 ev/s; randread 9392 IOPS; randwrite 558 IOPS; seqread 128 MB/s.
- Azure CPU nhanh ~2.8×, randread ~3×; AWS randwrite nhanh ~5.4×.
- Kết quả: `data/raw/benchmark-vm-b.txt`, `data/raw/benchmark-azure-central.txt`.
- **Còn thiếu:** chạy trên VM-A.

---

## Việc còn lại
- [ ] Chạy TN3 + TN4 + iperf3-to-Azure + ping public (P4) trên VM-A → `scripts/benchmark/run-vm-a-full.sh`
- [ ] Export CSV từ InfluxDB
- [ ] Tạo dashboard Chronograf (7 panel)
- [ ] Viết báo cáo `report/05-ketqua.md`
- [ ] Tắt 4 probe TN2 (tiết kiệm chi phí)
