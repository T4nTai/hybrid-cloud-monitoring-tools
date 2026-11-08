# Phương pháp luận đo lường (Methodology)

Tài liệu này quy định cách chạy và xử lý số liệu cho 4 thí nghiệm TN1–TN4.
Mục tiêu: đảm bảo tính **hợp lệ (validity)**, **tái lập (reproducibility)** và
**có thể kiểm chứng (verifiability)** của kết quả.

---

## 1. Quy tắc đo chung

| Tham số | Giá trị | Lý do |
|---|---|---|
| Số gói mỗi lần ping | 100 | đủ mẫu để tính p95/p99 ổn định |
| Khoảng cách gói (ping) | 0.2 s | tránh dồn cụm, tổng ~20 s/lần |
| Số lần lặp mỗi cấu hình | ≥ 3 | tính được mean ± std |
| Warm-up | 1 lần (bỏ kết quả) | loại ảnh hưởng khởi động (ARP, route cache, ramp-up nginx) |
| Thời lượng sysbench/fio | 60 s | đủ dài để ổn định, không quá dài (tránh burst credit cạn) |
| ab | 20,000 req, c=100 | tải đủ lớn để đo throughput ổn định |

**Quy tắc bắt buộc:**
- Luôn chạy **≥3 lần** cho mỗi cấu hình và báo cáo **mean ± std**.
- Luôn có **warm-up** (script dùng biến `WARMUP`, mặc định 1).
- Chạy **cùng khung giờ** cho các cấu hình cần so sánh (giảm nhiễu theo thời điểm).
- Không bao giờ báo cáo 1 con số đơn lẻ.

Cấu hình qua `configs/variables.env` (`PING_COUNT`, `PING_INTERVAL`, `REPEATS`, `WARMUP`).

---

## 2. Xử lý spike / outlier

- Trong phân tích, giá trị outlier bị loại theo ngưỡng **mean ± 3·std**
  (hàm `trim_outliers` trong `analysis/common/loaders.py`).
- Nếu < 4 mẫu thì **không** loại (mẫu nhỏ, loại sẽ thiên lệch).
- Báo cáo cả `n_runs` sau khi loại để người đọc biết số mẫu thực tế.
- Với mẫu đủ lớn (ping per-packet), báo cáo thêm **p50/p95/p99** thay vì chỉ mean.

---

## 3. Đồng bộ thời gian (bắt buộc)

Latency/jitter chỉ đáng tin khi đồng hồ các node đồng bộ.
- Chạy `bash scripts/setup/check-timesync.sh` trước mỗi buổi đo.
- Yêu cầu: `NTPSynchronized=yes` và |offset| (chrony) < **1 ms**.
- Nếu chưa: `sudo apt-get install -y chrony && sudo systemctl enable --now chrony`.

---

## 4. Self-interference (nhiễu do chính hệ thống đo)

Luồng thu thập metrics (Telegraf → InfluxDB) chạy **trên chính đường đang đo**
→ có thể làm sai lệch kết quả. Cách xử lý:
- **Đo và báo cáo**: script `scripts/benchmark/run-tn1-interference.sh` so sánh RTT
  khi Telegraf **ON** vs **OFF** trên on-prem → chênh lệch = mức self-interference.
  Kết quả in ở `analysis/output/tn1/tn1_interference.csv`.
- **Diễn giải**: nếu chênh lệch nhỏ hơn biên độ nhiễu của phép đo → có thể bỏ qua;
  nếu đáng kể → phải nêu như một nguồn sai số khi thảo luận.
- *Không* đổi topology (đưa Central vào VPN) vì sẽ thay đổi chính đường đo.

---

## 5. TN1 — Latency/Loss/Jitter & Throughput

- 4 đường: P1 (on-prem→VM-B qua VPN), P2 (on-prem→Central), P3 (VM-B→Central),
  P4 (on-prem→VM-B qua Internet).
- mtr để xem đường đi; iperf3 (qua VPN) để đo throughput.
- Báo cáo RTT (mean/p95/p99), loss %, iperf3 Mbps — kèm self-interference ở trên.
- Lưu ý: iperf3 chỉ chạy qua VPN do Security Group của VM-B chỉ mở cổng 5201
  cho dải `10.200.200.0/24`.

## 6. TN2 — Khoảng cách địa lý vs RTT

- Mô hình: `RTT = a·km + b`; báo cáo `a`, `b`, `R`, `R²`, `p-value`.
- **Bắt buộc ≥5–6 điểm đo** ở các khoảng cách khác nhau (vd Tokyo/Sydney/Virginia/
  Frankfurt/HK) — với 2 điểm, hồi quy **vô nghĩa về mặt thống kê**.
- Khoảng cách dùng đường **great-circle** (không phải đường cáp thực) → kỳ vọng
  `R²` chỉ ở mức trung bình và cần nêu trong phần thảo luận.
- Chỉnh danh sách probe trong `configs/probes.tsv`.

## 7. TN3 — Overhead Telegraf

- **Đo qua NIC thật**: nginx trên VM-A, `ab` chạy **từ VM-B → nginx VM-A qua VPN**
  (`http://10.200.200.2/`). Không dùng loopback.
- 4 mức Telegraf: off / 30s / 15s / 5s.
- Báo cáo req/s (mean±std), p99, overhead % so với mức "off".
- Mỗi mức có 1 lần warm-up (ab) bỏ trước khi đo.

## 8. TN4 — Compute benchmark (giới hạn)

Xem `data/raw/tn4/LIMITATIONS.txt`. Tóm tắt:
- **Noisy neighbor**: hạ tầng chia sẻ → cần nhiều lần lặp, chú ý std cao.
- **Burst credit**: t3.small (AWS) và dòng B-series (Azure) là burstable — 60s có
  thể chạm giới hạn credit; nên ghi lại credit trước/sau nếu có thể.
- **Lớp ảo hoá khác nhau**: KVM (on-prem) vs Nitro (AWS) vs Hyper-V (Azure) →
  so sánh là thực nghiệm, không phải so chuẩn phần cứng.
- **I/O cloud** (EBS/Azure Disk) dao động mạnh; luôn báo cáo mean ± std.

---

## 9. Cấu trúc dữ liệu

- Dữ liệu thô: `data/raw/tnX/` (bị gitignore — giữ lại để chèn phụ lục).
- Kết quả phân tích: `analysis/output/tnX/` (bảng CSV + biểu đồ PNG).
- Chạy: `bash scripts/benchmark/run-tnX.sh` → `python analysis/tnX_analysis.py`.
