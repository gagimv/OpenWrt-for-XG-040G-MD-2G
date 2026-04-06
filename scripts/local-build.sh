#!/bin/bash
# 本地构建脚本 - 用于测试配置

set -e

REPO_URL="https://github.com/xiangtailiang/openwrt.git"
REPO_BRANCH="xg040gmd-fixes"
CONFIG_FILE="../config/xg-040g-md.config"

echo "==> 克隆 OpenWrt 源码..."
if [ ! -d "openwrt" ]; then
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" openwrt
fi

cd openwrt

echo "==> 更新 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> 安装第三方包..."
cd package
bash ../../scripts/update-packages.sh
cd ..

echo "==> 应用固件定制..."
mkdir -p files/etc/config files/etc/sysctl.d files/etc/init.d
cp -fv ../patch/zram.config files/etc/config/zram
cp -fv ../patch/99-memory-optimization.conf files/etc/sysctl.d/
cp -fv ../patch/rpcd-fix.init files/etc/init.d/rpcd
chmod +x files/etc/init.d/rpcd

echo "==> 复制配置文件..."
cp -fv "$CONFIG_FILE" .config

echo "==> 生成完整配置..."
make defconfig

echo ""
echo "✓ 准备完成！"
echo ""
echo "下一步："
echo "  cd openwrt"
echo "  make menuconfig  # 可选：调整配置"
echo "  make download -j4"
echo "  make -j\$(nproc) V=s"
