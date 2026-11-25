param([string]$ReleaseRoot,[string]$ForbiddenPattern)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Runtime.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
if(-not $ReleaseRoot){$ReleaseRoot=Join-Path $script:SourceRoot 'releases\v1.0.0-beta.1'}
$work=Join-Path $script:SourceRoot ('.tmp\verify-'+[guid]::NewGuid().ToString('N'));[void](New-Item -ItemType Directory -Path $work -Force)
$results=@()
try{
    foreach($kind in @('Windows','Source')){
        $zip=Join-Path $ReleaseRoot ('LocalProxyLauncher-v1.0.0-beta.1-'+$kind+'.zip');$dest=Join-Path $work $kind
        [IO.Compression.ZipFile]::ExtractToDirectory($zip,$dest)
        $root=(Get-ChildItem -LiteralPath $dest -Directory)[0].FullName
        $manifest=Get-Content -LiteralPath (Join-Path $root 'FILE_MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $expected=@($manifest.Files.Path)+@('FILE_MANIFEST.json','SHA256SUMS.txt')
        $actual=@(Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
        if(@(Compare-Object $expected $actual).Count -gt 0){throw ('ZIP 文件清单不一致：'+$kind)}
        foreach($entry in $manifest.Files){
            $file=Join-Path $root $entry.Path
            if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.SHA256){throw '逐文件 SHA256 不匹配。'}
        }
        foreach($file in (Get-ChildItem -LiteralPath $root -File -Recurse)){
            if($file.Extension -in @('.log','.lnk','.exe','.dll') -or $file.Name -in @('config.json','config.previous.json','install-state.json','shortcut-manifest.json') -or $file.FullName -match '[\\/](logs|evidence|original)[\\/]'){throw '发现不应进入发布包的文件类型。'}
            if($file.Extension -in @('.ps1','.md','.json','.html','.txt','.bat') -or $file.Name -eq '.gitignore'){
                $text=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
                if($text -match '(?i)[a-z]:[\\/]+Users[\\/]+' -or ($ForbiddenPattern -and $text -match $ForbiddenPattern) -or $text -match '(?i)ya29\.[a-z0-9_-]{15,}|AIza[a-z0-9_-]{20,}|ghp_[a-z0-9]{20,}|sk-[a-z0-9_-]{20,}') {throw ('发现个人路径、被禁止内容或疑似令牌：'+$file.Name)}
            }
            if($file.Extension -eq '.ps1'){
                $b=[IO.File]::ReadAllBytes($file.FullName);if($b.Length -lt 3 -or $b[0] -ne 239 -or $b[1] -ne 187 -or $b[2] -ne 191){throw 'PS1 缺少 UTF-8 BOM。'}
                $t=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$t,[ref]$e);if($e.Count -gt 0){throw '打包脚本存在语法错误。'}
            }
        }
        $html=Get-Content -LiteralPath (Join-Path $root 'docs\使用教程.html') -Raw -Encoding UTF8
        if($html -match '(?i)<(?:script|img|link|iframe)[^>]+(?:src|href)\s*=\s*["'']https?://'){throw '离线教程含远程资源依赖。'}
        $results += [pscustomobject]@{Package=$kind;Files=$actual.Count;ManifestAndHashes=$true;PrivacyScan=$true;SyntaxAndEncoding=$true;OfflineGuide=$true}
    }
    $sumLines=Get-Content -LiteralPath (Join-Path $ReleaseRoot 'SHA256SUMS.txt') -Encoding UTF8
    foreach($line in $sumLines){if($line -match '^([0-9a-f]{64})  (.+\.zip)$'){if((Get-FileHash -LiteralPath (Join-Path $ReleaseRoot $Matches[2])).Hash.ToLowerInvariant() -ne $Matches[1]){throw 'ZIP 总校验值不匹配。'}}}
    $results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ReleaseRoot 'PACKAGE_VERIFICATION.json') -Encoding UTF8
    $results | ConvertTo-Json
}finally{
    if([IO.Path]::GetFullPath((Split-Path $work -Parent)) -eq [IO.Path]::GetFullPath((Join-Path $script:SourceRoot '.tmp'))){Remove-Item -LiteralPath $work -Recurse -Force}
}
