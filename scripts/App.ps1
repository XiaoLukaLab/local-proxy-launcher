[CmdletBinding()]
param([switch]$Quiet,[switch]$CheckOnly,[string]$InstallRoot)
. (Join-Path $PSScriptRoot 'Runtime.ps1')
if(-not $InstallRoot){$InstallRoot=Get-InstallRoot}
try {
    Assert-InstallOwnership $InstallRoot
    $config=Read-Config $InstallRoot
    if(-not $config){throw '尚未部署。请解压完整安装包并双击「01 一键部署.bat」。'}
    $exe=Find-Antigravity $config.executablePath
    if($CheckOnly){[pscustomobject]@{Version=$script:Version;ClientFound=$true;RunningInstances=@(Get-OldInstances).Count;UpdateState=(Get-UpdateState);ProxyConfigured=$true} | ConvertTo-Json;exit 0}
    Assert-CanLaunch
    if(-not $Quiet){Write-Host '正在检查代理与 Google TLS 连接，请稍候……'}
    $test=Test-Proxy $config.proxyUrl
    if(-not $test.Ok){
        if(-not $Quiet){Write-Host '保存的端口不可用，正在重新检测实际监听端口……'}
        $url=Select-Proxy -Preferred $config.proxyUrl -NonInteractive
        $config.proxyUrl=$url;Save-Config -Root $InstallRoot -Config $config
        Write-SafeLog -Root $InstallRoot -Event ProxyRevalidated
    }
    Assert-CanLaunch
    $psi=New-AppStartInfo -Config $config -Executable $exe
    $app=[Diagnostics.Process]::Start($psi)
    Write-SafeLog -Root $InstallRoot -Event Started
    try {
        [pscustomobject]@{ProcessId=$app.Id;StartedAt=$app.StartTime.ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallRoot 'logs\last-launch.json') -Encoding UTF8
    } catch { if(-not $Quiet){Write-Host '已发起启动，但本次启动记录未写入；不影响客户端自行运行。'} }
    if(-not $Quiet){Write-Host '已发起官方客户端启动。请在界面核对模型列表与真实回复。'}
    exit 0
} catch {
    $message=$_.Exception.Message
    if(Test-Path -LiteralPath (Join-Path $InstallRoot 'install-state.json')){try{Write-SafeLog -Root $InstallRoot -Event LaunchFailed -Code 1}catch{}}
    if($Quiet){
        try{Add-Type -AssemblyName System.Windows.Forms;[void][Windows.Forms.MessageBox]::Show($message,'Local Proxy Launcher：启动未完成',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Warning)}catch{Write-Host ('启动未完成：'+$message);[void](Read-Host '按回车关闭')}
    }else{Write-Host ('启动未完成：'+$message) -ForegroundColor Red}
    exit 1
}
