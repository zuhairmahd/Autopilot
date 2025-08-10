#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple function loading test to debug scoping issues
.DESCRIPTION
    This test loads functions directly using the same pattern as main.ps1
    to validate that the functions are accessible
#>

[CmdletBinding()]
param()

Write-Host "=== Simple Function Loading Test ===" -ForegroundColor Cyan

# Minimal environment initialization for tests that rely on Write-Log
$logsFolder = Join-Path $PWD "Logs"
if (-not (Test-Path $logsFolder)) {
    New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
}
$global:logFile = Join-Path $logsFolder "simple-function-loading.log"

# Load functions using the same pattern as main.ps1
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder) {
    Write-Host "Loading functions from $functionsFolder" -ForegroundColor Yellow
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    
    $loadedCount = 0
    foreach ($function in $functions) {
        try {
            Write-Verbose "Loading function $function"
            . $function.FullName
            $loadedCount++
        }
        catch {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
    
    Write-Host "Loaded $loadedCount functions" -ForegroundColor Green
} else {
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}

# Test specific functions
Write-Host "`n=== Testing Function Availability ===" -ForegroundColor Cyan

$testFunctions = @(
    "Write-Log",
    "Test-SettingsJsonExists", 
    "Test-MenuItemIncluded",
    "InitializeConfiguration",
    "MergeSettings"
)

$available = 0
foreach ($functionName in $testFunctions) {
    $cmd = Get-Command $functionName -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✓ $functionName is available" -ForegroundColor Green
        $available++
    } else {
        Write-Host "✗ $functionName is NOT available" -ForegroundColor Red
    }
}

Write-Host "`nResult: $available/$($testFunctions.Count) functions available" -ForegroundColor Cyan

# Test a simple function call
if (Get-Command "Test-MenuItemIncluded" -ErrorAction SilentlyContinue) {
    try {
        $result = Test-MenuItemIncluded -MenuItemName "Test" -Menus $null
        Write-Host "✓ Test-MenuItemIncluded executed successfully (result: $result)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Test-MenuItemIncluded failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

exit 0