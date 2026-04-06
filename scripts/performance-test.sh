#!/bin/sh
# OpenWrt 性能测试和验证脚本
# 用于验证所有优化是否生效

echo "=========================================="
echo "OpenWrt Performance Validation Report"
echo "=========================================="
echo ""

# ============================================================
# 系统信息
# ============================================================

echo "==> System Information"
echo "Hostname: $(uname -n)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
echo ""

# ============================================================
# 内存状态
# ============================================================

echo "==> Memory Status"
free -h
echo ""

if [ -d /sys/block/zram0 ]; then
    echo "ZRAM Status:"
    echo "  Algorithm: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')"
    echo "  Total Size: $(( $(cat /sys/block/zram0/disksize) / 1024 / 1024 )) MB"
    echo "  Used: $(( $(cat /sys/block/zram0/mem_used_total 2>/dev/null || echo 0) / 1024 / 1024 )) MB"
    echo ""
fi

# ============================================================
# 网络优化验证
# ============================================================

echo "==> Network Optimizations"

# TCP 拥塞控制
if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
    echo "TCP Congestion Control: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
fi

# 连接跟踪
if [ -f /proc/sys/net/netfilter/nf_conntrack_max ]; then
    CT_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
    CT_COUNT=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
    CT_PERCENT=$((CT_COUNT * 100 / CT_MAX))
    echo "Connection Tracking: $CT_COUNT / $CT_MAX ($CT_PERCENT%)"
fi

# 网络缓冲区
if [ -f /proc/sys/net/core/rmem_max ]; then
    echo "RX Buffer Max: $(( $(cat /proc/sys/net/core/rmem_max) / 1024 / 1024 )) MB"
    echo "TX Buffer Max: $(( $(cat /proc/sys/net/core/wmem_max) / 1024 / 1024 )) MB"
fi

echo ""

# ============================================================
# 硬件加速状态
# ============================================================

echo "==> Hardware Offload Status"

for iface in /sys/class/net/eth*; do
    [ -d "$iface" ] || continue
    ifname=$(basename "$iface")
    
    echo "Interface: $ifname"
    
    if command -v ethtool >/dev/null 2>&1; then
        ethtool -k "$ifname" 2>/dev/null | grep -E "offload|segmentation" | grep ": on" | sed 's/^/  /'
    fi
done

echo ""

# ============================================================
# CPU 状态
# ============================================================

echo "==> CPU Status"

if [ -f /proc/cpuinfo ]; then
    echo "CPU Cores: $(grep -c ^processor /proc/cpuinfo)"
fi

# CPU 频率
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    if [ -f "$cpu" ]; then
        FREQ=$(cat "$cpu")
        CPU_NUM=$(echo "$cpu" | grep -o 'cpu[0-9]*' | grep -o '[0-9]*')
        echo "CPU$CPU_NUM Frequency: $(( FREQ / 1000 )) MHz"
    fi
done

# CPU 调度器
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
fi

echo ""

# ============================================================
# 服务状态
# ============================================================

echo "==> Service Status"

for service in dnsmasq firewall network uhttpd rpcd; do
    if /etc/init.d/$service enabled 2>/dev/null; then
        STATUS="enabled"
    else
        STATUS="disabled"
    fi
    printf "%-15s: %s\n" "$service" "$STATUS"
done

echo ""

# ============================================================
# DNS 性能测试
# ============================================================

echo "==> DNS Performance Test"

if command -v nslookup >/dev/null 2>&1; then
    for domain in www.google.com www.github.com www.cloudflare.com; do
        START=$(date +%s%N)
        nslookup "$domain" 127.0.0.1 >/dev/null 2>&1
        END=$(date +%s%N)
        ELAPSED=$(( (END - START) / 1000000 ))
        printf "%-25s: %d ms\n" "$domain" "$ELAPSED"
    done
fi

echo ""

# ============================================================
# 网络接口统计
# ============================================================

echo "==> Network Interface Statistics"

for iface in /sys/class/net/eth*; do
    [ -d "$iface" ] || continue
    ifname=$(basename "$iface")
    
    RX_BYTES=$(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    TX_BYTES=$(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
    RX_ERRORS=$(cat "$iface/statistics/rx_errors" 2>/dev/null || echo 0)
    TX_ERRORS=$(cat "$iface/statistics/tx_errors" 2>/dev/null || echo 0)
    
    echo "$ifname:"
    echo "  RX: $(( RX_BYTES / 1024 / 1024 )) MB (Errors: $RX_ERRORS)"
    echo "  TX: $(( TX_BYTES / 1024 / 1024 )) MB (Errors: $TX_ERRORS)"
done

echo ""

# ============================================================
# 总结
# ============================================================

echo "=========================================="
echo "Validation Complete"
echo "=========================================="
echo ""
echo "To run network speed test:"
echo "  iperf3 -c <server_ip>"
echo ""
echo "To monitor real-time performance:"
echo "  htop"
echo "  iftop -i eth0"
echo ""
