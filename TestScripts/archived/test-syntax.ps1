# Comprehensive syntax check for PowerShell files using robust parser
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
        "$rootPath\test.ps1",
        "$rootPath\CreateRelease.ps1"
    )
    
    # Add ALL function files (not just first 10)
    $functionFiles = Get-ChildItem -Path "$rootPath\functions" -Filter '*.ps1' -Recurse | Select-Object -ExpandProperty FullName
    $Files += $functionFiles
    
    # Add test scripts
    $testFiles = Get-ChildItem -Path "$rootPath\TestScripts" -Filter '*.ps1' -Recurse | Select-Object -ExpandProperty FullName
    $Files += $testFiles
}

$totalFiles = 0
$passedFiles = 0
$errorDetails = @()

foreach ($file in $Files) {
    $totalFiles++
    $relativePath = $file -replace [regex]::Escape($rootPath), "."
    
    if (Test-Path $file) {
        Write-Host "Checking: $relativePath" -ForegroundColor Cyan
        try {
            $content = Get-Content $file -Raw -ErrorAction Stop
            
            # Use the more robust Language.Parser for better syntax checking
            $parseErrors = @()
            $tokens = @()
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$parseErrors)
            
            if ($parseErrors.Count -gt 0) {
                $errorMsg = "Parse errors found: " + ($parseErrors | ForEach-Object { "$($_.Message) (Line: $($_.Extent.StartLineNumber))" }) -join "; "
                Write-TestResult $errorMsg -Success $false
                $errorDetails += @{
                    File = $relativePath
                    Errors = $parseErrors
                }
            } else {
                Write-TestResult "Syntax OK - $($tokens.Count) tokens, $($ast.GetType().Name)" -Success $true
                $passedFiles++
            }
        } catch {
            Write-TestResult "Syntax Error: $($_.Exception.Message)" -Success $false
            $errorDetails += @{
                File = $relativePath
                Errors = @($_.Exception.Message)
            }
        }
    } else {
        Write-TestResult "File not found: $relativePath" -Success $false
        $errorDetails += @{
            File = $relativePath
            Errors = @("File not found")
        }
    }
}

Write-TestSection "Syntax Check Results"
Write-Host "Total files checked: $totalFiles" -ForegroundColor White
Write-Host "Passed: $passedFiles" -ForegroundColor Green
Write-Host "Failed: $($totalFiles - $passedFiles)" -ForegroundColor Red

# Display detailed error information if any failures occurred
if ($errorDetails.Count -gt 0) {
    Write-TestSection "Error Details"
    foreach ($errorItem in $errorDetails) {
        Write-Host "File: $($errorItem.File)" -ForegroundColor Yellow
        foreach ($err in $errorItem.Errors) {
            if ($err -is [System.Management.Automation.Language.ParseError]) {
                Write-Host "  Error: $($err.Message)" -ForegroundColor Red
                Write-Host "  Line: $($err.Extent.StartLineNumber), Column: $($err.Extent.StartColumnNumber)" -ForegroundColor Red
                Write-Host "  Text: $($err.Extent.Text)" -ForegroundColor Red
            } else {
                Write-Host "  Error: $err" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
}

# Exit with error code if any files failed
if ($passedFiles -ne $totalFiles) {
    exit 1
}