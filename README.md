地址: **192.168.6.1**<br>
用户名: **root**<br>
密码: **password**


**OpenClash 设置**
```
**插件设置**

✅ 使用 Meta 内核
✅ Redir-Host（TUN-混合）模式【UDP-TUN，TCP-转发】
✅ Mixed（仅 Meta 内核）


✅ 路由本机代理
✅ 禁用 QUIC

✅ 本地 DNS 劫持 使用 Dnsmasq 转发
✅ 禁止 Dnsmasq 缓存 DNS


**覆写设置**

Github 地址修改 https://testingcf.jsdelivr.net/

✅ 自定义上游 DNS 服务器

✅ Nameserver-Policy
"geosite:cn": [运营商DNS]

✅ NameServer
  - https://8.8.8.8/dns-query#⚡️ 国际代理

❌ FallBack

✅ Default-NameServer
 - 运营商DNS
    ✅ 节点域名解析

✅ 启用 TCP 并发
TCP Keep-alive 间隔（s）1800
❌ Geodata 数据加载方式 禁用
✅ 启用 GeoIP Dat 版数据库
✅ 启用流量（域名）探测
✅ 探测（嗅探）纯 IP 连接


exit 0
```
