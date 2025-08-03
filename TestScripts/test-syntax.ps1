# Simple syntax check for PowerShell files
param(
    [string[]]$Files = @()
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan
Write-Host "Unicode Support: $($psInfo.SupportsUnicode)" -ForegroundColor Cyan

Write-TestSection "PowerShell Syntax Check"

# Get root directory
$rootPath = Split-Path -Parent $PSScriptRoot

# Default files to check if none specified
if ($Files.Count -eq 0) {
    $Files = @(
        "$rootPath\main.ps1",
        "$rootPath\test.ps1"
    )
    
    # Add all function files
    $functionFiles = Get-ChildItem -Path "$rootPath\functions" -Filter '*.ps1' -Recurse | Select-Object -First 10 -ExpandProperty FullName
    $Files += $functionFiles
}

$totalFiles = 0
$passedFiles = 0

foreach ($file in $Files) {
    $totalFiles++
    $relativePath = $file -replace [regex]::Escape($rootPath), "."
    
    if (Test-Path $file) {
        Write-Host "Checking: $relativePath" -ForegroundColor Cyan
        try {
            $content = Get-Content $file -Raw
            $tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
            Write-TestResult "Syntax OK - $($tokens.Count) tokens" -Success $true
            $passedFiles++
        } catch {
            Write-TestResult "Syntax Error: $($_.Exception.Message)" -Success $false
        }
    } else {
        Write-TestResult "File not found: $relativePath" -Success $false
    }
}

Write-TestSection "Syntax Check Results"
Write-Host "Total files checked: $totalFiles" -ForegroundColor White
Write-Host "Passed: $passedFiles" -ForegroundColor Green
Write-Host "Failed: $($totalFiles - $passedFiles)" -ForegroundColor Red