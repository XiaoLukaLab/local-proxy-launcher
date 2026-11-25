[CmdletBinding()]
param()
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Runtime.ps1')
$checks=@()
function Check {param([string]$Name,[scriptblock]$Body); & $Body; $script:checks += [pscustomobject]@{Name=$Name;Pass=$true;Type='Local release check; no live model/network test'}}
Check 'PowerShell 5.1 syntax and UTF-8 BOM' {
 foreach($dir in @('scripts','tests','tools')){foreach($f in (Get-ChildItem -LiteralPath (Join-Path $script:SourceRoot $dir) -Filter '*.ps1' -File)){$t=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$t,[ref]$e);if($e.Count){throw 'Syntax error'};$b=[IO.File]::ReadAllBytes($f.FullName);if($b[0] -ne 239 -or $b[1] -ne 187 -or $b[2] -ne 191){throw 'Missing BOM'}}}
}
Check 'Product version and isolated install namespace' {
 if($script:Version -ne '1.0.0-beta.1' -or $script:ProductId -ne 'LocalProxyLauncher' -or (Split-Path (Get-InstallRoot) -Leaf) -ne 'LocalProxyLauncher'){throw 'Metadata mismatch'}
}
Check 'Local HTTP input normalization and invalid input rejection' {
 if((ConvertTo-LocalProxy 'localhost:65432') -ne 'http://localhost:65432'){throw 'Normalize failed'}
 foreach($bad in @('','127.0.0.1','127.0.0.1:0','127.0.0.1:65536','http://example.com:65432','http://user:password@localhost:65432','socks5://localhost:65432','localhost:65432/path','localhost:65432?q=x')){$accepted=$false;try{$null=ConvertTo-LocalProxy $bad;$accepted=$true}catch{};if($accepted){throw 'Invalid address accepted'}}
}
Check 'Scoped proxy settings and unchanged parent environment' {
 $before=@{};foreach($n in $script:ProxyNames){$before[$n]=[Environment]::GetEnvironmentVariable($n,'Process')}
 $cfg=[pscustomobject]@{proxyUrl='http://localhost:65432';useAllProxy=$false;useChromiumProxy=$true}
 $psi=New-AppStartInfo -Config $cfg -Executable (Join-Path ([Environment]::GetFolderPath('System')) 'notepad.exe')
 if($psi.EnvironmentVariables['HTTPS_PROXY'] -ne $cfg.proxyUrl -or $psi.EnvironmentVariables.ContainsKey('ALL_PROXY')){throw 'Process proxy mismatch'}
 foreach($n in $script:ProxyNames){if([Environment]::GetEnvironmentVariable($n,'Process') -cne $before[$n]){throw 'Parent environment modified'}}
 foreach($n in @('localhost','127.0.0.1','::1')){if($n -notin ($psi.EnvironmentVariables['NO_PROXY'] -split ',')){throw 'Loopback bypass missing'}}
}
Check 'Runtime file allowlist exists' {foreach($r in (Get-RuntimeFiles)){if(-not(Test-Path -LiteralPath (Join-Path $script:SourceRoot $r) -PathType Leaf)){throw 'Missing runtime file'}}}
Check 'Chinese space path in desktop shortcut arguments' {
 $spec=@(Get-ShortcutSpecs -Root (Join-Path $script:SourceRoot '.tmp\中文 space') -Desktop (Join-Path $script:SourceRoot '.tmp\桌面'))
 if($spec.Count -ne 2 -or $spec[0].Arguments -notmatch '".*中文 space.*"'){throw 'Quoted path missing'}
}
Check 'Final MIT license and build gate' {
 $license=Get-Content -LiteralPath (Join-Path $script:SourceRoot 'LICENSE') -Raw -Encoding UTF8
 if($license -notmatch 'MIT License' -or $license -notmatch 'Copyright \(c\) 2026 a3555745' -or $license -notmatch 'THE SOFTWARE IS PROVIDED'){throw 'Final MIT license invalid'}
 if(-not(Test-Path -LiteralPath (Join-Path $script:SourceRoot 'LICENSE'))){$rejected=$false;try{& (Join-Path $script:SourceRoot 'tools\Build-Release.ps1')}catch{$rejected=$true};if(-not $rejected){throw 'Unapproved build allowed'}}
}
$out=Join-Path $script:SourceRoot '.tmp\publication-checks';[void](New-Item -ItemType Directory -Path $out -Force)
$checks | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $out 'PUBLICATION_CHECKS.json') -Encoding UTF8
$checks | ConvertTo-Json -Depth 4
