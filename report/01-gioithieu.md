# CHƯƠNG 1: GIỚI THIỆU

## 1.1. Bối cảnh và động lực

Trong thập kỷ qua, mô hình **hybrid cloud** đã trở thành xu hướng chủ đạo trong kiến trúc hạ tầng công nghệ thông tin của các doanh nghiệp. Thay vì lựa chọn hoàn toàn on-premise (tự duy trì máy chủ tại chỗ) hay chuyển toàn bộ lên public cloud, nhiều tổ chức chọn kết hợp cả hai: giữ lại ứng dụng quan trọng hoặc dữ liệu nhạy cảm trên hạ tầng riêng, đồng thời tận dụng khả năng mở rộng (scalability), tính sẵn sàng cao (high availability) và đa dạng dịch vụ của các nhà cung cấp cloud công cộng như Amazon Web Services (AWS), Microsoft Azure, hay Google Cloud Platform (GCP).

**Lợi ích** của hybrid cloud bao gồm:
- **Tính linh hoạt**: Doanh nghiệp có thể di chuyển workload giữa on-premise và cloud tùy theo yêu cầu về hiệu năng, chi phí, hoặc tuân thủ pháp lý.
- **Tối ưu chi phí**: Các ứng dụng ít thay đổi chạy trên máy chủ tại chỗ (CAPEX), còn workload biến động cao sử dụng cloud (OPEX theo nhu cầu).
- **Tuân thủ quy định**: Dữ liệu cá nhân hoặc tài chính có thể giữ trong nước (on-premise), trong khi dịch vụ không nhạy cảm triển khai trên cloud quốc tế.

Tuy nhiên, mô hình này đặt ra **thách thức lớn về hiệu năng mạng**:
1. **Độ trễ (latency)**: Khoảng cách vật lý giữa data center on-premise (ví dụ tại TP. Hồ Chí Minh) và region cloud (Singapore, Hong Kong) có thể gây ra độ trễ hàng chục millisecond, ảnh hưởng đến ứng dụng thời gian thực.
2. **Băng thông giới hạn**: Kết nối giữa on-premise và cloud thường qua Internet công cộng hoặc VPN, có throughput thấp hơn mạng nội bộ data center.
3. **Biến động (jitter) và mất gói tin (packet loss)**: Đường truyền qua nhiều ISP có thể không ổn định như mạng LAN.
4. **Chi phí giám sát**: Triển khai hệ thống monitoring để theo dõi hiệu năng hybrid cloud có thể tốn tài nguyên (CPU, RAM, băng thông) và ảnh hưởng đến chính workload cần đo.

Với các doanh nghiệp tại **Việt Nam**, bối cảnh này càng rõ nét: hạ tầng on-premise thường nằm tại Hà Nội hoặc TP. Hồ Chí Minh, trong khi các cloud region gần nhất là Singapore (AWS `ap-southeast-1`, ~1,100 km), Hong Kong (Azure `eastasia`, ~1,400 km), hoặc Tokyo (AWS `ap-northeast-1`, ~3,600 km). Việc lựa chọn nhà cung cấp cloud, region, và thiết kế kết nối (VPN, Direct Connect) phụ thuộc nhiều vào **hiệu năng mạng thực tế**, mà các thông số lý thuyết từ vendor thường không phản ánh đủ điều kiện địa phương (ISP, routing policy, peering).

## 1.2. Vấn đề nghiên cứu

Để đưa ra quyết định sáng suót khi thiết kế hạ tầng hybrid cloud, kỹ sư cần trả lời các câu hỏi định lượng sau:

**Q1 (TN1): Độ trễ mạng giữa on-premise và cloud cao hơn giữa hai cloud bao nhiêu?**  
Một ứng dụng phân tán với front-end trên AWS và database trên on-premise sẽ chịu latency bao nhiêu? So với kiến trúc toàn bộ trên cloud (ví dụ AWS Singapore ↔ AWS Hong Kong), cross-cloud networking (on-premise ↔ cloud) chậm hơn bao nhiêu lần? VPN (ví dụ WireGuard) gây thêm overhead bao nhiêu so với kết nối trực tiếp?

**Q2 (TN2): Khoảng cách địa lý ảnh hưởng đến độ trễ như thế nào?**  
Liệu round-trip time (RTT) có quan hệ tuyến tính với khoảng cách vật lý giữa hai điểm? Hệ số góc của đường hồi quy có khớp với tốc độ lan truyền ánh sáng trong cáp quang (~200,000 km/s)? Overhead từ routing, switching, và processing chiếm bao nhiêu phần trăm so với propagation delay thuần túy?

**Q3 (TN3): Hệ thống giám sát (monitoring) ảnh hưởng đến hiệu năng workload bao nhiêu?**  
Khi triển khai agent như Telegraf để thu thập metrics mạng và hệ thống theo chu kỳ (ví dụ mỗi 10 giây), CPU, RAM, và băng thông bị tiêu tốn thêm bao nhiêu? Throughput của ứng dụng (request/s) hay latency (p99) có bị ảnh hưởng đáng kể không? Interval ngắn hơn (5s) có overhead cao hơn đáng kể so với interval dài (30s)?

**Q4 (TN4): Hiệu năng tính toán (compute) của on-premise so với cloud khác nhau như thế nào?**  
Một server vật lý tại chỗ (ví dụ Intel Core i5) so với instance cloud tương đương về vCPU (ví dụ AWS t3.small, Azure B2s_v2) có hiệu năng CPU, RAM, và I/O (IOPS, throughput) chênh lệch bao nhiêu? Ảo hóa (virtualization) trên cloud có ảnh hưởng đáng kể không? Burstable instance có phù hợp cho workload ổn định không?

Các câu hỏi này không chỉ quan trọng về mặt kỹ thuật mà còn ảnh hưởng trực tiếp đến **chi phí vận hành** (chọn region xa hơn có rẻ hơn nhưng latency cao có chấp nhận được?), **trải nghiệm người dùng** (API response time < 200ms?), và **chiến lược thiết kế** (nên đặt cache ở đâu? microservice giao tiếp thế nào?).

## 1.3. Mục tiêu nghiên cứu

Nghiên cứu này nhằm **đo đạc định lượng hiệu năng mạng và tính toán** trong mô hình hybrid cloud kết nối giữa on-premise tại Việt Nam và hai public cloud (AWS, Azure) ở khu vực Đông Nam Á. Cụ thể, các mục tiêu bao gồm:

1. **Đo lường và so sánh độ trễ mạng** (RTT, jitter, packet loss) giữa ba loại kết nối:
   - On-premise ↔ Cloud (cross-cloud, qua VPN)
   - Cloud A ↔ Cloud B (multi-cloud)
   - On-premise ↔ Cloud (direct, không VPN)

2. **Xác định mối quan hệ giữa khoảng cách địa lý và độ trễ** bằng hồi quy tuyến tính, sử dụng dữ liệu từ nhiều điểm phân bố (TP. Hồ Chí Minh, Hong Kong, Tokyo, Sydney, Virginia, Frankfurt).

3. **Đánh giá overhead của hệ thống monitoring** (TICK stack: Telegraf, InfluxDB, Chronograf) với các interval khác nhau (5s, 15s, 30s, off) lên throughput và latency của workload web.

4. **So sánh hiệu năng compute** (CPU, memory, I/O) giữa on-premise server và cloud instance tương đương, phân tích tác động của ảo hóa và burstable CPU credit.

5. **Xây dựng một lab hybrid cloud mở** (open-source, tái sử dụng được) với Terraform, WireGuard VPN, và TICK stack, phục vụ mục đích giảng dạy và thử nghiệm.

## 1.4. Phạm vi nghiên cứu

### 1.4.1. Không gian (địa lý)

- **On-premise**: Host vật lý tại TP. Hồ Chí Minh (10.8°N, 106.7°E), kết nối Internet qua ISP nội địa.
- **Cloud A (AWS)**: Region `ap-southeast-1` (Singapore), instance type `t3.small` (2 vCPU, 2 GB RAM, burstable).
- **Cloud B (Azure)**: Region `eastasia` (Hong Kong), instance type `Standard_B2s_v2` (2 vCPU, 8 GB RAM).
- **Geo-probes** (cho TN2): Tokyo (`ap-northeast-1`), Sydney (`ap-southeast-2`), Virginia (`us-east-1`), Frankfurt (`eu-central-1`).

### 1.4.2. Thời gian

- **Triển khai và cấu hình**: 3 ngày (2026-11-01 → 11-03).
- **Thu thập dữ liệu**: 1 tuần (2026-11-04 → 11-10), mỗi thí nghiệm lặp lại 3 lần, tổng cộng 4 thí nghiệm (TN1-TN4).
- **Điều kiện**: Thí nghiệm chạy trong giờ hành chính (9:00-18:00 GMT+7), tránh giờ cao điểm Internet (20:00-23:00).

### 1.4.3. Công nghệ

| Thành phần | Công nghệ | Phiên bản |
|---|---|---|
| Infrastructure as Code | Terraform | 1.5+ |
| VPN | WireGuard | 1.0.20220627 |
| Monitoring - Agent | Telegraf | 1.32.2 |
| Monitoring - Database | InfluxDB | 1.8 |
| Monitoring - Visualization | Chronograf | 1.10 |
| Container | Docker Compose | 2.20+ |
| Benchmark - CPU/RAM | sysbench | 1.0.20 |
| Benchmark - I/O | fio | 3.28 |
| Benchmark - Network | iperf3, mtr, ping | 3.9, 0.93, builtin |
| Benchmark - HTTP | Apache Bench (ab) | 2.3 |

### 1.4.4. Giới hạn

Nghiên cứu **không** bao gồm:
- **Bảo mật**: Không đo overhead của firewall, IDS/IPS, hoặc encryption ngoài VPN.
- **Application-level performance**: Không đo latency của database query, API gateway, hoặc microservice mesh.
- **Cost analysis**: Không so sánh chi phí giữa các cloud provider.
- **High availability / Disaster recovery**: Không thiết kế failover hay backup.
- **Production workload**: Thí nghiệm sử dụng synthetic benchmark (sysbench, fio, ab), không phải ứng dụng thực tế.

## 1.5. Đóng góp của nghiên cứu

Nghiên cứu này đóng góp:

1. **Dataset hiệu năng hybrid cloud thực tế** từ Việt Nam kết nối với cloud APAC (AWS Singapore, Azure Hong Kong), một khu vực ít được nghiên cứu so với US-EU.

2. **Công thức hồi quy distance-latency** cụ thể cho vùng Đông Nam Á - Đông Á - Oceania, giúp kỹ sư ước lượng nhanh RTT khi chọn region.

3. **Đánh giá overhead Telegraf/TICK stack**, một monitoring stack phổ biến cho time-series data, với các interval khác nhau — hữu ích cho quyết định cấu hình production.

4. **So sánh hiệu năng compute** giữa on-premise (bare metal), AWS burstable instance, và Azure B-series, minh họa tradeoff giữa cost và performance.

5. **Lab mở và tái sử dụng được**: Toàn bộ Terraform code, script, config được công khai trên GitHub, cho phép sinh viên và kỹ sư tái hiện thí nghiệm hoặc mở rộng (thêm GCP, Alibaba Cloud, v.v.).

6. **Tài liệu hướng dẫn đầy đủ**: Bao gồm troubleshooting thực tế (ví dụ: ISP Việt Nam chặn ICMP đến IP public, AWS burstable credit hết, v.v.), không chỉ lý thuyết mà còn kinh nghiệm triển khai.

## 1.6. Cấu trúc báo cáo

Báo cáo được tổ chức thành 8 chương:

- **Chương 1 (hiện tại)**: Giới thiệu bối cảnh, vấn đề, mục tiêu, phạm vi, và đóng góp.
- **Chương 2**: Cơ sở lý thuyết về hybrid cloud, network metrics, VPN, monitoring stack, và compute benchmark.
- **Chương 3**: Kiến trúc hệ thống — topology, cấu hình chi tiết từng thành phần (on-premise, AWS, Azure, VPN, TICK).
- **Chương 4**: Thiết kế thí nghiệm — phương pháp, công cụ, tham số cho TN1, TN2, TN3, TN4.
- **Chương 5**: Kết quả — dữ liệu đo được, biểu đồ, bảng so sánh.
- **Chương 6**: Thảo luận — giải thích kết quả, so sánh nghiên cứu liên quan, ý nghĩa thực tiễn, hạn chế, hướng phát triển.
- **Chương 7**: Kết luận — tóm tắt đóng góp, kết luận chính, khuyến nghị.
- **Chương 8**: Tài liệu tham khảo.

**Phụ lục** bao gồm: cấu hình Terraform, script benchmark, raw data mẫu, experiment log, và dashboard screenshots.

---

**Tóm tắt chương**  
Chương này giới thiệu bối cảnh hybrid cloud, đặt ra 4 câu hỏi nghiên cứu về latency, distance, monitoring overhead, và compute performance. Mục tiêu là đo đạc định lượng hiệu năng mạng giữa on-premise Việt Nam và cloud APAC, xây dựng dataset thực tế và lab mở. Phạm vi bao gồm 3 điểm (TP.HCM, Singapore, Hong Kong), 1 tuần đo, với 4 thí nghiệm (TN1-TN4) sử dụng TICK stack và WireGuard VPN. Đóng góp chính là dữ liệu APAC hybrid cloud, công thức distance-latency, đánh giá Telegraf overhead, và so sánh compute on-prem vs cloud.
