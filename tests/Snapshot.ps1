param([string]$OutputPath)
[Console]::OutputEncoding=New-Object Text.UTF8Encoding
function Fingerprint {param([string]$Value);if(-not $Value){return $null};$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))) -replace '-','')}finally{$sha.Dispose()}}
$raw=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$proxy=[pscustomobject]@{ProxyEnable=$raw.ProxyEnable;ProxyServerHash=(Fingerprint $raw.ProxyServer);PacHash=(Fingerprint $raw.AutoConfigURL)}
$environment=@();foreach($s in @('Process','User','Machine')){foreach($n in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')){$environment += [pscustomobject]@{Scope=$s;Name=$n;Hash=(Fingerprint ([Environment]::GetEnvironmentVariable($n,$s)))}}}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=New-Object Security.Principal.WindowsPrincipal($identity)
$state=[ordered]@{Proxy=$proxy;Environment=$environment;Routes=@(Get-NetRoute|Where-Object{$_.DestinationPrefix -in @('0.0.0.0/0','0.0.0.0/1','128.0.0.0/1')}|Select-Object DestinationPrefix,InterfaceIndex,NextHop);Dns=@(Get-DnsClientServerAddress|Select-Object InterfaceIndex,AddressFamily,ServerAddresses);CodexIds=@(Get-Process codex -ErrorAction SilentlyContinue|ForEach-Object Id);IsAdministrator=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);OS=(Get-CimInstance Win32_OperatingSystem|Select-Object Version,BuildNumber,OSArchitecture)}
$state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host '本地网络快照已保存；不应包含在发布包中。'
