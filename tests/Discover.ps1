. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Runtime.ps1')
Get-ProxyCandidates | ConvertTo-Json
