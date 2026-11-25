# v1.0.0-beta.1 架构说明

BAT → Entry → Deploy / App / Network / Remove → Runtime 共用函数。保留已有 ProcessStartInfo 进程代理、curl / Schannel TLS 核心，改造集中于发现与部署层。

部署先检查系统、客户端、代理，再写当前用户运行目录和两个固定桌面入口。没有服务、自启动、定时任务或内核组件。

## 代理与进程

只接受免认证 loopback HTTP URL，限制 scheme、主机、端口、userinfo、路径、查询和片段；IPv6 地址先标准化。候选顺序为旧配置、系统代理、进程/用户变量、实际监听端口。PAC 不执行，认证值不输出。最多 32 个候选、4 个 CONNECT 通过端口做 TLS 检查。

CONNECT 探测仅连接本机已发现的监听端口，目标为固定公开 Google 主机，不访问本机管理接口或 VPN 配置。预检验证两个核心域名，诊断比较五个域名。HTTP 状态不代替真实模型验收。

新进程设置 HTTP_PROXY、HTTPS_PROXY、NO_PROXY 和 Chromium 代理参数，默认不设置 ALL_PROXY。旧实例不会刷新环境，因此先拦截旧实例和更新过程。日常控制台最小化，失败弹出系统 WinForms 提示，保留早期策略失败的可见恢复路径。

## 状态与路径

安装目录由 Windows Known Folder 确定。文件操作用 LiteralPath，进程参数单独引用，支持中文和空格。

`install-state.json` 记录 productId、version、installed。复制前设 installed=false，成功创建运行文件和入口后才设 true。半完成部署可重试，不显示虚假成功。

`config.json` schemaVersion=1，保存本机代理 URL、客户端路径和两个代理开关，不含账号信息、不打包。重复部署保留字段和有效配置，变更前写入 config.previous.json。

`logs/` 只保存固定事件、时间、退出码、公开域名诊断状态和计时，不保存任意异常全文、响应正文、令牌、Cookie 或聊天，不上传。

## 卸载与限制

卸载校验归属，只移除固定相对文件白名单及仍指向本安装的入口。不递归删除根目录，保留配置、日志和用户未知文件，不终止客户端。

同用户文件不是对恶意本地篡改的安全隔离，包未签名。不要并发部署，应等当前操作结束。对同名 language_server 采用保守检测，可能拦截其他工具；不会强退。客户端自行覆盖环境或更改网络架构的版本需重新验证。
