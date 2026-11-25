param([Parameter(Mandatory=$true)][string]$LiveProxy)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Runtime.ps1')
$qaRoot=Join-Path $script:SourceRoot ('.tmp\部署 QA '+[guid]::NewGuid().ToString('N'))
$source=Join-Path $qaRoot '解压 Source Folder';$installed=Join-Path $qaRoot '稳定安装 App Folder';$desktop=Join-Path $qaRoot '测试桌面'
foreach($dir in @($source,$desktop)){[void](New-Item -ItemType Directory -Path $dir -Force)}
foreach($relative in (Get-RuntimeFiles)){$dest=Join-Path $source $relative;[void](New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force);Copy-Item -LiteralPath (Join-Path $script:SourceRoot $relative) -Destination $dest}
$results=@()
function Invoke-TestScript {
    param([string]$File,[string]$Arguments)
    $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell\v1.0\powershell.exe'
    $psi.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$File+'" '+$Arguments
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;[void]$p.Start();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
    if(-not $p.WaitForExit(50000)){$p.Kill();throw '测试子进程超时。'}
    $r=[pscustomobject]@{Code=$p.ExitCode;Output=$out.Result;Error=$err.Result};$p.Dispose();return $r
}
try{
    $args='-NonInteractive -InstallRoot "'+$installed+'" -Desktop "'+$desktop+'"'
    $invalid=Invoke-TestScript -File (Join-Path $source 'scripts\Deploy.ps1') -Arguments ($args+' -ProxyAddress "http://127.0.0.1:1"')
    if($invalid.Code -eq 0 -or $invalid.Output -notmatch '部署失败' -or $invalid.Output -match '部署完成' -or (Test-Path -LiteralPath $installed)){throw '坏代理没有明确停止部署，或出现虚假成功。'}
    $results += [pscustomobject]@{Name='部署失败明确返回且不显示成功';Kind='真实关闭/不可用端口';Pass=$true}
    $first=Invoke-TestScript -File (Join-Path $source 'scripts\Deploy.ps1') -Arguments $args
    if($first.Code -ne 0){throw ('首次部署失败：'+$first.Output+$first.Error)}
    $results += [pscustomobject]@{Name='中文及空格解压、安装和桌面目录';Kind='真实文件与真实代理';Pass=$true}
    $configPath=Join-Path $installed 'config.json';$firstHash=(Get-FileHash -LiteralPath $configPath).Hash
    $second=Invoke-TestScript -File (Join-Path $source 'scripts\Deploy.ps1') -Arguments $args
    $same=(Get-FileHash -LiteralPath $configPath).Hash -eq $firstHash
    $backedUp=(Test-Path -LiteralPath (Join-Path $installed 'config.previous.json')) -and (Get-FileHash -LiteralPath (Join-Path $installed 'config.previous.json')).Hash -eq $firstHash
    if($second.Code -ne 0 -or (-not $same -and -not $backedUp) -or @(Get-ChildItem -LiteralPath $desktop -Filter '*.lnk').Count -ne 2){throw ('重复部署检查失败：code='+$second.Code+'，原配置保留或备份='+($same -or $backedUp)+'，入口数='+@(Get-ChildItem -LiteralPath $desktop -Filter '*.lnk').Count+'，输出='+$second.Output+$second.Error)}
    $results += [pscustomobject]@{Name='重复部署无重复入口，原配置保留或备份';Kind='真实部署两次；允许经验证刷新代理';Pass=$true}
    $firstHash=(Get-FileHash -LiteralPath $configPath).Hash
    $scriptPath=Join-Path $source 'scripts\Deploy.ps1'
    if([IO.Path]::GetFullPath((Split-Path $source -Parent)) -ne [IO.Path]::GetFullPath($qaRoot)){throw '清理边界检查失败。'}
    Remove-Item -LiteralPath $source -Recurse -Force
    $shell=New-Object -ComObject WScript.Shell
    $link=$shell.CreateShortcut((Join-Path $desktop '独立代理启动器.lnk'))
    $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=$link.TargetPath;$psi.Arguments=$link.Arguments+' -CheckOnly -InstallRoot "'+$installed+'"'
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;[void]$p.Start();$read=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
    try{if(-not $p.WaitForExit(10000)){$p.Kill();throw '快捷方式目标自检超时。'};if($p.ExitCode -ne 0){throw ('删除解压目录后目标自检失败：'+$read.Result+$err.Result)}}finally{$p.Dispose()}
    $results += [pscustomobject]@{Name='删除原始解压目录后桌面目标自检';Kind='真实删除任务副本，不启动真实客户端';Pass=$true}
    '用户自放的未知文件必须保留' | Set-Content -LiteralPath (Join-Path $installed 'UserKeep.txt') -Encoding UTF8
    $remove=Invoke-TestScript -File (Join-Path $installed 'scripts\Remove.ps1') -Arguments ('-InstallRoot "'+$installed+'" -Desktop "'+$desktop+'"')
    if($remove.Code -ne 0 -or @(Get-ChildItem -LiteralPath $desktop -Filter '*.lnk').Count -ne 0 -or (Test-Path -LiteralPath (Join-Path $installed 'scripts\App.ps1')) -or -not(Test-Path -LiteralPath (Join-Path $installed 'UserKeep.txt')) -or (Get-FileHash -LiteralPath $configPath).Hash -ne $firstHash){throw '卸载未按白名单移除或未保留用户文件、配置。'}
    $results += [pscustomobject]@{Name='白名单卸载并保留配置与未知文件';Kind='真实临时安装';Pass=$true}
    $again=Invoke-TestScript -File (Join-Path $script:SourceRoot 'scripts\Deploy.ps1') -Arguments $args
    $same=(Get-FileHash -LiteralPath $configPath).Hash -eq $firstHash
    $backedUp=(Test-Path -LiteralPath (Join-Path $installed 'config.previous.json')) -and (Get-FileHash -LiteralPath (Join-Path $installed 'config.previous.json')).Hash -eq $firstHash
    if($again.Code -ne 0 -or (-not $same -and -not $backedUp)){throw '卸载后重新部署失败。'}
    $results += [pscustomobject]@{Name='卸载后重新部署';Kind='真实重新部署';Pass=$true}
    $currentProxy=(Read-Config $installed).proxyUrl
    $manual=Invoke-TestScript -File (Join-Path $installed 'scripts\Network.ps1') -Arguments ('-NonInteractive -ProxyAddress "'+$currentProxy+'" -InstallRoot "'+$installed+'"')
    if($manual.Code -ne 0){throw ('手动代理重新验证失败：'+$manual.Output+$manual.Error)}
    $results += [pscustomobject]@{Name='手动配置经验证后保存';Kind='真实本地代理';Pass=$true}
}catch{$results += [pscustomobject]@{Name='部署集成流程';Kind='真实流程';Pass=$false;Error=$_.Exception.Message}}
$outDir=Join-Path $script:SourceRoot '.tmp\v1-productization';[void](New-Item -ItemType Directory -Path $outDir -Force)
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outDir 'deployment-results.json') -Encoding UTF8
$results | ConvertTo-Json -Depth 4
if([IO.Path]::GetFullPath((Split-Path $qaRoot -Parent)) -eq [IO.Path]::GetFullPath((Join-Path $script:SourceRoot '.tmp'))){Remove-Item -LiteralPath $qaRoot -Recurse -Force}
if(@($results|Where-Object{-not $_.Pass}).Count -gt 0){exit 1}
exit 0
