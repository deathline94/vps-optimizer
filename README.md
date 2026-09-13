# ⚡ VPS Network & Latency Optimizer

<p align="center">
  <img src="https://img.shields.io/badge/OS-Linux%20(Universal)-blue?logo=linux&logoColor=white" alt="Linux" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white" alt="Bash" />
  <img src="https://img.shields.io/badge/Congestion%20Control-BBR%20%2B%20FQ-success" alt="BBR" />
  <img src="https://img.shields.io/badge/Anti--Bufferbloat-Tuned-blueviolet" alt="Anti-Bufferbloat" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" />
  <img src="https://img.shields.io/badge/PRs-Welcome-brightgreen.svg" alt="PRs Welcome" />
</p>

A universal, production-grade Linux kernel tuning and network stack optimization script designed to maximize throughput, eliminate bufferbloat, enable TCP BBR congestion control, and reduce network latency across any Linux VPS.

---

## 🚀 One-Click Quick Execution

Run directly on your Linux VPS as `root`:

```bash
curl -sSL https://raw.githubusercontent.com/deathline94/vps-optimizer/main/optimize.sh | sudo bash
```

*Alternative via process substitution:*
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/vps-optimizer/main/optimize.sh)
```

---

## 🔄 Clean Rollback

To instantly revert all changes back to standard factory Linux defaults:

```bash
curl -sSL https://raw.githubusercontent.com/deathline94/vps-optimizer/main/optimize.sh | sudo bash -s -- --rollback
```

---

## 🛠️ Sysctl Parameters Applied

| Parameter | Optimized Value | Purpose |
| :--- | :--- | :--- |
| `net.ipv4.tcp_congestion_control` | `bbr` | Low-latency congestion control |
| `net.core.default_qdisc` | `fq` | Fair Queuing with packet pacing |
| `net.ipv4.tcp_notsent_lowat` | `16384` (16 KB) | Kills bufferbloat in multiplexed streams |
| `net.ipv4.tcp_fastopen` | `3` | Enables TCP Fast Open for client and server |
| `net.ipv4.tcp_slow_start_after_idle` | `0` | Keeps CWND window warm across idle periods |
| `net.ipv4.tcp_tw_reuse` | `1` | Fast recycling of TIME_WAIT sockets |
| `net.ipv4.tcp_fin_timeout` | `15` | Rapid reclamation of abandoned sockets |
| `net.core.somaxconn` | `8192` | Enlarged connection backlog for heavy loads |
| `net.ipv4.tcp_max_syn_backlog` | `8192` | Protects against SYN bursts and scanning floods |
| `fs.file-max` | `2097152` | Prevents "Too many open files" errors |

---

## 🖥️ Compatibility

- **Supported Distributions:**
  - Ubuntu 20.04 / 22.04 / 24.04 LTS
  - Debian 10 / 11 / 12
  - CentOS 7 / 8 / 9
  - AlmaLinux & Rocky Linux 8 / 9
  - Arch Linux

---

## 🔍 Verification & Health Check

After running the script, verify your server configuration:

```bash
# 1. Verify BBR is active:
sysctl net.ipv4.tcp_congestion_control
# Output should be: net.ipv4.tcp_congestion_control = bbr

# 2. Verify FQ queue discipline:
sysctl net.core.default_qdisc
# Output should be: net.core.default_qdisc = fq

# 3. Verify MSS Clamping rules:
iptables -t mangle -L -n -v | grep TCPMSS
# Output will display: TCPMSS set 1360
```

---

## 🤝 Contributing

Pull requests and issues are welcome! If you have additional kernel optimizations for specific cloud environments, feel free to open a PR.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
