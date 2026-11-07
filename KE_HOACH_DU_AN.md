# Kế Hoạch Dự Án: Hybrid Cloud Monitoring Lab

## 1. Mục Tiêu & Phạm Vi

### 1.1 Mục Tiêu
Đo đạc hiệu năng mạng và tài nguyên khi triển khai hạ tầng hybrid cloud:
- **On-prem (TP.HCM)**: Host vật lý (4 vCPU i5-7200U, 7.8GB RAM)
- **AWS (Singapore)**: VM-B t3.small
- **Azure (Hong Kong)**: Central VM Standard_B2s_v2

Sử dụng TICK stack (Telegraf, InfluxDB, Chronograf) + WireGuard VPN cho monitoring tập trung.

### 1.2 Thí Nghiệm (TN)
| # | Tên | Mục Đích | Metrics |
|---|---|---|---|
| TN1 | Network Latency & Throughput | Đo RTT/jitter 3 điểm + iperf3 | RTT, loss%, Mbps |
| TN2 | Geographic Distance vs Latency | Hồi quy khoảng cách → RTT | km, ms, R² |
| TN3 | Telegraf Overhead | Ảnh hưởng Telegraf interval lên req/s | req/s, CPU%, NIC |
| TN4 | Compute Benchmark | Hiệu năng CPU, RAM, I/O | IOPS, MiB/s, ev/s |

---

## 2. Hạ Tầng

### 2.1 Topology

```
┌─────────────────────────────────────────────────┐
│ On-Prem TP.HCM (Host votantai-Vostro-5568)      │
│  - IP VPN: 10.200.200.2                         │
│  - Telegraf (host=vm-a) → Azure Central         │
│  - Run benchmarks                               │
└────────────────┬────────────────────────────────┘
                 │ WireGuard VPN 10.200.200.0/24
                 ├──────────────────┬──────────────┐
        ┌────────▼────┐      ┌──────▼──────┐      │
        │ AWS VM-B    │      │ Azure       │      │
        │ Singapore   │      │ Central     │      │
        │ 10.200.200.1│      │ 10.200.200.3│      │
        │ t3.small    │      │ B2s_v2      │      │
        │ Telegraf    │      │ TICK stack  │      │
        │ iperf3 srv  │      │ (IDB+Chrono)│      │
        └─────────────┘      └─────────────┘      │
                 │                   │            │
                 └───────┬───────────┴────────────┘
                    Internet (Public IPs)

TN2 Probes (geo-distributed, ping → Central):
  - Tokyo (ap-northeast-1)
  - Sydney (ap-southeast-2)
  - Virginia (us-east-1)
  - Frankfurt (eu-central-1)
```

### 2.2 Terraform Apply Status
- [ ] AWS VM-B + SG
- [ ] Azure Central + NSG
- [ ] TN2 probes (4 regions)

---

## 3. TICK Stack

### 3.1 InfluxDB (Azure Central)
- **Endpoint**: http://52.175.59.167:8086 (pending new IP after re-apply)
- **Database**: `monitoring`
- **Auth**: admin / `Hybrid2024SecurePass!`
- **Retention**: 30d

### 3.2 Chronograf (Azure Central)
- **URL**: http://52.175.59.167:8888 (pending new IP)

### 3.3 Telegraf Agents
| Host | Interval | Plugins | Status |
|---|---|---|---|
| vm-a (host) | 10s | cpu, mem, disk, net, ping, tcp, http | ⏳ pending setup |
| vm-b (AWS) | 10s | cpu, mem, disk, net, ping, tcp, http | ⏳ pending setup |

---

## 4. Thí Nghiệm Lịch Trình

### 4.1 TN1: Network Latency (Lần 1)
**Mục tiêu**: Đo RTT qua VPN, direct, public Internet

**Các phép đo**:
- P1: vm-a (VPN) → vm-b (VPN) — mtr, ping
- P2: vm-a (VPN) → Azure Central (public) — mtr, ping
- P3: vm-b (public) → Azure Central (public) — mtr, ping
- P4: vm-a (public) → vm-b (public) — ping (không VPN)

**Kết quả**:
| Point | RTT (ms) | Loss % | Notes |
|---|---|---|---|
| P1 (VPN) | — | — | ⏳ pending |
| P2 (to Azure) | — | — | ⏳ pending |
| P3 (AWS-Azure) | — | — | ⏳ pending |
| P4 (public) | — | — | ⏳ pending |

**VPN Overhead** = RTT(P1) − RTT(P4) = ? ms

---

### 4.2 TN2: Distance vs Latency (Lần 1)
**Mục tiêu**: Xác nhận quan hệ tuyến tính: RTT = a×distance + b

**Probe locations** (ping Azure Central 3 vòng):
| Probe | Region | Lat/Lng | Distance (km) | RTT (ms) |
|---|---|---|---|---|
| TP.HCM (VPN) | on-prem | 10.8°N, 106.7°E | ref | ⏳ |
| Hong Kong | HK | 22.3°N, 114.2°E | ~1400 | ⏳ |
| Tokyo | ap-northeast-1 | 35.7°N, 139.7°E | ~2200 | ⏳ |
| Sydney | ap-southeast-2 | -33.9°S, 151.2°E | ~1100 | ⏳ |
| Virginia | us-east-1 | 37.3°N, -78.6°W | ~11000 | ⏳ |
| Frankfurt | eu-central-1 | 50.1°N, 8.7°E | ~8300 | ⏳ |

**Hồi quy**: RTT = a×km + b → R² = ?

---

### 4.3 TN3: Telegraf Overhead (Lần 1)
**Mục tiêu**: Ảnh hưởng Telegraf interval lên nginx throughput

**Setup**: nginx trên vm-a, ab -n 20000 -c 100, 4 mức Telegraf:

| Level | Interval | Requests/s | p99 (ms) | CPU (%) | NIC (KB/s) |
|---|---|---|---|---|---|
| off | — | ⏳ | ⏳ | ⏳ | ⏳ |
| high | 30s | ⏳ | ⏳ | ⏳ | ⏳ |
| mid | 15s | ⏳ | ⏳ | ⏳ | ⏳ |
| low | 5s | ⏳ | ⏳ | ⏳ | ⏳ |

**Kết luận**: Overhead % = (1 − req/s(low) / req/s(off)) × 100

---

### 4.4 TN4: Compute Benchmark (Lần 1)
**Mục tiêu**: So sánh CPU, RAM, I/O hiệu năng 3 nodes

**Benchmarks** (3 lần, lấy mean ± std):

#### CPU (sysbench, 60s)
| Node | 1 thread (ev/s) | 2 thread (ev/s) |
|---|---|---|
| vm-a (host) | ⏳ | ⏳ |
| vm-b (AWS) | ⏳ | ⏳ |
| Azure Central | ⏳ | ⏳ |

#### Memory (sysbench, 1GB)
| Node | Throughput (MiB/s) |
|---|---|
| vm-a | ⏳ |
| vm-b | ⏳ |
| Azure Central | ⏳ |

#### I/O (fio, 1GB)
| Node | randread (IOPS) | randwrite (IOPS) | seqread (MiB/s) |
|---|---|---|---|
| vm-a | ⏳ | ⏳ | ⏳ |
| vm-b | ⏳ | ⏳ | ⏳ |
| Azure Central | ⏳ | ⏳ | ⏳ |

---

## 5. Setup Instructions

### 5.1 Terraform Apply
```bash
cd terraform/aws
terraform apply -auto-approve

cd ../azure
terraform apply -auto-approve

cd ../tn2
terraform apply -auto-approve
```

### 5.2 Setup Agents
```bash
# VM-B AWS
ssh -i terraform/keys/vm-b-aws-key ubuntu@<VM-B-IP> 'bash -s' < scripts/setup/setup-wireguard-server.sh
ssh -i terraform/keys/vm-b-aws-key ubuntu@<VM-B-IP> 'bash -s' < scripts/setup/setup-vm-a.sh

# On-prem (run trên host)
bash scripts/setup/setup-vm-a.sh
```

### 5.3 Verify Connectivity
```bash
# From on-prem:
ping 10.200.200.1  # VM-B via VPN
ping 52.175.59.167 # Azure Central

# Check Telegraf
systemctl status telegraf
```

---

## 6. Benchmarking

### 6.1 Run Script
```bash
# On host (vm-a)
bash scripts/benchmark/run-vm-a-full.sh
```

Outputs: `~/benchmark-results/tn*.txt`

---

## 7. Monitoring & Analysis

### 7.1 Chronograf Dashboard (Pending)
- [ ] Panel 1: RTT trend (3 points)
- [ ] Panel 2: Distance vs Latency scatter
- [ ] Panel 3: Telegraf CPU usage
- [ ] Panel 4: nginx req/s under Telegraf overhead
- [ ] Panel 5: CPU comparison (vm-a/b/Azure)
- [ ] Panel 6: RAM throughput comparison
- [ ] Panel 7: I/O IOPS comparison

### 7.2 Data Export
- [ ] CSV từ InfluxDB
- [ ] Raw log files: data/raw/tn{1-4}*.txt

### 7.3 Report
- [ ] `report/05-ketqua.md`: Results & findings
- [ ] Visualizations (Chronograf screenshots)
- [ ] Regression analysis (TN2)

---

## 8. Cleanup & Conclusion

### 8.1 After Benchmarking
- [ ] Stop iperf3 servers
- [ ] Save logs to data/raw
- [ ] Export InfluxDB data
- [ ] Terminate TN2 probes
- [ ] (Optional) Keep Azure Central for dashboard

### 8.2 Final Checklist
- [ ] All 4 TN complete
- [ ] Report written
- [ ] Terraform destroy (if needed)

---

## Notes & Decisions

- **VPN**: WireGuard 10.200.200.0/24, client on host, server on VM-B
- **Telegraf**: Interval 10s for sampling, count=5 for ping (to keep collection <2s)
- **InfluxDB**: docker-compose on Azure Central, HTTP auth enabled
- **Benchmark tools**: sysbench, fio, iperf3, ab, nginx, mtr

---

**Created**: Nov 04, 2026
**Status**: Ready for fresh start
