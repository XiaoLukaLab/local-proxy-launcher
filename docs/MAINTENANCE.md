# 测试与维护

先读 AGENTS.md 和 ROADMAP.md。使用 Windows PowerShell 5.1；以下仅面向维护者，普通用户无需编写命令。

## 验证入口

1. `tests/Discover.ps1`：列出经过地址过滤的本机候选，不判断模型资格。
2. `tests/Test-Runtime.ps1 -LiveProxy <已验证HTTP地址> -RejectPort <受控405服务端口> -ClosedPort <已关闭测试端口>`：语法、真实 TLS、失败路径、环境继承和配置测试。受控服务只需在本机收到 CONNECT 后返回 HTTP 405，不能使用未知远程服务。
3. `tests/Test-Deployment.ps1 -LiveProxy <已验证HTTP地址>`：在本项目 `.tmp/` 建立带中文和空格的源目录、安装目录、测试桌面。实际复制、卸载和删除的都只是本次任务副本，不碰正式客户端或真实项目。
4. `tests/Snapshot.ps1 -OutputPath <本地临时JSON>`：网络前后快照，仅限本地比较，不得打包。
5. 原生模型回复、TUN、Windows 11 和其他 VPN 必须单独实测。VPN 未开、客户端缺失、更新中测试采用函数替身，不改整机网络或卸载官方客户端。

## 构建与审计

运行 `tools/Build-Release.ps1`，按显式白名单生成两个 ZIP、文件清单及 SHA256。源码包只包含当前生产源码、测试、文档、构建工具，不包含历史个人版脚本、真实配置、日志、快照和临时文件。

构建前确保 PS1 使用 UTF-8 BOM，BAT 使用 ASCII 内容和 CRLF（中文只在文件名），HTML 为 UTF-8 无远程依赖。运行 `tools/Verify-Release.ps1` 重新解压、逐文件校验、扫描泄露模式与缺失文件。源码、教程或截图变更后需重新构建校验。

## 后续维护

- 补 Windows 11 x64、其他 HTTP/Mixed VPN 的实机覆盖。
- 在空闲客户端完成新版入口启动、模型列表、5 轮回复和开发文件任务。
- 跟踪官方进程、日志格式和网络栈变化，不采用关闭 TLS、注入或改二进制方案。
- 名称和 MIT 已获权利人确认。构建工具只生成本地文件，不上传内容；版本发布仍需维护者明确授权。
