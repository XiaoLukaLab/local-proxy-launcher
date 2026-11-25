param([ValidateSet('Deploy','Launch','Network','Remove')][string]$Action)
. (Join-Path $PSScriptRoot 'Runtime.ps1')
$root=Get-InstallRoot
switch($Action){
    'Deploy' { & (Join-Path $PSScriptRoot 'Deploy.ps1') -Pause }
    'Launch' {
        $file=Join-Path $root 'scripts\App.ps1'
        if(Test-Path -LiteralPath $file){& $file}else{Write-Host '请先双击「01 一键部署.bat」。';[void](Read-Host '按回车关闭');exit 1}
    }
    'Network' {
        $file=Join-Path $root 'scripts\Network.ps1'
        if(-not(Test-Path -LiteralPath $file)){$file=Join-Path $PSScriptRoot 'Network.ps1'}
        & $file -Pause
    }
    'Remove' {
        $file=Join-Path $root 'scripts\Remove.ps1'
        if(Test-Path -LiteralPath $file){& $file -Pause}else{Write-Host '没有已部署的运行文件；未删除任何内容。';[void](Read-Host '按回车关闭')}
    }
}
