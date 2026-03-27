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
# Tailscale - 最终修复版（使用 files/ 目录 + 避免 uci 在编译时执行）
# ===============================================================
echo "========== Starting Tailscale integration (arm64) - Final Fixed Version =========="

# 1. 获取最新稳定版本
TS_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -oE 'tailscale_[0-9]+\.[0-9]+\.[0-9]+_arm64\.tgz' | head -n1 | sed 's/tailscale_\(.*\)_arm64\.tgz/\1/')

if [ -z "$TS_VERSION" ]; then
    echo "Warning: Failed to detect latest version, fallback to 1.96.2"
    TS_VERSION="1.96.2"
fi

echo "→ Using Tailscale version: ${TS_VERSION}"

# 2. 下载、解压、UPX 压缩
cd /tmp
wget -q --show-progress "https://pkgs.tailscale.com/stable/tailscale_${TS_VERSION}_arm64.tgz" -O "tailscale_${TS_VERSION}_arm64.tgz"

tar -xzf "tailscale_${TS_VERSION}_arm64.tgz"
cd "tailscale_${TS_VERSION}_arm64"

if ! command -v upx >/dev/null 2>&1; then
    echo "→ Installing upx-ucl..."
    apt-get update -qq && apt-get install -y upx-ucl
fi

echo "→ Compressing binaries with UPX --best --lzma..."
upx --best --lzma tailscale >/dev/null
upx --best --lzma tailscaled >/dev/null

# 3. 复制到 files/ 目录（已验证成功）
echo "→ Copying Tailscale files to files/ directory..."

mkdir -p "${GITHUB_WORKSPACE}/files/usr/sbin"
mkdir -p "${GITHUB_WORKSPACE}/files/var/lib/tailscale"
mkdir -p "${GITHUB_WORKSPACE}/files/etc/init.d"
mkdir -p "${GITHUB_WORKSPACE}/files/etc/uci-defaults"

cp -f tailscale "${GITHUB_WORKSPACE}/files/usr/sbin/tailscale"
cp -f tailscaled "${GITHUB_WORKSPACE}/files/usr/sbin/tailscaled"

chmod +x "${GITHUB_WORKSPACE}/files/usr/sbin/tailscale"
chmod +x "${GITHUB_WORKSPACE}/files/usr/sbin/tailscaled"

echo "→ Binary sizes:"
ls -lh "${GITHUB_WORKSPACE}/files/usr/sbin/tailscale"*

# 4. 创建 init.d 服务脚本
cat > "${GITHUB_WORKSPACE}/files/etc/init.d/tailscale" << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1
PROG=/usr/sbin/tailscaled

start_service() {
    mkdir -p /var/lib/tailscale /var/run/tailscale

    procd_open_instance
    procd_set_param command "$PROG" \
        --state=/var/lib/tailscale/tailscaled.state \
        --socket=/var/run/tailscale/tailscaled.sock \
        --port=41641

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

chmod +x "${GITHUB_WORKSPACE}/files/etc/init.d/tailscale"

# 5. 创建 uci-defaults 脚本（关键修复：不在这里执行 uci，只创建文件）
cat > "${GITHUB_WORKSPACE}/files/etc/uci-defaults/99-tailscale-firewall" << 'UCI_EOF'
#!/bin/sh

echo "Applying Tailscale firewall and network settings..."

# 创建 Tailscale 接口
uci -q batch <<-EOF
    delete network.tailscale
    set network.tailscale=interface
    set network.tailscale.proto='none'
    set network.tailscale.device='tailscale0'
    set network.tailscale.auto='1'
    commit network
EOF

# 创建 Tailscale Zone + 转发规则
uci -q batch <<-EOF
    delete firewall.tailscale_zone
    set firewall.tailscale_zone=zone
    set firewall.tailscale_zone.name='tailscale'
    add_list firewall.tailscale_zone.network='tailscale'
    set firewall.tailscale_zone.input='ACCEPT'
    set firewall.tailscale_zone.output='ACCEPT'
    set firewall.tailscale_zone.forward='ACCEPT'
    set firewall.tailscale_zone.masq='1'
    set firewall.tailscale_zone.mtu_fix='1'
    set firewall.tailscale_zone.enabled='1'

    delete firewall.tailscale_to_lan
    set firewall.tailscale_to_lan=forwarding
    set firewall.tailscale_to_lan.src='tailscale'
    set firewall.tailscale_to_lan.dest='lan'

    delete firewall.lan_to_tailscale
    set firewall.lan_to_tailscale=forwarding
    set firewall.lan_to_tailscale.src='lan'
    set firewall.lan_to_tailscale.dest='tailscale'

    commit firewall
EOF

# 放行 WAN UDP 41641 端口
uci -q batch <<-EOF
    delete firewall.tailscale_wan_port
    set firewall.tailscale_wan_port=rule
    set firewall.tailscale_wan_port.name='Allow-Tailscale-WAN'
    set firewall.tailscale_wan_port.src='wan'
    set firewall.tailscale_wan_port.proto='udp'
    set firewall.tailscale_wan_port.dest_port='41641'
    set firewall.tailscale_wan_port.target='ACCEPT'
    set firewall.tailscale_wan_port.enabled='1'
    commit firewall
EOF

echo "Tailscale firewall and network configuration applied successfully."
UCI_EOF

chmod +x "${GITHUB_WORKSPACE}/files/etc/uci-defaults/99-tailscale-firewall"

# 清理临时文件
cd /tmp
rm -rf "tailscale_${TS_VERSION}_arm64" "tailscale_${TS_VERSION}_arm64.tgz"

echo "========== Tailscale integration completed successfully (v${TS_VERSION}) =========="
