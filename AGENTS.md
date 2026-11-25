# Local Proxy Launcher 发布规范

本目录为从原项目白名单筛选的独立公开发布目录，不继承原工作区 Git 历史。开始先读 ROADMAP.md 和 README.md。

- scripts/ 为当前生产实现，tests/ 为公开测试，tools/ 为本地构建审计。
- docs/、assets/ 仅包含脱敏文档和原创图示，不含官方客户端或品牌资产。
- 不提交配置、日志、账号数据、临时目录、构建产物、认证文件或历史私人资料。
- 只修复发布必要问题，不增加产品功能，不改变全局网络，不强退进程。
- 版本为 1.0.0-beta.1；历史 QA 为 14/14 运行项、6/7 部署项通过，不能扩大为 beta 全环境稳定。
- 许可证、公开名称和公开范围必须由权利人确认；确认前不推送或公开。
- 验证入口：tools/Build-Release.ps1、tools/Verify-Release.ps1、tests/。
