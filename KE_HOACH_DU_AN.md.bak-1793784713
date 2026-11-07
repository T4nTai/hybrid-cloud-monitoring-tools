# KẾ HOẠCH DỰ ÁN
## Đánh giá hiệu năng mạng trong mô hình Hybrid Cloud (On-premise + AWS + Azure) sử dụng TICK Stack

**Môn học:** Đánh giá hiệu năng mạng
**Đề tài:** Hybrid Cloud Monitoring Tools
**Thời lượng:** 3 tuần | **Chi phí ước tính:** ~$15/tháng

---

## 1. MỤC TIÊU & PHẠM VI

### 1.1 Mục tiêu
Xây dựng hệ thống giám sát (monitoring) trên nền tảng hybrid cloud AWS + Azure, đồng thời **sử dụng chính hệ thống đó để đo lường hiệu năng mạng** và trả lời các câu hỏi:

1. Hiệu năng mạng giữa **on-premise, AWS và Azure** khác nhau như thế nào (hybrid/VPN vs cross-cloud qua Internet)?
2. Khoảng cách vật lý ảnh hưởng thế nào đến độ trễ (latency)?
3. Bản thân hệ thống monitoring gây ra overhead bao nhiêu lên workload đang chạy?
4. Hiệu năng compute (CPU/RAM/Disk) của **on-prem, AWS và Azure** khác nhau thế nào khi dùng cấu hình tương đương?

### 1.2 Phạm vi

| | Bao gồm | Không bao gồm |
|---|---|---|
| **Cloud** | On-premise (TP.HCM, Việt Nam), AWS (ap-southeast-1 Singapore; probe ap-northeast-1 Tokyo, ap-southeast-2 Sydney, us-east-1, eu-central-1), Azure (eastasia Hong Kong) | GCP, OCI |
| **Chỉ số** | Latency (RTT, p50/p95/p99), Packet loss, Jitter, Throughput, Route quality | APM, Log analytics, Tracing |
| **Công cụ** | TICK Stack (thu thập & lưu) + sysbench/fio/iperf3/ab/mtr (đo lường) | Kafka, Mimir, Loki, Kubernetes |
| **Quy mô** | 3 VM chính (1 on-prem + 1 AWS + 1 Azure Central) + 4 probe nhỏ cho TN2 (bật/tắt theo nhu cầu) | Kiến trúc HA, multi-region failover |

---

## 2. KIẾN TRÚC HỆ THỐNG

```
┌─── On-premise TP.HCM (Việt Nam) ───────────────────────┐
│  Host KVM (WireGuard client 10.200.200.2)               │
│  └─ VM-A (Ubuntu 22.04, 192.168.122.146)                │
│     ├─ Telegraf Agent (host=vm-a) ──► OS metrics + ping │
│     └─ sysbench / fio / nginx (benchmark)               │
└────────────────────────┬────────────────────────────────┘
                         │ WireGuard UDP 51820 — 10.200.200.0/24
┌─── AWS ap-southeast-1 (Singapore) ─────────────────────┐
│  VM-B (t3.small)                                        │
│  ├─ Telegraf Agent (host=vm-b)                          │
│  ├─ iperf3 server :5201                                 │
│  └─ nginx :80 (Apache Bench)                            │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP :8086 (public internet)
┌─── Azure eastasia (Hong Kong) ─────────────────────────┐
│  Central VM (Standard_B2s_v2) — Neutral Observer        │
│  Docker Compose:                                        │
│  ├─ InfluxDB   :8086   (lưu time-series)                │
│  └─ Chronograf :8888   (dashboard)                      │
└─────────────────────────────────────────────────────────┘

TN2 probes (chỉ bật khi đo khoảng cách, tắt sau khi xong):
  AWS ap-northeast-1 Tokyo | ap-southeast-2 Sydney
  AWS us-east-1 Virginia   | eu-central-1 Frankfurt
```

### 2.1 Luồng hoạt động (chu kỳ 10 giây, lặp liên tục)

```
 Telegraf trên mỗi VM          InfluxDB              Chronograf
 ┌──────────────────┐         ┌──────────┐         ┌────────────┐
 │ cpu/mem/disk/net│         │          │  query   │ Dashboard  │
 │ ping (20 gói)   │────────►│ lưu điểm │◄────────│ biểu đồ    │
 │ net_response    │  HTTP   │ dữ liệu  │ InfluxQL│            │
 │ http_response   │  :8086  │          │         │ So sánh    │
 └──────────────────┘         └──────────┘         │ điểm đo    │
                                                      └────────────┘
```

**Ba nguồn dữ liệu được hệ thống ghi nhận:**
1. **Agent metrics** — đo trực tiếp trên VM (CPU, RAM, Disk, Network)
2. **Network probes** — Telegraf `inputs.ping` phát 20 gói ICMP mỗi 10s, tự tính RTT/loss/jitter/p50-p95-p99
3. **Cloud native** — Telegraf Central gọi API CloudWatch & Azure Monitor lấy metrics ở góc nhìn của từng provider

---

## 3. THÔNG SỐ ĐO ĐƯỢC

### 3.1 Nhóm chỉ số mạng (trọng tâm môn học)

| Chỉ số | Field Telegraf | Đơn vị | Ý nghĩa |
|---|---|---|---|
| **Latency trung bình (RTT)** | `average_response_ms` | ms | Thời gian gói tin đi và về |
| **Latency phân vị** | `percentile50/95/99_response_ms` | ms | 95% request dưới ngưỡng này — chuẩn đánh giá SLO |
| **Packet loss** | `percent_packet_loss` | % | Tỷ lệ gói tin bị mất |
| **Jitter** | `standard_deviation_ms` | ms | Độ dao động của RTT → ảnh hưởng chất lượng thoại/streaming |
| **Latency min/max** | `minimum/maximum_response_ms` | ms | Biên độ dao động |
| **TCP handshake** | `net_response.response_time_ms` | ms | Thời gian thiết lập kết nối TCP |
| **HTTP response** | `http_response.response_time` | ms | Thời gian server xử lý request |
| **Throughput** | (iperf3, ghi ngoài DB) | Mbps | Băng thông tối đa đạt được |
| **Độ trễ từng hop** | (mtr, ghi ngoài DB) | ms | Chất lượng route, phát hiện hop bị nghẽn |
| **Băng thông monitoring** | `net.bytes_sent/recv` | bytes/s | Overhead do chính hệ thống monitoring |

### 3.2 Nhóm chỉ số hệ thống (phục vụ TN3, TN4)

| Chỉ số | Field | Đơn vị |
|---|---|---|
| CPU sử dụng | `cpu.usage_user + usage_system` | % |
| CPU load | `cpu.load1/load5/load15` | - |
| RAM | `mem.used_percent` | % |
| Disk | `disk.used_percent`, `disk.io_time` | %, ms |

### 3.3 Chỉ số suy ra cho báo cáo

| Chỉ số suy ra | Công thức | Dùng ở |
|---|---|---|
| Hệ số chênh lệch latency | `RTT_crosscloud / RTT_intracloud` | TN1 |
| Hiệu quả truyền dẫn | `RTT_thực_đo / RTT_lý_thuyết` | TN2 |
| Overhead của monitoring | `(X_có_monitoring − X_không) / X_không × 100%` | TN3 |
| Throughput bị suy giảm | `Δrequests/sec khi bật Telegraf` | TN3 |

---

## 4. THIẾT BỊ & PHẦN MỀM

### 4.1 Danh sách VM

| VM | Vị trí | Spec | Hệ điều hành | Vai trò | Chi phí |
|---|---|---|---|---|---|
| VM-A | **On-prem TP.HCM** (KVM guest) | 2 vCPU / RAM tùy host | Ubuntu 22.04 | Agent + benchmark | $0 |
| VM-B | AWS ap-southeast-1 (Singapore) | t3.small (2 vCPU, 2 GB) | Ubuntu 22.04 | Agent + iperf3 + nginx | ~$15/tháng |
| Central | Azure eastasia (Hong Kong) | Standard_B2s_v2 (2 vCPU, 8 GB) | Ubuntu 22.04 | TICK — neutral observer | ~$30/tháng |
| Probe TN2 ×4 | AWS Tokyo / Sydney / Virginia / Frankfurt | t3.micro | Ubuntu 22.04 | Đo khoảng cách (chỉ bật khi đo) | ~$0.05/giờ |

> **Tắt 4 probe TN2 ngay sau khi đo** để tiết kiệm. Chúng chỉ phục vụ TN2 (khoảng cách – latency), không tham gia monitoring thường xuyên.

### 4.2 Cảnh báo về tính công bằng của phép so sánh (rất quan trọng)

Hai dòng VM giống nhau về "số vCPU" **không có cùng hiệu năng thực tế**:

| | AWS t3.small | Azure B2s_v2 | On-prem VM-A |
|---|---|---|---|
| vCPU | 2 | 2 | tùy host |
| Baseline CPU | **20%/vCPU** (burstable, tổng ~40%) | **burstable credit-based** (~40%/vCPU) | Không giới hạn (tùy host) |
| Cơ chế | AWS Credits — hết credit sẽ throttle | Azure Credits — hết credit sẽ throttle | Không |
| Bộ nhớ | 2 GB | 8 GB | tùy host |

**→ Bắt buộc phải nêu điểm này trong báo cáo**, nếu không kết luận "Azure nhanh hơn AWS gấp 5 lần" sẽ bị coi là kết luận sai.

**Cách xử lý (áp dụng cho TN4):**
- **Theo dõi credit trước/sau mỗi lần đo**: `CPUCreditBalance` (CloudWatch) và CPU credits (Azure Monitor). Ghi lại trong nhật ký.
- Chạy khi credit còn dồi dào, hoặc chấp nhận và ghi rõ: *kết quả phản ánh gói burstable cụ thể, không đại diện toàn dòng VM*.
- **Tắt Docker (InfluxDB + Chronograf) trên Central** trong lúc benchmark TN4 để tránh tranh CPU/disk, sau đó bật lại.
- Luôn chạy benchmark **3 lần, lấy trung bình + độ lệch chuẩn**, cùng khung giờ.
- On-prem VM-A đo cùng thời điểm để làm mốc "không bị giới hạn credit".

### 4.3 Phần mềm cài đặt

**Trên Central VM:**
```bash
sudo apt install -y docker.io docker-compose nginx iperf3 mtr-tiny
```

**Trên từng VM agent (A, B, C, D):**
```bash
# Telegraf
wget -qO- https://repos.influxdata.com/influxdb.key | \
  gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdb.gpg
echo "deb https://repos.influxdata.com/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/influxdb.list
sudo apt update && sudo apt install -y telegraf

# Công cụ benchmark
sudo apt install -y sysbench fio iperf3 apache2-utils mtr-tiny nginx
```

| Công cụ | Đo được | Câu lệnh mẫu |
|---|---|---|
| `sysbench` | CPU ops/s, RAM MB/s | `sysbench cpu --cpu-max-prime=25000 --threads=2 --time=60 run` |
| `fio` | Disk IOPS, latency (µs) | `fio --name=randread --ioengine=libaio --direct=1 --bs=4k --size=1G --runtime=60 --iodepth=32 --group_reporting` |
| `iperf3` | Throughput mạng (Mbps) | `iperf3 -c <IP> -t 30 -i 1` |
| `ab` (Apache Bench) | Requests/s, latency p99 | `ab -n 10000 -c 100 http://localhost/` |
| `mtr` | Độ trễ và loss từng hop | `mtr -rwc 100 <IP>` |

---

## 5. TRIỂN KHAI HỆ THỐNG

### 5.1 Central VM — Docker Compose

**File `docker-compose.yml`:**
```yaml
version: '3.8'
services:
  influxdb:
    image: influxdb:1.8
    container_name: influxdb
    restart: always
    ports: ["8086:8086"]
    environment:
      - INFLUXDB_DB=monitoring
      - INFLUXDB_ADMIN_USER=admin
      - INFLUXDB_ADMIN_PASSWORD=CHANGE_ME
      - INFLUXDB_HTTP_AUTH_ENABLED=true
    volumes:
      - influxdb-data:/var/lib/influxdb

  chronograf:
    image: chronograf:1.10
    container_name: chronograf
    restart: always
    ports: ["8888:8888"]
    environment:
      - INFLUXDB_URL=http://influxdb:8086
    volumes:
      - chronograf-data:/var/lib/chronograf
    depends_on: [influxdb]

volumes:
  influxdb-data:
  chronograf-data:
```

```bash
docker-compose up -d
docker-compose ps
# Mở http://<CENTRAL-IP>:8888, đăng nhập admin / CHANGE_ME
```

**Mở Security Group cho Central VM:**
- `8086/tcp` — InfluxDB (chỉ cho IP của 4 VM agent)
- `8888/tcp` — Chronograf (IP của bạn)
- `5201/tcp` — iperf3 (IP của 4 VM agent)
- `80/tcp` — nginx (IP của bạn + VM để test `ab`)

### 5.2 Telegraf trên VM agent (A, B, C, D)

**File `/etc/telegraf/telegraf.conf` — dùng chung, chỉ khác phần `urls`:**
```toml
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "2s"
  flush_interval = "10s"
  hostname = "vm-a"            # đổi theo từng VM

[[outputs.influxdb]]
  urls = ["http://<CENTRAL-IP>:8086"]
  database = "monitoring"
  username = "admin"
  password = "CHANGE_ME"
  timeout = "10s"

# ---- Metrics hệ thống ----
[[inputs.cpu]]
  percpu = false
  totalcpu = true
  collect_cpu_time = true
[[inputs.mem]]
[[inputs.disk]]
  mountpoints = ["/"]
[[inputs.net]]
  interfaces = ["eth0"]

# ---- ĐO HIỆU NĂNG MẠNG (quan trọng nhất) ----
[[inputs.ping]]
  urls = ["<IP-VM-B>", "<CENTRAL-IP>"]
  count = 20
  interval = "10s"
  ping_interval = "0.2"
  method = "native"
  percentile = [50, 95, 99]
  deadline = 10

[[inputs.net_response]]
  protocol = "tcp"
  address = "<IP-VM-B>:80"
  timeout = "5s"
  read_timeout = "5s"
  interval = "10s"

[[inputs.http_response]]
  urls = ["http://<IP-VM-B>/"]
  method = "GET"
  response_timeout = "5s"
  interval = "10s"

[[inputs.internal_write]]
[[inputs.statsd]]
```

```bash
# Cấp quyền raw socket cho inputs.ping dùng native mode
sudo setcap cap_net_raw+ep /usr/bin/telegraf

sudo systemctl restart telegraf
sudo systemctl status telegraf
sudo journalctl -u telegraf -f | head -50
```

**Bảng khai báo target cho từng VM:**

| VM | `hostname` | `urls` (ping) | Ghi chú |
|---|---|---|---|
| VM-A (on-prem TP.HCM) | `vm-a` | `10.200.200.1` (VPN), `52.175.59.167` (Azure), `8.8.8.8` | Đo cả đường VPN và Internet |
| VM-B (AWS SG) | `vm-b` | `52.175.59.167` (Azure), `8.8.8.8`, `1.1.1.1` | Đo cross-cloud AWS↔Azure |
| Central (Azure HK) | — | — | Không chạy Telegraf agent (chỉ TICK) |
| Probe TN2 (×4) | `probe-*` | IP VM-B, IP Central | Chỉ chạy ping trong lúc đo TN2 |

### 5.3 Telegraf Central — lấy metrics native từ CloudWatch & Azure Monitor

**IAM Role cho AWS (gắn vào Central VM):**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "ec2:DescribeInstances",
      "tag:GetResources"
    ],
    "Resource": "*"
  }]
}
```

**Service Principal cho Azure:**
```bash
az ad sp create-for-rbac \
  --name "monitoring-reader" \
  --role "Monitoring Reader" \
  --scopes /subscriptions/<SUBSCRIPTION-ID>
# Lưu: appId → client_id, password → client_secret, tenant → tenant_id
```

**Block bổ sung trong `/etc/telegraf/telegraf.conf` trên Central:**
```toml
[[outputs.influxdb]]
  urls = ["http://localhost:8086"]
  database = "monitoring"
  username = "admin"
  password = "CHANGE_ME"

[[inputs.cloudwatch]]
  region = "ap-southeast-1"
  period = "1m"
  delay = "2m"
  interval = "60s"
  namespace = "AWS/EC2"
  [[inputs.cloudwatch.metrics]]
    names = ["CPUUtilization", "NetworkIn", "NetworkOut", "StatusCheckFailed"]
    [[inputs.cloudwatch.metrics.dimensions]]
      name = "InstanceId"
      value = "<VM-A-INSTANCE-ID>"

[[inputs.azure_monitor]]
  subscription_id = "<SUBSCRIPTION-ID>"
  tenant_id = "<TENANT-ID>"
  client_id = "<CLIENT-ID>"
  client_secret = "<CLIENT-SECRET>"
  resource_type = "Microsoft.Compute/virtualMachines"
  interval = "60s"
  [[inputs.azure_monitor.resource_target]]
    resource_group = "<RESOURCE-GROUP>"
    resource_name = "<VM-B-NAME>"
  [[inputs.azure_monitor.metric]]
    name = ["Percentage CPU", "Network In Total", "Network Out Total"]
    time_grain = "PT1M"
```

---

## 6. THIẾT KẾ THỰC NGHIỆM

### 6.1 Nguyên tắc thiết kế

| Nguyên tắc | Cách thực hiện |
|---|---|
| **Kiểm soát biến** | Chỉ thay đổi **một** yếu tố mỗi thí nghiệm |
| **Lặp lại** | Mỗi phép đo chạy **≥3 lần**, lấy trung bình và độ lệch chuẩn |
| **Cùng thời điểm** | Chạy song song các phép đo trên các VM để tránh ảnh hưởng giờ cao điểm |
| **Thời gian đủ dài** | Phép đo mạng chạy **≥30 phút**/lần để tránh nhiễu ngắn hạn |
| **Ghi nhận điều kiện môi trường** | Ghi thời tiết/giờ chạy/lệnh cụ thể vào nhật ký thí nghiệm |

### 6.2 Danh mục thí nghiệm

| Mã | Tên thí nghiệm | Biến số | Công cụ đo | Chỉ số |
|---|---|---|---|---|
| **TN1** | Hybrid vs cross-cloud network | Đường đi: on-prem↔AWS (VPN), on-prem↔Azure (Internet), AWS↔Azure (Internet) | Telegraf ping, iperf3, mtr | RTT, loss, jitter, throughput, hop |
| **TN2** | Ảnh hưởng khoảng cách vật lý | Khoảng cách (TP.HCM/SG → 0–15.400 km) | Telegraf ping, mtr, probe VM | RTT, hiệu suất truyền dẫn |
| **TN3** | Overhead của agent monitoring | Telegraf tắt / bật (interval 5s–30s) | ab, iperf3, Telegraf | requests/s, RTT, bytes_sent, CPU% |
| **TN4** | So sánh compute on-prem / AWS / Azure | Provider | sysbench, fio | ops/s, MB/s, IOPS, latency |

> Các phép đo liên quan đến tinh chỉnh **tần suất lấy mẫu của monitoring** chỉ được thực hiện như **biến phụ trong TN3**, không tách thành thí nghiệm riêng — vì bản chất nó là đo *overhead*, thuộc phạm vi đánh giá hiệu năng.

---

### TN1 — Hiệu năng mạng: Hybrid (VPN) vs Cross-cloud (Internet)

**Giả thuyết:** Đường hybrid on-prem↔AWS qua WireGuard có RTT và loss thấp; đường cross-cloud AWS↔Azure qua Internet có RTT cao hơn; đường on-prem↔Azure chịu ảnh hưởng chất lượng tuyến Internet quốc tế (loss cao hơn).

**Bảng thiết kế (mô hình thực tế 3 điểm):**

| Mã | Đường đi | Loại | Khoảng cách ước tính |
|---|---|---|---|
| **P1** | VM-A (on-prem TP.HCM) ↔ VM-B (AWS Singapore) qua **WireGuard** | Hybrid / VPN | ~1.100 km |
| **P2** | VM-A (on-prem TP.HCM) ↔ Central (Azure Hong Kong) qua Internet | Hybrid / Internet | ~1.500 km |
| **P3** | VM-B (AWS Singapore) ↔ Central (Azure Hong Kong) qua Internet | Cross-cloud | ~2.600 km |
| **P4** | VM-A → VM-B **public IP** (18.139.136.124), cùng path không VPN | Baseline VPN overhead | ~1.100 km |
| **P0** | Loopback `127.0.0.1` mỗi máy | Baseline | 0 |

**Cách chạy:**
```bash
# 1) Telegraf ping liên tục (đã cấu hình) — thu 10–15 phút mỗi đường

# 2) mtr — 3 lần mỗi đường, đo số hop
mtr -rwc 100 10.200.200.1        # P1 (qua VPN)
mtr -rwc 100 52.175.59.167       # P3 (AWS -> Azure)
mtr -rwc 100 18.139.136.124      # P4 (public path)

# 3) iperf3 — 3 lần mỗi cặp, 30s
#    Server VM-B: iperf3 -s -4
#    Client VM-A: iperf3 -c 10.200.200.1 -t 30
#    Client VM-A: iperf3 -c 10.200.200.1 -t 30 -R
#    UDP:         iperf3 -c 10.200.200.1 -u -b 100M -t 20
```

**Truy vấn InfluxQL lấy kết quả:**
```sql
SELECT mean("average_response_ms") AS "rtt_avg",
       max("percentile95_response_ms") AS "rtt_p95",
       mean("percent_packet_loss") AS "loss",
       mean("standard_deviation_ms") AS "jitter"
FROM "ping"
WHERE time > now() - 1h
GROUP BY "host", "url"
```

**Bảng kết quả:**

| Đường | RTT avg (ms) | RTT p95 (ms) | Loss (%) | Jitter (ms) | Throughput (Mbps) | Số hop |
|---|---|---|---|---|---|---|
| P1 Hybrid VPN (on-prem↔AWS) | 28.86 (vòng sạch) | ~30 | 0 | 0.33 | TCP 139/136; UDP 100 (0.011% loss) | 1 |
| P2 Hybrid Internet (on-prem↔Azure) | 35.6 | ~45 | ~1.7 (TB) / ~5 (2 phút) | 9.45 | chưa đo | chưa đo |
| P3 Cross-cloud (AWS↔Azure) | 37.27 | ~41 | 0 | 1.15 | chưa đo | 21 |
| P4 Public path (on-prem↔AWS, không VPN) | chờ VM-A | | | | chờ VM-A | chờ VM-A |
| P0 Loopback baseline | ~0.05 | ~0.1 | 0 | ~0.02 | — | 0 |

> Kết quả thật ngày 2026-11-04. P1/P3 đo 3 vòng × 100 gói; P2 lấy từ Telegraf InfluxDB (host=vm-a, url=52.175.59.167). Chi tiết: `data/raw/iperf3-vm-a-vm-b.txt`, `data/raw/tn2-distance-latency.txt`.

**Kết luận cần rút ra:**
- **VPN overhead** = RTT(P1) − RTT(P4)
- So sánh hybrid VPN (P1) vs hybrid Internet (P2) vs cross-cloud (P3)
- Mối quan hệ giữa số hop (mtr) và RTT/loss
- Vì sao P2 (gần hơn P3) có thể loss cao hơn → chất lượng tuyến ISP quan trọng hơn khoảng cách

---

### TN2 — Ảnh hưởng của khoảng cách vật lý đến độ trễ

**Giả thuyết:** Độ trễ tăng gần như tuyến tính theo khoảng cách vật lý, xuất phát từ giới hạn tốc độ ánh sáng trong sợi quang, cộng thêm độ trễ do định tuyến.

**Cơ sở lý thuyết:** Ánh sáng trong sợi quang đi với tốc độ khoảng **200.000 km/s**, độ trễ tối thiểu xấp xỉ:
```
RTT_min (ms) ≈ (2 × khoảng cách km) / 200.000 × 1000 = khoảng cách km / 100
```

**Nguồn đo:** VM-B (Singapore) là mốc chính; VM-A (TP.HCM) là mốc phụ. 4 probe VM ở Tokyo/Sydney/Virginia/Frankfurt **chỉ bật trong lúc đo**, tắt ngay sau đó.

| Cặp | Khoảng cách (km) | RTT lý thuyết tối thiểu (ms) |
|---|---|---|
| SG ↔ TP.HCM | ~1.100 | 11 |
| SG ↔ Hong Kong (Central) | ~2.600 | 26 |
| SG ↔ Tokyo | ~5.300 | 53 |
| SG ↔ Sydney | ~6.300 | 63 |
| SG ↔ Frankfurt | ~10.000 | 100 |
| SG ↔ Virginia | ~15.400 | 154 |

**Cách chạy:**
```bash
# Trên VM-B (Singapore): ping 100 gói tới từng đích
for ip in <TOKYO_IP> <SYDNEY_IP> <FRANKFURT_IP> <VIRGINIA_IP> 52.175.59.167; do
  ping -c 100 -i 0.2 "$ip"
done

# Trên VM-A (TP.HCM): lặp lại tới từng probe
# mtr -rwc 100 <IP> để lấy số hop và loss từng chặng
```

**Bảng kết quả (nguồn: VM-B Singapore):**

| Cặp | Khoảng cách (km) | RTT đo (ms) | RTT lý thuyết (ms) | Hiệu suất truyền dẫn (%) |
|---|---|---|---|---|
| SG ↔ TP.HCM (VM-A, qua VPN) | ~1.090 | 31.40 | 10.90 | 34.7 |
| SG ↔ Hong Kong (Central) | ~2.570 | 37.27 | 25.70 | 69.0 |
| SG ↔ Tokyo | ~5.320 | 67.92 | 53.20 | 78.3 |
| SG ↔ Sydney | ~6.300 | 164.85 | 63.00 | 38.2 |
| SG ↔ Frankfurt | ~10.290 | 185.51 | 102.90 | 55.5 |
| SG ↔ Virginia | ~15.380 | 222.98 | 153.80 | 69.0 |

> Kết quả thật ngày 2026-11-04: hồi quy `RTT = 0.0144 × km + 21.28`, **R² = 0.81**. Sydney là outlier (định tuyến vòng). Chi tiết: `data/raw/tn2-distance-latency.txt`.

```
Hiệu suất truyền dẫn = RTT lý thuyết tối thiểu / RTT đo thực tế × 100%
```

**Kết luận cần rút ra:**
- Hồi quy tuyến tính giữa khoảng cách và RTT, báo cáo hệ số R²
- Hiệu suất truyền dẫn từng tuyến (càng xa càng tiệm cận ~70–80%)
- Vì sao tuyến gần chưa chắc nhanh hơn: VN↔HK (~1.500 km) có thể có RTT/loss cao hơn VN↔SG (~1.100 km) do định tuyến ISP

---

### TN3 — Ảnh hưởng của agent monitoring đến hiệu năng workload

**Giả thuyết:** Telegraf khi chạy trên cùng VM với ứng dụng sẽ tiêu thụ một phần tài nguyên, làm giảm throughput và tăng latency của workload đang đo.

**Ma trận phép đo:**

| Lần | Telegraf | Interval | Workload đồng thời | Thời gian |
|---|---|---|---|---|
| 1 | Tắt | — | `ab -n 20000 -c 100 http://localhost/` | 60s |
| 2 | Bật | 30s | Như trên | 60s |
| 3 | Bật | 15s | Như trên | 60s |
| 4 | Bật | 5s | Như trên | 60s |
| 5 | Tắt | — | `iperf3` với Central | 60s |

*Lặp lại toàn bộ 5 lần trên **cả 2 VM** (AWS và Azure), mỗi lần 3 lần đo.*

**Cách chạy:**
```bash
# Trên VM: chuẩn bị workload server
sudo systemctl start nginx
echo "<h1>benchmark</h1>" | sudo tee /var/www/html/index.html

# Tắt/bật Telegraf giữa các lần đo
sudo systemctl stop telegraf     # hoặc start

# Đo HTTP throughput
ab -n 20000 -c 100 http://localhost/ | tee results_ab_run1.txt

# Đo network throughput tới Central
iperf3 -c <CENTRAL-IP> -t 60 -i 1 | tee results_iperf_run1.txt

# Đo băng thông do chính Telegraf tiêu thụ (truy vấn InfluxDB)
```

**Truy vấn băng thông monitoring tiêu thụ:**
```sql
SELECT mean("bytes_sent") + mean("bytes_recv") AS "total_bytes_per_sec"
FROM "net"
WHERE "host" = 'vm-a' AND time > now() - 10m
GROUP BY time(1m)
```

**Bảng kết quả (AWS VM-A):**

| Interval | Requests/s | Mean latency (ms) | p99 (ms) | Throughput iperf3 (Mbps) | Băng thông Telegraf (KB/s) | CPU Telegraf (%) |
|---|---|---|---|---|---|---|
| Tắt | 12432.07 ± 23.79 | 8.04 | 9 | chưa đo | ~0 | 0 |
| 30s | 12692.19 ± 42.04 | 7.88 | 9 | chưa đo | ~0.23 | ~0.9 |
| 15s | 12504.63 ± 86.40 | 7.92 | 9 | chưa đo | ~0.46 | ~1.0 |
| 5s | 12485.17 ± 57.70 | 8.01 | 9 | chưa đo | ~0.83 | ~1.2 |

> Kết quả thật trên **VM-B** ngày 2026-11-04 (3 lần/mức, `ab -n 20000 -c 100`). Overhead nằm trong nhiễu; băng thông monitoring tăng gần tuyến tính với 1/interval. Chi tiết: `data/raw/benchmark-vm-b.txt`.

**Kết luận cần rút ra:**
- Overhead tối đa của Telegraf lên throughput: `___ %`
- Overhead lên p99 latency: `+___ ms`
- Mối quan hệ giữa interval và overhead (tuyến tính hay bão hòa?)
- **Khuyến nghị cấu hình tối ưu cho môi trường production**

---

### TN4 — So sánh hiệu năng compute: On-prem vs AWS vs Azure

**Giả thuyết:** Với cùng số vCPU và cùng OS, on-prem, AWS và Azure cho hiệu năng compute khác nhau, phụ thuộc loại instance (burstable vs không giới hạn) và vi kiến trúc CPU.

**Lưu ý bắt buộc:** Đọc lại mục **4.2 — cảnh báo về tính công bằng**. Cả `t3.small` và `B2s_v2` đều là **burstable credit-based**, nên phải ghi lại `CPUCreditBalance` trước/sau mỗi lần chạy và nêu rõ hạn chế trong báo cáo.

**Các phép đo con (cùng OS, cùng khung giờ, lặp 3 lần):**

```bash
# CPU — hiệu năng đa luồng
sysbench cpu --cpu-max-prime=25000 --threads=2 --time=60 run

# CPU — hiệu năng đơn luồng (kiểm tra khác biệt kiến trúc)
sysbench cpu --cpu-max-prime=25000 --threads=1 --time=60 run

# RAM — băng thông đọc
sysbench memory --memory-total-size=8G --threads=2 run

# Disk — đọc ngẫu nhiên, đo IOPS
fio --name=randread --ioengine=libaio --direct=1 --bs=4k \
    --size=1G --runtime=60 --iodepth=32 --group_reporting

# Disk — ghi ngẫu nhiên
fio --name=randwrite --ioengine=libaio --direct=1 --bs=4k \
    --size=1G --runtime=60 --iodepth=32 --group_reporting

# Disk — tuần tự (kiểm tra tốc độ nền tảng)
fio --name=seqread --ioengine=libaio --direct=1 --bs=1M \
    --size=1G --runtime=60 --group_reporting
```

**Bảng kết quả (trung bình ± độ lệch chuẩn của 3 lần chạy):**

| Phép đo | Đơn vị | On-prem VM-A | AWS VM-B (t3.small) | Azure Central (B2s_v2) |
|---|---|---|---|---|
| CPU 1 thread | events/sec | (chờ VM-A) | 302.17 ± 0.07 | 842.98 ± 0.57 |
| CPU 2 threads | events/sec | (chờ VM-A) | 475.60 ± 0.10 | 877.07 ± 0.14 |
| RAM read | MiB/sec | (chờ VM-A) | 6869.05 ± 13.62 | 8037.97 ± 190.01 |
| Disk seq read | MB/s | (chờ VM-A) | 137.67 ± 6.13 | 127.67 ± 0.47 |
| Disk rand read | IOPS | (chờ VM-A) | 3047.67 ± 0.47 | 9392.00 ± 2.94 |
| Disk rand read | avg latency (µs) | (chờ VM-A) | 10186.81 ± 0.51 | 3401.45 ± 1.32 |
| Disk rand write | IOPS | (chờ VM-A) | 3009.67 ± 2.05 | 557.67 ± 0.94 |

> Kết quả thật ngày 2026-11-04 (3 lần × 60s, `direct=1 iodepth=32`). Azure CPU nhanh hơn ~2.8× nhưng ghi ngẫu nhiên chậm hơn ~5.4×. Chi tiết: `data/raw/benchmark-vm-b.txt`, `data/raw/benchmark-azure-central.txt`.

**Bổ sung: credit & chi phí trên hiệu năng**

```sql
-- CPU% thực tế trong lúc benchmark (từ InfluxDB)
SELECT mean("usage_user") + mean("usage_system") AS cpu_percent
FROM "cpu" WHERE "host" = 'vm-b' AND time > now() - 1h
GROUP BY time(1m)
```

| | On-prem VM-A | AWS t3.small | Azure B2s_v2 |
|---|---|---|---|
| Giá/tháng (ước tính) | $0 (điện + hạ tầng) | ~$15 | ~$30 |
| CPU ops/s đạt được | | | |
| **ops/s trên 1 USD** | | | |
| CPUCreditBalance trước/sau | — | | |

**Kết luận cần rút ra:**
- Provider nào cho hiệu năng compute cao nhất trên cấu hình tương đương
- Chi phí trên đơn vị hiệu năng
- Tác động của cơ chế burstable/credit (cả t3.small và B2s_v2 đều burstable)
- On-prem mạnh/yếu hơn cloud ở điểm nào (CPU, disk, memory)

---

## 7. DASHBOARD & TRỰC QUAN HÓA

### 7.1 Các panel Chronograf cần có

```sql
-- PANEL 1: Latency các đường đo (Line chart) — kết quả chính của TN1
SELECT mean("average_response_ms") AS "RTT"
FROM "ping"
WHERE time > now() - 6h
GROUP BY time(1m), "host", "url"

-- PANEL 2: Packet loss (Area chart)
SELECT mean("percent_packet_loss") AS "loss"
FROM "ping"
WHERE time > now() - 6h
GROUP BY time(1m), "host"

-- PANEL 3: Jitter (Line chart)
SELECT mean("standard_deviation_ms") AS "jitter"
FROM "ping"
WHERE time > now() - 6h
GROUP BY time(1m), "host"

-- PANEL 4: Latency p50 vs p95 vs p99 (Line chart) — đánh giá SLO
SELECT mean("percentile50_response_ms")  AS "p50",
       mean("percentile95_response_ms")  AS "p95",
       mean("percentile99_response_ms")  AS "p99"
FROM "ping"
WHERE time > now() - 6h
GROUP BY time(1m), "host"

-- PANEL 5: Băng thông Telegraf tiêu thụ (Area chart) — kết quả TN3
SELECT mean("bytes_sent") + mean("bytes_recv") AS "bytes_per_sec"
FROM "net"
WHERE time > now() - 3h
GROUP BY time(1m), "host"

-- PANEL 6: CPU so sánh 2 cloud (Line chart) — phục vụ TN4
SELECT mean("usage_user") + mean("usage_system") AS "CPU %"
FROM "cpu"
WHERE time > now() - 3h
GROUP BY time(1m), "host"
```

### 7.2 Biểu đồ bổ sung (vẽ bằng Python/Excel để chèn vào báo cáo)

Các biểu đồ sau **không cần làm trong Chronograf**, vẽ bằng `matplotlib` từ file kết quả benchmark sẽ trông chuyên nghiệp hơn:

| Biểu đồ | Nguồn dữ liệu | Dùng cho |
|---|---|---|
| Đường cong RTT vs khoảng cách (kèm đường lý thuyết) | TN2 | Minh họa giới hạn vật lý |
| Biểu đồ cột nhóm: ops/s, IOPS của 2 cloud | TN4 | So sánh compute |
| Biểu đồ đường: overhead vs interval (TN3) | TN3 | Khuyến nghị cấu hình |
| Boxplot: phân bố RTT của 4 đường đo | TN1 | Thể hiện tính ngẫu nhiên của mạng |
| Bảng mtr (sơ đồ route) | TN1/TN2 | Phân tích định tuyến |

```python
# Mẫu: vẽ đường cong RTT vs khoảng cách
import matplotlib.pyplot as plt

distances = [0, 5300, 6300, 15400]   # km
rtt_measured = [1.2, 78.4, 85.1, 232.6]  # ms - điền sau khi đo
rtt_theoretical = [d/100 for d in distances]

plt.plot(distances, rtt_measured, 'o-', label='Đo thực tế')
plt.plot(distances, rtt_theoretical, '--', label='Lý thuyết tối thiểu')
plt.xlabel('Khoảng cách vật lý (km)')
plt.ylabel('RTT (ms)')
plt.title('Ảnh hưởng khoảng cách vật lý đến độ trễ')
plt.legend()
plt.grid(True, alpha=0.3)
plt.savefig('rtt_vs_distance.png', dpi=300, bbox_inches='tight')
```

---

## 8. CẤU TRÚC BÁO CÁO

```
1. MỞ ĐẦU
   1.1 Bối cảnh: vì sao cần monitoring hybrid cloud
   1.2 Mục tiêu và câu hỏi nghiên cứu
   1.3 Phạm vi và giới hạn nghiên cứu

2. CƠ SỞ LÝ THUYẾT
   2.1 Mô hình hybrid cloud và đặc thù đường truyền xuyên cloud
   2.2 Các đại lượng hiệu năng mạng
       - Latency (RTT), phân vị p50/p95/p99
       - Jitter và ý nghĩa thực tế
       - Packet loss
       - Throughput
       - Quan hệ giữa khoảng cách vật lý và độ trễ
   2.3 Giới thiệu TICK Stack và vai trò của từng thành phần
   2.4 Tổng quan các công cụ benchmark sử dụng

3. KIẾN TRÚC HỆ THỐNG MONITORING
   3.1 Sơ đồ khối
   3.2 Mô tả thành phần và luồng dữ liệu
   3.3 Thiết kế môi trường thực nghiệm (bảng thông số VM)

4. THIẾT KẾ THỰC NGHIỆM
   4.1 Nguyên tắc phương pháp (kiểm soát biến, lặp lại, điều kiện cố định)
   4.2 Mô tả chi tiết 4 thí nghiệm TN1–TN4
   4.3 Hạn chế về tính công bằng của phép so sánh (burstable VM)
   4.4 Nhật ký thực nghiệm (ngày, giờ, điều kiện, lệnh đã chạy)

5. KẾT QUẢ
   5.1 TN1: Cross-cloud vs Intra-cloud
   5.2 TN2: Ảnh hưởng khoảng cách vật lý
   5.3 TN3: Overhead của agent monitoring
   5.4 TN4: So sánh hiệu năng compute AWS vs Azure
   (Mỗi TN gồm: Giả thuyết → Dữ liệu thô → Biểu đồ → Kết luận)

6. THẢO LUẬN
   6.1 Giải thích cơ chế gây ra độ trễ xuyên cloud
   6.2 Phân tích ảnh hưởng của kiến trúc burstable
   6.3 Đánh giá độ tin cậy của phương pháp đo
   6.4 Hạn chế của nghiên cứu

7. KẾT LUẬN VÀ KHUYẾN NGHỊ
   7.1 Tổng hợp kết quả 4 thí nghiệm
   7.2 Cấu hình monitoring được khuyến nghị
   7.3 Hướng nghiên cứu tiếp

8. TÀI LIỆU THAM KHẢO
   Phụ lục: cấu hình đầy đủ, log benchmark, ảnh chụp màn hình
```

---

## 9. KẾ HOẠCH THỜI GIAN (3 tuần)

### Tuần 1 — Xây dựng hệ thống (20-25 giờ)

| Ngày | Công việc | Giờ |
|---|---|---|
| 1 | Tạo 5 VM trên AWS + Azure, cấu hình Security Group / NSG | 4 |
| 2 | Cài Docker + TICK Stack trên Central, cấu hình InfluxDB/Chronograf | 4 |
| 3 | Cài Telegraf trên 4 VM agent, cấu hình `inputs.ping` + `net_response` | 5 |
| 4 | Cấu hình CloudWatch + Azure Monitor trên Telegraf Central | 4 |
| 5 | Cài đặt công cụ benchmark (sysbench, fio, iperf3, ab, mtr) trên các VM | 3 |
| 6 | Kiểm chứng: dữ liệu đủ vào InfluxDB, dựng dashboard | 4 |

**Cổng cần mở:**
| Cổng | Dịch vụ | Cho phép |
|---|---|---|
| 8086/tcp | InfluxDB | 4 VM agent |
| 8888/tcp | Chronograf | IP của bạn |
| 5201/tcp | iperf3 | 4 VM agent |
| 80/tcp | nginx | IP của bạn, VM nội bộ |
| 9105/udp | ICMP | Security Group cần cho phép ICMP |

> ICMP thường bị chặn mặc định — cần thêm rule cho phép ICMP echo trong Security Group (AWS) và NSG (Azure), nếu không `inputs.ping` sẽ báo 100% loss.

### Tuần 2 — Chạy thực nghiệm (20-25 giờ)

| Ngày | Công việc | Giờ |
|---|---|---|
| 7 | Chạy TN1 — mỗi đường đo ≥30 phút, lặp 3 lần | 5 |
| 8 | Chạy TN2 — thu thập dữ liệu khoảng cách, vẽ biểu đồ regression | 4 |
| 9 | Chạy TN3 — ma trận 5 lần đo × 2 VM × 3 lần lặp | 5 |
| 10 | Chạy TN4 — sysbench + fio trên cả 2 cloud, 3 lần mỗi phép đo | 5 |
| 11 | Tổng hợp dữ liệu vào bảng Excel, kiểm tra tính nhất quán | 4 |
| 12 | Viết phần 1-4 báo cáo (mở đầu, cơ sở lý thuyết, kiến trúc, phương pháp) | 5 |

### Tuần 3 — Phân tích & hoàn thiện (18-22 giờ)

| Ngày | Công việc | Giờ |
|---|---|---|
| 13 | Vẽ biểu đồ bằng matplotlib, chụp ảnh dashboard | 4 |
| 14 | Viết phần 5 — trình bày kết quả 4 TN | 5 |
| 15 | Viết phần 6-7 — thảo luận, kết luận, khuyến nghị | 4 |
| 16 | Rà soát tính nhất quán số liệu giữa bảng, biểu đồ, kết luận | 3 |
| 17 | Làm slide thuyết trình (12-15 slide) | 4 |
| 18 | Chuẩn bị phòng vấn: dự đoán 5-8 câu hỏi thầy có thể hỏi | 2 |

---

## 10. CHECKLIST HOÀN THÀNH

### Hệ thống
- [ ] 5 VM hoạt động ổn định
- [ ] InfluxDB nhận dữ liệu từ đủ 4 VM agent + Telegraf Central
- [ ] `inputs.ping` trả về đủ: RTT, loss, jitter, p50/p95/p99 (kiểm tra bằng `SELECT * FROM ping LIMIT 1`)
- [ ] CloudWatch và Azure Monitor lấy được metrics
- [ ] Dashboard Chronograf có đủ 6 panel
- [ ] iperf3 đo được throughput giữa các cặp VM

### Dữ liệu thực nghiệm
- [ ] TN1: đủ 4 đường đo × 3 lần lặp × ≥30 phút
- [ ] TN2: đủ 4 mức khoảng cách
- [ ] TN3: đủ 5 cấu hình × 2 VM × 3 lần lặp
- [ ] TN4: đủ 7 phép đo × 2 cloud × 3 lần lặp
- [ ] Nhật ký thực nghiệm ghi đủ: thời gian, điều kiện, lệnh chạy
- [ ] Tính trung bình và độ lệch chuẩn cho mọi phép đo

### Báo cáo
- [ ] Sơ đồ kiến trúc rõ ràng, có chú thích luồng dữ liệu
- [ ] Mỗi bảng số liệu có cột đơn vị và nguồn dữ liệu
- [ ] Mỗi thí nghiệm có: giả thuyết → dữ liệu → biểu đồ → kết luận
- [ ] Có phần nói rõ hạn chế về burstable VM
- [ ] Biểu đồ có chú thích, đơn vị trục, nguồn dữ liệu
- [ ] Kết luận trả lời trực tiếp 4 câu hỏi ở mục 1.1
- [ ] Kiểm tra tính nhất quán: số trong bảng = số trong biểu đồ = số trong kết luận

### Slide
- [ ] 12-15 slide
- [ ] Font chữ ≥20pt, biểu đồ đọc được từ hàng cuối
- [ ] Ảnh dashboard chất lượng cao, không bị vỡ pixel
- [ ] Chuẩn bị trả lời: "Tại sao chọn TICK, không chọn Prometheus/Grafana?"

---

## 11. XỬ LÝ SỰ CỐ

**Telegraf không đẩy được dữ liệu lên InfluxDB**
```bash
sudo journalctl -u telegraf -n 50
telnet <CENTRAL-IP> 8086              # kiểm tra kết nối mạng
# Nếu connection refused → kiểm tra Security Group cổng 8086
# Nếu unauthorized → kiểm tra username/password trong outputs.influxdb
```

**`inputs.ping` báo 100% packet loss dù VM vẫn ping được bằng tay**
```bash
# Gần như luôn do ICMP bị chặn ở tầng Security Group
# AWS: thêm rule "Allow ICMP - Echo Request" vào inbound
# Azure: thêm NSG rule cho protocol ICMP
sudo telegraf --config /etc/telegraf/telegraf.conf --test --input-filter ping
```

**`inputs.ping` báo lỗi quyền**
```bash
sudo setcap cap_net_raw+ep /usr/bin/telegraf
sudo systemctl restart telegraf
```

**Dashboard trống / query không trả kết quả**
```bash
docker exec -it influxdb influx
> USE monitoring
> SHOW MEASUREMENTS
> SHOW TAG KEYS FROM "ping"
> SELECT * FROM "ping" LIMIT 5
```

**sysbench báo lỗi khi chạy trên VM nhỏ**
```bash
# Giảm kích thước: --memory-total-size=8G thay vì 32G
# Nếu OOM: giảm --time=60 xuống --time=30
free -h                                    # kiểm tra RAM khả dụng
sudo dmesg | grep -i "killed process"      # kiểm tra OOM killer
```

**Kết quả benchmark không ổn định giữa 3 lần chạy**
```bash
# Kiểm tra CPU credit của AWS instance (ảnh hưởng lớn tới t3)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUCreditBalance \
  --dimensions Name=InstanceId,Value=<INSTANCE-ID> \
  --start-time <START> --end-time <END> --period 300 --statistics Average
# Nếu credit balance thấp → kết quả không đáng tin, phải chạy lại
```

---

## 12. ƯỚC TÍNH CHI PHÍ

| Hạng mục | Spec | Số lượng | Giá/giờ | Giá/tháng (24/7) |
|---|---|---|---|---|
| AWS t3.small (Central) | 2 vCPU, 2 GB | 1 | $0.0216 | ~$15 |
| AWS t3.small (VM-A) | 2 vCPU, 2 GB | 1 | $0.0216 | ~$15 |
| AWS t3.small (VM-C, VM-D) | 2 vCPU, 2 GB | 2 | $0.0216 | ~$31 |
| Azure B2s | 2 vCPU, 4 GB | 1 | $0.0836 | ~$60 |
| Data transfer ra Internet | ~2 GB/tháng | | | ~$0.20 |
| **Tổng nếu chạy 24/7** | | **5 VM** | | **~$121** |

**Kịch bản thực tế của đồ án:** chỉ cần 2 VM agent + Central chạy liên tục, VM-C/VM-D bật khi chạy TN2.

| Kịch bản | Chi phí ước tính |
|---|---|
| 2 agent + Central, chạy 24/7 | ~$40/tháng |
| 2 agent + Central, chạy 8h/ngày | ~$13/tháng |
| Toàn bộ 5 VM, chạy 24/7 trong 1 tuần rồi tắt | ~$30 |

**Lưu ý:** AWS Free Tier và Azure Free Tier (12 tháng đầu, tài khoản mới) có thể giảm chi phí đáng kể. Azure B2s không nằm trong Free Tier — cân nhắc dùng `B1ms` nếu cần tiết kiệm.

---

## 13. TÀI LIỆU THAM KHẢO

**Tài liệu kỹ thuật chính thức**
- Telegraf — plugin `ping`, `net_response`, `http_response`: https://docs.influxdata.com/telegraf/v1/plugins/
- Telegraf — plugin `cloudwatch`, `azure_monitor`: https://docs.influxdata.com/telegraf/v1/plugins/inputs/cloudwatch/
- InfluxDB 1.8 — Query với InfluxQL: https://docs.influxdata.com/influxdb/v1.8/
- Chronograf 1.10 — Dashboard: https://docs.influxdata.com/chronograf/v1/
- sysbench — https://github.com/akopytov/sysbench
- fio — https://fio.readthedocs.io/
- iperf3 — https://software.es.net/iperf/
- Apache Bench — https://httpd.apache.org/docs/2.4/programs/ab.html
- MTR — https://www.tiny-techtips.com/mtr/

**Bài báo và tài liệu học thuật**
- Amazon EC2 — T2/T3 instance burstable performance: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html
- Microsoft Azure — B-series VM: https://learn.microsoft.com/azure/virtual-machines/sizes/b-series
- ITU-T G.114 — One-way transmission time (giới hạn trễ 150 ms trong thoại)
- RFC 6298 — Guidelines for TCP retransmission timer (vì sao loss ảnh hưởng latency mạnh)
- G. Glass, "Network Quality of Service" — các đại lượng và cách đo

**Tài liệu định nghĩa**
- Cloud Infrastructure: tài liệu kiến trúc AWS Well-Architected Framework
- Hybrid Cloud: NIST SP 800-125, "Guidelines for the Security and Availability of Cloud Computing"

---

## 14. THÔNG TIN DỰ ÁN

| | |
|---|---|
| **Học phần** | Đánh giá hiệu năng mạng |
| **Đề tài** | Hybrid Cloud Monitoring Tools |
| **Giảng viên hướng dẫn** | [Họ tên] — [email] |
| **Thành viên nhóm** | [Danh sách] |
| **Bắt đầu** | [Ngày] |
| **Hạn nộp** | [Ngày] |
| **Cập nhật gần nhất** | [Ngày] |
