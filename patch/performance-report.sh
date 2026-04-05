#!/bin/sh
# 性能状态检查脚本

echo "=========================================="
echo "  XG-040G-MD 性能状态报告"
echo "=========================================="
echo ""

# 系统信息
echo "【系统信息】"
echo "  主机名: $(cat /proc/sys/kernel/hostname)"
echo "  内核版本: $(uname -r)"
echo "  运行时间: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
echo ""

# 内存状态
echo "【内存状态】"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
FREE_MEM=$(free -m | awk '/^Mem:/{print $4}')
AVAIL_MEM=$(free -m | awk '/^Mem:/{print $7}')
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/{print $3}')

echo "  总内存: ${TOTAL_MEM}MB"
echo "  已使用: ${USED_MEM}MB ($(( USED_MEM * 100 / TOTAL_MEM ))%)"
echo "  可用: ${AVAIL_MEM}MB ($(( AVAIL_MEM * 100 / TOTAL_MEM ))%)"
echo "  Swap总计: ${SWAP_TOTAL}MB"
echo "  Swap使用: ${SWAP_USED}MB"

if [ "$SWAP_TOTAL" -gt 0 ]; then
    echo "  Swap使用率: $(( SWAP_USED * 100 / SWAP_TOTAL ))%"
fi
echo ""

# zram 状态
if [ -f /sys/block/zram0/disksize ]; then
    echo "【zram 状态】"
    ZRAM_SIZE=$(cat /sys/block/zram0/disksize)
    ZRAM_USED=$(cat /sys/block/zram0/mem_used_total 2>/dev/null || echo 0)
    ZRAM_COMP=$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo 0)
    
    echo "  虚拟大小: $(( ZRAM_SIZE / 1024 / 1024 ))MB"
    echo "  实际占用: $(( ZRAM_USED / 1024 / 1024 ))MB"
    echo "  压缩后: $(( ZRAM_COMP / 1024 / 1024 ))MB"
    
    if [ "$ZRAM_COMP" -gt 0 ]; then
        RATIO=$(( ZRAM_USED * 100 / ZRAM_COMP ))
        echo "  压缩比: $(( RATIO / 100 )).$(( RATIO % 100 )):1"
    fi
    echo ""
fi

# CPU 状态
echo "【CPU 状态】"
CPU_COUNT=$(grep -c ^processor /proc/cpuinfo)
echo "  CPU 核心数: $CPU_COUNT"

# 获取CPU使用率（简单方法）
CPU_IDLE=$(top -bn1 | grep "CPU:" | awk '{print $8}' | sed 's/%//')
if [ -n "$CPU_IDLE" ]; then
    CPU_USAGE=$(( 100 - CPU_IDLE ))
    echo "  CPU 使用率: ${CPU_USAGE}%"
fi

# CPU 频率
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
    echo "  CPU 频率: $(( FREQ / 1000 ))MHz"
fi
echo ""

# 网络连接
echo "【网络连接】"
if [ -f /proc/sys/net/netfilter/nf_conntrack_count ]; then
    CONN_COUNT=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
    CONN_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
    echo "  当前连接数: $CONN_COUNT"
    echo "  最大连接数: $CONN_MAX"
    echo "  连接使用率: $(( CONN_COUNT * 100 / CONN_MAX ))%"
else
    echo "  连接跟踪未启用"
fi
echo ""

# TCP 状态
echo "【TCP 连接状态】"
if command -v netstat >/dev/null 2>&1; then
    netstat -ant | awk '{print $6}' | sort | uniq -c | sort -rn | head -5
elif command -v ss >/dev/null 2>&1; then
    ss -ant | awk '{print $1}' | sort | uniq -c | sort -rn | head -5
fi
echo ""

# 网络接口
echo "【网络接口】"
for iface in eth0 eth1 br-lan; do
    if [ -d "/sys/class/net/$iface" ]; then
        RX_BYTES=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        TX_BYTES=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        
        echo "  $iface:"
        echo "    RX: $(( RX_BYTES / 1024 / 1024 ))MB"
        echo "    TX: $(( TX_BYTES / 1024 / 1024 ))MB"
        
        # 链路状态
        if [ -f "/sys/class/net/$iface/carrier" ]; then
            CARRIER=$(cat /sys/class/net/$iface/carrier 2>/dev/null || echo 0)
            if [ "$CARRIER" = "1" ]; then
                echo "    状态: UP"
                
                # 速率
                if [ -f "/sys/class/net/$iface/speed" ]; then
                    SPEED=$(cat /sys/class/net/$iface/speed 2>/dev/null || echo "unknown")
                    [ "$SPEED" != "unknown" ] && echo "    速率: ${SPEED}Mbps"
                fi
            else
                echo "    状态: DOWN"
            fi
        fi
    fi
done
echo ""

# 硬件加速状态
echo "【硬件加速】"
if [ -f /proc/sys/net/netfilter/nf_flowtable_hw_offload ]; then
    HW_OFFLOAD=$(cat /proc/sys/net/netfilter/nf_flowtable_hw_offload)
    if [ "$HW_OFFLOAD" = "1" ]; then
        echo "  Flow offload: 已启用 ✓"
    else
        echo "  Flow offload: 未启用 ✗"
    fi
else
    echo "  Flow offload: 不支持"
fi

# 检查 BBR
if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
    TCP_CC=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
    echo "  TCP 拥塞控制: $TCP_CC"
fi
echo ""

# 存储状态
echo "【存储状态】"
df -h | grep -E "Filesystem|/overlay|/tmp" | awk '{printf "  %-20s %8s %8s %8s %6s\n", $6, $2, $3, $4, $5}'
echo ""

# 进程 TOP 5
echo "【CPU占用 TOP 5】"
ps aux | sort -rn -k 3 | head -6 | tail -5 | awk '{printf "  %-20s %6s%%  %6s%%\n", $11, $3, $4}'
echo ""

# 服务状态
echo "【关键服务状态】"
for service in uhttpd rpcd dnsmasq firewall network; do
    if /etc/init.d/$service enabled 2>/dev/null; then
        STATUS="已启用"
        if pgrep -x $service >/dev/null 2>&1; then
            STATUS="$STATUS, 运行中 ✓"
        else
            STATUS="$STATUS, 未运行 ✗"
        fi
    else
        STATUS="未启用"
    fi
    printf "  %-15s: %s\n" "$service" "$STATUS"
done
echo ""

echo "=========================================="
echo "  报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
