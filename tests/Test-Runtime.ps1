[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$LiveProxy,[Parameter(Mandatory=$true)][int]$RejectPort,[Parameter(Mandatory=$true)][int]$ClosedPort)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Runtime.ps1')
$script:TestResults=@()
$testRoot=Join-Path (Split-Path $PSScriptRoot -Parent) ('.tmp\qa-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot -Force)
function Add-Case {
    param([string]$Name,[string]$Kind,[scriptblock]$Body)
    try{& $Body;$script:TestResults += [pscustomobject]@{Name=$Name;Kind=$Kind;Pass=$true}}catch{$script:TestResults += [pscustomobject]@{Name=$Name;Kind=$Kind;Pass=$false;Error=$_.Exception.Message}}
}
function Must-Reject {param([scriptblock]$Body);$failed=$false;try{& $Body}catch{$failed=$true};if(-not $failed){throw '预期拒绝，但操作通过。'}}
Add-Case 'PowerShell 5.1 语法解析' '真实脚本' {
    foreach($dir in @('scripts','tests','tools')){
        foreach($f in (Get-ChildItem -LiteralPath (Join-Path $script:SourceRoot $dir) -Filter '*.ps1' -ErrorAction SilentlyContinue)){
            $t=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$t,[ref]$e)
            if($e.Count -gt 0){throw ('语法错误：'+$f.Name+' '+($e.Message -join ';'))}
        }
    }
}
Add-Case '本地地址和 IPv6 标准化' '真实函数' {
    if((ConvertTo-LocalProxy ' localhost:45678 ') -ne 'http://localhost:45678'){throw 'localhost 标准化错误。'}
    if((ConvertTo-LocalProxy '[::1]:45678') -ne 'http://[::1]:45678'){throw 'IPv6 标准化错误。'}
}
Add-Case '无效端口、远程主机、认证和注入输入被拒绝' '真实函数' {
    foreach($address in @('127.0.0.1:0','127.0.0.1:65536','127.0.0.1:abc','192.0.2.1:8080','http://user:secret@127.0.0.1:8080','socks5://127.0.0.1:8080','127.0.0.1:8080/path','127.0.0.1:8080?x=1','127.0.0.1:8080" & calc','http://localhost')){Must-Reject {ConvertTo-LocalProxy $address | Out-Null}}
}
Add-Case '当前代理 CONNECT 和 Google TLS' '真实网络' {
    $r=Test-Proxy $LiveProxy;if(-not $r.Ok){throw $r.Reason}
}
Add-Case 'HTTP 服务不支持 CONNECT' '本机模拟 HTTP 服务' {
    $r=Test-ConnectProtocol ('127.0.0.1:'+$RejectPort);if($r.Ok -or $r.Code -ne 405){throw '未拒绝不支持 CONNECT 的服务。'}
}
Add-Case '关闭端口失败并有限返回' '真实关闭端口' {
    $watch=[Diagnostics.Stopwatch]::StartNew();$r=Test-Proxy ('127.0.0.1:'+$ClosedPort)
    if($r.Ok -or $watch.Elapsed.TotalSeconds -gt 5){throw '关闭端口未及时失败。'}
}
Add-Case 'VPN 未开时无候选代理' '模拟发现层' {
    function Get-ProxyCandidates {return @()}
    Must-Reject {Select-Proxy -NonInteractive | Out-Null}
}
Add-Case '端口变化后重新选择可用代理' '模拟候选列表，真实代理 TLS' {
    function Get-ProxyCandidates {return @(('http://127.0.0.1:'+$ClosedPort),$LiveProxy)}
    if((Select-Proxy -NonInteractive) -ne (ConvertTo-LocalProxy $LiveProxy)){throw '未选中有效代理。'}
}
Add-Case '未安装客户端' '模拟文件不存在' {
    function Test-Path {return $false}
    function Get-Process {return @()}
    Must-Reject {Find-Antigravity | Out-Null}
}
Add-Case '旧实例拦截' '模拟进程列表' {
    function Get-OldInstances {return @([pscustomobject]@{ProcessName='Antigravity'})}
    Must-Reject {Assert-CanLaunch}
}
Add-Case '更新中拦截及失败状态识别' '模拟官方日志' {
    $log=Join-Path $testRoot 'main.log'
    '[info] Downloading update from a public endpoint' | Set-Content -LiteralPath $log -Encoding UTF8
    if((Get-UpdateState -LogPath $log) -ne 'DownloadingOrUnconfirmed'){throw '下载状态未识别。'}
    function Get-OldInstances {return @()}
    function Get-UpdateState {return 'DownloadingOrUnconfirmed'}
    Must-Reject {Assert-CanLaunch}
}
Add-Case '父环境不变，子进程实际继承' '真实子进程' {
    $before=@{};foreach($n in $script:ProxyNames){$before[$n]=[Environment]::GetEnvironmentVariable($n,'Process')}
    $config=[pscustomobject]@{proxyUrl=$LiveProxy;useAllProxy=$false;useChromiumProxy=$true}
    $psExe=Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell\v1.0\powershell.exe'
    $psi=New-AppStartInfo -Config $config -Executable $psExe
    foreach($n in $script:ProxyNames){if([Environment]::GetEnvironmentVariable($n,'Process') -cne $before[$n]){throw '父环境被修改。'}}
    foreach($n in @('localhost','127.0.0.1','::1')){if($n -notin ($psi.EnvironmentVariables['NO_PROXY'] -split ',')){throw '回环排除缺失。'}}
    if($psi.EnvironmentVariables.ContainsKey('ALL_PROXY')){throw '不应默认设置 ALL_PROXY。'}
    $file=Join-Path $testRoot 'child.ps1'
    '$r=@{};foreach($n in @(''HTTP_PROXY'',''HTTPS_PROXY'',''NO_PROXY'')){$r[$n]=[Environment]::GetEnvironmentVariable($n)};$r|ConvertTo-Json -Compress' | Set-Content -LiteralPath $file -Encoding UTF8
    $psi.Arguments='-NoProfile -NonInteractive -File "'+$file+'"';$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true
    $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;[void]$p.Start();$task=$p.StandardOutput.ReadToEndAsync()
    try{if(-not $p.WaitForExit(10000)){$p.Kill();throw '测试子进程超时。'};$c=$task.Result|ConvertFrom-Json;if($p.ExitCode -ne 0 -or $c.HTTP_PROXY -ne $LiveProxy -or $c.HTTPS_PROXY -ne $LiveProxy){throw '继承内容不匹配。'}}finally{$p.Dispose()}
}
Add-Case '重复保存配置保持字节不变，改动前备份' '真实临时文件' {
    $c=[pscustomobject]@{schemaVersion=1;proxyUrl=$LiveProxy;executablePath='';useChromiumProxy=$true;useAllProxy=$false}
    Save-Config -Root $testRoot -Config $c;$file=Join-Path $testRoot 'config.json';$hash=(Get-FileHash -LiteralPath $file).Hash
    Save-Config -Root $testRoot -Config $c;if((Get-FileHash -LiteralPath $file).Hash -ne $hash){throw '相同配置被改写。'}
    $c.useAllProxy=$true;Save-Config -Root $testRoot -Config $c
    if((Get-FileHash -LiteralPath (Join-Path $testRoot 'config.previous.json')).Hash -ne $hash){throw '旧配置备份不匹配。'}
}
Add-Case '同名无关快捷方式保留' '真实临时快捷方式' {
    $desktop=Join-Path $testRoot '桌面';[void](New-Item -ItemType Directory -Path $desktop -Force)
    $file=Join-Path $desktop '独立代理启动器.lnk';$shell=New-Object -ComObject WScript.Shell;$lnk=$shell.CreateShortcut($file)
    $lnk.TargetPath=Join-Path ([Environment]::GetFolderPath('System')) 'notepad.exe';$lnk.Save()
    $hash=(Get-FileHash -LiteralPath $file).Hash
    Must-Reject {Assert-ShortcutSlots -Root $testRoot -Desktop $desktop}
    if((Get-FileHash -LiteralPath $file).Hash -ne $hash){throw '无关快捷方式被修改。'}
}
$script:TestResults | ConvertTo-Json -Depth 4
$outDir=Join-Path $script:SourceRoot '.tmp\v1-productization';[void](New-Item -ItemType Directory -Path $outDir -Force)
$script:TestResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outDir 'runtime-results.json') -Encoding UTF8
# Verify the exact directory before recursive removal. It was created by this test invocation.
if([IO.Path]::GetFullPath((Split-Path $testRoot -Parent)) -eq [IO.Path]::GetFullPath((Join-Path $script:SourceRoot '.tmp'))){Remove-Item -LiteralPath $testRoot -Recurse -Force}
if(@($script:TestResults|Where-Object{-not $_.Pass}).Count -gt 0){exit 1}
exit 0
