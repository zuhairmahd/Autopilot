#!/usr/bin/env pwsh
# Test separate domain configuration file functionality

param(
    [string]$TestFolder = $null
)

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Load the new domain configuration functions directly
    . "$PSScriptRoot\..\functions\setupFunctions\Load-DomainConfiguration.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\Save-DomainConfiguration.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\Migrate-DomainsToSeparateFiles.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\Initialize-ApplicationConfiguration.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\Update-Setting.ps1"
    
    # Load other essential functions
    . "$PSScriptRoot\..\functions\utilityFunctions\Write-Log.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Separate Domain Configuration Files" -TestFolder $TestFolder
    
    Write-TestResult "Test environment initialized" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up test files
$LogFile = "$($testContext.TestFolder)\test.log"
$configFile = "$($testContext.TestFolder)\.secrets\config.json"
$settingsFile = "$($testContext.TestFolder)\settings.json"
$stringsFile = "$($testContext.TestFolder)\strings.json"

try {
    Write-TestSection "Creating test settings with domains section for migration"
    
    # Create a settings.json file with domains to test migration
    $testSettings = @{
        description = "Test settings file with domains for migration"
        version = "1.1.0.0"
        auth = @{
            Delegated = $true
            authType = "PublicAuthFlow"
        }
        globalSettings = @{
            autoUpdate = $false
            appMode = "full"
            maxWaitTime = 30
        }
        domains = @{
            "contoso.com" = @{
                groupsToInclude = @("Contoso-Users", "Device-Recipients")
                groupsToExclude = @("Contractors")
                settings = @{
                    deviceNamePrefix = "CONTOSO-"
                    domain = "contoso.com"
                    maxNumberOfDevicesAllowed = 5
                    MinimumDevicePhysicalMemoryInGB = 8
                }
                additionalScopes = @()
            }
            "fabrikam.com" = @{
                groupsToInclude = @("Fabrikam-Users")
                groupsToExclude = @()
                settings = @{
                    deviceNamePrefix = "FAB-"
                    domain = "fabrikam.com"
                    maxNumberOfDevicesAllowed = 3
                    operatingSystem = "Windows"
                }
                additionalScopes = @("CustomScope.Read")
            }
        }
        requiredScopes = @(
            @{ Scope = "User.Read.All"; Reason = "Required for user operations" }
            @{ Scope = "Device.ReadWrite.All"; Reason = "Required for device operations" }
        )
    }
    
    # Create .secrets directory
    $secretsDir = Split-Path $configFile -Parent
    if (-not (Test-Path $secretsDir)) {
        New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
    }
    
    # Write settings file with domains
    $testSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $settingsFile -Encoding UTF8
    Write-TestResult "Created test settings file with domains section" $true
    
    # Create basic strings file
    $testStrings = @{
        returnValues = @{
            message1 = "Test message"
        }
    }
    $testStrings | ConvertTo-Json -Depth 5 | Out-File -FilePath $stringsFile -Encoding UTF8
    Write-TestResult "Created test strings file" $true
    
    Write-TestSection "Testing new domain configuration functions"
    
    # Functions are already loaded above
    Write-TestResult "Functions loaded successfully" $true
    
    Write-TestSection "Testing Load-DomainConfiguration function"
    
    # Test loading domain that doesn't exist yet (should create it)
    $testDomainConfig = Load-DomainConfiguration -DomainName "newdomain.com" -GlobalSettings $testSettings.globalSettings -ConfigurationPath $testContext.TestFolder
    
    if ($testDomainConfig) {
        Write-TestResult "Load-DomainConfiguration created new domain configuration" $true
        
        # Verify new domain file was created
        $newDomainFile = Join-Path $testContext.TestFolder "newdomain.com.json"
        if (Test-Path $newDomainFile) {
            Write-TestResult "New domain configuration file was created" $true
            
            # Verify structure
            $newDomainContent = Get-Content $newDomainFile -Raw | ConvertFrom-Json
            if ($newDomainContent.groupsToInclude -and 
                $newDomainContent.groupsToExclude -and 
                $newDomainContent.settings -and
                $newDomainContent.settings.domain -eq "newdomain.com") {
                Write-TestResult "New domain configuration has correct structure" $true
            } else {
                Write-TestResult "New domain configuration structure is incorrect" $false
            }
        } else {
            Write-TestResult "New domain configuration file was not created" $false
        }
    } else {
        Write-TestResult "Load-DomainConfiguration failed to create new domain" $false
    }
    
    Write-TestSection "Testing Save-DomainConfiguration function"
    
    # Test saving domain configuration
    $testDomainConfig.settings.testSetting = "testValue"
    $testDomainConfig.groupsToInclude += "TestGroup"
    
    $saveResult = Save-DomainConfiguration -DomainName "newdomain.com" -DomainConfiguration $testDomainConfig -ConfigurationPath $testContext.TestFolder
    
    if ($saveResult) {
        Write-TestResult "Save-DomainConfiguration saved successfully" $true
        
        # Verify the saved content
        $savedContent = Get-Content (Join-Path $testContext.TestFolder "newdomain.com.json") -Raw | ConvertFrom-Json
        if ($savedContent.settings.testSetting -eq "testValue" -and 
            $savedContent.groupsToInclude -contains "TestGroup") {
            Write-TestResult "Saved domain configuration contains updated values" $true
        } else {
            Write-TestResult "Saved domain configuration missing updated values" $false
        }
    } else {
        Write-TestResult "Save-DomainConfiguration failed" $false
    }
    
    Write-TestSection "Testing Migrate-DomainsToSeparateFiles function"
    
    # Test migration from settings.json to separate files
    $migrationResult = Migrate-DomainsToSeparateFiles -SettingsFile $settingsFile -ConfigurationPath $testContext.TestFolder -RemoveFromSettings $true
    
    if ($migrationResult.Success) {
        Write-TestResult "Domain migration completed successfully" $true
        Write-TestResult "Migrated domains: $($migrationResult.MigratedDomains -join ', ')" $true
        
        # Verify separate domain files were created
        $contosoDomainFile = Join-Path $testContext.TestFolder "contoso.com.json"
        $fabrikamDomainFile = Join-Path $testContext.TestFolder "fabrikam.com.json"
        
        if ((Test-Path $contosoDomainFile) -and (Test-Path $fabrikamDomainFile)) {
            Write-TestResult "Separate domain files were created" $true
            
            # Verify contoso.com configuration
            $contosoConfig = Get-Content $contosoDomainFile -Raw | ConvertFrom-Json
            if ($contosoConfig.settings.deviceNamePrefix -eq "CONTOSO-" -and 
                $contosoConfig.groupsToInclude -contains "Contoso-Users") {
                Write-TestResult "Contoso domain configuration migrated correctly" $true
            } else {
                Write-TestResult "Contoso domain configuration migration incomplete" $false
            }
            
            # Verify fabrikam.com configuration
            $fabrikamConfig = Get-Content $fabrikamDomainFile -Raw | ConvertFrom-Json
            if ($fabrikamConfig.settings.deviceNamePrefix -eq "FAB-" -and 
                $fabrikamConfig.additionalScopes -contains "CustomScope.Read") {
                Write-TestResult "Fabrikam domain configuration migrated correctly" $true
            } else {
                Write-TestResult "Fabrikam domain configuration migration incomplete" $false
            }
            
            # Verify domains section was removed from settings.json
            $updatedSettings = Get-Content $settingsFile -Raw | ConvertFrom-Json
            if (-not $updatedSettings.domains) {
                Write-TestResult "Domains section removed from settings.json after migration" $true
            } else {
                Write-TestResult "Domains section still exists in settings.json after migration" $false
            }
        } else {
            Write-TestResult "Separate domain files were not created" $false
        }
    } else {
        Write-TestResult "Domain migration failed: $($migrationResult.ErrorMessages -join '; ')" $false
    }
    
    Write-TestSection "Testing Initialize-ApplicationConfiguration with separate domain files"
    
    # Test the updated Initialize-ApplicationConfiguration function
    $initResult = Initialize-ApplicationConfiguration -InitFile $settingsFile -StringsFile $stringsFile -Domain "contoso.com" -LogFile $LogFile
    
    if ($initResult.Success) {
        Write-TestResult "Initialize-ApplicationConfiguration succeeded with separate domain files" $true
        
        # Verify local settings were loaded from separate file
        if ($initResult.LocalSettings.deviceNamePrefix -eq "CONTOSO-") {
            Write-TestResult "Local settings loaded correctly from separate domain file" $true
        } else {
            Write-TestResult "Local settings not loaded correctly from separate domain file" $false
        }
    } else {
        Write-TestResult "Initialize-ApplicationConfiguration failed: $($initResult.ErrorMessage)" $false
    }
    
    Write-TestSection "Testing Update-Setting function with separate domain files"
    
    # Test updating domain settings
    $updateSettings = @{
        testNewSetting = "newValue"
        deviceNamePrefix = "UPDATED-"
    }
    
    $updateResult = Update-Setting -SettingType "Domain" -SettingsFile $settingsFile -DomainName "contoso.com" -Settings $updateSettings -MergeSettings
    
    if ($updateResult) {
        Write-TestResult "Update-Setting successfully updated domain configuration file" $true
        
        # Verify the update
        $updatedDomainConfig = Get-Content $contosoDomainFile -Raw | ConvertFrom-Json
        if ($updatedDomainConfig.settings.testNewSetting -eq "newValue" -and 
            $updatedDomainConfig.settings.deviceNamePrefix -eq "UPDATED-") {
            Write-TestResult "Domain settings updated correctly in separate file" $true
        } else {
            Write-TestResult "Domain settings not updated correctly in separate file" $false
        }
    } else {
        Write-TestResult "Update-Setting failed to update domain configuration" $false
    }
    
    Write-TestSection "Testing backward compatibility"
    
    # Test that the system can still handle old format if no separate files exist
    # Create a new settings file with domains in the old format
    $backwardCompatSettings = @{
        description = "Backward compatibility test"
        version = "1.1.0.0"
        globalSettings = @{
            autoUpdate = $false
            maxWaitTime = 30
        }
        domains = @{
            "legacy.com" = @{
                groupsToInclude = @("Legacy-Users")
                groupsToExclude = @()
                settings = @{
                    domain = "legacy.com"
                    legacySetting = "legacyValue"
                }
            }
        }
    }
    
    $legacySettingsFile = Join-Path $testContext.TestFolder "legacy-settings.json"
    $backwardCompatSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $legacySettingsFile -Encoding UTF8
    
    # Test loading with the legacy format
    $legacyInitResult = Initialize-ApplicationConfiguration -InitFile $legacySettingsFile -StringsFile $stringsFile -Domain "legacy.com" -LogFile $LogFile
    
    if ($legacyInitResult.Success) {
        Write-TestResult "Backward compatibility maintained for legacy domain format" $true
        
        # Verify automatic migration occurred
        $legacyDomainFile = Join-Path $testContext.TestFolder "legacy.com.json"
        if (Test-Path $legacyDomainFile) {
            Write-TestResult "Legacy domain automatically migrated to separate file" $true
        } else {
            Write-TestResult "Legacy domain not migrated to separate file" $false
        }
    } else {
        Write-TestResult "Backward compatibility failed: $($legacyInitResult.ErrorMessage)" $false
    }
    
    Write-TestSection "Test Summary"
    Write-TestResult "Separate domain configuration functionality test completed successfully" $true
    
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    Write-Verbose "Full error details: $($_.Exception | Format-List * | Out-String)"
    exit 1
}
finally {
    # Complete unified test
    Complete-UnifiedTest -TestContext $testContext
}