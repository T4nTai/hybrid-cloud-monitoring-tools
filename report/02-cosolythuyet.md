# CHƯƠNG 2: CƠ SỞ LÝ THUYẾT

## 2.1. Hybrid Cloud

**Hybrid cloud** là mô hình kết hợp hạ tầng on-premise (tại chỗ) với một hoặc nhiều public cloud, cho phép workload và dữ liệu di chuyển giữa hai môi trường. Doanh nghiệp giữ ứng dụng nhạy cảm trên hạ tầng riêng và tận dụng cloud cho khả năng mở rộng.

Mô hình trong nghiên cứu này gồm ba điểm: on-premise (TP.HCM), AWS (Singapore), Azure (Hong Kong). Thách thức cốt lõi là **hiệu năng mạng giữa các điểm cách xa về địa lý** — độ trễ, băng thông, và độ ổn định của đường truyền qua Internet/VPN.

## 2.2. Các chỉ số hiệu năng mạng

Nghiên cứu tập trung vào bốn chỉ số: độ trễ vòng (RTT), độ dao động trễ (jitter), tỷ lệ mất gói (packet loss) và thông lượng (throughput). Mỗi chỉ số được trình bày theo hai phần: (a) cơ sở lý thuyết, và (b) cách đo trong mô hình đồ án.

### 2.2.1. Độ trễ vòng (Round-Trip Time — RTT)

**a) Cơ sở lý thuyết**

RTT là thời gian tính từ lúc nguồn gửi gói tin đầu tiên cho đến khi nhận được phản hồi từ đích. Đây là chỉ số trực tiếp nhất phản ánh độ trễ (latency) của đường truyền. RTT có thể được đo ở nhiều tầng khác nhau, mỗi tầng cộng thêm một lớp chi phí xử lý:

- **Tầng 1 — Network RTT**: thời gian di chuyển thuần túy của gói tin trên đường truyền vật lý, thường đo bằng ICMP Ping. Thành phần này gồm propagation delay (phụ thuộc khoảng cách và tốc độ ánh sáng trong cáp quang) cộng thời gian hàng đợi tại các router trung gian.
- **Tầng 2 — TCP RTT**: bao gồm Network RTT cộng chi phí xử lý TCP ở hai đầu, như bắt tay ba bước, xác nhận gói (ACK) và cơ chế điều khiển tắc nghẽn.
- **Tầng 3 — Application Latency**: độ trễ tổng thể, bao gồm TCP RTT cộng thời gian phân tích giao thức tầng ứng dụng (ví dụ HTTP), xử lý logic máy chủ và truyền tải nội dung phản hồi.

Về mặt thành phần, Network RTT được mô hình hóa như sau:

```
RTT = 2 × propagation_delay + processing_overhead
propagation_delay = distance / tốc độ ánh sáng trong cáp quang (~200.000 km/s)
processing_overhead = tổng thời gian xử lý và hàng đợi tại các router trên đường đi
```

**b) Cách đo trong đồ án**

Đồ án lấy **Network RTT (Tầng 1)** làm chỉ số chính, vì mục tiêu là đánh giá chất lượng đường truyền hybrid cloud giữa các điểm cách xa về địa lý, độc lập với ứng dụng cụ thể. Application Latency (Tầng 3) chỉ được đo riêng trong TN3 (bằng Apache Bench qua HTTP) để đánh giá overhead monitoring; TCP RTT (Tầng 2) dùng như lớp diễn giải khái niệm, không đo trực tiếp.

Network RTT được thu thập theo hai cách bổ sung cho nhau:
- **Telegraf `inputs.ping`** (liên tục): gửi `count = 20` gói ICMP mỗi 10 giây, lưu các field `average_response_ms`, `minimum_response_ms`, `maximum_response_ms` vào InfluxDB. Dữ liệu này dựng nên biểu đồ RTT theo thời gian trên Chronograf.
- **`ping -c 100`** (theo lịch, trong TN1 và TN2): gửi 100 gói × 3 vòng lặp cho mỗi cặp điểm, lấy trung bình ± độ lệch chuẩn. Số mẫu lớn giúp kết quả ổn định và tái lập được.

### 2.2.2. Độ dao động trễ (Jitter)

**a) Cơ sở lý thuyết**

Jitter là mức độ dao động của RTT giữa các gói tin đo liên tiếp, thường biểu diễn bằng độ lệch chuẩn của RTT:

```
jitter = sqrt( Σ(RTTᵢ − RTT_mean)² / n )
```

Jitter phát sinh do thời gian hàng đợi tại các router thay đổi theo lưu lượng mạng tức thời. Một đường truyền có RTT trung bình cao nhưng ổn định (jitter thấp) thường tốt hơn đường truyền có RTT thấp nhưng dao động mạnh, vì ứng dụng thời gian thực (VoIP, video, game) phải tăng kích thước buffer để bù dao động — làm tăng độ trễ cảm nhận và nguy cơ gián đoạn.

**b) Cách đo trong đồ án**

Jitter được thu thập liên tục qua **Telegraf `inputs.ping`** tại field `standard_deviation_ms` của measurement `ping`, song song với RTT. Trong các phép đo theo lịch, jitter được tính từ cùng tập 100 gói của lệnh `ping -c 100` (mdev do `ping` báo cáo). Chỉ số này phản ánh độ ổn định của đường truyền on-premise ↔ cloud qua ISP nội địa — một yếu tố quan trọng khi đánh giá tính khả dụng của hybrid cloud cho ứng dụng nhạy cảm với độ trễ.

### 2.2.3. Tỷ lệ mất gói (Packet Loss)

**a) Cơ sở lý thuyết**

Packet loss là tỷ lệ gói tin không đến được đích trên tổng số gói đã gửi:

```
packet_loss (%) = (số gói gửi − số gói nhận) / số gói gửi × 100
```

Nguyên nhân gồm tắc nghẽn (router đầy hàng đợi phải loại bỏ gói), lỗi đường truyền vật lý, hoặc định tuyến sai. Packet loss có tác động **phi tuyến** đến hiệu năng: giao thức TCP diễn giải mất gói là tín hiệu tắc nghẽn và kích hoạt cơ chế giảm cửa sổ truyền (congestion window). Vì vậy chỉ cần loss 0,1–1% cũng đủ làm throughput TCP sụt giảm đáng kể, dù đường truyền vẫn còn băng thông.

**b) Cách đo trong đồ án**

Packet loss được đo bằng chính các phép ping:
- **Telegraf `inputs.ping`** lưu field `percent_packet_loss` liên tục, phát hiện suy giảm chất lượng đường truyền theo thời gian.
- **`ping -c 100`** trong TN1/TN2: với 100 gói mỗi vòng, độ phân giải đạt 1% — đủ để phát hiện loss ở mức thấp.

ISP nội địa Việt Nam có thể có loss cao hơn vào giờ cao điểm, nên các phép đo được thực hiện trong khung giờ kiểm soát để giảm biến nhiễu.

### 2.2.4. Thông lượng (Throughput)

**a) Cơ sở lý thuyết**

Throughput là lượng dữ liệu thực tế truyền được trong một đơn vị thời gian (Mbps). Cần phân biệt với **bandwidth** — băng thông lý thuyết tối đa của đường truyền. Throughput luôn thấp hơn bandwidth do ảnh hưởng của RTT, packet loss và cơ chế điều khiển của giao thức.

Với TCP, throughput tối đa có thể ước lượng theo mô hình Mathis:

```
Throughput_TCP ≈ (MSS × √1.5) / (RTT × √packet_loss)
```

với MSS (Maximum Segment Size) thường là 1460 byte. Công thức chỉ áp dụng khi loss > 0; khi loss bằng 0, throughput bị giới hạn bởi băng thông đường truyền và kích thước cửa sổ TCP. Ví dụ với MSS = 1460 byte, RTT = 30 ms, loss = 0,1% → throughput ≈ 15 Mbps; nếu loss tăng lên 1% → throughput giảm còn ≈ 4,8 Mbps. Cả RTT lẫn loss đều làm giảm throughput, nên đường truyền vừa xa vừa nhiều loss chịu thiệt kép.

**b) Cách đo trong đồ án**

Throughput được đo chủ động bằng **iperf3** giữa on-premise và cloud, qua đường hầm WireGuard:
- `iperf3 -c <target> -t 30`: TCP upload 30 giây, lấy cả giá trị sender và receiver.
- `iperf3 -c <target> -R -t 30`: TCP download (hướng ngược lại).
- `iperf3 -u -b 100M`: luồng UDP để đo throughput không chịu ảnh hưởng của congestion control TCP, đồng thời quan sát loss ở throughput cao.

Song song, **Telegraf `inputs.net`** theo dõi `bytes_sent`/`bytes_recv` của card mạng để quan sát traffic nền (dùng cho TN3 khi đánh giá băng thông mà agent monitoring tiêu tốn).

> **Lưu ý phương pháp.** Hai plugin `inputs.net_response` (đo TCP handshake) và `inputs.http_response` (đo HTTP latency) của Telegraf *không* được bật trong agent. Lý do: chúng tạo kết nối TCP/HTTP liên tục trên đúng đường truyền đang đo, sinh ra traffic nền làm nhiễu phép đo Network RTT và throughput. Thay vào đó, các phép đo tầng cao hơn được thực hiện bằng công cụ chuyên dụng (`iperf3`, `ab`) chạy theo lịch kiểm soát, tách biệt khỏi luồng thu thập liên tục của Telegraf.

## 2.3. WireGuard VPN

**WireGuard** là giao thức VPN hiện đại, chạy trong kernel Linux, dùng để tạo đường hầm mã hóa giữa on-premise và cloud.

Ưu điểm so với IPsec và OpenVPN:
- **Nhẹ**: ~4.000 dòng mã (so với hàng trăm nghìn dòng của IPsec/OpenVPN), dễ kiểm toán.
- **Nhanh**: chạy trong kernel-space, dùng mật mã hiện đại (ChaCha20, Curve25519), overhead thấp.
- **Đơn giản**: cấu hình bằng cặp khóa public/private, không cần quản lý certificate phức tạp.

Trong nghiên cứu, WireGuard tạo mạng riêng `10.200.200.0/24` kết nối on-premise và cloud. Lý do dùng VPN: ISP tại TP.HCM chặn ICMP đến IP public, nên cần đường hầm riêng để đo latency ổn định và tái lập được.

## 2.4. TICK Stack (Monitoring)

**TICK** là bộ công cụ giám sát time-series của InfluxData. Nghiên cứu dùng ba thành phần:

- **Telegraf** (agent): thu thập metrics hệ thống (CPU, RAM, disk, network) và mạng (ping) trên mỗi node, đẩy về trung tâm theo chu kỳ 10 giây.
- **InfluxDB** (database): cơ sở dữ liệu time-series lưu trữ metrics, tối ưu cho ghi/truy vấn theo thời gian.
- **Chronograf** (visualization): dashboard hiển thị biểu đồ từ InfluxDB.

Stack hoạt động theo **push model**: agent chủ động gửi dữ liệu về trung tâm (InfluxDB trên Azure Central), khác với pull model (Prometheus). Push model phù hợp khi agent nằm sau NAT/firewall — đúng với on-premise.

> Thành phần thứ tư của TICK là **Kapacitor** (xử lý luồng, cảnh báo) không được triển khai vì nằm ngoài phạm vi nghiên cứu (chỉ cần thu thập, lưu trữ, hiển thị). Azure Central đóng vai trò **neutral observer** — chỉ nhận và lưu metrics, không tham gia benchmark.

## 2.5. Quan hệ khoảng cách — độ trễ

Ánh sáng truyền trong cáp quang với tốc độ ~200.000 km/s (bằng 2/3 tốc độ trong chân không do chiết suất). Về lý thuyết, RTT tối thiểu giữa hai điểm cách nhau `d` km:

```
RTT_min = 2 × d / 200.000 (giây) = d / 100 (ms)
```

Nghĩa là mỗi 100 km lý thuyết thêm ~1 ms RTT. Thực tế RTT cao hơn do:
- Đường cáp không đi thẳng (men theo tuyến cáp biển, đất liền).
- Overhead tại mỗi router (xử lý, hàng đợi).
- Peering giữa các ISP không tối ưu.

TN2 kiểm chứng quan hệ này bằng hồi quy tuyến tính `RTT = a × distance + b`, trong đó hệ số `a` phản ánh tốc độ lan truyền thực tế và `b` phản ánh overhead cố định.

## 2.6. Công cụ benchmark

| Công cụ | Đo gì | Dùng trong |
|---|---|---|
| **ping** | RTT, packet loss | TN1, TN2 |
| **mtr** | RTT theo từng hop (traceroute + ping) | TN1 |
| **iperf3** | Throughput TCP/UDP | TN1 |
| **Apache Bench (ab)** | HTTP throughput (req/s), latency p99 | TN3 |
| **sysbench** | Hiệu năng CPU (event/s), RAM (MiB/s) | TN4 |
| **fio** | Hiệu năng I/O (IOPS, MiB/s) | TN4 |

Các công cụ này chạy theo lịch kiểm soát thay vì liên tục, đảm bảo phép đo sạch và tái lập được.

---

**Tóm tắt chương**  
Chương này trình bày nền tảng cho bốn thí nghiệm: mô hình hybrid cloud ba điểm, bốn chỉ số mạng (RTT, jitter, packet loss, throughput), giao thức WireGuard (nhẹ, nhanh, kernel-space), TICK stack theo push model (Telegraf–InfluxDB–Chronograf, không dùng Kapacitor), quan hệ lý thuyết khoảng cách–độ trễ (~1 ms/100 km), và sáu công cụ benchmark.
