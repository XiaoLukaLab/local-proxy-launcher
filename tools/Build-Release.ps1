[CmdletBinding()]
param([string]$OutputRoot,[switch]$ReviewCandidate)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Runtime.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
if(-not(Test-Path -LiteralPath (Join-Path $script:SourceRoot 'LICENSE')) -and -not $ReviewCandidate){throw '许可证尚未由权利人确认。仅可用 -ReviewCandidate 构建本地审阅包，不可公开发布。'}
if(-not $OutputRoot){$OutputRoot=Join-Path $script:SourceRoot 'releases\v1.0.0-beta.1'}
[void](New-Item -ItemType Directory -Path $OutputRoot -Force)
$stageRoot=Join-Path $script:SourceRoot ('.tmp\release-'+[guid]::NewGuid().ToString('N'))
$userStage=Join-Path $stageRoot 'LocalProxyLauncher-v1.0.0-beta.1-Windows'
$sourceStage=Join-Path $stageRoot 'LocalProxyLauncher-v1.0.0-beta.1-Source'
$runtime=@(Get-RuntimeFiles)
$sourceExtra=@('AGENTS.md','ROADMAP.md','README.md','README_EN.md','CHANGELOG.md','SECURITY.md','CONTRIBUTING.md','COMPATIBILITY.md','COMPATIBILITY_MATRIX.md','SECURITY_REVIEW.md','FINAL_ACCEPTANCE.md','THIRD_PARTY_NOTICES.md','QA_SUMMARY.json','PUBLICATION_CHECKS.json','docs\ARCHITECTURE.md','docs\MAINTENANCE.md','docs\ROADMAP_PUBLIC.md','tests\Test-Publication.ps1','tests\Test-Runtime.ps1','tests\Test-Deployment.ps1','tests\Snapshot.ps1','tests\Discover.ps1','tools\Build-Release.ps1','tools\Verify-Release.ps1','release-docs\SHARE_COPY.md','release-docs\GITHUB_INTRO.md','release-docs\LOCAL_ADAPTATION_PROMPT.md','release-docs\QA_SUMMARY.json','assets\connection-flow.svg','.github\ISSUE_TEMPLATE\bug_report.md','.github\ISSUE_TEMPLATE\compatibility_report.md')
$releaseFiles=@('RELEASE_NOTES.md','COMPATIBILITY_MATRIX.md','SECURITY_REVIEW.md','FINAL_ACCEPTANCE.md','SHARE_COPY.md','GITHUB_INTRO.md','LOCAL_ADAPTATION_PROMPT.md','QA_SUMMARY.json')
function Copy-Whitelist {
    param([string]$Destination,[string[]]$Files)
    foreach($relative in $Files){
        $src=Join-Path $script:SourceRoot $relative
        if(-not(Test-Path -LiteralPath $src -PathType Leaf)){throw ('发布文件缺失：'+$relative)}
        $dest=Join-Path $Destination $relative;[void](New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force)
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
}
function Write-Manifest {
    param([string]$Root)
    $items=@(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{Path=$_.FullName.Substring($Root.Length+1).Replace('\','/');Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    })
    [pscustomobject]@{Product='Local Proxy Launcher';Version='1.0.0-beta.1';Note='清单不校验自身及 SHA256SUMS.txt；完整 ZIP 校验值另列。';Files=$items} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Root 'FILE_MANIFEST.json') -Encoding UTF8
    $items | ForEach-Object {$_.SHA256+'  '+$_.Path} | Set-Content -LiteralPath (Join-Path $Root 'SHA256SUMS.txt') -Encoding UTF8
}
try{
    Copy-Whitelist -Destination $userStage -Files $runtime
    Copy-Whitelist -Destination $sourceStage -Files @($runtime+$sourceExtra)
    Copy-Item -LiteralPath (Join-Path $script:SourceRoot '.gitignore') -Destination (Join-Path $sourceStage '.gitignore') -Force
    Write-Manifest $userStage;Write-Manifest $sourceStage
    foreach($item in @(@($userStage,'LocalProxyLauncher-v1.0.0-beta.1-Windows.zip'),@($sourceStage,'LocalProxyLauncher-v1.0.0-beta.1-Source.zip'))){
        $target=Join-Path $OutputRoot $item[1]
        if(Test-Path -LiteralPath $target){
            if(-not(Test-Path -LiteralPath (Join-Path $OutputRoot 'release-owned.json'))){throw '输出 ZIP 已存在且没有本工具构建标识，未覆盖。'}
            Remove-Item -LiteralPath $target
        }
        [IO.Compression.ZipFile]::CreateFromDirectory($item[0],$target,[IO.Compression.CompressionLevel]::Optimal,$true)
        Write-Host ('已生成：'+$item[1])
    }
    $docsRoot=Join-Path $OutputRoot 'Release-Docs';[void](New-Item -ItemType Directory -Path $docsRoot -Force)
    foreach($file in $releaseFiles){$src=if($file -in @('RELEASE_NOTES.md','COMPATIBILITY_MATRIX.md','SECURITY_REVIEW.md','FINAL_ACCEPTANCE.md')){Join-Path $script:SourceRoot $file}else{Join-Path $script:SourceRoot ('release-docs\'+$file)};Copy-Item -LiteralPath $src -Destination (Join-Path $docsRoot $file) -Force}
    foreach($kind in @('Windows','Source')){
        $stage=if($kind -eq 'Windows'){$userStage}else{$sourceStage}
        Copy-Item -LiteralPath (Join-Path $stage 'FILE_MANIFEST.json') -Destination (Join-Path $OutputRoot ($kind+'-FILE_MANIFEST.json')) -Force
    }
    $screenshotRoot=Join-Path $script:SourceRoot 'release-docs\screenshots'
    if(Test-Path -LiteralPath $screenshotRoot){
        $shotDest=Join-Path $docsRoot 'screenshots';[void](New-Item -ItemType Directory -Path $shotDest -Force)
        foreach($file in (Get-ChildItem -LiteralPath $screenshotRoot -File | Where-Object {$_.Extension -in @('.png','.jpg','.jpeg','.md')})){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $shotDest $file.Name) -Force}
    }
    Get-ChildItem -LiteralPath $OutputRoot -Filter '*.zip' -File | Sort-Object Name | ForEach-Object {(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$_.Name} | Set-Content -LiteralPath (Join-Path $OutputRoot 'SHA256SUMS.txt') -Encoding UTF8
    [pscustomobject]@{Product='LocalProxyLauncher';Version='1.0.0-beta.1'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputRoot 'release-owned.json') -Encoding UTF8
}finally{
    if([IO.Path]::GetFullPath((Split-Path $stageRoot -Parent)) -eq [IO.Path]::GetFullPath((Join-Path $script:SourceRoot '.tmp')) -and (Test-Path -LiteralPath $stageRoot)){Remove-Item -LiteralPath $stageRoot -Recurse -Force}
}
