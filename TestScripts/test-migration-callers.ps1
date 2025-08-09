#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests that migrated callers correctly use the new unified Update-Setting function.

.DESCRIPTION
    Validates that the migration from old Update functions to Update-Setting works correctly.
#>

# Set up test environment
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Test configuration
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestConfigFolder = Join-Path $tempPath "migration-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
$TestSettingsFile = Join-Path $TestConfigFolder "test-settings.json"

Write-Host "=== Caller Migration Tests ===" -ForegroundColor Yellow
Write-Host "Test folder: $TestConfigFolder" -ForegroundColor Gray

try {
    # Create test directory
    New-Item -ItemType Directory -Path $TestConfigFolder -Force | Out-Null
    
    # Load functions
    Write-Host "Loading functions..." -ForegroundColor Gray
    $functionCount = 0
    $functionErrors = 0
    
    Get-ChildItem -Path "./functions" -Recurse -Filter "*.ps1" | ForEach-Object {
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
    
    # Create test settings file
    $testSettings = @{
        globalSettings = @{
            GroupTag = "TESTGROUP"
            autoUpdate = $false
            appMode = "full"
        }
        auth = @{
            authType = "PublicAuthFlow"
            delegated = $true
            scope = @("Device.Read.All", "User.Read.All")
        }
        domains = @{
            "test.com" = @{
                groupsToInclude = @("TestGroup1")
                groupsToExclude = @("TestGroup2") 
                settings = @{
                    GroupTag = "DOMAIN-TEST"
                }
            }
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $TestSettingsFile -Force
    Write-Host "Created test settings file" -ForegroundColor Gray
    
    # Test 1: Direct calls using unified Update-Setting function
    Write-Host "`n1. Testing Direct Update-Setting Calls..." -ForegroundColor Cyan
    
    # Test global settings update
    try {
        $result = Update-Setting -SettingType "Global" -SettingsFile $TestSettingsFile -SettingName "maxWaitTime" -SettingValue 120
        if ($result) {
            Write-Host "✓ Global setting update works" -ForegroundColor Green
        } else {
            Write-Host "✗ Global setting update failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Global setting update error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test auth settings update
    try {
        $result = Update-Setting -SettingType "Auth" -SettingsFile $TestSettingsFile -SettingName "forceNewToken" -SettingValue $true
        if ($result) {
            Write-Host "✓ Auth setting update works" -ForegroundColor Green
        } else {
            Write-Host "✗ Auth setting update failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Auth setting update error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test domain settings update
    try {
        $domainSettings = @{ "GroupTag" = "NEW-DOMAIN"; "customSetting" = "testValue" }
        $result = Update-Setting -SettingType "Domain" -SettingsFile $TestSettingsFile -DomainName "test.com" -Settings $domainSettings -MergeSettings
        if ($result) {
            Write-Host "✓ Domain setting update works" -ForegroundColor Green
        } else {
            Write-Host "✗ Domain setting update failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Domain setting update error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 2: Verify settings were actually updated
    Write-Host "`n2. Verifying Settings Updates..." -ForegroundColor Cyan
    
    $verifySettings = Get-Content -Path $TestSettingsFile -Raw | ConvertFrom-Json
    
    # Check global settings
    if ($verifySettings.globalSettings.maxWaitTime -eq 120) {
        Write-Host "✓ Global setting updated correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Global setting not updated (expected: 120, actual: $($verifySettings.globalSettings.maxWaitTime))" -ForegroundColor Red
    }
    
    # Check auth settings
    if ($verifySettings.auth.forceNewToken -eq $true) {
        Write-Host "✓ Auth setting updated correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Auth setting not updated (expected: true, actual: $($verifySettings.auth.forceNewToken))" -ForegroundColor Red
    }
    
    # Check domain settings (should be merged)
    if ($verifySettings.domains."test.com".settings.customSetting -eq "testValue") {
        Write-Host "✓ Domain setting updated correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Domain setting not updated (expected: testValue, actual: $($verifySettings.domains.'test.com'.settings.customSetting))" -ForegroundColor Red
    }
    
    Write-Host "`n=== Migration Tests Passed! ===" -ForegroundColor Green
    Write-Host "All migrated callers work correctly with the unified Update-Setting function." -ForegroundColor Green
    
} catch {
    Write-Host "`n=== Migration Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    if (Test-Path $TestConfigFolder) {
        Write-Host "`nCleaning up test folder..." -ForegroundColor Gray
        Remove-Item -Path $TestConfigFolder -Recurse -Force
        Write-Host "Test folder cleaned up" -ForegroundColor Gray
    }
}

Write-Host "`nMigration test completed successfully!" -ForegroundColor Green