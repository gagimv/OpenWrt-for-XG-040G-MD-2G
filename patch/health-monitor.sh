#!/bin/sh
# 系统健康监控和自动优化脚本
# 每5分钟运行一次，监控系统状态并自动调优

# ============================================================
# 内存监控与自动释放
# ============================================================

check_memory() {
    local mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    local mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    local mem_percent=$((mem_available * 100 / mem_total))
    
    # 如果可用内存低于20%，触发缓存清理
    if [ "$mem_percent" -lt 20 ]; then
        logger -t health-monitor "Low memory detected: ${mem_percent}% available"
        
        # 清理页面缓存和dentries/inodes
        sync
        echo 3 > /proc/sys/vm/drop_caches
        
        logger -t health-monitor "Cache cleared, memory freed"
    fi
}

# ============================================================
# 连接跟踪表监控
# ============================================================

check_conntrack() {
    if [ -f /proc/sys/net/netfilter/nf_conntrack_count ]; then
        local ct_count=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
        local ct_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
        local ct_percent=$((ct_count * 100 / ct_max))
        
        # 如果连接跟踪表使用超过80%，记录警告
        if [ "$ct_percent" -gt 80 ]; then
            logger -t health-monitor "WARNING: Conntrack table ${ct_percent}% full (${ct_count}/${ct_max})"
            
            # 如果超过90%，清理TIME_WAIT连接
            if [ "$ct_percent" -gt 90 ]; then
                echo 30 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_time_wait
                logger -t health-monitor "Reduced TIME_WAIT timeout to free conntrack entries"
            fi
        fi
    fi
}

# ============================================================
# CPU 温度监控（如果支持）
# ============================================================

check_temperature() {
    local temp_file="/sys/class/thermal/thermal_zone0/temp"
    
    if [ -f "$temp_file" ]; then
        local temp=$(cat "$temp_file")
        local temp_c=$((temp / 1000))
        
        # 如果温度超过80°C，记录警告
        if [ "$temp_c" -gt 80 ]; then
            logger -t health-monitor "WARNING: High CPU temperature: ${temp_c}°C"
        fi
    fi
}

# ============================================================
# 网络接口状态检查
# ============================================================

check_interfaces() {
    for iface in /sys/class/net/eth*; do
        [ -d "$iface" ] || continue
        
        local ifname=$(basename "$iface")
        local operstate=$(cat "$iface/operstate" 2>/dev/null)
        
        # 检查接口是否down
        if [ "$operstate" = "down" ]; then
            logger -t health-monitor "WARNING: Interface $ifname is down"
        fi
        
        # 检查是否有错误包
        local rx_errors=$(cat "$iface/statistics/rx_errors" 2>/dev/null || echo 0)
        local tx_errors=$(cat "$iface/statistics/tx_errors" 2>/dev/null || echo 0)
        
        if [ "$rx_errors" -gt 1000 ] || [ "$tx_errors" -gt 1000 ]; then
            logger -t health-monitor "WARNING: Interface $ifname has errors (RX: $rx_errors, TX: $tx_errors)"
        fi
    done
}

# ============================================================
# DNS 服务检查
# ============================================================

check_dns() {
    # 测试本地DNS是否响应
    if ! nslookup www.google.com 127.0.0.1 >/dev/null 2>&1; then
        logger -t health-monitor "WARNING: Local DNS not responding, restarting dnsmasq"
        /etc/init.d/dnsmasq restart
    fi
}

# ============================================================
# 主循环
# ============================================================

main() {
    logger -t health-monitor "Starting system health check"
    
    check_memory
    check_conntrack
    check_temperature
    check_interfaces
    check_dns
    
    logger -t health-monitor "Health check completed"
}

main
