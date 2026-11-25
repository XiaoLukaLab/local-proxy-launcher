[CmdletBinding()]
param([string]$ProxyAddress,[string]$ExecutablePath,[switch]$NonInteractive,[switch]$Pause,[string]$InstallRoot,[string]$Desktop)
. (Join-Path $PSScriptRoot 'Runtime.ps1')
$code=1
try {
    Write-Host 'Local Proxy Launcher v1.0.0-beta.1｜非官方独立代理启动器'
    $os=Get-CimInstance Win32_OperatingSystem
    if([version]$os.Version -lt [version]'10.0'){throw '本版面向 Windows 10 / 11；当前系统不在支持设计范围。'}
    $curl=Join-Path ([Environment]::GetFolderPath('System')) 'curl.exe'
    if(-not(Test-Path -LiteralPath $curl)){throw '缺少 Windows 自带 curl.exe，请更新系统后重试；不会自动安装组件。'}
    if(-not $InstallRoot){$InstallRoot=Get-InstallRoot};$InstallRoot=[IO.Path]::GetFullPath($InstallRoot)
    if(-not $Desktop){$Desktop=[Environment]::GetFolderPath('Desktop')}
    Assert-InstallOwnership $InstallRoot
    $old=$null
    try {$old=Read-Config $InstallRoot}catch{Write-Host '原配置无法解析，将在网络验证成功后备份并重新生成。'}
    $preferredPath=if($ExecutablePath){$ExecutablePath}elseif($old){$old.executablePath}else{''}
    try {$exe=Find-Antigravity $preferredPath}catch{
        if($NonInteractive){throw}
        Write-Host $_.Exception.Message
        $custom=Read-Host '输入已安装的 Antigravity.exe 完整路径；直接回车取消'
        if(-not $custom){throw '未找到客户端，部署取消。'}
        $exe=Find-Antigravity $custom
    }
    Write-Host ('已识别客户端版本：'+(Get-Item -LiteralPath $exe).VersionInfo.ProductVersion)
    $preferred=if($old){$old.proxyUrl}else{''}
    $url=Select-Proxy -Preferred $preferred -Explicit $ProxyAddress -NonInteractive:$NonInteractive
    Write-Host '网络验证通过，正在部署当前用户运行文件……'
    Assert-ShortcutSlots -Root $InstallRoot -Desktop $Desktop -LegacyRoot $script:SourceRoot
    $files=@(Get-RuntimeFiles)
    foreach($relative in $files){if(-not(Test-Path -LiteralPath (Join-Path $script:SourceRoot $relative) -PathType Leaf)){throw ('安装包不完整：'+$relative+'。请重新解压完整 ZIP。')}}
    [void](New-Item -ItemType Directory -Path $InstallRoot -Force)
    # Ownership marker permits repair after a partial copy; it does not claim successful installation.
    $marker=Join-Path $InstallRoot 'install-state.json'
    [pscustomobject]@{productId=$script:ProductId;version=$script:Version;installed=$false} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
    foreach($relative in $files){
        $source=Join-Path $script:SourceRoot $relative;$dest=Join-Path $InstallRoot $relative
        [void](New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force)
        if([IO.Path]::GetFullPath($source) -ine [IO.Path]::GetFullPath($dest)){Copy-Item -LiteralPath $source -Destination $dest -Force}
    }
    if($old){$config=$old;$config.proxyUrl=$url;$config.executablePath=$exe}
    else{$config=[pscustomobject][ordered]@{schemaVersion=1;proxyUrl=$url;executablePath=$exe;useChromiumProxy=$true;useAllProxy=$false}}
    Save-Config -Root $InstallRoot -Config $config
    Install-Shortcuts -Root $InstallRoot -Executable $exe -Desktop $Desktop -LegacyRoot $script:SourceRoot
    [pscustomobject]@{productId=$script:ProductId;version=$script:Version;installed=$true} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
    Write-SafeLog -Root $InstallRoot -Event Deployed
    Write-Host '部署完成。桌面已有「独立代理启动器」和「独立代理启动器 网络诊断」。'
    Write-Host ('运行目录：'+$InstallRoot)
    Write-Host '可以删除原始解压目录。请保留当前用户运行目录，后续从桌面启动。'
    if(@(Get-OldInstances).Count -gt 0){Write-Host '客户端目前仍在运行。请等待任务与更新结束，正常退出后再使用新入口。'}
    if((Get-UpdateState) -eq 'DownloadingOrUnconfirmed'){Write-Host '更新状态仍是下载中或未确认；请勿中断官方更新。'}
    $code=0
} catch {Write-Host ('部署失败：'+$_.Exception.Message) -ForegroundColor Red;Write-Host '没有完成部署，请根据原因修复后重试；不会显示成功或改动全局网络。'}
if($Pause){[void](Read-Host '按回车关闭')}
exit $code
