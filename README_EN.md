# Local Proxy Launcher

A non-official Windows process-scoped proxy launcher for Antigravity.

[简体中文](README.md) · [Offline Chinese guide](docs/使用教程.html) · [Compatibility](COMPATIBILITY.md) · [Security](SECURITY.md)

> v1.0.0-beta.2 is a public pre-release. This maintenance update changes the maintainer identity, links and release metadata only. This is not a universally compatible stable release.

Maintainer: [小路卡 XiaoLuka / XiaoLukaLab](https://github.com/XiaoLukaLab). [Release page](https://github.com/XiaoLukaLab/local-proxy-launcher/releases/tag/v1.0.0-beta.2).

## Why use it?

If browser sign-in works but Antigravity keeps failing to load models or times out during TLS handshakes, a background process may not be using your existing local proxy. This launcher verifies an HTTP/Mixed proxy and starts the installed official client with process-scoped proxy settings.

It does not include the official client, provide VPN access, accounts, quotas or regional eligibility, or bypass service restrictions. It is not affiliated with, endorsed by or sponsored by Google.

## Download and start

[Windows ZIP](https://github.com/XiaoLukaLab/local-proxy-launcher/releases/download/v1.0.0-beta.2/LocalProxyLauncher-v1.0.0-beta.2-Windows.zip) · [Source ZIP](https://github.com/XiaoLukaLab/local-proxy-launcher/releases/download/v1.0.0-beta.2/LocalProxyLauncher-v1.0.0-beta.2-Source.zip) · [SHA256](https://github.com/XiaoLukaLab/local-proxy-launcher/releases/download/v1.0.0-beta.2/SHA256SUMS.txt)

1. Install and sign in to Antigravity yourself, then enable an existing unauthenticated loopback HTTP/Mixed proxy. The intended setup keeps TUN off.
2. Extract the entire Windows ZIP and double-click `01 一键部署.bat`. Wait for an explicit successful deployment message.
3. Wait for client tasks and official updates to finish, exit the old instance normally, then use the desktop `独立代理启动器` shortcut. Verify the model list and an actual reply.

No Codex, coding or additional runtime installation is needed. Administrator access is usually unnecessary. Runtime files are copied to `%LOCALAPPDATA%\LocalProxyLauncher`, so shortcuts survive deletion of the extracted download folder.

## Features and operation

Automatic local proxy and client discovery; HTTPS CONNECT and TLS checks; manual proxy validation; bounded timeouts; Chinese diagnostics; running-instance/update protection; configuration backup; repeatable deployment; fixed-file uninstall.

The launcher uses `ProcessStartInfo` to set `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY` for a new process tree, plus Chromium proxy switches. `ALL_PROXY` is off by default. Loopback communication stays local. Tools spawned by the client may inherit these settings; unrelated running applications do not.

It does not modify global proxy settings, DNS, hosts, registry, certificates, firewall, client binaries, credentials or startup settings. It does not inject code, terminate existing applications or disable TLS verification. Requests are unauthenticated probes to fixed public endpoints; no tokens, cookies, passwords or chat data are collected or uploaded.

## Evidence and limitations

- Real local coverage: Windows 10 x64, non-administrator token, the existing MagicHut proxy, Unicode/space paths, repeat deployment and uninstall/reinstall.
- Historical V1.0.0 runtime checks: 14/14 passed, including simulated cases.
- Historical deployment checks: 6/7 passed. The final manual-proxy retest hit an upstream TLS timeout and correctly refused to save the change.
- Windows 11, other VPNs, ARM64 and end-to-end IPv6 proxying have not been tested on real systems.
- Actual model replies through the new entry point still require final confirmation.
- Upstream TLS timeouts remain possible. A successful HTTP probe does not establish account eligibility or model availability.
- SOCKS-only, remote authenticated and PAC-only proxies are unsupported.
- Unsigned scripts may be blocked by organizational policies or security software. Do not bypass those controls.

See [QA_SUMMARY.json](QA_SUMMARY.json) and [COMPATIBILITY.md](COMPATIBILITY.md). Historical results are not a fresh all-environment certification of this Beta.

## Diagnostics and removal

Use `03 网络故障诊断.bat`; option 2 validates a manually entered local HTTP/Mixed address, while option 3 rediscovers candidates. HTTP 401/403/404 responses prove only that a response arrived, not that a model request succeeded.

Run `04 卸载启动器.bat` to remove owned runtime files and shortcuts. Configuration, diagnostic files and unknown user files are retained. Exit the client normally and use its original official entry point to restore the previous launch behavior.

## License and credits

Licensed under the [MIT License](LICENSE). Use, modification, redistribution and commercial use are permitted under its terms. Preserve the copyright and license notice. The software is provided as is.

Implementation principles were informed by [mujian0086/antigravity-proxy-launcher](https://github.com/mujian0086/antigravity-proxy-launcher). No remote installer, vendor binary, protected logo or repository file is bundled. See [third-party notices](THIRD_PARTY_NOTICES.md), [contributing](CONTRIBUTING.md) and [maintenance](docs/MAINTENANCE.md).
