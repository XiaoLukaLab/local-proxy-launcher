$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$script:ProductId = 'LocalProxyLauncher'
$script:Version = '1.0.0-beta.2'
$script:SourceRoot = Split-Path $PSScriptRoot -Parent
$script:ProxyNames = @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')

function Get-InstallRoot {
    return (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'LocalProxyLauncher')
}

function ConvertTo-LocalProxy {
    param([string]$Address)
    if ([string]::IsNullOrWhiteSpace($Address)) { throw '没有填写本地代理地址。' }
    $text = $Address.Trim()
    if ($text -notmatch '^[a-z]+://') { $text = 'http://' + $text }
    $u = $null
    if (-not [Uri]::TryCreate($text,[UriKind]::Absolute,[ref]$u) -or $u.Scheme -ne 'http' -or $u.UserInfo -or $u.Query -or $u.Fragment -or $u.AbsolutePath -ne '/') {
        throw '请填写免认证的本机 HTTP/Mixed 代理，例如 127.0.0.1:7890；不能包含密码、路径或参数。'
    }
    $hostText = $u.DnsSafeHost.Trim('[',']').ToLowerInvariant()
    $parsedAddress=$null
    if([Net.IPAddress]::TryParse($hostText,[ref]$parsedAddress)){$hostText=$parsedAddress.ToString()}
    if ($hostText -notin @('127.0.0.1','localhost','::1') -or $u.Port -lt 1 -or $u.Port -gt 65535 -or $text -notmatch ':\d{1,5}/?$') {
        throw '只支持 localhost、127.0.0.1 或 [::1] 的本地代理，必须明确填写 1 至 65535 的端口。'
    }
    $hostPart = if ($hostText -eq '::1') { '[::1]' } else { $hostText }
    return ('http://' + $hostPart + ':' + $u.Port)
}

function Read-Config {
    param([string]$Root = (Get-InstallRoot))
    $file = Join-Path $Root 'config.json'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    $c = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    $url = ConvertTo-LocalProxy ([string]$c.proxyUrl)
    if ($c.schemaVersion -ne 1 -or $c.useChromiumProxy -isnot [bool] -or $c.useAllProxy -isnot [bool]) { throw '配置格式不受支持，请运行一键部署重新检测。' }
    if ($c.executablePath -and ([string]$c.executablePath).Contains('"')) { throw '客户端路径不能包含引号。' }
    $c.proxyUrl = $url
    return $c
}

function Save-Config {
    param([string]$Root, $Config)
    [void](ConvertTo-LocalProxy $Config.proxyUrl)
    $target = Join-Path $Root 'config.json'
    $json = $Config | ConvertTo-Json -Depth 4
    if (Test-Path -LiteralPath $target) {
        $old = Get-Content -LiteralPath $target -Raw -Encoding UTF8
        if ($old.Trim() -eq $json.Trim()) { return }
        Copy-Item -LiteralPath $target -Destination (Join-Path $Root 'config.previous.json') -Force
    }
    $tempDir = Join-Path $Root '.tmp'
    [void](New-Item -ItemType Directory -Path $tempDir -Force)
    $tempFile = Join-Path $tempDir ([guid]::NewGuid().ToString('N') + '.json')
    try {
        $json | Set-Content -LiteralPath $tempFile -Encoding UTF8
        Move-Item -LiteralPath $tempFile -Destination $target -Force
    } finally { if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile } }
}

function Find-Antigravity {
    param([string]$PreferredPath)
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    if ($PreferredPath) { $candidates.Add($PreferredPath.Trim().Trim('"')) }
    $local = [Environment]::GetFolderPath('LocalApplicationData')
    $candidates.Add((Join-Path $local 'Programs\antigravity\Antigravity.exe'))
    foreach ($base in @([Environment]::GetFolderPath('ProgramFiles'),[Environment]::GetFolderPath('ProgramFilesX86'))) {
        if ($base) { $candidates.Add((Join-Path $base 'Antigravity\Antigravity.exe')) }
    }
    $running = @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue)
    foreach ($p in $running) { try { if ($p.Path) { $candidates.Add($p.Path) } } catch {} }
    # Read only existing product shortcuts. Do not enumerate user documents or read account data.
    $shell = New-Object -ComObject WScript.Shell
    foreach ($base in @([Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('StartMenu'),[Environment]::GetFolderPath('CommonStartMenu'))) {
        foreach ($relative in @('Antigravity.lnk','Programs\Antigravity.lnk','Programs\Antigravity\Antigravity.lnk')) {
            $link = Join-Path $base $relative
            if (Test-Path -LiteralPath $link) { $target=$shell.CreateShortcut($link).TargetPath; if ($target) { $candidates.Add($target) } }
        }
    }
    foreach ($p in $candidates) {
        if ($p.Contains('"')) { continue }
        if ([IO.Path]::GetFileName($p) -ieq 'Antigravity.exe' -and (Test-Path -LiteralPath $p -PathType Leaf)) { return (Get-Item -LiteralPath $p).FullName }
    }
    throw '未找到 Antigravity 官方客户端。请先安装客户端；自定义位置可在部署时填写 Antigravity.exe 的完整路径。本工具不包含客户端。'
}

function Get-ProxyCandidates {
    param([string]$Preferred)
    $raw = New-Object 'System.Collections.Generic.List[string]'
    if ($Preferred) { $raw.Add($Preferred) }
    $s = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($s.ProxyEnable -eq 1 -and $s.ProxyServer) {
        foreach ($piece in ([string]$s.ProxyServer -split ';')) {
            if ($piece -match '^(https?|socks)=([^;]+)$') { $raw.Add($Matches[2]) }
            elseif ($piece -notmatch '=') { $raw.Add($piece) }
        }
    }
    foreach ($scope in @('Process','User')) {
        foreach ($name in @('HTTPS_PROXY','HTTP_PROXY','ALL_PROXY')) {
            $value=[Environment]::GetEnvironmentVariable($name,$scope)
            if ($value) { $raw.Add($value) }
        }
    }
    try {
        $ports = @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object { $_.LocalAddress -in @('127.0.0.1','::1','0.0.0.0','::') -and $_.OwningProcess -ne 4 -and $_.LocalPort -ge 1024 } | Sort-Object LocalPort -Unique)
        foreach ($p in $ports) { $hostPart=if($p.LocalAddress -in @('::1','::')){'[::1]'}else{'127.0.0.1'}; $raw.Add(('http://' + $hostPart + ':' + $p.LocalPort)) }
    } catch { Write-Host '无法枚举监听端口，将继续使用已知代理或手动输入。' }
    $seen=@{}
    $result=@()
    foreach ($address in $raw) {
        try { $url=ConvertTo-LocalProxy $address; if(-not $seen.ContainsKey($url)){$seen[$url]=$true;$result+=$url} } catch {}
        if ($result.Count -ge 32) { break }
    }
    return $result
}

function Test-ConnectProtocol {
    param([string]$ProxyUrl)
    $url=ConvertTo-LocalProxy $ProxyUrl
    $u=[Uri]$url
    $client=New-Object Net.Sockets.TcpClient
    try {
        $task=$client.ConnectAsync($u.DnsSafeHost.Trim('[',']'),$u.Port)
        if(-not $task.Wait(1000)){return [pscustomobject]@{Ok=$false;Code=0;Reason='本地端口连接超时。'}}
        $stream=$client.GetStream();$stream.ReadTimeout=1200;$stream.WriteTimeout=1200
        $bytes=[Text.Encoding]::ASCII.GetBytes("CONNECT oauth2.googleapis.com:443 HTTP/1.1`r`nHost: oauth2.googleapis.com:443`r`n`r`n")
        $stream.Write($bytes,0,$bytes.Length)
        $buffer=New-Object byte[] 1024
        $count=$stream.Read($buffer,0,$buffer.Length)
        $line=([Text.Encoding]::ASCII.GetString($buffer,0,$count) -split "`r?`n")[0]
        $code=0;if($line -match '^HTTP/1\.[01] (\d{3})(?: |$)'){$code=[int]$Matches[1]}
        $reason=if($code -eq 200){'支持 HTTPS CONNECT。'}elseif($code -eq 407){'代理要求认证，本版不保存凭据，不能使用。'}else{'端口未返回成功的 HTTP CONNECT；可能是 SOCKS-only、管理端口或其他服务。'}
        return [pscustomobject]@{Ok=($code -eq 200);Code=$code;Reason=$reason}
    } catch { return [pscustomobject]@{Ok=$false;Code=0;Reason='本地代理连接失败、关闭或未响应 CONNECT。'} }
    finally { $client.Dispose() }
}

function Test-HttpsEndpoint {
    param([string]$HostName,[string]$ProxyUrl='')
    if($HostName -notin @('accounts.google.com','oauth2.googleapis.com','daily-cloudcode-pa.googleapis.com','cloudcode-pa.googleapis.com','aicode.googleapis.com')){throw '诊断域名不在固定公开服务列表中。'}
    if($ProxyUrl){$ProxyUrl=ConvertTo-LocalProxy $ProxyUrl}
    $curl=Join-Path ([Environment]::GetFolderPath('System')) 'curl.exe'
    if(-not(Test-Path -LiteralPath $curl)){throw '未找到 Windows 自带 curl.exe。请更新 Windows；不会自动下载安装组件。'}
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$curl;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
    $psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $proxyArg=if($ProxyUrl){$ProxyUrl}else{'""'};$bypass=if($ProxyUrl){'""'}else{'*'}
    $format='status=%{http_code};connect=%{http_connect};dns=%{time_namelookup};tcp=%{time_connect};tls=%{time_appconnect};total=%{time_total};verify=%{ssl_verify_result}'
    $psi.Arguments='--disable --silent --show-error --output NUL --connect-timeout 6 --max-time 12 --proxy '+$proxyArg+' --noproxy '+$bypass+' --write-out "'+$format+'" "https://'+$HostName+'/"'
    foreach($name in $script:ProxyNames){[void]$psi.EnvironmentVariables.Remove($name)}
    $p=New-Object Diagnostics.Process;$p.StartInfo=$psi
    try {
        [void]$p.Start();$outTask=$p.StandardOutput.ReadToEndAsync();$errTask=$p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit(15000)){$p.Kill();$p.WaitForExit();return [pscustomobject]@{HostName=$HostName;Mode=$(if($ProxyUrl){'Proxy'}else{'Direct'});ExitCode=124;HttpStatus=0;ConnectStatus=0;TransportOk=$false;Error='单次诊断超过 15 秒，已停止本次 curl 探测。'}}
        $exitCode=$p.ExitCode;$out=$outTask.Result;$err=$errTask.Result;$f=@{}
        foreach($piece in ($out -split ';')){$pair=$piece -split '=',2;if($pair.Count -eq 2){$f[$pair[0]]=$pair[1]}}
        $status=0;[void][int]::TryParse([string]$f.status,[ref]$status)
        $reason=if($exitCode -eq 0){''}elseif($err -match 'timeout|timed out'){'连接或 TLS 握手超时。'}elseif($err -match 'certificate|SSL peer'){'证书校验失败，未绕过校验。'}elseif($err -match 'resolve'){'DNS 解析失败。'}else{'连接失败，curl 退出码 '+$exitCode+'。'}
        return [pscustomobject]@{HostName=$HostName;Mode=$(if($ProxyUrl){'Proxy'}else{'Direct'});ExitCode=$exitCode;HttpStatus=$status;ConnectStatus=$f.connect;DnsSeconds=$f.dns;TcpSeconds=$f.tcp;TlsSeconds=$f.tls;TotalSeconds=$f.total;TlsVerify=$f.verify;TransportOk=($exitCode -eq 0 -and $status -ge 100 -and $f.verify -eq '0' -and (-not $ProxyUrl -or $f.connect -eq '200'));Error=$reason}
    } finally {$p.Dispose()}
}

function Test-Proxy {
    param([string]$ProxyUrl)
    $url=ConvertTo-LocalProxy $ProxyUrl
    $protocol=Test-ConnectProtocol $url
    if(-not $protocol.Ok){return [pscustomobject]@{Ok=$false;Url=$url;Reason=$protocol.Reason;Results=@()}}
    $results=@()
    foreach($hostName in @('oauth2.googleapis.com','daily-cloudcode-pa.googleapis.com')){
        $r=Test-HttpsEndpoint -HostName $hostName -ProxyUrl $url;$results+=$r
        if(-not $r.TransportOk){return [pscustomobject]@{Ok=$false;Url=$url;Reason=($hostName+'：'+$r.Error);Results=$results}}
    }
    return [pscustomobject]@{Ok=$true;Url=$url;Reason='CONNECT 和两个 Google 服务的 TLS/HTTP 已完成；不代表账号权限或模型回复通过。';Results=$results}
}

function Select-Proxy {
    param([string]$Preferred,[string]$Explicit,[switch]$NonInteractive)
    if($Explicit){$test=Test-Proxy $Explicit;if($test.Ok){return $test.Url};throw ('手动代理验证失败：'+$test.Reason)}
    $candidates=@(Get-ProxyCandidates -Preferred $Preferred)
    $tlsCandidates=0
    foreach($url in $candidates){
        Write-Host ('检查本地端口 '+([Uri]$url).Port+'……')
        $protocol=Test-ConnectProtocol $url
        if(-not $protocol.Ok){continue}
        $tlsCandidates++
        $test=Test-Proxy $url
        if($test.Ok){return $test.Url}
        Write-Host ('该端口未通过：'+$test.Reason)
        if($tlsCandidates -ge 4){break}
    }
    if($NonInteractive){throw '未发现通过 CONNECT 和 Google TLS 检查的本机代理。请开启 VPN 的 HTTP/Mixed 监听后重新部署，或手动指定本机地址；PAC-only、远程认证及 SOCKS-only 不支持。'}
    for($attempt=0;$attempt -lt 3;$attempt++){
        $answer=Read-Host '自动检测失败。输入本地 HTTP/Mixed 地址和端口，例如 127.0.0.1:7890；直接回车取消'
        if(-not $answer){throw '用户取消，未完成部署。'}
        try {$test=Test-Proxy $answer;if($test.Ok){return $test.Url};Write-Host ('验证失败：'+$test.Reason)}catch{Write-Host $_.Exception.Message}
    }
    throw '连续三次未通过验证，请先检查 VPN 的本地代理设置。'
}

function Get-OldInstances {
    # Conservative fallback for a version whose language-service installation path is not exposed.
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'Antigravity' -or $_.ProcessName -match '^language_server($|_)' })
}

function Get-UpdateState {
    param([string]$LogPath=(Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Antigravity\logs\main.log'))
    if(-not(Test-Path -LiteralPath $LogPath)){return 'Unknown'}
    $events=@(Get-Content -LiteralPath $LogPath -Tail 600 -Encoding UTF8 | Where-Object {$_ -match 'Downloading update|Update downloaded|downloaded successfully|Up to date|\[AutoUpdater\].*(Error|Failed)'})
    if($events.Count -eq 0){return 'Unknown'}
    if($events[-1] -match 'Downloading update'){return 'DownloadingOrUnconfirmed'}
    if($events[-1] -match 'Error|Failed'){return 'LastAttemptFailed'}
    return 'NoDownloadInLatestEvent'
}

function Assert-CanLaunch {
    if(@(Get-OldInstances).Count -gt 0){throw 'Antigravity 或语言服务仍在运行。请等待任务与官方更新结束，从菜单正常退出（含托盘）后重试；不会强制终止。'}
    if((Get-UpdateState) -eq 'DownloadingOrUnconfirmed'){throw '官方日志最后状态为下载中或尚未确认。请从官方入口完成更新后再试；不会中断更新。'}
    $updateRoot=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'antigravity-updater'
    $installers=@(Get-CimInstance Win32_Process | Where-Object {$_.ExecutablePath -and $_.ExecutablePath.StartsWith($updateRoot+'\',[StringComparison]::OrdinalIgnoreCase)})
    if($installers.Count -gt 0){throw '检测到官方更新程序，请等待其完成。'}
}

function New-AppStartInfo {
    param($Config,[string]$Executable)
    $proxy=ConvertTo-LocalProxy $Config.proxyUrl
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$Executable;$psi.WorkingDirectory=Split-Path $Executable -Parent;$psi.UseShellExecute=$false
    $psi.EnvironmentVariables['HTTP_PROXY']=$proxy;$psi.EnvironmentVariables['HTTPS_PROXY']=$proxy
    $psi.EnvironmentVariables['NO_PROXY']='localhost,127.0.0.1,::1,[::1]'
    [void]$psi.EnvironmentVariables.Remove('ALL_PROXY')
    if($Config.useAllProxy){$psi.EnvironmentVariables['ALL_PROXY']=$proxy}
    [void]$psi.EnvironmentVariables.Remove('ELECTRON_RUN_AS_NODE')
    if($Config.useChromiumProxy){$psi.Arguments='--proxy-server="'+$proxy+'" --proxy-bypass-list="localhost;127.0.0.1;[::1]"'}
    return $psi
}

function Write-SafeLog {
    param([string]$Root,[string]$Event,[int]$Code=0)
    # Intentionally no arbitrary exception text, paths, account data or response bodies.
    if($Event -notin @('Started','LaunchFailed','ProxyRevalidated','Deployed','NetworkCompleted','Uninstalled')){return}
    $dir=Join-Path $Root 'logs';[void](New-Item -ItemType Directory -Path $dir -Force)
    Add-Content -LiteralPath (Join-Path $dir ('launcher-'+(Get-Date -Format 'yyyyMMdd')+'.log')) -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+' '+$Event+' code='+$Code) -Encoding UTF8
}

function Get-RuntimeFiles {
    $licenseFile='LICENSE'
    return @('scripts\Runtime.ps1','scripts\Deploy.ps1','scripts\App.ps1','scripts\Network.ps1','scripts\Remove.ps1','scripts\Entry.ps1','01 一键部署.bat','02 启动反重力.bat','03 网络故障诊断.bat','04 卸载启动器.bat','docs\使用教程.html','VERSION.txt','RELEASE_NOTES.md','LICENSE-NOTICE.md',$licenseFile)
}

function Get-ShortcutSpecs {
    param([string]$Root,[string]$Desktop=([Environment]::GetFolderPath('Desktop')))
    $powershell=Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell\v1.0\powershell.exe'
    return @(
        [pscustomobject]@{Path=(Join-Path $Desktop '独立代理启动器.lnk');Target=$powershell;Arguments=('-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $Root 'scripts\App.ps1')+'" -Quiet')},
        [pscustomobject]@{Path=(Join-Path $Desktop '独立代理启动器 网络诊断.lnk');Target=$powershell;Arguments=('-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $Root 'scripts\Network.ps1')+'" -Pause')}
    )
}

function Test-ShortcutOwnership {
    param($Link,$Spec,[string]$LegacyRoot)
    if($Link.TargetPath -eq $Spec.Target -and $Link.Arguments -eq $Spec.Arguments){return $true}
    if($LegacyRoot -and (Test-Path -LiteralPath (Join-Path $LegacyRoot 'shortcut-manifest.json'))){
        $oldEntry=if([IO.Path]::GetFileName($Spec.Path) -eq '独立代理启动器.lnk'){'Launch.cmd'}else{'Diagnose.cmd'}
        $cmd=Join-Path ([Environment]::GetFolderPath('System')) 'cmd.exe'
        if($Link.TargetPath -eq $cmd -and $Link.Arguments -eq ('/d /c ""'+(Join-Path $LegacyRoot $oldEntry)+'""')){return $true}
    }
    return $false
}

function Assert-ShortcutSlots {
    param([string]$Root,[string]$Desktop=([Environment]::GetFolderPath('Desktop')),[string]$LegacyRoot)
    $shell=New-Object -ComObject WScript.Shell
    foreach($spec in (Get-ShortcutSpecs -Root $Root -Desktop $Desktop)){
        if(Test-Path -LiteralPath $spec.Path){$link=$shell.CreateShortcut($spec.Path);if(-not(Test-ShortcutOwnership -Link $link -Spec $spec -LegacyRoot $LegacyRoot)){throw '桌面存在同名但不属于本安装的快捷方式，未覆盖。请先重命名该同名入口后重新部署。'}}
    }
}

function Install-Shortcuts {
    param([string]$Root,[string]$Executable,[string]$Desktop=([Environment]::GetFolderPath('Desktop')),[string]$LegacyRoot)
    Assert-ShortcutSlots -Root $Root -Desktop $Desktop -LegacyRoot $LegacyRoot
    $shell=New-Object -ComObject WScript.Shell
    foreach($spec in (Get-ShortcutSpecs -Root $Root -Desktop $Desktop)){
        $link=$shell.CreateShortcut($spec.Path);$link.TargetPath=$spec.Target;$link.Arguments=$spec.Arguments
        $link.WorkingDirectory=$Root;$link.IconLocation=$Executable+',0';$link.Description='LocalProxyLauncher：非官方独立进程代理启动工具'
        # Minimized, not fully hidden: execution-policy or early PowerShell failures stay recoverable.
        $link.WindowStyle=7;$link.Save()
    }
}

function Assert-InstallOwnership {
    param([string]$Root)
    if(-not(Test-Path -LiteralPath $Root)){return}
    $marker=Join-Path $Root 'install-state.json'
    if(-not(Test-Path -LiteralPath $marker)){
        if(@(Get-ChildItem -LiteralPath $Root -Force).Count -gt 0){throw '安装目录已存在其他文件，且没有本工具标识；已停止以免覆盖。'}
        return
    }
    $state=Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json
    if($state.productId -ne $script:ProductId){throw '安装目录归属不匹配，未覆盖。'}
}
