$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
Import-Module Pester
Invoke-Pester -Path (Join-Path $PSScriptRoot 'main.Tests.ps1') -CodeCoverage (Join-Path $repoRoot 'main.ps1')
