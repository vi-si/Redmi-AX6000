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

✅ NameServer
  - https://8.8.8.8/dns-query#⚡️ 国际代理

❌ FallBack

✅ Default-NameServer
  - 运营商DNS

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

LOG_OUT "Tip: Start Add Custom Firewall Rules (Hardcoded CIDR v4/v6)..."

# 定义 Clash TPROXY 监听端口和 Mark 标记
CLASH_PORT=7895
CLASH_MARK=0x162

# --- IPv4 规则 ---
# 删除 OpenClash 可能已添加的默认 IPv4 规则
iptables -t nat -D PREROUTING -p tcp -j openclash 2>/dev/null
iptables -t nat -D OUTPUT -j openclash_output 2>/dev/null
iptables -t mangle -D PREROUTING -p udp -j openclash 2>/dev/null
iptables -t mangle -D OUTPUT -p udp -j openclash_output 2>/dev/null

# 清理并创建自定义的 IPv4 mangle 链
iptables -t mangle -F PREROUTING
iptables -t mangle -F clash_tproxy_v4
iptables -t mangle -N clash_tproxy_v4

# 排除本地网络流量，使其不走代理（根据您的实际网络环境修改）
# 常见的局域网段包括 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12
iptables -t mangle -A clash_tproxy_v4 -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A clash_tproxy_v4 -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A clash_tproxy_v4 -d 10.0.0.0/8 -j RETURN

# 列表中的端口才会继续执行 TPROXY
iptables -t mangle -A clash_tproxy_v4 -p tcp -m multiport ! --dport 21,22,53,80,143,443,587,853,993 -j RETURN
iptables -t mangle -A clash_tproxy_v4 -p udp -m multiport ! --dport 21,22,53,80,143,443,587,853,993 -j RETURN

# 使用 TPROXY 将所有剩余流量转发到 Clash 端口
iptables -t mangle -A clash_tproxy_v4 -p udp -j TPROXY --on-port ${CLASH_PORT} --tproxy-mark ${CLASH_MARK}
iptables -t mangle -A clash_tproxy_v4 -p tcp -j TPROXY --on-port ${CLASH_PORT} --tproxy-mark ${CLASH_MARK}

# 将自定义链加入 PREROUTING
iptables -t mangle -A PREROUTING -j clash_tproxy_v4

# --- IPv6 规则 ---
# 删除 OpenClash 可能已添加的默认 IPv6 规则
ip6tables -t mangle -D PREROUTING -p udp -j openclash 2>/dev/null
ip6tables -t mangle -D OUTPUT -p udp -j openclash_output 2>/dev/null

# 清理并创建自定义的 IPv6 mangle 链
ip6tables -t mangle -F PREROUTING
ip6tables -t mangle -F clash_tproxy_v6
ip6tables -t mangle -N clash_tproxy_v6

# 排除本地网络 IPv6 流量（本地链接 fe80::/10 和回环 ::1/128）
ip6tables -t mangle -A clash_tproxy_v6 -d ::1/128 -j RETURN
ip6tables -t mangle -A clash_tproxy_v6 -d fe80::/10 -j RETURN
# 如果您有特定的 ULA (Unique Local Address) 前缀 (fc00::/7)，也可以添加

# 列表中的端口才会继续执行 TPROXY
ip6tables -t mangle -A clash_tproxy_v6 -p tcp -m multiport ! --dport 21,22,53,80,143,443,587,853,993 -j RETURN
ip6tables -t mangle -A clash_tproxy_v6 -p udp -m multiport ! --dport 21,22,53,80,143,443,587,853,993 -j RETURN

# 使用 TPROXY 将所有剩余 IPv6 流量转发到 Clash 端口
ip6tables -t mangle -A clash_tproxy_v6 -p udp -j TPROXY --on-port ${CLASH_PORT} --tproxy-mark ${CLASH_MARK}
ip6tables -t mangle -A clash_tproxy_v6 -p tcp -j TPROXY --on-port ${CLASH_PORT} --tproxy-mark ${CLASH_MARK}

# 将自定义 IPv6 链加入 PREROUTING
ip6tables -t mangle -A PREROUTING -j clash_tproxy_v6

LOG_OUT "Tip: Add Custom Firewall Rules finished."

exit 0
```
