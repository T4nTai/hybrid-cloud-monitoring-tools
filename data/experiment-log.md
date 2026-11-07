# Experiment Log

## Environment Setup

### Machines
- **on-prem (vm-a)**: Host votantai-Vostro-5568, 4 vCPU, 7.8GB RAM
- **AWS VM-B**: Singapore (ap-southeast-1), t3.small (2 vCPU, 2GB), pending deploy
- **Azure Central**: Hong Kong (eastasia), B2s_v2 (2 vCPU, 4GB), pending deploy

### TICK Stack
- **InfluxDB**: Docker on Azure Central, port 8086, DB `monitoring`
- **Chronograf**: Docker on Azure Central, port 8888
- **Telegraf**: Will deploy on vm-a (host) and vm-b (AWS)

### VPN
- **WireGuard**: 10.200.200.0/24
  - Server: vm-b (10.200.200.1)
  - Client: host (10.200.200.2)

---

## Experiments Status

- [ ] TN1: Network latency & throughput
- [ ] TN2: Geographic distance vs RTT
- [ ] TN3: Telegraf overhead analysis
- [ ] TN4: Compute benchmark (CPU, RAM, I/O)

---

## Next Steps

1. Run `terraform apply` for AWS + Azure
2. Deploy WireGuard + Telegraf
3. Run benchmark script
4. Analyze results
5. Create report

---

**Log Date**: Nov 04, 2026
**Status**: Fresh start
