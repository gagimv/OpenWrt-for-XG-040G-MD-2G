#!/bin/bash
# Apply patches and configurations for XG-040G-MD

set -e

OPENWRT_DIR="${1:-openwrt}"
PATCH_DIR="$(dirname "$0")/../patch"

echo "==> Applying XG-040G-MD patches to $OPENWRT_DIR"

# 1. Check if device tree exists, if not copy it
echo "==> Handling device tree file..."
DTS_TARGET="$OPENWRT_DIR/target/linux/airoha/dts/an7581-bell_xg-040g-md.dts"
if [ ! -f "$DTS_TARGET" ]; then
    # Device tree doesn't exist, copy our version
    echo "Device tree not found in upstream, copying our version..."
    mkdir -p "$(dirname "$DTS_TARGET")"
    cp -fv "$PATCH_DIR/an7581-bell_xg-040g-md.dts" "$DTS_TARGET"
    echo "✓ Device tree added"
else
    # Device tree exists, patch it
    echo "Device tree found, patching memory restriction..."
    sed -i '/linux,usable-memory-range/d' "$DTS_TARGET"
    echo "✓ Device tree patched"
fi

# 2. Check if device makefile has our device, if not add it
echo "==> Handling device makefile..."
MK_TARGET="$OPENWRT_DIR/target/linux/airoha/image/an7581.mk"
if [ -f "$MK_TARGET" ]; then
    if ! grep -q "bell_xg-040g-md" "$MK_TARGET"; then
        echo "Device not found in makefile, appending..."
        cat "$PATCH_DIR/an7581.mk" | grep -A 20 "define Device/bell_xg-040g-md" >> "$MK_TARGET"
        echo "✓ Device added to makefile"
    else
        echo "✓ Device already in makefile"
    fi
else
    echo "⚠ Makefile not found"
fi

# 3. Copy network configuration
echo "==> Copying network configuration..."
NETWORK_TARGET="$OPENWRT_DIR/target/linux/airoha/an7581/base-files/etc/board.d/02_network"
if [ -f "$PATCH_DIR/02_network" ]; then
    mkdir -p "$(dirname "$NETWORK_TARGET")"
    cp -fv "$PATCH_DIR/02_network" "$NETWORK_TARGET"
    chmod +x "$NETWORK_TARGET"
    echo "✓ Network configuration updated"
fi

# 4. Copy zram configuration to firmware files
echo "==> Copying zram configuration..."
ZRAM_TARGET="$OPENWRT_DIR/files/etc/config/zram"
if [ -f "$PATCH_DIR/zram.config" ]; then
    mkdir -p "$(dirname "$ZRAM_TARGET")"
    cp -fv "$PATCH_DIR/zram.config" "$ZRAM_TARGET"
    echo "✓ zram configuration added"
fi

# 5. Copy sysctl optimization
echo "==> Copying sysctl optimization..."
SYSCTL_TARGET="$OPENWRT_DIR/files/etc/sysctl.d/99-memory-optimization.conf"
if [ -f "$PATCH_DIR/99-memory-optimization.conf" ]; then
    mkdir -p "$(dirname "$SYSCTL_TARGET")"
    cp -fv "$PATCH_DIR/99-memory-optimization.conf" "$SYSCTL_TARGET"
    echo "✓ sysctl optimization added"
fi

# 6. Copy LuCI Bad Gateway fix script
echo "==> Copying LuCI fix script..."
FIX_SCRIPT_TARGET="$OPENWRT_DIR/files/usr/bin/fix-luci-gateway"
if [ -f "$PATCH_DIR/fix-luci-gateway.sh" ]; then
    mkdir -p "$(dirname "$FIX_SCRIPT_TARGET")"
    cp -fv "$PATCH_DIR/fix-luci-gateway.sh" "$FIX_SCRIPT_TARGET"
    chmod +x "$FIX_SCRIPT_TARGET"
    echo "✓ LuCI fix script added"
fi

# 7. Copy rpcd init fix
echo "==> Copying rpcd init fix..."
RPCD_INIT_TARGET="$OPENWRT_DIR/files/etc/init.d/rpcd"
if [ -f "$PATCH_DIR/rpcd-fix.init" ]; then
    mkdir -p "$(dirname "$RPCD_INIT_TARGET")"
    cp -fv "$PATCH_DIR/rpcd-fix.init" "$RPCD_INIT_TARGET"
    chmod +x "$RPCD_INIT_TARGET"
    echo "✓ rpcd init fix added"
fi

# 8. Copy performance tuning script
echo "==> Copying performance tuning script..."
PERF_SCRIPT_TARGET="$OPENWRT_DIR/files/etc/init.d/performance-tuning"
if [ -f "$PATCH_DIR/99-performance-tuning.sh" ]; then
    mkdir -p "$(dirname "$PERF_SCRIPT_TARGET")"
    cp -fv "$PATCH_DIR/99-performance-tuning.sh" "$PERF_SCRIPT_TARGET"
    chmod +x "$PERF_SCRIPT_TARGET"
    echo "✓ Performance tuning script added"
fi

# 9. Copy NPU optimization service
echo "==> Copying NPU optimization service..."
NPU_INIT_TARGET="$OPENWRT_DIR/files/etc/init.d/npu-optimization"
if [ -f "$PATCH_DIR/npu-optimization.init" ]; then
    mkdir -p "$(dirname "$NPU_INIT_TARGET")"
    cp -fv "$PATCH_DIR/npu-optimization.init" "$NPU_INIT_TARGET"
    chmod +x "$NPU_INIT_TARGET"
    echo "✓ NPU optimization service added"
fi

# 10. Copy dnsmasq optimization config
echo "==> Copying dnsmasq optimization..."
DNSMASQ_CONF_TARGET="$OPENWRT_DIR/files/etc/dnsmasq.d/99-performance.conf"
if [ -f "$PATCH_DIR/dnsmasq.conf" ]; then
    mkdir -p "$(dirname "$DNSMASQ_CONF_TARGET")"
    cp -fv "$PATCH_DIR/dnsmasq.conf" "$DNSMASQ_CONF_TARGET"
    echo "✓ dnsmasq optimization added"
fi

echo ""
echo "==> Patches applied successfully!"
echo ""
