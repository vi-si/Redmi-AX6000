地址: **192.168.6.1**<br>
用户名: **root**<br>
密码: **password**


**OpenClash 设置**
```
**插件设置**

✅ 运行模式 Redir-Host（兼容）模式

✅ UDP 流量转发


✅ 路由本机代理
✅ 禁用 QUIC
✅ 绕过服务器地址

✅ 本地 DNS 劫持 使用 Dnsmasq 转发
✅ 禁止 Dnsmasq 缓存 DNS

✅ IPv6 流量代理
✅ IPv6 代理模式 TProxy 模式
✅ UDP 流量转发
✅ 允许解析 IPv6 类型的 DNS 请求

✅ 自动更新 GeoIP Dat 数据库
✅ 自动更新 GeoSite 数据库
✅ 自动更新 大陆白名单


**覆写设置**

Github 地址修改 https://testingcf.jsdelivr.net/

✅ 自定义上游 DNS 服务器

✅ Nameserver-Policy
"geosite:cn,private": 
  - 运营商DNS
  - 119.29.29.29
  - 223.5.5.5

✅ NameServer
  - HTTPS://8.8.8.8/dns-query#⚡️ 国际代理

❌ FallBack

✅ Default-NameServer
  - 运营商DNS
  - 119.29.29.29
  - 223.5.5.5

✅ 启用 TCP 并发
❌ Geodata 数据加载方式 禁用
✅ 启用 GeoIP Dat 版数据库
✅ 启用流量（域名）探测
✅ 探测（嗅探）纯 IP 连接
✅ 自定义流量探测（嗅探）设置

```
**IPV6 设置**
```
✅ 删除 全局网络选项 » IPv6 ULA 前缀

接口 » LAN » 高级设置
✅  委托 IPv6 前缀
   IPv6 分配长度 64

接口 » LAN » DHCP 服务器
✅ RA 服务 服务器模式
❌ DHCPv6 服务 已禁用
❌ 本地 IPV6 DNS 服务器
❌ NDP 代理 已禁用

接口 » LAN » DHCP 服务器 » IPv6 RA 设置
✅ 启用 SLAAC
✅ RA 标记 无

```

**使用TProxy代理所有流量**
  插件设置 开发者选项
```
#!/bin/sh
. /usr/share/openclash/log.sh
. /lib/functions.sh

LOG_OUT "Tip: Start Add Custom Firewall Rules (Optimized)..."

# ========== 配置区 ==========
TPROXY_PORT=7895
MARK=0x162        # 必须和 Clash 配置文件里 proxy-providers 的 mark 一致
MANGLE_CHAIN="CLASH_TPROXY"
LAN_IFACE="br-lan"   # 根据你的实际情况修改，一般是 br-lan
# ============================

# 彻底清理旧规则
delete_old_rules() {
    ip_tables="iptables ip6tables"
    for tbl in $ip_tables; do
        # 删除可能的跳链
        $tbl -t nat -D PREROUTING -j openclash 2>/dev/null
        $tbl -t nat -D OUTPUT -j openclash_output 2>/dev/null
        $tbl -t mangle -D PREROUTING -j "$MANGLE_CHAIN" 2>/dev/null
        $tbl -t mangle -D OUTPUT -j "$MANGLE_CHAIN" 2>/dev/null
        $tbl -t mangle -F "$MANGLE_CHAIN" 2>/dev/null
        $tbl -t mangle -X "$MANGLE_CHAIN" 2>/dev/null
    done

    # 清理 OpenClash 自带的链（可选，防止残留）
    iptables -t nat -F openclash 2>/dev/null
    iptables -t nat -X openclash 2>/dev/null
    iptables -t nat -F openclash_output 2>/dev/null
    iptables -t nat -X openclash_output 2>/dev/null
}

add_tproxy_rules() {
    ip_tables="iptables"
    [ "$(uci get firewall.@defaults[0].ipv6 2>/dev/null)" = "1" ] && ip_tables="iptables ip6tables"

    for tbl in $ip_tables; do
        # 创建自定义链
        $tbl -t mangle -N "$MANGLE_CHAIN" 2>/dev/null

        # 1. 已经打过 mark 的包直接返回（防止 Clash 自身环路）
        $tbl -t mangle -A "$MANGLE_CHAIN" -m mark --mark "$MARK" -j RETURN

        # 2. 本地回环流量直接返回
        $tbl -t mangle -A "$MANGLE_CHAIN" -i lo -j RETURN

        # 3. 来自 LAN 界面但目的是本路由器的流量直接返回（访问 LuCI、SSH 等）
        $tbl -t mangle -A "$MANGLE_CHAIN" -i "$LAN_IFACE" -d 192.168.0.0/16 -j RETURN
        $tbl -t mangle -A "$MANGLE_CHAIN" -i "$LAN_IFACE" -d 172.16.0.0/12 -j RETURN
        $tbl -t mangle -A "$MANGLE_CHAIN" -i "$LAN_IFACE" -d 10.0.0.0/8 -j RETURN

        # 4. ipset 排除中国大陆直连 IP（localnetwork 通常是这个）
        $tbl -t mangle -A "$MANGLE_CHAIN" -m set --match-set localnetwork dst -j RETURN

        # 5. 可选：某些端口走直连（比如 53 可防止某些运营商 DNS 被干扰）
        # $tbl -t mangle -A "$MANGLE_CHAIN" -p udp --dport 53 -j RETURN

        # 6. 剩余流量全部 TPROXY
        $tbl -t mangle -A "$MANGLE_CHAIN" -p tcp -j TPROXY --on-port "$TPROXY_PORT" --tproxy-mark "$MARK"
        $tbl -t mangle -A "$MANGLE_CHAIN" -p udp -j TPROXY --on-port "$TPROXY_PORT" --tproxy-mark "$MARK"

        # 插入跳链（插在第 2 位，留给 OpenClash 的 DNS 劫持规则第一位）
        $tbl -t mangle -I PREROUTING 2 -j "$MANGLE_CHAIN"

        # 路由器自己发出的包也需要走代理（重要！）
        $tbl -t mangle -I OUTPUT 1 -j "$MANGLE_CHAIN"
    done
}

delete_old_rules
add_tproxy_rules

LOG_OUT "Tip: Custom TPROXY Firewall Rules Added Successfully."

exit 0

```
