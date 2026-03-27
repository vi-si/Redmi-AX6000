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
# Tailscale - 100% 可靠版（完全模仿 mihomo / GeoSite 风格）
# ===============================================================
echo "========== Starting Tailscale integration (arm64) =========="

TS_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -oE 'tailscale_[0-9]+\.[0-9]+\.[0-9]+_arm64\.tgz' | head -n1 | sed 's/tailscale_\(.*\)_arm64\.tgz/\1/')

if [ -z "$TS_VERSION" ]; then
    TS_VERSION="1.96.2"
fi

echo "→ Using Tailscale version: ${TS_VERSION}"

cd /tmp
wget -q --show-progress "https://pkgs.tailscale.com/stable/tailscale_${TS_VERSION}_arm64.tgz" -O "tailscale_${TS_VERSION}_arm64.tgz"
tar -xzf "tailscale_${TS_VERSION}_arm64.tgz"
cd "tailscale_${TS_VERSION}_arm64"

if ! command -v upx >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y upx-ucl
fi

echo "→ Compressing with UPX --best --lzma..."
upx --best --lzma tailscale >/dev/null
upx --best --lzma tailscaled >/dev/null

echo "→ Placing Tailscale files (like mihomo style)..."

# === 关键：先创建目录 ===
mkdir -p package/base-files/files/usr/sbin
mkdir -p package/base-files/files/var/lib/tailscale
mkdir -p package/base-files/files/etc/init.d
mkdir -p package/base-files/files/etc/uci-defaults

# === 直接复制（和 mihomo 风格完全一致）===
cp -f tailscale package/base-files/files/usr/sbin/tailscale
cp -f tailscaled package/base-files/files/usr/sbin/tailscaled

chmod +x package/base-files/files/usr/sbin/tailscale
chmod +x package/base-files/files/usr/sbin/tailscaled

echo "→ Binary sizes:"
ls -lh package/base-files/files/usr/sbin/tailscale*

# init.d 服务
cat > package/base-files/files/etc/init.d/tailscale << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1
PROG=/usr/sbin/tailscaled

start_service() {
    mkdir -p /var/lib/tailscale /var/run/tailscale
    procd_open_instance
    procd_set_param command "$PROG" --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock --port=41641
    procd_set_param env GOGC=10
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall tailscaled 2>/dev/null
}
EOF

chmod +x package/base-files/files/etc/init.d/tailscale

# 防火墙配置（uci-defaults）
cat > package/base-files/files/etc/uci-defaults/99-tailscale-firewall << 'UCI_EOF'
#!/bin/sh
echo "Applying Tailscale configuration..."

uci -q batch <<-EOF
    delete network.tailscale
    set network.tailscale=interface
    set network.tailscale.proto='none'
    set network.tailscale.device='tailscale0'
    set network.tailscale.auto='1'
    commit network

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
echo "Tailscale firewall applied."
UCI_EOF

chmod +x package/base-files/files/etc/uci-defaults/99-tailscale-firewall

cd /tmp
rm -rf "tailscale_${TS_VERSION}_arm64"*

echo "========== Tailscale integration completed (v${TS_VERSION}) =========="
