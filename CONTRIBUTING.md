# 贡献指南

先阅读 AGENTS.md、ROADMAP.md、README.md、docs/ARCHITECTURE.md 和 docs/MAINTENANCE.md。当前项目进入维护阶段，优先修复可复现问题、补充真实兼容性记录和改正文档，不新增大型 UI、账号、云服务或未知依赖。

- 先提交不含敏感信息的复现描述，再讨论影响较大的实现变化。
- PowerShell 5.1 源码使用 UTF-8 BOM，BAT 保持 CRLF；支持中文和空格路径。
- 维持本机免认证 HTTP/Mixed、正常 TLS 校验和进程环境边界。
- 测试在独立 `.tmp/` 副本与测试桌面中进行，不关整机 VPN，不强退应用，不操作官方凭据或聊天。
- 清楚标注真实、模拟、用户自报和未验证的结果，不把请求状态码当作模型成功。
- 不提交 config.json、日志、令牌、个人路径、原始截图、CLI 授权文件或生成包。
- Pull request 说明问题、范围、验证和剩余限制。未经讨论不更改许可证、安全边界或公开兼容承诺。

本项目采用 MIT License，贡献前请阅读根目录 LICENSE；不要提交无权再分发的代码或素材。
