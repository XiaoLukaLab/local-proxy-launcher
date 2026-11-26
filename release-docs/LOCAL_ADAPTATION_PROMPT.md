# 供其他用户用 Codex 本地适配的备用 Prompt

请担任我的 Windows 网络排障与 PowerShell 工程师，在当前解压的 Local Proxy Launcher v1.0.0-beta.2 源码目录中执行以下任务。

先读取 AGENTS.md、ROADMAP.md、README.md、docs/ARCHITECTURE.md、docs/MAINTENANCE.md、COMPATIBILITY_MATRIX.md。保留已验证的进程代理逻辑，以最小必要改动适配我的电脑，不重新开发大型客户端，不安装额外未知组件。

任务范围：只读检查 Windows、Antigravity 版本和实际路径、现有代理、相关进程、本地监听与官方更新状态；检测真实 HTTP/Mixed 端口，用正常 TLS 验证和无凭据 GET 比较 accounts.google.com、oauth2.googleapis.com、daily-cloudcode-pa.googleapis.com、cloudcode-pa.googleapis.com、aicode.googleapis.com。不要假定常见端口，不读取密码、Token、Cookie、VPN 密钥或无关私人文件。

不要关闭 VPN 或修改整机 TUN、DNS、hosts、注册表、全局代理、证书、防火墙、杀毒、系统或用户环境变量。必要的整机网络切换必须先解释并征得我同意。不要强退应用，不中断官方更新，不删除客户端、项目、聊天或登录数据，不修改二进制、注入或 Hook，不关闭 TLS 校验，不绕过服务资格。

检查当前用户安装目录 LocalApplicationData 下的 LocalProxyLauncher，以及本工具 config.json。配置只在本地保留，不上传。优先验证已有地址，再检测系统代理和实际监听；必要时让我填写本机 HTTP/Mixed 地址。无法发现可用 HTTP/Mixed 时明确报告，不凭空配置端口。HTTP 401/403/404 仅能说明响应，不能当作权限或模型成功。

适配后验证：中文空格路径、非管理员运行、代理关闭、端口变化、非 CONNECT 服务、未安装客户端、旧实例、更新保护、重复部署、卸载重装、删除解压副本后桌面目标可用、全局网络前后一致。模拟与真实测试必须区分。不要为了测试关闭我的 VPN、卸载客户端或影响正在运行的任务。

真实客户端测试只在我确认空闲并正常退出后，从专属入口重新启动。若存在未发送草稿、正在运行的任务或更新，先保留现场并集中提示我。验收模型列表和至少 5 轮简单回复，条件允许时在独立临时工作目录创建、读取和核对一份无敏感小文件。没有真实 Windows 11 或其他 VPN 环境，不得宣称通过。

交付本地适配结果、必要源码修改、验证证据和中文说明；更新相关项目文档。不得提交、推送、上传 GitHub、公开发布或发送他人消息。打包时按白名单排除个人用户名、绝对路径、配置、日志和账号信息，重新生成文件清单与 SHA256。若授权或名称使用不明确，保留本地交付并列出具体待确认项。
