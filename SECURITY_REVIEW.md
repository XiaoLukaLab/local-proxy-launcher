# v1.0.0-beta.2 发布安全审查

## 范围与结论

基于本地 V1.0.0 生产脚本建立独立白名单目录；不复制旧 Git 历史、真实配置、网络原始日志、账号数据、私人截图、官方二进制或其他开发项目。名称、版本和安装命名空间变更，核心网络逻辑保持不变。

公开白名单包含 6 个核心 PowerShell 脚本、4 个中文 BAT 入口、离线教程、公开测试与构建脚本、项目文档、原创建图和问题模板。最终文件及 SHA256 由构建清单确定；敏感模式扫描不能证明绝对不存在所有未知泄露方式。

## 代码安全

- HTTP 代理只允许 loopback、明确端口和免认证地址；拒绝远程主机、密码、路径和参数。
- CONNECT 与五个固定公开 Google 根路径用于无凭据探测，不调用账号 Token，不存响应正文；TLS 证书校验开启。
- ProcessStartInfo 只设置新进程的环境；不写系统代理、全局环境、DNS、hosts、注册表、证书、防火墙或启动项。注册表访问仅用于读取当前用户代理。
- 不修改官方二进制，不注入或 Hook，不读取聊天、Cookie、凭据库和 VPN 密钥，不上传诊断数据。
- 不强退客户端或其他软件；超时终止只涉及自己创建的 curl 探测或测试子进程。
- 卸载依赖产品归属标记和固定文件白名单，不递归删除安装根目录，保留配置、日志和未知文件。同名无关快捷方式不覆盖。
- 构建和测试的递归清理限于自己创建的 .tmp GUID 子目录，并核对父目录。
- 执行策略参数仅限本次进程；脚本未签名，不代替来源验证，不绕过组织策略。

## 源码、依赖与品牌

Windows PowerShell、.NET、WScript.Shell、WinForms 和 curl 均调用系统现有组件，不随包分发。官方 Antigravity 客户端和图标不打包；快捷方式只引用使用者已经安装的图标位置。项目使用独立名称和原创中性连接图，Antigravity 仅描述适配对象，不宣称官方关系。

参考 mujian0086/antigravity-proxy-launcher 的进程代理实现原理；已核对其公开 LICENSE 为 MIT。没有复制其仓库文件或执行远程安装脚本。详见 THIRD_PARTY_NOTICES.md。权利人已明确确认本项目原创代码以 MIT 授权，完整条款见 LICENSE。

## Git 与隐私

独立 main 仓库不承接原目录历史。仅使用账号 XiaoLukaLab 的 GitHub noreply 提交邮箱，不使用机器原有私人 Git 邮箱。只按显式公开文件清单暂存，不对原开发目录执行 git add 全部上传。

本次账号更名维护继续保留原有 47 文件白名单；旧公开提交及 beta.1 标签保持历史原样，不强制改写历史。新提交使用更新后的维护者名称及同一账号 ID 对应的 noreply 邮箱。新发布包不包含旧账号名称、个人路径、真实配置或诊断日志。

## 限制

静态审查与模式扫描不是独立渗透测试或法律意见。未签名包不能抵御同用户恶意篡改，不支持并发安装。更新识别与同名 language_server 检测可能保守拦截；CONNECT 响应片段或慢网络可能导致验证失败。偶发 TLS 超时不通过降低安全校验处理。

## 参考来源

- [参考项目许可证](https://github.com/mujian0086/antigravity-proxy-launcher/blob/main/LICENSE) 。
- [PowerShell 执行策略](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1) 。
- [Google 品牌使用指引](https://about.google/brand-resource-center/guidance/) 。
- [GitHub 提交邮箱隐私](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address) 。
