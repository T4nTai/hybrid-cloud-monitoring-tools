## 2. Các kịch bản triển khai

Đồ án tập trung vào **hai trọng tâm**:
1. **Đánh giá hiệu năng mạng hybrid cloud** — đo định lượng độ trễ, mất gói, jitter,
   thông lượng giữa on-premise (TP. Hồ Chí Minh) và hai public cloud (AWS Singapore,
   Azure Hong Kong).
2. **Năng lực của hệ sinh thái giám sát TICK Stack** — bộ công cụ (Telegraf, InfluxDB,
   Chronograf, Kapacitor) dùng để đo đạc chính mạng đó: chi phí nó gây ra, khả năng chịu
   tải, và hiệu quả phát hiện – cảnh báo sự cố.

Tương ứng, 5 kịch bản thực nghiệm được chia thành hai nhóm:

| Mã | Nhóm | Tên kịch bản | Câu hỏi nghiên cứu chính |
|----|------|--------------|--------------------------|
| TN1 | A. Hiệu năng mạng | Độ trễ – mất gói – jitter – thông lượng trên các đường kết nối | VPN/xuyên cloud chậm hơn nội cloud bao nhiêu? |
| TN2 | A. Hiệu năng mạng | Ảnh hưởng của khoảng cách địa lý đến độ trễ | RTT có quan hệ tuyến tính với khoảng cách? |
| TN3 | B. Hệ thống giám sát | Overhead của Telegraf lên hiệu năng workload | Giám sát tiêu tốn bao nhiêu hiệu năng ứng dụng? |
| TN4 | B. Hệ thống giám sát | Khả năng chịu tải của pipeline giám sát | Tải đến đâu thì pipeline bắt đầu trễ/mất dữ liệu? |
| TN5 | B. Hệ thống giám sát | Hiệu quả giám sát end-to-end | Hệ thống phát hiện & cảnh báo sự cố nhanh, đúng đến đâu? |

> Ghi chú: hiệu năng **tính toán** (sysbench/fio trên từng nút) **không còn là kịch bản
> riêng**; được đưa về Chương 3 (Kiến trúc) như **thông số baseline của nút đo**, nhằm
> giải thích bối cảnh phần cứng cho kết quả mạng (tránh lệch khỏi trọng tâm "hiệu năng mạng").

---

## PHẦN A — ĐÁNH GIÁ HIỆU NĂNG MẠNG HYBRID CLOUD

### 2.1. TN1 — Độ trễ, mất gói, jitter và thông lượng trên các đường kết nối

**Mục tiêu.** Định lượng độ trễ (RTT), tỷ lệ mất gói (packet loss), độ dao động
(jitter) và thông lượng (throughput) trên các đường truyền khác nhau của mô hình
hybrid cloud; so sánh chi phí đi xuyên cloud (cross-cloud) với lưu lượng nội cloud,
và chi phí của VPN so với kết nối Internet trực tiếp.

**Câu hỏi nghiên cứu.**
- On-premise ↔ Cloud chậm hơn Cloud ↔ Cloud bao nhiêu?
- WireGuard VPN thêm bao nhiêu overhead so với đường truyền công cộng?
- Đường truyền có ổn định (loss/jitter thấp) trong suốt thời gian đo không?

**Thiết lập.** Bốn điểm đo giữa ba nút (on-premise `vm-a`, AWS `vm-b`, Azure Central):
- P1: on-premise → AWS qua **WireGuard VPN** (địa chỉ VPN `10.200.200.1`).
- P2: on-premise → Azure Central qua **Internet công cộng**.
- P3: AWS → Azure Central qua **Internet công cộng**.
- P4: on-premise → AWS qua **Internet trực tiếp** (không VPN, dùng EIP của `vm-b`).

**Công cụ và tham số.** `ping` (100 gói × 0.2 s) đo RTT/loss/jitter; `mtr` xem đường đi
(hop); `iperf3` (30 s) đo throughput TCP qua VPN. Mỗi điểm lặp **3 lần** + **1 lần warm-up**.

**Chỉ số thu thập.** RTT (mean/min/max), phân vị p50/p95/p99, tỷ lệ mất gói, jitter
(độ lệch chuẩn), thông lượng (Mbps).

**Biến kiểm soát.** Cùng khung giờ đo, cùng kích thước gói, cùng tần số lấy mẫu; các node
đã đồng bộ thời gian (NTP).

---

### 2.2. TN2 — Ảnh hưởng của khoảng cách địa lý đến độ trễ

**Mục tiêu.** Xác định mối quan hệ giữa khoảng cách địa lý và độ trễ mạng, kiểm chứng giả
thuyết RTT tỉ lệ tuyến tính với khoảng cách, và so sánh hệ số hồi quy thu được với tốc độ
lan truyền ánh sáng trong cáp quang.

**Câu hỏi nghiên cứu.**
- Mô hình `RTT = a × khoảng_cách + b` có phù hợp không (hệ số xác định R²)?
- Hệ số góc `a` chênh lệch bao nhiêu so với giá trị lý thuyết (~0.01 ms/km round-trip)?
- Phần overhead của routing/switching/processing chiếm bao nhiêu so với độ trễ lan truyền?

**Thiết lập.** Một tập **geo-probes** ở các khoảng cách khác nhau (ví dụ Tokyo, Sydney,
Virginia, Frankfurt, Hong Kong) cùng ping tới Azure Central (`eastasia`). Cần **tối thiểu
5–6 điểm đo** ở các khoảng cách trải đều để hồi quy có ý nghĩa thống kê.

**Công cụ và tham số.** `ping` (100 gói × 0.2 s) từ mỗi probe; khoảng cách lấy theo đường
tròn lớn giữa toạ độ hai điểm; mỗi probe lặp 3 lần.

**Chỉ số thu thập.** RTT trung bình và độ lệch chuẩn theo từng probe; tham số hồi quy
`a`, `b`, `R²`, giá trị `p`.

**Biến kiểm soát.** Cùng target (một Central cố định), cùng thời điểm, cùng tham số gói tin;
ghi nhận rõ probe nào đo qua VPN và probe nào qua Internet để không trộn đường truyền.

---

## PHẦN B — NĂNG LỰC HỆ SINH THÁI GIÁM SÁT (TICK STACK)

### 2.3. TN3 — Overhead của Telegraf lên hiệu năng workload

**Mục tiêu.** Đo mức ảnh hưởng của agent thu thập (Telegraf) lên hiệu năng một ứng dụng
web — tức **chi phí của việc giám sát** — và sự phụ thuộc vào tần số lấy mẫu.

**Câu hỏi nghiên cứu.**
- Throughput (req/s) và độ trễ p99 của ứng dụng thay đổi bao nhiêu khi bật Telegraf?
- Interval ngắn (5 s) có overhead cao hơn rõ rệt so với interval dài (30 s) không?

**Thiết lập.** `nginx` chạy trên on-premise (`vm-a`); client `ab` chạy **từ `vm-b` đánh vào
nginx của `vm-a` qua WireGuard VPN** để lưu lượng thực sự đi qua card mạng (NIC), không qua
loopback. Trên `vm-a`, Telegraf chạy ở 4 mức: **tắt (off) / 30 s / 15 s / 5 s**.

**Công cụ và tham số.** `ab` với `-n 20000 -c 100`; mỗi mức chạy 3 lần, có 1 lần warm-up;
ghi thêm mức sử dụng CPU của Telegraf trong lúc đo.

**Chỉ số thu thập.** Requests/giây, p50/p95/p99, số request lỗi, %CPU Telegraf, mức sử dụng
băng thông NIC; từ đó tính **phần trăm overhead** so với mức "off".

**Biến kiểm soát.** Cùng cấu hình nginx, cùng kích thước và số request; biến độc lập duy
nhất là interval của Telegraf; đo cùng khung giờ.

---

### 2.4. TN4 — Khả năng chịu tải (scalability) của pipeline giám sát

**Mục tiêu.** Đánh giá **sức chịu tải** của chuỗi Telegraf → InfluxDB → Kapacitor: khi tải
thu thập tăng dần thì đến mức nào pipeline bắt đầu trễ ghi, mất dữ liệu, hoặc xử lý luồng
không kịp — đây là khía cạnh "hiệu năng của công cụ giám sát".

**Câu hỏi nghiên cứu.**
- Với Central (B2s_v2, 8 GB) chịu được bao nhiêu **điểm dữ liệu/giây** trước khi trễ/mất?
- Khi tải tăng, CPU/RAM của InfluxDB và độ trễ query tăng thế nào?
- Kapacitor có xử lý luồng kịp khi tần số dữ liệu tăng (5 s, 1 s)?

**Thiết lập.** Tăng dần tải theo hai cách: (a) giảm interval Telegraf
(`30s → 15s → 10s → 5s → 1s`); (b) nhân thêm nguồn dữ liệu (thêm probe/agent hoặc bật thêm
input plugin). Giữ nguyên phần cứng Central để cô lập biến "tải".

**Công cụ và tham số.** Telegraf (interval/input); InfluxDB (`SHOW STATS`, số điểm ghi được);
Kapacitor (số điểm xử lý); script sinh tải.

**Chỉ số thu thập.** Điểm/giây tạo ra so với ghi thành công (**% dữ liệu mất**), độ trễ ghi,
%CPU/%RAM của InfluxDB, độ trễ query (`durationMs`), số khoảng trống dữ liệu.

**Biến kiểm soát.** Cùng cấu hình Central; biến độc lập = tần số/khối lượng dữ liệu; đo theo
từng mức tải tăng dần.

---

### 2.5. TN5 — Hiệu quả giám sát end-to-end (phát hiện & cảnh báo sự cố)

**Mục tiêu.** Kiểm chứng tính **hiệu quả tổng thể** của TICK Stack: từ lúc một sự cố mạng
xảy ra → dữ liệu bất thường được ghi vào InfluxDB → Kapacitor phát cảnh báo → hiển thị trên
Chronograf. Đánh giá cả **tính đúng** (đúng ngưỡng, ít báo động giả) và **hiệu năng**
(độ trễ phát hiện).

**Câu hỏi nghiên cứu.**
- Độ trễ **end-to-end** từ sự cố đến khi cảnh báo xuất hiện là bao nhiêu?
- Độ trễ này phụ thuộc thế nào vào interval Telegraf (5 s / 15 s / 30 s)?
- Cảnh báo có đúng ngưỡng cấu hình, tự hồi phục (về OK) và không báo động giả không?

**Thiết lập.** Dùng **tiêm lỗi** (`tc`/`netem`) tạo suy giảm có kiểm soát trên một đường
(tăng độ trễ / mất gói). Hệ thống đã có 3 tác vụ Kapacitor (`rtt_alert`, `packet_loss_alert`,
`jitter_alert`, ngưỡng WARNING/CRITICAL, `stateChangesOnly`, ghi cảnh báo về InfluxDB).

**Hai phần.**
- **5a — Kiểm chứng chức năng (tiền đề, ngắn gọn):** tác vụ `enabled`/`executing`, đúng dbrp
  `monitoring/autogen`; dữ liệu ghi đúng DB; auth InfluxDB hoạt động.
- **5b — Đánh giá hiệu năng (trọng tâm):**
  - **Độ trễ phát hiện**: thời điểm tiêm lỗi → thời điểm điểm bất thường vào InfluxDB → thời
    điểm cảnh báo xuất hiện (phân tách từng chặng: `Telegraf(interval+flush)` +
    `Kapacitor(window/every)`).
  - **Vòng đời cảnh báo**: `OK → WARNING → CRITICAL → OK`, không phát lặp.
  - **Kiểm thử âm tính**: không cảnh báo khi hệ thống bình thường.
  - **Độ tươi hiển thị**: độ trễ từ điểm dữ liệu mới nhất đến khi dashboard cập nhật.

**Công cụ và tham số.** `tc`/`netem` (tiêm lỗi); Kapacitor (`list tasks`, `show`, HTTP API);
InfluxQL đối chiếu timestamp giữa `ping` và `alerts_*`; Chronograf (`/queries` có `durationMs`).

**Chỉ số thu thập.** Độ trễ phát hiện và độ trễ phát cảnh báo (giây); cảnh báo đúng ngưỡng
(đúng/không); số báo động giả; chuỗi chuyển trạng thái; độ tươi dữ liệu hiển thị.

**Biến kiểm soát.** Cùng biên độ và thời lượng tiêm lỗi, cùng ngưỡng cảnh báo; biến độc lập
là loại sự cố và interval Telegraf; NTP đồng bộ để đo đúng độ trễ giữa các mốc.

---

**Ghi chú chung.** Mọi kịch bản dùng chung một hệ thống thu thập tập trung: Telegraf trên
các agent đẩy metrics về InfluxDB trên Azure Central; Chronograf hiển thị trực quan;
Kapacitor xử lý luồng và cảnh báo. Dữ liệu thô được lưu theo từng kịch bản để phục vụ phân
tích và tái lập.
