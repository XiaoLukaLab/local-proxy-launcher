[CmdletBinding()]
param([switch]$NonInteractive,[switch]$ProxyOnly,[switch]$Pause,[string]$ProxyAddress,[switch]$Redetect,[string]$InstallRoot)
. (Join-Path $PSScriptRoot 'Runtime.ps1')
if(-not $InstallRoot){$InstallRoot=Get-InstallRoot}
$code=1
try {
    $config=$null
    try{$config=Read-Config $InstallRoot}catch{Write-Host '保存的配置格式无效，可重新部署或手动设置代理。'}
    if(-not $NonInteractive -and -not $ProxyAddress -and -not $Redetect){
        Write-Host '1：网络诊断；2：手动配置本地代理；3：自动重新检测代理。'
        $choice=Read-Host '请选择，直接回车为 1'
        if($choice -eq '2'){$ProxyAddress=Read-Host '输入 HTTP/Mixed 地址，例如 127.0.0.1:7890';if(-not $ProxyAddress){throw '未填写地址，操作取消。'}}
        elseif($choice -eq '3'){$Redetect=$true}
        elseif($choice -and $choice -ne '1'){throw '无效选项，未修改配置。'}
    }
    if($ProxyAddress -or $Redetect){
        if(-not $config){throw '请先运行一键部署；本菜单只修改已经部署的独立代理配置。'}
        $preferred=if($Redetect){''}else{$config.proxyUrl}
        $config.proxyUrl=Select-Proxy -Preferred $preferred -Explicit $ProxyAddress -NonInteractive:$NonInteractive
        Save-Config -Root $InstallRoot -Config $config
        Write-Host '新代理已验证并保存。请正常退出客户端后，从专属入口重开；全局网络未改动。'
        $code=0
    }else{
        $url=if($config){$config.proxyUrl}else{Select-Proxy -NonInteractive:$NonInteractive}
        Write-Host '以下请求无账号凭据，保留 TLS 证书验证，不记录响应正文。'
        Write-Host ('官方更新日志状态：'+(Get-UpdateState))
        $results=@()
        foreach($hostName in @('accounts.google.com','oauth2.googleapis.com','daily-cloudcode-pa.googleapis.com','cloudcode-pa.googleapis.com','aicode.googleapis.com')){
            foreach($mode in $(if($ProxyOnly){@('Proxy')}else{@('Direct','Proxy')})){
                Write-Host ('检查 '+$hostName+'，'+$mode+'……')
                $proxy=if($mode -eq 'Proxy'){$url}else{''}
                $r=Test-HttpsEndpoint -HostName $hostName -ProxyUrl $proxy;$results+=$r
                Write-Host ('HTTP='+$r.HttpStatus+'，CONNECT='+$r.ConnectStatus+'，耗时='+$r.TotalSeconds+' 秒。'+$r.Error)
            }
        }
        $logRoot=if(Test-Path -LiteralPath (Join-Path $InstallRoot 'install-state.json')){$InstallRoot}else{$script:SourceRoot}
        $dir=Join-Path $logRoot 'logs';[void](New-Item -ItemType Directory -Path $dir -Force)
        $file=Join-Path $dir ('network-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.json')
        [pscustomobject]@{Version=$script:Version;Time=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K');Results=$results} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file -Encoding UTF8
        Write-Host 'HTTP 401/403/404 仅表明收到响应，不等于账号有资格或模型可用。Direct 为显式不使用代理的对照。'
        Write-Host ('结果已保存在本机：'+$file)
        Write-SafeLog -Root $logRoot -Event NetworkCompleted
        $code=if(@($results|Where-Object{$_.Mode -eq 'Proxy' -and -not $_.TransportOk}).Count -gt 0){2}else{0}
    }
}catch{Write-Host ('操作未完成：'+$_.Exception.Message) -ForegroundColor Red}
if($Pause){[void](Read-Host '按回车关闭')}
exit $code
