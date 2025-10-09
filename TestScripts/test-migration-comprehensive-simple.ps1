#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Simplified comprehensive migration tests - expects functions to be pre-loaded.

.DESCRIPTION
    This test script assumes all application functions have been loaded by the test harness.
    It focuses on test execution rather than function loading.
#>

$ErrorActionPreference = "Stop"

# Test configuration
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestConfigFolder = Join-Path $tempPath "migration-comprehensive-$(Get-Date -Format 'yyyyMMddHHmmss')"
$TestSettingsFile = Join-Path $TestConfigFolder "settings.psd1"

# Use global log file if set by harness, otherwise create local one
if (-not $global:LogFile)
{
    $global:LogFile = Join-Path $TestConfigFolder "test.log"
}

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

function Test-Result
{
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailureMessage = ""
    )
    
    if ($Condition)
    {
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $script:TestsPassed++
        return $true
    }
    else
    {
        Write-Host "  ✗ $TestName" -ForegroundColor Red
        if ($FailureMessage)
        {
            Write-Host "    $FailureMessage" -ForegroundColor Yellow
        }
        $script:TestsFailed++
        return $false
    }
}

Write-Host "Setting up test environment..." -ForegroundColor Yellow

# Create test directory
if (Test-Path $TestConfigFolder)
{
    Remove-Item -Path $TestConfigFolder -Recurse -Force
}
New-Item -ItemType Directory -Path $TestConfigFolder -Force | Out-Null

# Initialize log file
"Migration Comprehensive Test Log - $(Get-Date)" | Set-Content -Path $global:LogFile

Write-Host "  Test folder: $TestConfigFolder" -ForegroundColor Gray
Write-Host ""

try
{
    # ===================================================================
    # TEST 1: Invoke-SettingsMigration - Domain File Migration
    # ===================================================================
    Write-Host "Test 1: Domain File Migration" -ForegroundColor Cyan
    
    # Create test JSON file
    $domainJsonPath = Join-Path $TestConfigFolder "contoso.com.json"
    $domainJson = @{
        groupsToInclude   = @("IT-Admins", "Help-Desk")
        groupsToExclude   = @("External-Users")
        autopilotProfiles = @("Standard-Profile")
        appMode           = "full"
    }
    $domainJson | ConvertTo-Json -Depth 10 | Set-Content -Path $domainJsonPath
    
    # Run migration
    $migrationResult = Invoke-SettingsMigration -SearchPath $TestConfigFolder -Force -RemoveJsonFiles:$false
    
    Test-Result -TestName "Migration reported success" -Condition ($migrationResult.success -eq $true)
    Test-Result -TestName "Migration was needed" -Condition ($migrationResult.migrationNeeded -eq $true)
    Test-Result -TestName "Domain PSD1 file created" -Condition (Test-Path (Join-Path $TestConfigFolder "contoso.com.psd1"))
    
    # Load and verify PSD1 structure
    $domainPsd1Path = Join-Path $TestConfigFolder "contoso.com.psd1"
    if (Test-Path $domainPsd1Path)
    {
        $domainPsd1 = Import-PowerShellDataFile -Path $domainPsd1Path
        Test-Result -TestName "PSD1 has migrateLegacyConfiguration flag" -Condition ($domainPsd1.ContainsKey('migrateLegacyConfiguration') -and $domainPsd1.migrateLegacyConfiguration -eq $true)
        Test-Result -TestName "PSD1 has groupsToInclude array" -Condition ($domainPsd1.ContainsKey('groupsToInclude') -and $domainPsd1.groupsToInclude.Count -eq 2)
        Test-Result -TestName "PSD1 converted appMode to appModes array" -Condition ($domainPsd1.ContainsKey('appModes') -and $domainPsd1.appModes -is [array])
    }
    
    Write-Host ""
    
    # ===================================================================
    # TEST 2: Settings.json Migration
    # ===================================================================
    Write-Host "Test 2: Settings.json Migration" -ForegroundColor Cyan
    
    $settingsJsonPath = Join-Path $TestConfigFolder "settings.json"
    $settingsJson = @{
        auth           = @{
            authType = "certificate"
            appId    = "12345"
        }
        requiredScopes = @("DeviceManagementManagedDevices.ReadWrite.All")
        globalSettings = @{
            appMode = "full"
        }
        menu           = @{
            mainMenu = @{ }
        }
        domains        = @{
            "contoso.com" = @{ }
        }
    }
    $settingsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsJsonPath
    
    $settingsMigrationResult = Invoke-SettingsMigration -SearchPath $TestConfigFolder -Force -RemoveJsonFiles:$false
    
    Test-Result -TestName "Settings migration succeeded" -Condition ($settingsMigrationResult.success -eq $true)
    
    $settingsPsd1Path = Join-Path $TestConfigFolder "settings.psd1"
    if (Test-Path $settingsPsd1Path)
    {
        $settingsPsd1 = Import-PowerShellDataFile -Path $settingsPsd1Path
        Test-Result -TestName "Settings PSD1 preserved auth" -Condition ($settingsPsd1.ContainsKey('auth'))
        Test-Result -TestName "Settings PSD1 preserved requiredScopes" -Condition ($settingsPsd1.ContainsKey('requiredScopes'))
        Test-Result -TestName "Settings PSD1 removed menu" -Condition (-not $settingsPsd1.ContainsKey('menu'))
        Test-Result -TestName "Settings PSD1 removed domains" -Condition (-not $settingsPsd1.ContainsKey('domains'))
    }
    
    Write-Host ""
    
    # ===================================================================
    # TEST 3: Resolve-MigratedLegacyObjects - User Defers
    # ===================================================================
    Write-Host "Test 3: Legacy Object Resolution - User Defers" -ForegroundColor Cyan
    
    # Create a test PSD1 with legacy objects
    $testDomainPsd1 = Join-Path $TestConfigFolder "test-domain.psd1"
    @"
@{
    migrateLegacyConfiguration = `$true
    autopilotProfiles = @('Profile1', 'Profile2')
    groupsToInclude = @('Group1')
}
"@ | Set-Content -Path $testDomainPsd1
    
    # Mock Read-Host to simulate user deferring
    function global:Read-Host
    {
        param($Prompt)
        if ($Prompt -like "*continue*" -or $Prompt -like "*proceed*")
        {
            return 'no'
        }
        return ''
    }
    
    # Mock Get-EntraDirectoryObject to avoid real Graph calls
    function global:Get-EntraDirectoryObject
    {
        param($EntityType, $EntityName, $AccessToken, [switch]$findSimilar)
        return @{
            value = @(
                @{ displayName = $EntityName; id = "test-id-$(Get-Random)" }
            )
        }, $false
    }
    
    $resolveResult = Resolve-MigratedLegacyObjects -SettingsFile $testDomainPsd1 -AccessToken "test-token"
    
    Test-Result -TestName "User deferral returned userDeferred=true" -Condition ($resolveResult.userDeferred -eq $true)
    Test-Result -TestName "User deferral did not resolve objects" -Condition ($resolveResult.totalProcessed -eq 0)
    
    Write-Host ""
    
    # ===================================================================
    # Display Results
    # ===================================================================
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Test Results" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Passed:  $script:TestsPassed" -ForegroundColor Green
    Write-Host "Failed:  $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Skipped: $script:TestsSkipped" -ForegroundColor Gray
    
    $successRate = if (($script:TestsPassed + $script:TestsFailed) -gt 0)
    {
        [math]::Round(($script:TestsPassed / ($script:TestsPassed + $script:TestsFailed)) * 100, 2)
    }
    else { 0 }
    
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { 'Green' } elseif ($successRate -ge 80) { 'Yellow' } else { 'Red' })
    Write-Host ""
    
    if ($script:TestsFailed -eq 0)
    {
        Write-Host "All tests passed!" -ForegroundColor Green
    }
    else
    {
        Write-Host "Some tests failed. Review output above." -ForegroundColor Red
    }
    
}
catch
{
    Write-Host "Test suite failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    exit 1
}
finally
{
    # Cleanup
    Write-Host "Cleaning up test folder..." -ForegroundColor Gray
    if (Test-Path $TestConfigFolder)
    {
        Remove-Item -Path $TestConfigFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Test folder cleaned up" -ForegroundColor Gray
}

exit $(if ($script:TestsFailed -eq 0) { 0 } else { 1 })
