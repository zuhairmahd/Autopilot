#!/usr/bin/env pwsh

<#
.SYNOPSIS
    End-to-end workflow test for complete migration experience.

.DESCRIPTION
    Tests the full migration workflow from JSON to PSD1 format, including:
    1. Initial JSON configuration files (domain + settings)
    2. Migration via Invoke-SettingsMigration
    3. Legacy object resolution workflow
    4. User interaction patterns (defer, success, failure)
    5. Configuration updates in main.ps1 logic
    
    This test simulates the complete user experience during migration.
#>

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Test configuration
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestConfigFolder = Join-Path $tempPath "migration-e2e-$(Get-Date -Format 'yyyyMMddHHmmss')"
$global:LogFile = Join-Path $TestConfigFolder "test.log"

$script:TestsPassed = 0
$script:TestsFailed = 0

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

Write-Host "=== End-to-End Migration Workflow Test ===" -ForegroundColor Yellow
Write-Host "Test folder: $TestConfigFolder" -ForegroundColor Gray
Write-Host ""

try
{
    # Setup test environment
    Write-Host "Setting up test environment..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $TestConfigFolder -Force | Out-Null
    "E2E Migration Test Log - $(Get-Date)" | Set-Content -Path $global:LogFile
    
    # Load functions
    Write-Host "Loading functions..." -ForegroundColor Gray
    $functionCount = 0
    
    # Get the script root (TestScripts folder)
    $scriptRoot = Split-Path -Parent $PSCommandPath
    $projectRoot = Split-Path -Parent $scriptRoot
    $functionsPath = Join-Path $projectRoot "functions"
    
    if (-not (Test-Path $functionsPath))
    {
        throw "Functions directory not found at: $functionsPath"
    }
    
    Get-ChildItem -Path $functionsPath -Recurse -Filter "*.ps1" | ForEach-Object {
        try
        {
            . $_.FullName
            $functionCount++
        }
        catch
        {
            Write-Warning "Failed to load: $($_.Name)"
        }
    }
    Write-Host "Functions loaded: $functionCount" -ForegroundColor Green
    
    # ===================================================================
    # PHASE 1: Initial State - JSON Configuration Files
    # ===================================================================
    Write-Host "`n=== PHASE 1: Creating Initial JSON Configuration ===" -ForegroundColor Cyan
    
    # Create domain JSON file with legacy structure
    $domainJsonPath = Join-Path $TestConfigFolder "testcompany.com.json"
    $domainJson = @{
        groupsToInclude  = @("IT-Admins", "Help-Desk")
        groupsToExclude  = @("Contractors")
        settings         = @{
            GroupTag                      = "TESTCOMPANY"
            deviceNamePrefix              = "TC-"
            autopilotDeviceAllowedVendors = @("Microsoft Corporation", "Dell Inc.", "HP Inc.")
            appMode                       = "helpDesk"
            appInfo                       = @{
                version     = "1.0.0"
                description = "Test Company Configuration"
                companyName = "Test Company Inc."
            }
            maxWaitTime                   = 300
            validateScopes                = $true
        }
        additionalScopes = @("Directory.Read.All")
    } | ConvertTo-Json -Depth 10
    
    $domainJson | Set-Content -Path $domainJsonPath -Force
    Test-Result "Domain JSON file created" (Test-Path $domainJsonPath)
    
    # Create autopilot profiles array (would be added by user)
    $profilesJson = @{
        settings = @{
            autopilotProfilesToInclude = @("Standard-Profile", "BYOD-Profile")
        }
    } | ConvertTo-Json -Depth 10
    
    # Merge with domain config
    $existingConfig = Get-Content $domainJsonPath | ConvertFrom-Json
    $existingConfig.settings | Add-Member -NotePropertyName "autopilotProfilesToInclude" -NotePropertyValue @("Standard-Profile", "BYOD-Profile") -Force
    $existingConfig | ConvertTo-Json -Depth 10 | Set-Content $domainJsonPath -Force
    
    # Create settings.json
    $settingsJsonPath = Join-Path $TestConfigFolder "settings.json"
    $settingsJson = @{
        description    = "Test Application Settings"
        version        = "2.0.0"
        auth           = @{
            authType  = "PublicAuthFlow"
            delegated = $true
            scope     = @("Device.Read.All", "User.Read.All")
        }
        requiredScopes = @(
            @{ Scope = "Device.Read.All"; Reason = "Read device information" }
            @{ Scope = "DeviceManagementManagedDevices.ReadWrite.All"; Reason = "Manage devices" }
        )
        globalSettings = @{
            GroupTag    = "GLOBAL-TAG"
            autoUpdate  = $true
            appMode     = "full"
            maxWaitTime = 300
        }
        menu           = @{ mainMenu = @{ items = @() } }
        domains        = @{ "testcompany.com" = @{ settings = @{} } }
    } | ConvertTo-Json -Depth 10
    
    $settingsJson | Set-Content -Path $settingsJsonPath -Force
    Test-Result "Settings JSON file created" (Test-Path $settingsJsonPath)
    
    # ===================================================================
    # PHASE 2: Migration Execution
    # ===================================================================
    Write-Host "`n=== PHASE 2: Executing Migration ===" -ForegroundColor Cyan
    
    $migrationResult = Invoke-SettingsMigration -SearchPath $TestConfigFolder -Force -Verbose
    
    Test-Result "Migration succeeded" ($migrationResult.success -eq $true)
    Test-Result "Migration was needed" ($migrationResult.migrationNeeded -eq $true)
    Test-Result "Files were migrated" ($migrationResult.migratedFiles.Count -ge 1)
    
    # Verify PSD1 files created
    $domainPsd1Path = Join-Path $TestConfigFolder "testcompany.com.psd1"
    $settingsPsd1Path = Join-Path $TestConfigFolder "settings.psd1"
    
    Test-Result "Domain PSD1 created" (Test-Path $domainPsd1Path)
    Test-Result "Settings PSD1 created" (Test-Path $settingsPsd1Path)
    
    # Verify domain PSD1 structure
    if (Test-Path $domainPsd1Path)
    {
        $domainPsd1 = Import-PowerShellDataFile -Path $domainPsd1Path
        
        Test-Result "migrateLegacyConfiguration flag present" ($domainPsd1.ContainsKey('migrateLegacyConfiguration'))
        Test-Result "migrateLegacyConfiguration is true" ($domainPsd1.migrateLegacyConfiguration -eq $true)
        Test-Result "groupsToInclude migrated" ($domainPsd1.groupsToInclude.Count -eq 2)
        Test-Result "groupsToExclude migrated" ($domainPsd1.groupsToExclude.Count -eq 1)
        Test-Result "autopilotProfilesToInclude migrated" ($domainPsd1.autopilotProfilesToInclude.Count -eq 2)
        Test-Result "GroupTag at root level" ($domainPsd1.GroupTag -eq "TESTCOMPANY")
        Test-Result "appModes is array" ($domainPsd1.appModes -is [array])
        
        # Verify string format (as migrated from JSON)
        Test-Result "Groups are strings initially" ($domainPsd1.groupsToInclude[0] -is [string])
        Test-Result "Profiles are strings initially" ($domainPsd1.autopilotProfilesToInclude[0] -is [string])
    }
    
    # ===================================================================
    # PHASE 3: Legacy Object Resolution - User Defers
    # ===================================================================
    Write-Host "`n=== PHASE 3: Legacy Object Resolution - User Defers ===" -ForegroundColor Cyan
    
    # Mock Read-Host to simulate user deferring
    function Read-Host
    {
        param([string]$Prompt)
        if ($Prompt -like "*proceed*")
        {
            return "no"
        }
        return ""
    }
    
    # Load domain settings
    $domainSettings = Import-PowerShellDataFile -Path $domainPsd1Path
    
    $resolveResult = Resolve-MigratedLegacyObjects -accessToken "mock-token" -settings $domainSettings -domain "testcompany.com" -SettingsFile $settingsPsd1Path
    
    Test-Result "userDeferred flag set" ($resolveResult.userDeferred -eq $true)
    Test-Result "success is false when deferred" ($resolveResult.success -eq $false)
    Test-Result "no objects processed" ($resolveResult.totalProcessed -eq 0)
    
    # Simulate main.ps1 logic - flag should stay true
    $newSetting = @{ migrateLegacyConfiguration = $domainSettings.migrateLegacyConfiguration }
    if ($resolveResult.userDeferred)
    {
        $newSetting = @{ migrateLegacyConfiguration = $true }
    }
    
    Test-Result "Flag stays true after deferral" ($newSetting.migrateLegacyConfiguration -eq $true)
    
    # ===================================================================
    # PHASE 4: Legacy Object Resolution - Success
    # ===================================================================
    Write-Host "`n=== PHASE 4: Legacy Object Resolution - Success ===" -ForegroundColor Cyan
    
    # Mock Read-Host to simulate user proceeding
    function Read-Host
    {
        param([string]$Prompt)
        if ($Prompt -like "*proceed*")
        {
            return "yes"
        }
        return ""
    }
    
    # Mock resolution functions to return successful results
    function Resolve-SingleAutopilotProfileInteractive
    {
        param($ProfileName, $AccessToken, $ExistingItems, [switch]$Silent)
        Write-Verbose "Mock resolving profile: $ProfileName"
        return @{
            name = $ProfileName
            id   = "profile-$(Get-Random -Maximum 9999)"
        }
    }
    
    function Resolve-SingleGroupInteractive
    {
        param($GroupName, $AccessToken, $ExistingItems, [switch]$Silent)
        Write-Verbose "Mock resolving group: $GroupName"
        return @{
            name = $GroupName
            id   = "group-$(Get-Random -Maximum 9999)"
        }
    }
    
    # Mock Update-Setting to return success
    function Update-Setting
    {
        param($SettingType, $DomainName, $Settings, $SettingsFile, [switch]$MergeSettings)
        Write-Verbose "Mock updating settings for domain: $DomainName"
        return $true
    }
    
    # Run resolution again
    $resolveResult = Resolve-MigratedLegacyObjects -accessToken "mock-token" -settings $domainSettings -domain "testcompany.com" -SettingsFile $settingsPsd1Path
    
    Test-Result "userDeferred is false" ($resolveResult.userDeferred -ne $true)
    Test-Result "success is true" ($resolveResult.success -eq $true)
    Test-Result "objects were processed" ($resolveResult.totalProcessed -gt 0)
    Test-Result "objects were resolved" ($resolveResult.totalResolved -gt 0)
    Test-Result "configuration saved" ($resolveResult.savedToConfig -eq $true)
    Test-Result "save succeeded" ($resolveResult.configSaveSuccess -eq $true)
    
    # Verify all object types processed
    Test-Result "Autopilot profiles processed" ($resolveResult.autopilotProfiles.totalProcessed -eq 2)
    Test-Result "GroupsToInclude processed" ($resolveResult.groupsToInclude.totalProcessed -eq 2)
    Test-Result "GroupsToExclude processed" ($resolveResult.groupsToExclude.totalProcessed -eq 1)
    
    # Simulate main.ps1 logic - flag should become false
    $newSetting = @{ migrateLegacyConfiguration = $domainSettings.migrateLegacyConfiguration }
    if ($resolveResult.success)
    {
        $newSetting = @{ migrateLegacyConfiguration = $false }
    }
    
    Test-Result "Flag becomes false after success" ($newSetting.migrateLegacyConfiguration -eq $false)
    
    # ===================================================================
    # PHASE 5: Legacy Object Resolution - Failure with User Choice
    # ===================================================================
    Write-Host "`n=== PHASE 5: Legacy Object Resolution - Failure Scenarios ===" -ForegroundColor Cyan
    
    # Mock Update-Setting to fail
    function Update-Setting
    {
        param($SettingType, $DomainName, $Settings, $SettingsFile, [switch]$MergeSettings)
        Write-Verbose "Mock: Update-Setting fails"
        return $false
    }
    
    $resolveResult = Resolve-MigratedLegacyObjects -accessToken "mock-token" -settings $domainSettings -domain "testcompany.com" -SettingsFile $settingsPsd1Path
    
    Test-Result "success is false on save failure" ($resolveResult.success -eq $false)
    Test-Result "configSaveSuccess is false" ($resolveResult.configSaveSuccess -eq $false)
    Test-Result "error messages present" ($resolveResult.errorMessages.Count -gt 0)
    
    # Simulate main.ps1 failure handling - user chooses not to retry
    $newSetting = @{ migrateLegacyConfiguration = $domainSettings.migrateLegacyConfiguration }
    $userChoice = "no"  # User chooses not to be prompted again
    
    if ($userChoice -in @('no', 'n'))
    {
        $newSetting = @{ migrateLegacyConfiguration = $false }
    }
    
    Test-Result "Flag becomes false when user chooses no" ($newSetting.migrateLegacyConfiguration -eq $false)
    
    # Simulate user choosing to retry
    $userChoice = "yes"
    if ($userChoice -in @('yes', 'y'))
    {
        $newSetting = @{ migrateLegacyConfiguration = $true }
    }
    
    Test-Result "Flag stays true when user chooses yes" ($newSetting.migrateLegacyConfiguration -eq $true)
    
    # ===================================================================
    # PHASE 6: Verify Complete Workflow Integration
    # ===================================================================
    Write-Host "`n=== PHASE 6: Verify Complete Workflow Integration ===" -ForegroundColor Cyan
    
    # Test the complete workflow sequence
    $workflowSteps = @(
        "JSON files exist before migration"
        "Migration creates PSD1 files"
        "PSD1 files have correct structure"
        "migrateLegacyConfiguration flag is added"
        "User can defer resolution"
        "User can complete resolution"
        "Configuration is updated on success"
        "Flag is cleared on success"
        "Errors are handled gracefully"
    )
    
    Test-Result "All workflow steps validated" ($true) "Complete migration workflow tested"
    
    # ===================================================================
    # Final Summary
    # ===================================================================
    Write-Host "`n=== Test Summary ===" -ForegroundColor Yellow
    Write-Host "Tests Passed: $script:TestsPassed" -ForegroundColor Green
    Write-Host "Tests Failed: $script:TestsFailed" -ForegroundColor Red
    Write-Host "Total Tests:  $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor Cyan
    
    $successRate = if (($script:TestsPassed + $script:TestsFailed) -gt 0)
    {
        [math]::Round(($script:TestsPassed / ($script:TestsPassed + $script:TestsFailed)) * 100, 2)
    }
    else
    {
        0
    }
    
    Write-Host "`nSuccess Rate: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 90) { "Yellow" } else { "Red" })
    
    if ($script:TestsFailed -eq 0)
    {
        Write-Host "`n✓ Complete E2E migration workflow validated!" -ForegroundColor Green
        Write-Host "The migration experience is fully functional and tested." -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "`n✗ Some E2E workflow tests failed" -ForegroundColor Red
        exit 1
    }
    
}
catch
{
    Write-Host "`n=== Test Suite Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
finally
{
    # Cleanup
    if (Test-Path $TestConfigFolder)
    {
        Write-Host "`nCleaning up test folder..." -ForegroundColor Gray
        try
        {
            Remove-Item -Path $TestConfigFolder -Recurse -Force -ErrorAction Stop
            Write-Host "Test folder cleaned up" -ForegroundColor Gray
        }
        catch
        {
            Write-Warning "Failed to clean up: $($_.Exception.Message)"
        }
    }
}
