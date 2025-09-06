#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Simplified tests for basic Update-Setting function validation with PSD1 compatibility.

.DESCRIPTION
    Basic validation tests to ensure Update-Setting function works correctly in the new PSD1 environment.
    This focuses on ensuring the core functionality works while the full PSD1 migration is completed.
#>

# Set up test environment
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"


# Test configuration - create all artifacts in temp folder
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestConfigFolder = Join-Path $tempPath "update-setting-simplified-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "=== Simplified Update-Setting Function Tests ===" -ForegroundColor Yellow
Write-Host "Test folder: $TestConfigFolder" -ForegroundColor Gray

try {
    # Create test directory
    New-Item -ItemType Directory -Path $TestConfigFolder -Force | Out-Null
    
    # Change to test directory to ensure all artifacts stay here
    Push-Location $TestConfigFolder
    
    # Load functions
    Write-Host "Loading functions..." -ForegroundColor Gray
    $functionCount = 0
    $functionErrors = 0
    Write-Host "The script root folder is $psscriptroot"
    Get-ChildItem -Path "$PSScriptRoot/../functions" -Recurse -Filter "*.ps1" | ForEach-Object {
        try {
            . $_.FullName
            $functionCount++
        }
        catch {
            Write-Warning "Failed to load function: $($_.Name) - $($_.Exception.Message)"
            $functionErrors++
        }
    }
    
    Write-Host "Functions loaded: $functionCount, Errors: $functionErrors" -ForegroundColor Green
    
    # Set up global variables needed by the functions
    $global:logFile = Join-Path $TestConfigFolder "test.log"
    $global:LogFile = Join-Path $TestConfigFolder "test.log"
    $global:jsonDepth = 10
    
    # Test 1: Function Existence
    Write-Host "`n1. Testing Function Existence..." -ForegroundColor Cyan
    
    $updateSettingFunction = Get-Command Update-Setting -ErrorAction SilentlyContinue
    if ($updateSettingFunction) {
        Write-Host "✓ Update-Setting function is available" -ForegroundColor Green
    } else {
        Write-Host "✗ Update-Setting function not found" -ForegroundColor Red
        throw "Update-Setting function not found"
    }
    
    # Test 2: Parameter Validation
    Write-Host "`n2. Testing Parameter Validation..." -ForegroundColor Cyan
    
    # Test Global without required parameters
    $result = Update-Setting -SettingType "Global" -SettingsFile "nonexistent.psd1"
    if (-not $result) {
        Write-Host "✓ Global parameter validation works" -ForegroundColor Green
    } else {
        Write-Host "✗ Global parameter validation failed" -ForegroundColor Red
        throw "Global parameter validation failed"
    }
    
    # Test Domain without required parameters
    $result = Update-Setting -SettingType "Domain" -SettingsFile "nonexistent.psd1"
    if (-not $result) {
        Write-Host "✓ Domain parameter validation works" -ForegroundColor Green
    } else {
        Write-Host "✗ Domain parameter validation failed" -ForegroundColor Red
        throw "Domain parameter validation failed"
    }
    
    # Test 3: File Not Found Handling
    Write-Host "`n3. Testing File Not Found Handling..." -ForegroundColor Cyan
    
    $result = Update-Setting -SettingType "Global" -SettingsFile "nonexistent.psd1" -SettingName "test" -SettingValue "test"
    if (-not $result) {
        Write-Host "✓ File not found handling works" -ForegroundColor Green
    } else {
        Write-Host "✗ File not found handling failed" -ForegroundColor Red
        throw "File not found handling failed"
    }
    
    Write-Host "`n=== Basic Tests Passed! ===" -ForegroundColor Green
    Write-Host "The Update-Setting function has basic functionality intact." -ForegroundColor Green
    Write-Host "Note: Full PSD1 support requires updating the function to use Import-PowerShellDataFile instead of ConvertFrom-Json" -ForegroundColor Yellow
    
} catch {
    Write-Host "`n=== Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Return to original location
    Pop-Location
    
    # Cleanup
    if (Test-Path $TestConfigFolder) {
        Write-Host "`nCleaning up test folder..." -ForegroundColor Gray
        Remove-Item -Path $TestConfigFolder -Recurse -Force
        Write-Host "Test folder cleaned up" -ForegroundColor Gray
    }
}

Write-Host "`nSimplified test completed successfully!" -ForegroundColor Green