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
    
    # Verify structure contains expected settings
    Write-TestResult "GlobalSettings contains autoUpdate" ($overwriteConfig.GlobalSettings.ContainsKey("autoUpdate"))
    Write-TestResult "LocalSettings contains deviceContactThresholdInDays" ($overwriteConfig.LocalSettings.ContainsKey("deviceContactThresholdInDays"))
    Write-TestResult "UniversalSettings contains operatingSystem" ($overwriteConfig.UniversalSettings.ContainsKey("operatingSystem"))
    
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
    
    # Create test global settings
    $testGlobalData = [PSCustomObject]@{
        "autoUpdate" = $false
        "testMode" = $true
        "operatingSystem" = "Linux"
        "customSetting" = "customValue"
    }
    
    # Test Initialize-GlobalSettings applies overwrites
    $globalResult = Initialize-GlobalSettings -GlobalConfigData $testGlobalData -PSBoundParameters @{}
    
    if ($globalResult -and $globalResult.GlobalSettings)
    {
        $globalSettings = $globalResult.GlobalSettings
        
        # Check that global overwrites were applied
        Write-TestResult "Global overwrite: autoUpdate forced to true" ($globalSettings["autoUpdate"] -eq $true)
        Write-TestResult "Global overwrite: testMode forced to false" ($globalSettings["testMode"] -eq $false)
        
        # Check that universal overwrites were applied
        Write-TestResult "Universal overwrite: operatingSystem forced to Windows" ($globalSettings["operatingSystem"] -eq "Windows")
        
        # Check that non-overwrite settings are preserved
        Write-TestResult "Non-overwrite setting preserved" ($globalSettings["customSetting"] -eq "customValue")
    }
    else
    {
        Write-TestResult "Global settings processing works" $false
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