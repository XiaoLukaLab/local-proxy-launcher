[CmdletBinding()]
param([switch]$Pause,[string]$InstallRoot,[string]$Desktop)
. (Join-Path $PSScriptRoot 'Runtime.ps1')
if(-not $InstallRoot){$InstallRoot=Get-InstallRoot}
if(-not $Desktop){$Desktop=[Environment]::GetFolderPath('Desktop')}
$code=1
try{
    Assert-InstallOwnership $InstallRoot
    $marker=Join-Path $InstallRoot 'install-state.json'
    if(-not(Test-Path -LiteralPath $marker)){throw '没有发现本工具安装标识，未删除任何文件。'}
    $shell=New-Object -ComObject WScript.Shell
    foreach($spec in (Get-ShortcutSpecs -Root $InstallRoot -Desktop $Desktop)){
        if(Test-Path -LiteralPath $spec.Path){$link=$shell.CreateShortcut($spec.Path);if(Test-ShortcutOwnership -Link $link -Spec $spec){Remove-Item -LiteralPath $spec.Path}else{Write-Host '同名入口已改为其他目标，予以保留。'}}
    }
    # Fixed relative file allowlist, never recursively delete the installation or user data.
    foreach($relative in (Get-RuntimeFiles)){
        $file=Join-Path $InstallRoot $relative
        if(Test-Path -LiteralPath $file -PathType Leaf){Remove-Item -LiteralPath $file}
    }
    [pscustomobject]@{productId=$script:ProductId;version=$script:Version;installed=$false} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
    Write-SafeLog -Root $InstallRoot -Event Uninstalled
    Write-Host '卸载完成：已移除本工具运行文件和仍属于本工具的桌面入口。'
    Write-Host '保留独立配置、上次配置备份和诊断日志，便于重新部署。没有全局设置需要回滚。'
    Write-Host '已运行的客户端不会被终止。正常退出后从官方入口打开，即恢复原启动方式。'
    $code=0
}catch{Write-Host ('卸载未完成：'+$_.Exception.Message) -ForegroundColor Red}
if($Pause){[void](Read-Host '按回车关闭')}
exit $code
