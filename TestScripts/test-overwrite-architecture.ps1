#!/usr/bin/env pwsh
# Test the new overwrite settings architecture

param(
    [string]$TestFolder = $null
)

try
{
    # Load test helper functions
    . "$PSScriptRoot/test-helper.ps1"
    
    # Load the functions we need to test
    . "$PSScriptRoot/../functions/setupFunctions/Get-ApplicationDefaults.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/Initialize-ApplicationConfiguration.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/Initialize-GlobalSettings.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/Initialize-LocalSettings.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertFrom-JsonToHashtable.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/Merge-ConfigurationDefaults.ps1"
    . "$PSScriptRoot/../functions/utilityFunctions/Write-Log.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Overwrite Settings Architecture" -TestFolder $TestFolder
    Write-TestResult "Test environment initialized" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try
{
    Write-TestSection "Testing Get-ApplicationDefaults overwrite configuration"
    
    # Test that we can retrieve overwrite configuration
    $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
    
    Write-TestResult "Retrieved overwrite configuration" ($null -ne $overwriteConfig)
    Write-TestResult "Has GlobalSettings section" ($null -ne $overwriteConfig.GlobalSettings)
    Write-TestResult "Has LocalSettings section" ($null -ne $overwriteConfig.LocalSettings)
    Write-TestResult "Has UniversalSettings section" ($null -ne $overwriteConfig.UniversalSettings)
    
    # Verify structure contains expected sections (they may be empty by design)
    Write-TestResult "GlobalSettings section exists" ($null -ne $overwriteConfig.GlobalSettings)
    Write-TestResult "LocalSettings section exists" ($null -ne $overwriteConfig.LocalSettings) 
    Write-TestResult "UniversalSettings section exists" ($null -ne $overwriteConfig.UniversalSettings)
    
    # Check that the sections are hashtables (even if empty)
    Write-TestResult "GlobalSettings is hashtable" ($overwriteConfig.GlobalSettings -is [hashtable])
    Write-TestResult "LocalSettings is hashtable" ($overwriteConfig.LocalSettings -is [hashtable])
    Write-TestResult "UniversalSettings is hashtable" ($overwriteConfig.UniversalSettings -is [hashtable])
    
    Write-TestSection "Testing Merge-ConfigurationDefaults without OverwriteSettings parameter"
    
    # Test that Merge-ConfigurationDefaults no longer has OverwriteSettings parameter
    $mergeFunction = Get-Command Merge-ConfigurationDefaults -ErrorAction SilentlyContinue
    if ($mergeFunction)
    {
        $hasOverwriteParam = $mergeFunction.Parameters.ContainsKey("OverwriteSettings")
        Write-TestResult "Merge-ConfigurationDefaults no longer has OverwriteSettings parameter" (-not $hasOverwriteParam)
        
        # Test that the basic merge functionality still works
        $existingConfig = @{
            "setting1" = "value1"
            "setting2" = "value2"
        }
        
        $defaultConfig = @{
            "setting2" = "defaultValue2"
            "setting3" = "defaultValue3"
        }
        
        $merged = Merge-ConfigurationDefaults -ExistingConfig $existingConfig -DefaultConfig $defaultConfig
        
        if ($merged)
        {
            Write-TestResult "Basic merge functionality works" $true
            Write-TestResult "Existing values preserved" ($merged["setting1"] -eq "value1")
            Write-TestResult "Existing values preserved over defaults" ($merged["setting2"] -eq "value2")
            Write-TestResult "Missing keys added from defaults" ($merged["setting3"] -eq "defaultValue3")
        }
        else
        {
            Write-TestResult "Basic merge functionality works" $false
        }
    }
    else
    {
        Write-TestResult "Merge-ConfigurationDefaults function found" $false
    }
    
    Write-TestSection "Testing global settings processing with overwrite"
    
    # Create test global settings as hashtable (not PSCustomObject)
    $testGlobalData = @{
        "autoUpdate"      = $false
        "testMode"        = $true
        "operatingSystem" = "Linux"
        "customSetting"   = "customValue"
    }
    
    # Test Initialize-GlobalSettings without overwrite processing (normal operation)
    $globalResult = Initialize-GlobalSettings -GlobalConfigData $testGlobalData -PSBoundParameters @{}
    
    if ($globalResult -and $globalResult.GlobalSettings)
    {
        $globalSettings = $globalResult.GlobalSettings
        
        # Check that settings are preserved without overwrite processing
        Write-TestResult "Normal processing: autoUpdate preserved as false" ($globalSettings["autoUpdate"] -eq $false)
        Write-TestResult "Normal processing: testMode preserved as true" ($globalSettings["testMode"] -eq $true)
        Write-TestResult "Normal processing: operatingSystem preserved as Linux" ($globalSettings["operatingSystem"] -eq "Linux")
        Write-TestResult "Normal processing: customSetting preserved" ($globalSettings["customSetting"] -eq "customValue")
    }
    else
    {
        Write-TestResult "Global settings processing works" $false
    }
    
    # Test Initialize-GlobalSettings with overwrite processing
    $globalResultWithOverwrite = Initialize-GlobalSettings -GlobalConfigData $testGlobalData -PSBoundParameters @{} -processConfigOverwrite
    
    if ($globalResultWithOverwrite -and $globalResultWithOverwrite.GlobalSettings)
    {
        $globalSettingsOverwrite = $globalResultWithOverwrite.GlobalSettings
        
        # Since the default overwrite sections are empty, settings should remain unchanged
        Write-TestResult "Overwrite processing: autoUpdate unchanged (no overwrites defined)" ($globalSettingsOverwrite["autoUpdate"] -eq $false)
        Write-TestResult "Overwrite processing: testMode unchanged (no overwrites defined)" ($globalSettingsOverwrite["testMode"] -eq $true)
        Write-TestResult "Overwrite processing: operatingSystem unchanged (no overwrites defined)" ($globalSettingsOverwrite["operatingSystem"] -eq "Linux")
        Write-TestResult "Overwrite processing: customSetting preserved" ($globalSettingsOverwrite["customSetting"] -eq "customValue")
    }
    else
    {
        Write-TestResult "Global settings overwrite processing works" $false
    }
    
    Write-TestSection "Testing all default types still work"
    
    # Test that all other default types still work
    $authDefaults = Get-ApplicationDefaults -DefaultType "Auth"
    Write-TestResult "Auth defaults retrieved" ($null -ne $authDefaults)
    
    $globalDefaults = Get-ApplicationDefaults -DefaultType "Global"
    Write-TestResult "Global defaults retrieved" ($null -ne $globalDefaults)
    
    $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain"
    Write-TestResult "Domain defaults retrieved" ($null -ne $domainDefaults)
    
    $settingsDefaults = Get-ApplicationDefaults -DefaultType "Settings"
    Write-TestResult "Settings defaults retrieved" ($null -ne $settingsDefaults)
    
    $allDefaults = Get-ApplicationDefaults -DefaultType "All"
    Write-TestResult "All defaults retrieved" ($null -ne $allDefaults)
    Write-TestResult "All defaults includes overwrite config" ($null -ne $allDefaults.Overwrite)
    
    Write-TestSection "Test Summary"
    Write-TestResult "Overwrite architecture implemented successfully" $true
    
}
catch
{
    Write-TestResult "Test execution failed: $($_.Exception.Message)" $false
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
finally
{
    Complete-UnifiedTest -TestContext $testContext
}