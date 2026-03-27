#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# ---------------------------------------------------------------
## OpenClash
git clone -b v0.46.014-beta --depth=1 https://github.com/vernesong/openclash.git OpenClash
rm -rf feeds/luci/applications/luci-app-openclash
mv OpenClash/luci-app-openclash feeds/luci/applications/luci-app-openclash
# ---------------------------------------------------------------

# ##------------- meta core ---------------------------------
wget https://github.com/MetaCubeX/mihomo/releases/download/v1.19.2/mihomo-linux-arm64-v1.19.2.gz
gzip -d mihomo-linux-arm64-v1.19.2.gz
chmod +x mihomo-linux-arm64-v1.19.2 >/dev/null 2>&1
mkdir -p feeds/luci/applications/luci-app-openclash/root/etc/openclash/core
mv mihomo-linux-arm64-v1.19.2 feeds/luci/applications/luci-app-openclash/root/etc/openclash/core/clash_meta >/dev/null 2>&1
# ##---------------------------------------------------------

# ##-------------- GeoIP 数据库 -----------------------------
curl -sL -m 30 --retry 2 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -o /tmp/GeoIP.dat
mv /tmp/GeoIP.dat feeds/luci/applications/luci-app-openclash/root/etc/openclash/GeoIP.dat >/dev/null 2>&1
# ##---------------------------------------------------------

# ##-------------- GeoSite 数据库 ---------------------------
curl -sL -m 30 --retry 2 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -o /tmp/GeoSite.dat
mv -f /tmp/GeoSite.dat feeds/luci/applications/luci-app-openclash/root/etc/openclash/GeoSite.dat >/dev/null 2>&1
# ##---------------------------------------------------------


# ===============================================================
# Tailscale - 优化版集成（arm64 + UPX + 可靠路径）
# ===============================================================
echo "========== Starting optimized Tailscale integration (arm64) =========="

# 1. 获取最新稳定版本（自动，避免手动更新）
TS_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -oE 'tailscale_[0-9]+\.[0-9]+\.[0-9]+_arm64\.tgz' | head -n1 | sed 's/tailscale_\(.*\)_arm64\.tgz/\1/')

if [ -z "$TS_VERSION" ]; then
    echo "Warning: Failed to detect latest version, fallback to 1.96.2"
    TS_VERSION="1.96.2"
fi

echo "→ Using Tailscale version: ${TS_VERSION}"

# 2. 下载并解压到临时目录
cd /tmp
wget -q --show-progress "https://pkgs.tailscale.com/stable/tailscale_${TS_VERSION}_arm64.tgz" -O "tailscale_${TS_VERSION}_arm64.tgz"

tar -xzf "tailscale_${TS_VERSION}_arm64.tgz"
cd "tailscale_${TS_VERSION}_arm64"

# 3. UPX 强力压缩（大幅减小二进制体积）
if ! command -v upx >/dev/null 2>&1; then
    echo "→ Installing upx-ucl for compression..."
    apt-get update -qq && apt-get install -y upx-ucl
fi

echo "→ Compressing binaries with UPX --best --lzma..."
upx --best --lzma tailscale >/dev/null
upx --best --lzma tailscaled >/dev/null

# 4. 复制到 package/base-files/files/ （最推荐的 Actions-OpenWrt 路径）
mkdir -p "${TOPDIR}/package/base-files/files/usr/sbin"
mkdir -p "${TOPDIR}/package/base-files/files/var/lib/tailscale"

cp -f tailscale "${TOPDIR}/package/base-files/files/usr/sbin/tailscale"
cp -f tailscaled "${TOPDIR}/package/base-files/files/usr/sbin/tailscaled"

chmod +x "${TOPDIR}/package/base-files/files/usr/sbin/tailscale"
chmod +x "${TOPDIR}/package/base-files/files/usr/sbin/tailscaled"

echo "→ Binaries placed in package/base-files/files/usr/sbin/"

# 5. 创建优化后的 init.d 服务脚本
mkdir -p "${TOPDIR}/package/base-files/files/etc/init.d"

cat > "${TOPDIR}/package/base-files/files/etc/init.d/tailscale" << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1
PROG=/usr/sbin/tailscaled

start_service() {
    # 确保状态文件和 socket 目录存在（持久化认证信息）
    mkdir -p /var/lib/tailscale
    mkdir -p /var/run/tailscale

    procd_open_instance
    procd_set_param command "$PROG" \
        --state=/var/lib/tailscale/tailscaled.state \
        --socket=/var/run/tailscale/tailscaled.sock \
        --port=41641

    # 内存优化（适合路由器）
    procd_set_param env GOGC=10

    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall tailscaled 2>/dev/null
}

service_triggers() {
    procd_add_reload_trigger "tailscale"
}
EOF

chmod +x "${TOPDIR}/package/base-files/files/etc/init.d/tailscale"

echo "→ Init script created with persistent state and memory optimization"

# 清理临时文件
cd /tmp
rm -rf "tailscale_${TS_VERSION}_arm64" "tailscale_${TS_VERSION}_arm64.tgz"

echo "========== Tailscale integration completed successfully (v${TS_VERSION}) =========="

#
