# Hybrid Cloud Monitoring Tools

**Đánh giá hiệu năng mạng trong Hybrid Cloud (On-Premise + AWS + Azure) sử dụng TICK Stack**

---

## Kiến trúc

```
┌─── ON-PREMISE (KVM on Ubuntu 8GB) ────────────────────┐
│  Host Machine                                          │
│  ├─ KVM Guest: VM-A (2GB RAM, Ubuntu 22.04)           │
│  │  ├─ Telegraf Agent                                 │
│  │  ├─ inputs.ping → AWS VMs                          │
│  │  └─ sysbench/fio/nginx (benchmark workload)        │
│  │                                                     │
│  └─ [VPN to AWS VGW] ────────────────────────┐        │
└───────────────────────────────────────────────┼────────┘
                                                │
              ┌─────────────────────────────────┼────────────┐
              │                                 │            │
    ┌─────────▼────────────────┐    ┌──────────▼─────────┐  │
    │ AZURE (Southeast Asia)   │    │ AWS (Singapore)    │  │
    │ Central VM (B1s)         │    │ VM-B (t3.small)    │  │
    │ ├─ InfluxDB :8086        │◄───┤ Telegraf Agent     │  │
    │ ├─ Chronograf :8888      │    │ ping → VM-A        │  │
    │ └─ Telegraf Central      │    │ (benchmark peer)   │  │
    │    └─ CloudWatch input   │    └────────────────────┘  │
    └──────────────────────────┘                            │
                                           ┌─────────────────┼──┐
                                           │ AWS Tokyo       │  │
                                           │ VM-C (optional) │  │
                                           └─────────────────┼──┘
                                                             │
                                           ┌─────────────────▼──┐
                                           │ AWS US-East        │
                                           │ VM-D (optional)    │
                                           └────────────────────┘
```

### Vai trò các thành phần

| Component | Location | Role | Chi phí/tháng |
|-----------|----------|------|---------------|
| **Central** | Azure Southeast Asia (B1s) | InfluxDB + Chronograf — **neutral observer**, không tham gia benchmark | ~$8-15 |
| **VM-A** | On-Premise (KVM) | Agent + workload được đo (cloud A) | $0 |
| **VM-B** | AWS Singapore (t3.small) | Agent + benchmark peer (cloud B) | ~$15 |
| **VM-C** | AWS Tokyo (t3.micro) | Distance test (~5300 km) | ~$7 (chỉ bật khi cần) |
| **VM-D** | AWS US-East (t3.micro) | Distance test (~15400 km) | ~$7 (chỉ bật khi cần) |

**Tổng chi phí:** ~$23-37/tháng (tùy có bật VM-C/D không)

---

## Mục tiêu 4 thí nghiệm

| Mã | Tên | Câu hỏi nghiên cứu | Kết quả mong đợi |
|----|-----|---------------------|------------------|
| **TN1** | Cross-cloud vs Intra-cloud | On-prem↔AWS chậm hơn AWS↔AWS bao nhiêu? | Đo RTT, loss, jitter giữa các đường |
| **TN2** | Ảnh hưởng khoảng cách | Độ trễ tăng theo khoảng cách vật lý? | Regression RTT vs km, so với lý thuyết |
| **TN3** | Overhead monitoring | Telegraf ảnh hưởng workload bao nhiêu? | Đo +% latency, -% throughput khi bật agent |
| **TN4** | So sánh compute | On-prem (KVM) vs AWS hiệu năng khác nhau? | sysbench, fio: ops/s, IOPS, MB/s |

---

## Hướng dẫn triển khai (Quick Start)

### Bước 1: Triển khai Azure Central (neutral observer)

```bash
cd terraform/azure

# Điền thông tin
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Sửa allowed_ssh_cidrs, azure_region

# Triển khai
terraform init
terraform plan
terraform apply

# Lưu lại PUBLIC IP
export AZURE_CENTRAL_IP=$(terraform output -raw central_public_ip)
echo $AZURE_CENTRAL_IP
echo "export AZURE_CENTRAL_IP=$AZURE_CENTRAL_IP" >> ~/.bashrc
```

### Bước 2: Setup TICK Stack trên Azure Central

```bash
# SSH vào Azure Central
ssh azureuser@$AZURE_CENTRAL_IP

# Chạy script setup
wget https://raw.githubusercontent.com/<repo>/main/scripts/setup/setup-central.sh
chmod +x setup-central.sh
./setup-central.sh

# Đổi password
cd ~/hybrid-cloud-monitoring
nano .env  # Đổi INFLUXDB_PASSWORD

# Khởi động
docker-compose up -d
docker-compose ps
```

Truy cập Chronograf: `http://<AZURE_CENTRAL_IP>:8888`

### Bước 3: Triển khai AWS VMs

```bash
cd terraform/aws

cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Sửa allowed_ssh_cidr, enable_distance_vms

terraform init
terraform plan
terraform apply

# Lưu IPs
export AWS_VMB_IP=$(terraform output -raw vmb_public_ip)
export AWS_VMC_IP=$(terraform output -raw vmc_public_ip)  # nếu enable_distance_vms=true
echo "export AWS_VMB_IP=$AWS_VMB_IP" >> ~/.bashrc
```

### Bước 4: Setup Agent trên AWS VM-B

```bash
ssh ubuntu@$AWS_VMB_IP

# Setup agent
wget https://raw.githubusercontent.com/<repo>/main/scripts/setup/setup-agent.sh
chmod +x setup-agent.sh
./setup-agent.sh

# Configure Telegraf
wget https://raw.githubusercontent.com/<repo>/main/scripts/setup/configure-telegraf.sh
chmod +x configure-telegraf.sh

sudo ./configure-telegraf.sh \
    --hostname vm-b \
    --central-ip $AZURE_CENTRAL_IP \
    --influx-pass <YOUR-PASSWORD> \
    --ping-targets "<ONPREM-VM-A-IP>,$AZURE_CENTRAL_IP" \
    --tcp-target "<ONPREM-VM-A-IP>:80" \
    --http-target "http://<ONPREM-VM-A-IP>/"

sudo systemctl restart telegraf
sudo systemctl enable telegraf
```

### Bước 5: Setup On-Premise (KVM + VM-A)

```bash
# Trên máy Ubuntu 8GB của bạn
cd scripts/setup

# Cài KVM
./install-kvm.sh
# LOG OUT và LOG IN lại

# Tạo VM-A
./create-vm-a.sh
# Đợi 1 phút, lấy IP
virsh domifaddr vm-a

export ONPREM_VMA_IP=<IP-VM-A>

# SSH vào VM-A
ssh ubuntu@$ONPREM_VMA_IP

# Setup agent (giống như AWS VM-B ở trên)
wget ...
./setup-agent.sh
sudo ./configure-telegraf.sh \
    --hostname vm-a \
    --central-ip $AZURE_CENTRAL_IP \
    --influx-pass <YOUR-PASSWORD> \
    --ping-targets "$AWS_VMB_IP,$AZURE_CENTRAL_IP"
```

### Bước 6: Kiểm tra hệ thống

```bash
# Từ bất kỳ máy nào
cd scripts/setup
./check-health.sh $AZURE_CENTRAL_IP <INFLUX-PASSWORD>
```

Nếu tất cả PASS → hệ thống hoạt động!

---

## Cấu trúc thư mục

```
hybrid-cloud-monitoring/
├── terraform/
│   ├── aws/                  # Terraform cho AWS VMs (B/C/D)
│   ├── azure/                # Terraform cho Azure Central
│   └── modules/
│       ├── aws-vm/           # Module EC2 tái sử dụng
│       └── azure-vm/         # Module Azure VM tái sử dụng
├── configs/
│   ├── telegraf-agent.conf           # Template cho VM agent
│   ├── telegraf-central.conf         # Config cho Telegraf Central (CloudWatch)
│   └── variables.env.example         # Biến môi trường
├── docker/
│   ├── docker-compose.yml            # TICK stack (InfluxDB + Chronograf)
│   └── .env.example
├── scripts/
│   ├── setup/
│   │   ├── install-kvm.sh            # Cài KVM trên Ubuntu host
│   │   ├── create-vm-a.sh            # Tạo VM-A guest
│   │   ├── setup-central.sh          # Setup Azure Central
│   │   ├── setup-agent.sh            # Setup agent VM
│   │   ├── configure-telegraf.sh     # Gen config Telegraf
│   │   └── check-health.sh           # Health check toàn hệ thống
│   ├── benchmark/                     # Scripts chạy TN1-TN4 (TODO)
│   ├── analysis/                      # Export data từ InfluxDB (TODO)
│   └── cloud-init/                    # User-data scripts (TODO)
├── analysis/                          # Python scripts vẽ biểu đồ (TODO)
├── dashboard/                         # Chronograf dashboard JSON (TODO)
├── docs/                              # Tài liệu kỹ thuật (TODO)
└── report/                            # Báo cáo tiếng Việt (TODO)
```

---

## Thông số đo được

### Metrics mạng (trọng tâm)

| Chỉ số | Field Telegraf | Đơn vị | Giải thích |
|--------|----------------|--------|------------|
| RTT trung bình | `average_response_ms` | ms | Độ trễ đi-về |
| RTT phân vị | `percentile50/95/99_response_ms` | ms | 95% request < ngưỡng này |
| Packet loss | `percent_packet_loss` | % | Tỷ lệ gói tin mất |
| Jitter | `standard_deviation_ms` | ms | Độ dao động RTT |
| TCP handshake | `net_response.response_time_ms` | ms | Thời gian thiết lập kết nối |
| HTTP response | `http_response.response_time` | ms | Thời gian server xử lý request |

### Metrics hệ thống

- CPU: `cpu.usage_user`, `cpu.usage_system`, `cpu.load1/5/15`
- Memory: `mem.used_percent`
- Disk: `disk.used_percent`, `disk.io_time`
- Network: `net.bytes_sent`, `net.bytes_recv`

---

## Troubleshooting

### InfluxDB không nhận được data

```bash
# Trên agent VM
sudo journalctl -u telegraf -n 50

# Kiểm tra kết nối
telnet $AZURE_CENTRAL_IP 8086

# Kiểm tra Azure NSG rule cho port 8086
```

### inputs.ping báo 100% loss

```bash
# Kiểm tra ICMP rule
# Azure: NSG phải có rule Allow Inbound ICMP
# AWS: Security Group phải có ICMP echo request

# Kiểm tra capability
getcap /usr/bin/telegraf
# Phải có: cap_net_raw+ep

# Nếu thiếu
sudo setcap cap_net_raw+ep /usr/bin/telegraf
sudo systemctl restart telegraf
```

### VM-A (KVM) không lấy được IP

```bash
virsh domifaddr vm-a
# Nếu trống, đợi thêm 1-2 phút

# Hoặc vào console
virsh console vm-a
# Login: ubuntu / (không password, dùng SSH key)
ip a
```

---

## Roadmap (TODO)

- [x] Terraform infrastructure (AWS + Azure + modules)
- [x] Setup scripts (KVM, agents, Central)
- [x] Telegraf configs + health check
- [x] Docker Compose cho TICK stack
- [ ] Scripts benchmark (TN1-TN4)
- [ ] Python analysis scripts (matplotlib)
- [ ] Chronograf dashboard JSON
- [ ] Cập nhật KE_HOACH_DU_AN.md
- [ ] Viết tài liệu kỹ thuật đầy đủ
- [ ] Báo cáo tiếng Việt

---

## Tác giả

- **Nhóm:** group-n531
- **Môn học:** Đánh giá hiệu năng mạng
- **Học kỳ:** 2024-2025

---

## Tài liệu tham khảo

- [InfluxDB 1.8 Docs](https://docs.influxdata.com/influxdb/v1.8/)
- [Telegraf Plugins](https://docs.influxdata.com/telegraf/v1/plugins/)
- [Chronograf Guide](https://docs.influxdata.com/chronograf/v1/)
- [KVM/QEMU Documentation](https://www.linux-kvm.org/)
- [AWS EC2 T3 Burstable Performance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html)

---

**License:** MIT (for educational purposes)
