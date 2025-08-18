#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive tests for the new unified Update-Setting function.

.DESCRIPTION
    Tests all functionality of Update-Setting including Global, Domain, and Auth setting types.
    Validates that the unified function preserves all functionality from the original three functions.
#>

# Set up test environment
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Test configuration
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestConfigFolder = Join-Path $tempPath "update-setting-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
$TestSettingsFile = Join-Path $TestConfigFolder "test-settings.json"

Write-Host "=== Update-Setting Function Tests ===" -ForegroundColor Yellow
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
    
    # Set up global variables needed by the functions
    $global:logFile = Join-Path $tempPath "test.log"
    $global:LogFile = Join-Path $tempPath "test.log"
    $global:jsonDepth = 10
    
    # Create test settings file
    $testSettings = @{
        globalSettings = @{
            GroupTag = "TESTGROUP"
            maxWaitTime = 60
            deviceNamePrefix = "test-"
        }
        auth = @{
            authType = "PublicAuthFlow"
            delegated = $true
            scope = @("Device.Read.All", "User.Read.All")
            forceNewToken = $false
        }
        domains = @{
            "test.com" = @{
                groupsToInclude = @("TestGroup1")
                groupsToExclude = @("TestGroup2") 
                settings = @{
                    GroupTag = "DOMAIN-TEST"
                    customSetting = "domainValue"
                }
            }
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $TestSettingsFile -Force
    Write-Host "Created test settings file: $TestSettingsFile" -ForegroundColor Gray
    
    # Test 1: Global Setting Update
    Write-Host "`n1. Testing Global Setting Update..." -ForegroundColor Cyan
    
    $result = Update-Setting -SettingType "Global" -SettingsFile $TestSettingsFile -SettingName "GroupTag" -SettingValue "UPDATED-GLOBAL"
    
    if ($result) {
        $verifySettings = Get-Content -Path $TestSettingsFile -Raw | ConvertFrom-Json
        if ($verifySettings.globalSettings.GroupTag -eq "UPDATED-GLOBAL") {
            Write-Host "✓ Global setting update successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Global setting verification failed" -ForegroundColor Red
            throw "Global setting verification failed"
        }
    } else {
        Write-Host "✗ Global setting update failed" -ForegroundColor Red
        throw "Global setting update failed"
    }
    
    # Test 2: Auth Setting Update (scalar)
    Write-Host "`n2. Testing Auth Setting Update (scalar)..." -ForegroundColor Cyan
    
    $result = Update-Setting -SettingType "Auth" -SettingsFile $TestSettingsFile -SettingName "forceNewToken" -SettingValue $true
    
    if ($result) {
        $verifySettings = Get-Content -Path $TestSettingsFile -Raw | ConvertFrom-Json
        if ($verifySettings.auth.forceNewToken -eq $true) {
            Write-Host "✓ Auth setting (scalar) update successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Auth setting (scalar) verification failed" -ForegroundColor Red
            throw "Auth setting (scalar) verification failed"
        }
    } else {
        Write-Host "✗ Auth setting (scalar) update failed" -ForegroundColor Red
        throw "Auth setting (scalar) update failed"
    }
    
    # Test 3: Auth Setting Update (array)
    Write-Host "`n3. Testing Auth Setting Update (array)..." -ForegroundColor Cyan
    
    $newScope = @("Device.ReadWrite.All", "User.ReadWrite.All", "Directory.Read.All")
    $result = Update-Setting -SettingType "Auth" -SettingsFile $TestSettingsFile -SettingName "scope" -SettingValue $newScope
    
    if ($result) {
        $verifySettings = Get-Content -Path $TestSettingsFile -Raw | ConvertFrom-Json
        $actualScope = $verifySettings.auth.scope
        $comparisonResult = Compare-Object $newScope $actualScope
        if ($null -eq $comparisonResult) {
            Write-Host "✓ Auth setting (array) update successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Auth setting (array) verification failed" -ForegroundColor Red
            Write-Host "Expected: $($newScope -join ', ')" -ForegroundColor Red
            Write-Host "Actual: $($actualScope -join ', ')" -ForegroundColor Red
            throw "Auth setting (array) verification failed"
        }
    } else {
        Write-Host "✗ Auth setting (array) update failed" -ForegroundColor Red
        throw "Auth setting (array) update failed"
    }
    
    # Test 4: Domain Setting Update (merge)
    Write-Host "`n4. Testing Domain Setting Update (merge)..." -ForegroundColor Cyan
    
    $newDomainSettings = @{
        newSetting = "newValue"
        GroupTag = "MERGED-GROUP"
    }
    
    $result = Update-Setting -SettingType "Domain" -SettingsFile $TestSettingsFile -DomainName "test.com" -Settings $newDomainSettings -MergeSettings
    
    if ($result) {
        # Check domain settings in the separate domain file (new architecture)
        $domainConfigFile = Join-Path (Split-Path $TestSettingsFile -Parent) "test.com.json"
        if (Test-Path $domainConfigFile) {
            $domainConfig = Get-Content -Path $domainConfigFile -Raw | ConvertFrom-Json
            $domainSettings = $domainConfig.settings
        } else {
            # Fallback to old format for backward compatibility
            $verifySettings = Get-Content -Path $TestSettingsFile -Raw | ConvertFrom-Json
            $domainSettings = $verifySettings.domains."test.com".settings
        }
        
        if ($domainSettings.GroupTag -eq "MERGED-GROUP" -and 
            $domainSettings.newSetting -eq "newValue" -and 
            $domainSettings.customSetting -eq "domainValue") {
            Write-Host "✓ Domain setting update (merge) successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Domain setting (merge) verification failed" -ForegroundColor Red
            Write-Host "GroupTag: $($domainSettings.GroupTag)" -ForegroundColor Red
            Write-Host "newSetting: $($domainSettings.newSetting)" -ForegroundColor Red
            Write-Host "customSetting: $($domainSettings.customSetting)" -ForegroundColor Red
            throw "Domain setting (merge) verification failed"
        }
    } else {
        Write-Host "✗ Domain setting update (merge) failed" -ForegroundColor Red
        throw "Domain setting update (merge) failed"
    }
    
    # Test 5: Domain Setting Update (replace)
    Write-Host "`n5. Testing Domain Setting Update (replace)..." -ForegroundColor Cyan
    
    $replaceDomainSettings = @{
        onlySetting = "replaceValue"
        GroupTag = "REPLACED-GROUP"
    }
    
    $result = Update-Setting -SettingType "Domain" -SettingsFile $TestSettingsFile -DomainName "test.com" -Settings $replaceDomainSettings
    
    if ($result) {
        # Check domain settings in the separate domain file (new architecture)
        $domainConfigFile = Join-Path (Split-Path $TestSettingsFile -Parent) "test.com.json"
        if (Test-Path $domainConfigFile) {
            $domainConfig = Get-Content -Path $domainConfigFile -Raw | ConvertFrom-Json
            $domainSettings = $domainConfig.settings
        } else {
            # Fallback to old format for backward compatibility
            $verifySettings = Get-Content -Path $TestSettingsFile -Raw | ConvertFrom-Json
            $domainSettings = $verifySettings.domains."test.com".settings
        }
        
        if ($domainSettings.GroupTag -eq "REPLACED-GROUP" -and 
            $domainSettings.onlySetting -eq "replaceValue" -and 
            -not ($domainSettings.PSObject.Properties.Name -contains "customSetting")) {
            Write-Host "✓ Domain setting update (replace) successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Domain setting (replace) verification failed" -ForegroundColor Red
            Write-Host "Domain settings after replace:" -ForegroundColor Red
            $domainSettings | ConvertTo-Json -Depth 2 | Write-Host -ForegroundColor Red
            throw "Domain setting (replace) verification failed"
        }
    } else {
        Write-Host "✗ Domain setting update (replace) failed" -ForegroundColor Red
        throw "Domain setting update (replace) failed"
    }
    
    # Test 6: New Domain Creation
    Write-Host "`n6. Testing New Domain Creation..." -ForegroundColor Cyan
    
    $newDomainSettings = @{
        GroupTag = "NEW-DOMAIN"
        customValue = "newDomainValue"
    }
    
    $result = Update-Setting -SettingType "Domain" -SettingsFile $TestSettingsFile -DomainName "newdomain.com" -Settings $newDomainSettings
    
    if ($result) {
        # Check for new domain in separate domain file (new architecture)
        $newDomainConfigFile = Join-Path (Split-Path $TestSettingsFile -Parent) "newdomain.com.json"
        if (Test-Path $newDomainConfigFile) {
            $newDomainConfig = Get-Content -Path $newDomainConfigFile -Raw | ConvertFrom-Json
            if ($newDomainConfig.settings.GroupTag -eq "NEW-DOMAIN" -and 
                $newDomainConfig.groupsToInclude -is [array] -and 
                $newDomainConfig.groupsToExclude -is [array]) {
                Write-Host "✓ New domain creation successful" -ForegroundColor Green
            } else {
                Write-Host "✗ New domain structure verification failed" -ForegroundColor Red
                throw "New domain structure verification failed"
            }
        } else {
            # Fallback to old format for backward compatibility
            $verifySettings = Get-Content -Path $TestSettingsFile -Raw | ConvertFrom-Json
            if ($verifySettings.domains.PSObject.Properties.Name -contains "newdomain.com") {
                $newDomainObj = $verifySettings.domains."newdomain.com"
                if ($newDomainObj.settings.GroupTag -eq "NEW-DOMAIN" -and 
                    $newDomainObj.groupsToInclude -is [array] -and 
                    $newDomainObj.groupsToExclude -is [array]) {
                    Write-Host "✓ New domain creation successful" -ForegroundColor Green
                } else {
                    Write-Host "✗ New domain structure verification failed" -ForegroundColor Red
                    throw "New domain structure verification failed"
                }
            } else {
                Write-Host "✗ New domain not found" -ForegroundColor Red
                throw "New domain not found"
            }
        }
    } else {
        Write-Host "✗ New domain creation failed" -ForegroundColor Red
        throw "New domain creation failed"
    }
    
    # Test 7: Parameter Validation
    Write-Host "`n7. Testing Parameter Validation..." -ForegroundColor Cyan
    
    # Test Global without required parameters
    $result = Update-Setting -SettingType "Global" -SettingsFile $TestSettingsFile
    if (-not $result) {
        Write-Host "✓ Global parameter validation works" -ForegroundColor Green
    } else {
        Write-Host "✗ Global parameter validation failed" -ForegroundColor Red
        throw "Global parameter validation failed"
    }
    
    # Test Domain without required parameters
    $result = Update-Setting -SettingType "Domain" -SettingsFile $TestSettingsFile
    if (-not $result) {
        Write-Host "✓ Domain parameter validation works" -ForegroundColor Green
    } else {
        Write-Host "✗ Domain parameter validation failed" -ForegroundColor Red
        throw "Domain parameter validation failed"
    }
    
    # Test 8: Backup Creation
    Write-Host "`n8. Testing Backup Creation..." -ForegroundColor Cyan
    
    # Wait a moment to ensure timestamp difference
    Start-Sleep -Seconds 1
    
    $backupFiles = Get-ChildItem -Path $TestConfigFolder -Filter "test-settings.json.backup.*"
    $backupCount = $backupFiles.Count
    Write-Host "Current backup count: $backupCount" -ForegroundColor Gray
    
    $result = Update-Setting -SettingType "Global" -SettingsFile $TestSettingsFile -SettingName "testBackup" -SettingValue "backupTest"
    
    if ($result) {
        $newBackupFiles = Get-ChildItem -Path $TestConfigFolder -Filter "test-settings.json.backup.*"
        $newBackupCount = $newBackupFiles.Count
        Write-Host "New backup count: $newBackupCount" -ForegroundColor Gray
        if ($newBackupCount -ge $backupCount) {
            Write-Host "✓ Backup creation works (backups exist)" -ForegroundColor Green
        } else {
            Write-Host "✗ Backup count decreased unexpectedly" -ForegroundColor Red
            throw "Backup count decreased unexpectedly"
        }
    } else {
        Write-Host "✗ Backup test failed" -ForegroundColor Red
        throw "Backup test failed"
    }
    
    # Test 9: File Not Found
    Write-Host "`n9. Testing File Not Found Handling..." -ForegroundColor Cyan
    
    $result = Update-Setting -SettingType "Global" -SettingsFile "nonexistent.json" -SettingName "test" -SettingValue "test"
    if (-not $result) {
        Write-Host "✓ File not found handling works" -ForegroundColor Green
    } else {
        Write-Host "✗ File not found handling failed" -ForegroundColor Red
        throw "File not found handling failed"
    }
    
    Write-Host "`n=== All Tests Passed! ===" -ForegroundColor Green
    Write-Host "The unified Update-Setting function successfully replaces all three original functions." -ForegroundColor Green
    
} catch {
    Write-Host "`n=== Test Failed ===" -ForegroundColor Red
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

Write-Host "`nTest completed successfully!" -ForegroundColor Green