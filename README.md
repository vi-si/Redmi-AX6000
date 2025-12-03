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
  - HTTPS://8.8.8.8/dns-query#⚡️ 国际代理

❌ FallBack

✅ Default-NameServer
  - 运营商DNS
  ✅ 用于解析直连域名的 IP 地址（仅 Meta 内核）
  ✅ 用于解析节点域名的 IP 地址（仅 Meta 内核）

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
# 引入 OpenClash 的日志记录功能
. /usr/share/openclash/log.sh
# 引入 OpenWrt 的通用函数库
. /lib/functions.sh

# 脚本开始，输出日志提示
LOG_OUT "Tip: Start Add Custom Firewall Rules..."

# 确保删除命令不会因为规则不存在而报错，使用 2>/dev/null 隐藏错误输出，|| true 确保命令失败时脚本继续执行
# 这一步清除了 OpenClash 默认设置的规则，为（可能存在的）自定义 TPROXY 规则让路
iptables -t nat -D PREROUTING -p tcp -j openclash 2>/dev/null || true
iptables -t nat -D OUTPUT -j openclash_output 2>/dev/null || true
iptables -t mangle -D PREROUTING -p udp -j openclash 2>/dev/null || true
iptables -t mangle -D OUTPUT -p udp -j openclash_output 2>/dev/null || true

# --- 自定义 TPROXY 逻辑实现 ---

# 1. 确保自定义链存在并且是空的 (幂等操作：无论执行多少次，结果都一样)
# 使用 -F 清空链，使用 || iptables -t mangle -N clash_tproxy 在链不存在时创建它
iptables -t mangle -F clash_tproxy 2>/dev/null || iptables -t mangle -N clash_tproxy

# 2. 添加必要的本地流量排除 (避免代理内部通信和组播)
# 假设 localnetwork ipset 已经被 OpenClash 主程序创建好了
iptables -t mangle -A clash_tproxy -m set --match-set localnetwork dst -j RETURN
iptables -t mangle -A clash_tproxy -d 224.0.0.0/4 -j RETURN # 排除组播地址

# 3. 端口绕过逻辑 (根据您的需求，此逻辑保持不变，目前被注释掉了)
# 如果取消注释，只有目标端口是 25, 53, 80, 443, 853 的流量才会继续往下走 TPROXY
# iptables -t mangle -A clash_tproxy -p tcp -m multiport ! --dport 25,53,80,443,853 -j RETURN
# iptables -t mangle -A clash_tproxy -p udp -m multiport ! --dport 25,53,80,443,853 -j RETURN

# 4. TPROXY 透明代理重定向和标记
# 将符合条件的 UDP 和 TCP 流量重定向到本地 7895 端口，并打上 0x162 的标记
iptables -t mangle -A clash_tproxy -p udp -j TPROXY --on-port 7895 --tproxy-mark 0x162
iptables -t mangle -A clash_tproxy -p tcp -j TPROXY --on-port 7895 --tproxy-mark 0x162

# 5. 将自定义链挂载到 PREROUTING
# 这一步也保证幂等性，只添加一次：检查链是否存在 (-C)，如果不存在，则追加 (-A)
if ! iptables -t mangle -C PREROUTING -j clash_tproxy >/dev/null 2>&1; then
    iptables -t mangle -A PREROUTING -j clash_tproxy
fi

# 脚本结束，输出日志提示
LOG_OUT "Tip: Add Custom Firewall Rules Done."

exit 0

```
