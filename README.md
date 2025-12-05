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

# This script is called by /etc/init.d/openclash
# Add your custom firewall rules here, they will be added after the end of the OpenClash iptables rules

LOG_OUT "Tip: Start Add Custom Firewall Rules..."

# 删除自带的规则
iptables -t nat -D PREROUTING -p tcp -j openclash
iptables -t nat -D OUTPUT -j openclash_output
iptables -t mangle -D PREROUTING -p udp -j openclash
iptables -t mangle -D OUTPUT -p udp -j openclash_output

# 清理 mangle 表中的自定义链和 PREROUTING 链
iptables -t mangle -F PREROUTING
iptables -t mangle -F clash_tproxy
iptables -t mangle -X clash_tproxy # 删除自定义链

# 重建 clash_tproxy 链
iptables -t mangle -N clash_tproxy

# 排除本地网络流量 (使用 ipset localnetwork)
iptables -t mangle -A clash_tproxy -m set --match-set localnetwork dst -j RETURN

# 非以下端口的流量不会经过内核，可以自己定，比如BT，这些流量方便走FORWARD链能享受到flow offloading
iptables -t mangle -A clash_tproxy -p tcp -m multiport ! --dport 25,53,80,143,443,587,993 -j RETURN
iptables -t mangle -A clash_tproxy -p udp -m multiport ! --dport 25,53,80,143,443,587,993 -j RETURN

# 将所有剩余流量 TPROXY 到 7895 端口并打上标记
iptables -t mangle -A clash_tproxy -p udp -j TPROXY --on-port 7895 --tproxy-mark 0x162
iptables -t mangle -A clash_tproxy -p tcp -j TPROXY --on-port 7895 --tproxy-mark 0x162

# 将 PREROUTING 链的流量引入自定义链
iptables -t mangle -A PREROUTING -j clash_tproxy

# 脚本结束，输出日志提示
LOG_OUT "Tip: Add Custom Firewall Rules Done."

exit 0

```
