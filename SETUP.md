# Hybrid Cloud Monitoring — Setup Guide

Hướng dẫn triển khai sau khi clone repository về máy on-premise.

## 📋 Prerequisites

### Software Requirements
- **Terraform** >= 1.0
- **AWS CLI** (configured with credentials)
- **Azure CLI** (logged in with `az login`)
- **Git**
- **SSH key pair** at `~/.ssh/id_rsa` (or custom path)

### Cloud Accounts
- **AWS account** with IAM user credentials
- **Azure subscription** (Azure for Students hoặc Pay-As-You-Go)
- **Resource Group** `NT531` already created in Azure

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <YOUR_REPO_URL> hybrid-cloud-monitoring
cd hybrid-cloud-monitoring
```

### 2. Configure Terraform

#### AWS (VM-B Singapore)
```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Fill in:
- `ssh_key_name`: Your AWS key pair name
- `allowed_ssh_cidr`: Your public IP (get from `curl ifconfig.me`)

#### Azure (Central VM Tokyo)
```bash
cd terraform/azure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Fill in:
- `allowed_ssh_cidrs`: Your public IP

### 3. Deploy Infrastructure

#### Deploy Azure Central first
```bash
cd terraform/azure
terraform init
terraform plan
terraform apply
```

**Save outputs:**
- `central_public_ip`: Azure Central IP (e.g., 20.222.98.235)
- `influxdb_url`: http://<IP>:8086
- `chronograf_url`: http://<IP>:8888

#### Deploy AWS VM-B
```bash
cd terraform/aws
terraform init
terraform plan
terraform apply
```

### 4. Setup TICK Stack on Azure Central

```bash
# SSH into Azure Central
ssh azureuser@<AZURE_CENTRAL_IP>

# Upload docker files (from local machine)
scp -r docker/ azureuser@<AZURE_CENTRAL_IP>:~/docker

# Upload setup script
scp scripts/setup/setup-central.sh azureuser@<AZURE_CENTRAL_IP>:~/

# Run setup (on Azure Central)
bash setup-central.sh

# Create .env file
cd docker
cp .env.example .env
nano .env  # Set INFLUXDB_PASSWORD

# Start TICK stack
docker-compose up -d

# Verify
docker-compose ps
docker exec influxdb influx -username admin -password <YOUR_PASSWORD> -execute "SHOW DATABASES"
```

### 5. Configure Telegraf on AWS VM-B

```bash
# Upload scripts (from local machine)
scp scripts/setup/setup-agent.sh ubuntu@<AWS_VM_B_IP>:~/
scp scripts/setup/configure-telegraf.sh ubuntu@<AWS_VM_B_IP>:~/

# SSH into VM-B
ssh ubuntu@<AWS_VM_B_IP>

# Install Telegraf + benchmark tools
bash setup-agent.sh

# Configure Telegraf
sudo bash configure-telegraf.sh \
  --hostname vm-b \
  --central-ip <AZURE_CENTRAL_IP> \
  --influx-pass "<YOUR_INFLUXDB_PASSWORD>" \
  --ping-targets "<AZURE_CENTRAL_IP>,8.8.8.8,1.1.1.1" \
  --interval "10s"

# Start Telegraf
sudo systemctl restart telegraf
sudo systemctl enable telegraf
sudo systemctl status telegraf
```

### 6. Verify Metrics Pipeline

```bash
# On Azure Central
docker exec influxdb influx -username admin -password <PASSWORD> -database monitoring -execute "SHOW MEASUREMENTS"

# Should see: cpu, disk, mem, net, ping, system

# Check ping data
docker exec influxdb influx -username admin -password <PASSWORD> -database monitoring -execute "SELECT url, average_response_ms FROM ping LIMIT 10"
```

### 7. Access Chronograf Dashboard

Open browser: `http://<AZURE_CENTRAL_IP>:8888`

1. Login with InfluxDB credentials (admin / <YOUR_PASSWORD>)
2. Navigate to **Dashboards**
3. Open **"Network Monitoring - Ping"**
4. View latency graphs for:
   - 8.8.8.8 (~1ms)
   - 1.1.1.1 (~1.25ms)
   - Azure Central (~68ms Singapore→Tokyo)

## 📊 Architecture

```
┌──────────────────┐         ┌──────────────────┐
│  AWS VM-B        │         │  On-Premise VM-A │
│  Singapore       │◄───────►│  (to be deployed)│
│  47.131.178.196  │  iperf3 │                  │
│                  │         │                  │
│  - Telegraf      │         │  - Telegraf      │
│  - Benchmark     │         │  - Benchmark     │
└────────┬─────────┘         └────────┬─────────┘
         │ metrics                    │ metrics
         │ every 10s                  │ every 10s
         │                            │
         └────────────┬───────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │  Azure Central VM      │
         │  Tokyo (japaneast)     │
         │  20.222.98.235         │
         │                        │
         │  - InfluxDB 1.8        │
         │  - Chronograf 1.10     │
         │  - Docker Compose      │
         └────────────────────────┘
```

## 🛠️ Troubleshooting

### Telegraf không start
```bash
# Check config
telegraf --config /etc/telegraf/telegraf.conf --test

# Check logs
sudo journalctl -u telegraf -f
```

### InfluxDB connection failed
```bash
# Verify InfluxDB running
docker ps | grep influxdb

# Test connection
curl -I http://localhost:8086/ping
```

### No data in Chronograf
1. Verify InfluxDB has data: `SELECT COUNT(*) FROM ping`
2. Check Chronograf connections: Chronograf UI → Configuration → Connections
3. Verify time range in dashboard (default: last 1 hour)

## 📚 Next Steps

1. **Deploy VM-A on-premise** using KVM/libvirt
2. **Run benchmarks** between VM-A ↔ VM-B
3. **Create additional dashboards** for CPU, memory, disk metrics
4. **Setup alerts** in Chronograf for latency thresholds

## 📝 Important Files

- `terraform/aws/terraform.tfvars` — AWS config (gitignored)
- `terraform/azure/terraform.tfvars` — Azure config (gitignored)
- `docker/.env` — InfluxDB password (gitignored)
- Scripts errors fixed:
  - ✅ Telegraf install from .deb (GPG key expired)
  - ✅ Removed unsupported `percentile` field
  - ✅ Fixed `mountpoints` → `mount_points`

## 🔐 Security Notes

- Never commit `*.tfvars` or `.env` files
- Change default passwords in production
- Restrict `allowed_ssh_cidrs` to your IP only
- Use Azure Policy to restrict allowed regions

## 📧 Contact

Project: NT531 - Hybrid Cloud Monitoring
Owner: 23521383@ms.uit.edu.vn
