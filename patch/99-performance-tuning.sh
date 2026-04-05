#!/bin/sh
# 2GB RAM Performance Tuning Script
# 在系统启动后自动优化各项性能参数

# 等待系统完全启动
sleep 10

# ============================================================
# 网络接口优化
# ============================================================

# 增加所有网络接口的队列长度
for iface in /sys/class/net/eth*; do
    [ -d "$iface" ] || continue
    ifname=$(basename "$iface")
    
    # 设置TX队列长度
    ip link set "$ifname" txqueuelen 2000
    
    # 启用硬件offload（如果支持）
    ethtool -K "$ifname" gro on 2>/dev/null
    ethtool -K "$ifname" gso on 2>/dev/null
    ethtool -K "$ifname" tso on 2>/dev/null
    ethtool -K "$ifname" rx on 2>/dev/null
    ethtool -K "$ifname" tx on 2>/dev/null
    
    logger -t performance "Optimized interface: $ifname"
done

# ============================================================
# IRQ 亲和性优化（多核负载均衡）
# ============================================================

# 如果是多核CPU，分散网络中断到不同核心
if [ -f /proc/irq/default_smp_affinity ]; then
    echo f > /proc/irq/default_smp_affinity 2>/dev/null
    logger -t performance "IRQ affinity optimized"
fi

# ============================================================
# 文件系统优化
# ============================================================

# 挂载tmpfs到/tmp（如果还没有）
if ! mount | grep -q "tmpfs on /tmp"; then
    mount -t tmpfs -o size=256M,mode=1777 tmpfs /tmp
    logger -t performance "tmpfs mounted on /tmp"
fi

# ============================================================
# CPU 调度器优化
# ============================================================

# 设置CPU调度器为performance（如果可用）
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo performance > "$cpu" 2>/dev/null
done

# ============================================================
# 连接跟踪优化
# ============================================================

# 动态调整conntrack表大小
if [ -f /proc/sys/net/netfilter/nf_conntrack_max ]; then
    # 2GB内存可以支持更多连接
    echo 131072 > /proc/sys/net/netfilter/nf_conntrack_max
    
    # 调整hash表大小
    if [ -f /sys/module/nf_conntrack/parameters/hashsize ]; then
        echo 32768 > /sys/module/nf_conntrack/parameters/hashsize
    fi
    
    logger -t performance "Connection tracking optimized: 131072 max connections"
fi

# ============================================================
# BBR 拥塞控制
# ============================================================

# 确保BBR已加载
if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
    modprobe tcp_bbr 2>/dev/null
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    logger -t performance "TCP BBR enabled"
fi

# ============================================================
# 内存压缩优化
# ============================================================

# 启用透明大页（如果支持）
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    logger -t performance "Transparent hugepage enabled"
fi

# KSM（内核同页合并）- 节省内存
if [ -f /sys/kernel/mm/ksm/run ]; then
    echo 1 > /sys/kernel/mm/ksm/run
    echo 100 > /sys/kernel/mm/ksm/sleep_millisecs
    logger -t performance "KSM enabled"
fi

# ============================================================
# DNS 缓存优化
# ============================================================

# 重启dnsmasq以应用大缓存配置
if [ -f /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart
    logger -t performance "dnsmasq restarted with optimized cache"
fi

# ============================================================
# 日志记录
# ============================================================

logger -t performance "2GB RAM performance tuning completed"
logger -t performance "Total RAM: $(free -m | awk '/^Mem:/{print $2}')MB"
logger -t performance "Available RAM: $(free -m | awk '/^Mem:/{print $7}')MB"
logger -t performance "Swap: $(free -m | awk '/^Swap:/{print $2}')MB"
