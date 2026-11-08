## 2. Các kịch bản triển khai

Để đánh giá toàn diện hiệu năng của mô hình Hybrid Cloud cũng như kiểm chứng tính
hiệu quả của hệ sinh thái giám sát TICK Stack, đồ án xây dựng 5 kịch bản thực nghiệm
độc lập (được ký hiệu từ TN1 đến TN5). Mỗi kịch bản được thiết kế để trả lời một câu
hỏi nghiên cứu riêng, có biến độc lập – biến phụ thuộc rõ ràng và các biến được kiểm
soát. Các kịch bản dùng chung một nền hạ tầng (on-premise tại TP. Hồ Chí Minh, AWS
Singapore, Azure Hong Kong) và một hệ thống thu thập số liệu tập trung (Telegraf →
InfluxDB → Chronograf/Kapacitor).

Bảng dưới tóm tắt 5 kịch bản và câu hỏi nghiên cứu tương ứng:

| Mã | Tên kịch bản | Câu hỏi nghiên cứu chính |
|----|--------------|--------------------------|
| TN1 | Độ trễ & thông lượng mạng | VPN/đường xuyên cloud chậm hơn đường nội cloud bao nhiêu? |
| TN2 | Ảnh hưởng khoảng cách địa lý | RTT có quan hệ tuyến tính với khoảng cách vật lý không? |
| TN3 | Overhead của hệ thống giám sát | Telegraf ảnh hưởng thế nào đến throughput ứng dụng? |
| TN4 | Hiệu năng tính toán | On-premise khác cloud tương đương bao nhiêu về CPU/RAM/I/O? |
| TN5 | Kiểm thử Kapacitor (cảnh báo) | Kapacitor phát cảnh báo đúng ngưỡng, nhanh và ít báo động giả? |

---

### 2.1. TN1 — Đo độ trễ, mất gói, jitter và thông lượng giữa các đường kết nối

**Mục tiêu.** Định lượng độ trễ (RTT), tỷ lệ mất gói (packet loss), độ dao động
(jitter) và thông lượng (throughput) trên các đường truyền khác nhau của mô hình
hybrid cloud, từ đó so sánh chi phí của việc đi xuyên cloud (cross-cloud) so với
lưu lượng nội cloud, và chi phí của VPN so với kết nối Internet trực tiếp.

**Câu hỏi nghiên cứu.**
- On-premise ↔ Cloud chậm hơn Cloud ↔ Cloud bao nhiêu lần?
- WireGuard VPN thêm bao nhiêu overhead so với đường truyền công cộng?
- Đường truyền có ổn định (loss/jitter thấp) trong suốt thời gian đo không?

**Thiết lập.** Bốn điểm đo độc lập giữa ba node (on-premise `vm-a`, AWS `vm-b`,
Azure Central):
- P1: on-premise → AWS qua **WireGuard VPN** (địa chỉ VPN `10.200.200.1`).
- P2: on-premise → Azure Central qua **Internet công cộng**.
- P3: AWS → Azure Central qua **Internet công cộng**.
- P4: on-premise → AWS qua **Internet trực tiếp** (không VPN, dùng EIP của `vm-b`).

**Công cụ và tham số.**
- `ping` (100 gói, khoảng cách 0.2 s/gói) để đo RTT, loss, jitter (độ lệch chuẩn).
- `mtr` để quan sát đường đi (hop) và phát hiện điểm nghẽn.
- `iperf3` (chạy 30 s) để đo thông lượng TCP qua VPN.
- Mỗi điểm đo lặp **3 lần**, có **1 lần warm-up** (bỏ kết quả).

**Chỉ số thu thập.** RTT trung bình/nhỏ nhất/lớn nhất, phân vị p50/p95/p99, tỷ lệ mất
gói, jitter (độ lệch chuẩn), thông lượng (Mbps).

**Biến kiểm soát.** Cùng khung giờ đo, cùng kích thước gói, cùng tần số lấy mẫu; các
node đã đồng bộ thời gian (NTP).

---

### 2.2. TN2 — Ảnh hưởng của khoảng cách địa lý đến độ trễ

**Mục tiêu.** Xác định mối quan hệ giữa khoảng cách địa lý và độ trễ mạng, kiểm
chứng giả thuyết RTT tỉ lệ tuyến tính với khoảng cách, và so sánh hệ số hồi quy thu
được với tốc độ lan truyền ánh sáng trong cáp quang.

**Câu hỏi nghiên cứu.**
- Mô hình `RTT = a × khoảng_cách + b` có phù hợp không (hệ số xác định R²)?
- Hệ số góc `a` chênh lệch bao nhiêu so với giá trị lý thuyết (~0.01 ms/km cho
  round-trip khi coi đường truyền xấp xỉ đường tròn lớn)?
- Phần overhead của routing/switching/processing chiếm bao nhiêu so với độ trễ
  lan truyền thuần túy?

**Thiết lập.** Từ một tập **geo-probes** phân bố ở các khoảng cách khác nhau (ví dụ
Tokyo, Sydney, Virginia, Frankfurt, Hong Kong) cùng ping tới Azure Central
(`eastasia`), ghi lại RTT trung bình. Cần **tối thiểu 5–6 điểm đo** ở các khoảng cách
trải đều để hồi quy có ý nghĩa thống kê. Danh sách probe được cấu hình tập trung.

**Công cụ và tham số.** `ping` (100 gói × 0.2 s) từ mỗi probe; khoảng cách lấy theo
đường tròn lớn giữa toạ độ hai điểm; mỗi probe lặp 3 lần.

**Chỉ số thu thập.** RTT trung bình và độ lệch chuẩn theo từng probe; các tham số hồi
quy `a`, `b`, `R²`, giá trị `p`.

**Biến kiểm soát.** Cùng target (một Central cố định), cùng thời điểm, cùng tham số
gói tin; ghi nhận rõ probe nào đo qua VPN và probe nào qua Internet để không trộn
đường truyền khi so khoảng cách.

---

### 2.3. TN3 — Overhead của hệ thống giám sát Telegraf lên hiệu năng ứng dụng

**Mục tiêu.** Đo mức ảnh hưởng của Telegraf (agent thu thập metrics) lên hiệu năng
một ứng dụng web, để trả lời câu hỏi: chi phí giám sát là bao nhiêu và có nên giảm
tần số lấy mẫu trong môi trường production hay không.

**Câu hỏi nghiên cứu.**
- Throughput (req/s) và độ trễ p99 của ứng dụng thay đổi bao nhiêu khi bật Telegraf?
- Interval ngắn (5 s) có overhead cao hơn rõ rệt so với interval dài (30 s) không?

**Thiết lập.** Một máy chủ web `nginx` chạy trên on-premise (`vm-a`). Client đo tải
(`ab`) chạy **từ `vm-b` đánh vào nginx của `vm-a` qua WireGuard VPN**, để lưu lượng
thực sự đi qua card mạng (NIC) chứ không qua loopback. Trên `vm-a`, Telegraf được
thay đổi tần số lấy mẫu ở 4 mức: **tắt (off), 30 s, 15 s, 5 s**.

**Công cụ và tham số.** `ab` với `-n 20000 -c 100`; mỗi mức chạy 3 lần, có 1 lần
warm-up; ghi thêm mức sử dụng CPU của Telegraf trong lúc đo.

**Chỉ số thu thập.** Requests/giây, độ trễ p99, số request lỗi, %CPU của Telegraf,
mức sử dụng băng thông NIC; từ đó tính phần trăm overhead so với mức "off".

**Biến kiểm soát.** Cùng cấu hình nginx, cùng kích thước và số request; chỉ thay đổi
duy nhất biến độc lập là interval của Telegraf; đo cùng khung giờ.

---

### 2.4. TN4 — So sánh hiệu năng tính toán giữa on-premise và cloud

**Mục tiêu.** So sánh hiệu năng CPU, bộ nhớ và I/O của ba node có đặc điểm hạ tầng
khác nhau (server vật lý/ảo hoá KVM tại chỗ, AWS t3.small, Azure B2s_v2), làm cơ sở
đánh giá sự đánh đổi giữa chi phí và hiệu năng khi chọn nơi đặt workload.

**Câu hỏi nghiên cứu.**
- Hiệu năng CPU (events/s), băng thông bộ nhớ (MiB/s) và I/O (IOPS, MB/s) giữa ba node
  chênh lệch bao nhiêu?
- Ảo hoá và instance dạng burstable ảnh hưởng thế nào đến độ ổn định của kết quả?

**Thiết lập.** Chạy bộ benchmark trên lần lượt ba node: on-premise (`vm-a`), AWS
(`vm-b`), Azure Central. Mỗi phép đo lặp **3 lần** để tính mean ± độ lệch chuẩn.

**Công cụ và tham số.**
- `sysbench`: CPU (1 và 2 luồng, `--time=60`) và memory (`--memory-total-size=1G`).
- `fio`: đọc ngẫu nhiên 4K, ghi ngẫu nhiên 4K (đo IOPS) và đọc tuần tự 1M (đo MB/s),
  thời lượng 60 s.

**Chỉ số thu thập.** Events/giây (CPU), MiB/s (memory), IOPS và MB/s (I/O), kèm độ
lệch chuẩn giữa các lần chạy.

**Biến kiểm soát.** Cùng tham số benchmark, cùng thời lượng; ghi nhận **các giới hạn
cần nêu trong báo cáo**: ảnh hưởng "noisy neighbor" trên hạ tầng chia sẻ, cơ chế
**burst credit** của t3/B-series (chỉ giữ hiệu năng đỉnh trong thời gian ngắn), và sự
khác biệt lớp ảo hoá (KVM vs Nitro vs Hyper-V).

---

### 2.5. TN5 — Kiểm thử Kapacitor (xử lý luồng và cảnh báo)

**Mục tiêu.** Kiểm chứng thành phần "K" của TICK Stack — **Kapacitor** — trong vai trò
xử lý luồng dữ liệu và phát cảnh báo. Kịch bản này gồm **một loạt thí nghiệm nhỏ**,
mỗi thí nghiệm kiểm tra một khả năng cụ thể của Kapacitor (nạp & chạy tác vụ, đánh giá
đúng ngưỡng, vòng đời cảnh báo, độ trễ phát hiện, chống báo động giả, ghi cảnh báo trở
lại InfluxDB), thay vì một phép đo hiệu năng đơn lẻ.

**Câu hỏi kiểm thử.**
- Kapacitor có nạp đúng các tác vụ cảnh báo và chạy chúng trên luồng dữ liệu thật không?
- Cảnh báo có kích hoạt đúng ngưỡng WARNING/CRITICAL đã cấu hình không?
- Độ trễ từ khi sự cố xuất hiện đến khi cảnh báo được phát là bao nhiêu, và phụ thuộc
  thế nào vào tần số lấy mẫu của Telegraf?
- Hệ thống có tránh báo động giả ở trạng thái bình thường và tự "hồi phục" (trở về OK) không?

**Thiết lập.** Hệ thống đã cài sẵn ba tác vụ Kapacitor: `rtt_alert`, `packet_loss_alert`,
`jitter_alert` (cửa sổ trượt, ngưỡng WARNING/CRITICAL, `stateChangesOnly`, ghi cảnh báo
ngược lại InfluxDB dưới các measurement `alerts_rtt`, `alerts_packet_loss`, `alerts_jitter`).
Dùng công cụ **tiêm lỗi** để tạo tình huống suy giảm có kiểm soát, ví dụ tăng độ trễ hoặc
mất gói bằng `tc`/`netem` trên một node, hoặc tạm dừng một node để ngắt kết nối.

**Các thí nghiệm nhỏ.**
- **T5.1 — Nạp & kích hoạt tác vụ:** kiểm tra 3 tác vụ ở trạng thái `enabled` và đang
  `executing`, đúng cơ sở dữ liệu/retention policy (`monitoring`.`autogen`).
- **T5.2 — Cảnh báo theo ngưỡng (RTT):** tiêm độ trễ để RTT trung bình vượt ngưỡng
  WARNING (80 ms) và CRITICAL (150 ms); kiểm tra cảnh báo tương ứng xuất hiện.
- **T5.3 — Cảnh báo mất gói và jitter:** lặp lại cách kiểm tra tương tự cho hai tác vụ
  còn lại (loss > 2%/5%; jitter > 10/25 ms).
- **T5.4 — Vòng đời cảnh báo:** cho sự cố xuất hiện rồi kết thúc; kiểm tra chuỗi trạng
  thái OK → WARNING → CRITICAL → OK và xác nhận `stateChangesOnly` không phát cảnh báo lặp.
- **T5.5 — Độ trễ phát hiện:** đo khoảng thời gian từ mốc tiêm lỗi đến mốc cảnh báo xuất
  hiện, lặp lại với các mức interval Telegraf (5 s / 15 s / 30 s).
- **T5.6 — Kiểm thử âm tính (chống báo động giả):** giữ hệ thống ở trạng thái bình thường
  trong một khoảng thời gian và xác nhận không phát sinh cảnh báo.

**Công cụ và tham số.** `tc`/`netem` (tiêm lỗi); Telegraf (thu thập); Kapacitor
(`kapacitor list tasks`, `kapacitor show <task>`, HTTP API `/kapacitor/v1/...` để xem
trạng thái và cảnh báo); InfluxDB (truy vấn các measurement `alerts_*`); Chronograf
(Alert History).

**Chỉ số thu thập.** Trạng thái tác vụ (enabled/executing); cảnh báo đúng ngưỡng
(đúng/không); độ trễ phát hiện và độ trễ phát cảnh báo (giây); số báo động giả; chuỗi
chuyển trạng thái cảnh báo.

**Biến kiểm soát.** Cùng biên độ và thời lượng tiêm lỗi, cùng ngưỡng cảnh báo; biến độc
lập là tần số lấy mẫu Telegraf và loại sự cố. Đảm bảo các node đã đồng bộ thời gian để
đo đúng độ trễ giữa mốc sự cố và mốc cảnh báo.

---

**Ghi chú chung.** Năm kịch bản dùng chung một hệ thống thu thập tập trung: Telegraf
trên các agent đẩy metrics về InfluxDB trên Azure Central; Chronograf hiển thị trực
quan; Kapacitor xử lý luồng và cảnh báo. Số liệu thô được lưu theo từng kịch bản để
phục vụ phân tích và tái lập.
