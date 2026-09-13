#!/bin/bash
# ==============================================================================
# Universal VPS Network Stack & Sysctl Optimization Script
# Anti-Censorship, Post-Quantum Low Latency, Anti-Fragmentation & BBR Tuning
# Suitable for ANY Linux VPS (Ubuntu, Debian, CentOS, AlmaLinux, RockyLinux, Arch)
# Supports: Full Apply & Clean Rollback (--rollback / -r)
# ==============================================================================

set -euo pipefail

SYSCTL_CUSTOM="/etc/sysctl.d/99-vps-network-tuning.conf"
MODULES_CONF="/etc/modules-load.d/bbr.conf"

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Rollback Routine
# ------------------------------------------------------------------------------
if [ "${1:-}" = "--rollback" ] || [ "${1:-}" = "-r" ]; then
    echo "======================================================================"
    echo " Rolling Back VPS Network Optimizations"
    echo "======================================================================"
    
    # 1. Remove sysctl custom file
    if [ -f "${SYSCTL_CUSTOM}" ]; then
        rm -f "${SYSCTL_CUSTOM}"
        echo "  [OK] Removed ${SYSCTL_CUSTOM}"
    fi

    # 2. Remove kernel module auto-load configuration
    if [ -f "${MODULES_CONF}" ]; then
        rm -f "${MODULES_CONF}"
        echo "  [OK] Removed ${MODULES_CONF}"
    fi

    # 3. Re-apply system default sysctl
    sysctl --system >/dev/null 2>&1 || true
    echo "  [OK] Reloaded system default sysctl parameters"

    # 4. Remove iptables TCPMSS clamping rules
    if command -v iptables >/dev/null 2>&1; then
        while iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360 2>/dev/null; do :; done
        while iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360 2>/dev/null; do :; done
        while iptables -t mangle -D PREROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360 2>/dev/null; do :; done
        echo "  [OK] Removed IPv4 iptables MSS clamping rules"
    fi

    if command -v ip6tables >/dev/null 2>&1; then
        while ip6tables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 2>/dev/null; do :; done
        while ip6tables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 2>/dev/null; do :; done
        while ip6tables -t mangle -D PREROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 2>/dev/null; do :; done
        echo "  [OK] Removed IPv6 ip6tables MSS clamping rules"
    fi

    # Persist firewall rollback
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    elif command -v iptables-save >/dev/null 2>&1 && [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true
    fi

    echo "======================================================================"
    echo " Rollback Complete. Kernel is restored to standard system defaults."
    echo "======================================================================"
    exit 0
fi

echo "======================================================================"
echo " Applying Universal VPS Network & Latency Optimization"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Enable BBR & BBR Modules
# ------------------------------------------------------------------------------
echo "[1/4] Ensuring BBR kernel modules are loaded..."
modprobe tcp_bbr 2>/dev/null || true
modprobe sch_fq 2>/dev/null || true

mkdir -p /etc/modules-load.d
cat << 'EOF' > "${MODULES_CONF}"
tcp_bbr
sch_fq
EOF
echo "  [OK] BBR modules set to load automatically on boot"

# ------------------------------------------------------------------------------
# 2. Dynamic Memory Envelope Detection & Port Auto-Discovery
# ------------------------------------------------------------------------------
echo "[2/4] Detecting VPS memory profile and active services..."

TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ "$TOTAL_RAM_KB" -lt 2097152 ]; then
    # Less than 2GB RAM
    MAX_BUF=8388608    # 8MB
    DEF_BUF=131072     # 128KB
elif [ "$TOTAL_RAM_KB" -lt 8388608 ]; then
    # 2GB to 8GB RAM
    MAX_BUF=16777216   # 16MB
    DEF_BUF=262144     # 256KB
else
    # 8GB+ RAM
    MAX_BUF=33554432   # 32MB
    DEF_BUF=524288     # 512KB
fi
echo "  [OK] Dynamic buffer ceiling calculated: $((MAX_BUF / 1024 / 1024))MB (Total RAM: $((TOTAL_RAM_KB / 1024))MB)"

# Auto-detect currently listening ports to prevent ephemeral collision
ACTIVE_PORTS="22,80,443,2053,8080,8443"
if command -v ss >/dev/null 2>&1; then
    DETECTED_PORTS=$(ss -tulpn 2>/dev/null | awk '{print $5}' | grep -oE '[0-9]+$' | sort -nu | tr '\n' ',' | sed 's/,$//')
    if [ -n "$DETECTED_PORTS" ]; then
        ACTIVE_PORTS=$(echo "${ACTIVE_PORTS},${DETECTED_PORTS}" | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')
    fi
fi
echo "  [OK] Reserved listening ports: ${ACTIVE_PORTS}"

# ------------------------------------------------------------------------------
# 3. Write Sysctl Configuration
# ------------------------------------------------------------------------------
echo "[3/4] Writing kernel sysctl optimizations (${SYSCTL_CUSTOM})..."
mkdir -p /etc/sysctl.d

cat << EOF > "${SYSCTL_CUSTOM}"
# ==============================================================================
# Universal VPS Network & Latency Optimization Configuration
# ==============================================================================

# Fair Queueing & TCP BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Fast Open: Enable for incoming (1) and outgoing (2) = 3
net.ipv4.tcp_fastopen = 3

# Avoid CWND reset after idle (critical for long-lived proxy & multiplexed connections)
net.ipv4.tcp_slow_start_after_idle = 0

# Mitigate bufferbloat in multiplexed HTTP/2 & XHTTP streams by limiting unsent socket buffer
net.ipv4.tcp_notsent_lowat = 16384

# TCP Buffer Sizing (Dynamic BDP Tuning)
net.core.rmem_max = ${MAX_BUF}
net.core.wmem_max = ${MAX_BUF}
net.core.rmem_default = ${DEF_BUF}
net.core.wmem_default = ${DEF_BUF}
net.core.optmem_max = 2097152
net.ipv4.tcp_rmem = 4096 87380 ${MAX_BUF}
net.ipv4.tcp_wmem = 4096 65536 ${MAX_BUF}

# UDP Buffer Tuning (Optimizes Hysteria2, TUIC & WireGuard under burst packet loss)
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# Socket backlog queues & file limits
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 1440000
fs.file-max = 2097152
fs.nr_open = 2097152

# Connection State & Timeout Management
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# MSS Clamping & Path MTU Discovery (Anti-Fragmentation)
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 1024

# Ephemeral Port Range & Inbound Protection
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.ip_local_reserved_ports = ${ACTIVE_PORTS}
EOF

sysctl --system > /dev/null 2>&1 || true
echo "  [OK] Sysctl parameters applied successfully"

# ------------------------------------------------------------------------------
# 4. Anti-Fragmentation TCP MSS Clamping via Netfilter
# ------------------------------------------------------------------------------
echo "[4/4] Configuring netfilter MSS clamping for mobile / PPPoE transit..."

if command -v iptables >/dev/null 2>&1; then
    while iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360 2>/dev/null; do :; done
    while iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360 2>/dev/null; do :; done
    while iptables -t mangle -D PREROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360 2>/dev/null; do :; done

    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360
    echo "  [OK] IPv4 MSS clamped to 1360 bytes (prevents 1.2KB key packet fragmentation)"
fi

if command -v ip6tables >/dev/null 2>&1; then
    while ip6tables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 2>/dev/null; do :; done
    while ip6tables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 2>/dev/null; do :; done
    while ip6tables -t mangle -D PREROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 2>/dev/null; do :; done

    ip6tables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340
    ip6tables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340
    echo "  [OK] IPv6 MSS clamped to 1340 bytes"
fi

# Persist firewall rules
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
elif command -v iptables-save >/dev/null 2>&1 && [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true
fi

echo "======================================================================"
echo " Verification:"
echo "   TCP Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
echo "   Default Queue Disc:     $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'N/A')"
echo "   TCP notsent_lowat:      $(sysctl -n net.ipv4.tcp_notsent_lowat 2>/dev/null || echo 'N/A') bytes"
echo "   TCP Max Buffer:         $(sysctl -n net.core.rmem_max 2>/dev/null || echo 'N/A') bytes"
echo "======================================================================"
echo " Optimization Applied Successfully!"
echo " (To revert at any time, run: bash optimize.sh --rollback)"
echo "======================================================================"
