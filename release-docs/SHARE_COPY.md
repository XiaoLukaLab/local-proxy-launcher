# 分享文案

公开测试版 v1.0.0-beta.2，不宣称全平台或全 VPN 稳定。

## 微信

做了一个 Windows 小工具：Local Proxy Launcher（独立代理启动器），用于让 Antigravity 通过已验证的本机 HTTP/Mixed 代理启动，目标是在 TUN 关闭时使用。中文一键部署、网络诊断和卸载，不需要 Codex，也不修改全局网络。

当前为维护测试版 v1.0.0-beta.2，由小路卡 XiaoLuka（XiaoLukaLab）维护。仅 Windows 10 x64 + 当前 MagicHut 环境有实测；其他 VPN、Windows 11、新入口真实模型回复仍需验证，上游可能 TLS 超时。非 Google 官方工具，不提供 VPN、账号或访问资格。

项目地址：https://github.com/XiaoLukaLab/local-proxy-launcher

## 小红书

标题：Antigravity 总是网络重试？我把独立代理方案整理成了 Windows 小工具

浏览器能登录，后台模型却连不上，可能需要给客户端进程单独配置代理。这个工具先检查本机 HTTP/Mixed 代理和 TLS，再启动客户端；有中文部署、诊断、卸载入口，安装后桌面入口不依赖原解压目录。

先说限制：这是 Beta，Windows 11 和其他 VPN 未实机覆盖，新入口真实回复仍待确认，偶发 TLS 超时未彻底消除。不会修复账号权限、地区资格或模型故障，也不提供 VPN。请先看兼容性再尝试。

#Windows工具 #Antigravity #独立代理 #开源工具
