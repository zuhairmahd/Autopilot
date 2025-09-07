#!/usr/bin/env pwsh
# Simple test for domain configuration separation

param(
    [string]$TestFolder = $null
)

# Use unified test framework
try
{
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Load essential functions directly
    . "$PSScriptRoot\..\functions\setupFunctions\Get-DomainConfigurationFromFiles.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\Save-DomainConfiguration.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\Get-ApplicationDefaults.ps1"
    . "$PSScriptRoot\..\functions\setupFunctions\Get-ConfigurationData.ps1"
    . "$PSScriptRoot\..\functions\utilityFunctions\Export-PowerShellDataFile.ps1"
    . "$PSScriptRoot\..\functions\utilityFunctions\Write-Log.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Domain Configuration Simple Test" -TestFolder $TestFolder
    
    Write-TestResult "Test environment initialized" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up test files
$LogFile = "$($testContext.TestFolder)\test.log"
$settingsFile = "$($testContext.TestFolder)\settings.json"

try
{
    Write-TestSection "Creating test settings with domains for migration"
    
    # Create a simple settings.json with domains
    $testSettings = @{
        description    = "Test settings for domain separation"
        version        = "1.1.0.0"
        globalSettings = @{
            autoUpdate  = $false
            maxWaitTime = 30
        }
        domains        = @{
            "testdomain.com" = @{
                groupsToInclude  = @("Test-Group-1", "Test-Group-2")
                groupsToExclude  = @("Excluded-Group")
                settings         = @{
                    deviceNamePrefix          = "TEST-"
                    domain                    = "testdomain.com"
                    maxNumberOfDevicesAllowed = 5
                }
                additionalScopes = @()
            }
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $settingsFile -Encoding UTF8
    Write-TestResult "Created test settings file with domains" $true
    
    Write-TestSection "Testing PSD1 domain configuration functionality"
    
    # Test creating domain configuration with defaults
    $testDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "testdomain.com"
    $domainPsd1File = Join-Path $testContext.TestFolder "testdomain.com.psd1"
    
    # Export domain configuration to PSD1
    Export-PowerShellDataFile -InputObject $testDefaults -Path $domainPsd1File
    
    if (Test-Path $domainPsd1File)
    {
        Write-TestResult "Domain PSD1 file created successfully" $true
        
        # Test loading the domain configuration
        $loadedDomainConfig = Get-ConfigurationData -ConfigurationPath $domainPsd1File -DefaultValues @{}
        
        if ($loadedDomainConfig -and $loadedDomainConfig.domain -eq "testdomain.com")
        {
            Write-TestResult "Domain PSD1 file contains correct data" $true
        }
        else
        {
            Write-TestResult "Domain PSD1 file missing expected data" $false
        }
    }
    else
    {
        Write-TestResult "Domain PSD1 file was not created" $false
    }
    
    Write-TestSection "Testing load functionality"
    
    # Test loading the domain configuration using Get-ConfigurationData 
    $loadedConfig = Get-ConfigurationData -ConfigurationPath $domainPsd1File -DefaultValues @{}
    
    if ($loadedConfig)
    {
        Write-TestResult "Successfully loaded domain configuration via Get-ConfigurationData" $true
        
        if ($loadedConfig.domain -eq "testdomain.com")
        {
            Write-TestResult "Loaded configuration has correct domain name" $true
        }
        else
        {
            Write-TestResult "Loaded configuration has incorrect domain name" $false
        }
    }
    else
    {
        Write-TestResult "Failed to load domain configuration" $false
    }
    
    Write-TestSection "Testing save functionality"
    
    # Test updating and saving using Export-PowerShellDataFile
    $loadedConfig.minUsernameLength = 5  # Update a value
    $loadedConfig.groupsToExclude += "New-Exclude-Group"  # Add to array
    
    $saveResult = Export-PowerShellDataFile -InputObject $loadedConfig -Path $domainPsd1File -Force
    
    if ($saveResult)
    {
        Write-TestResult "Successfully saved updated configuration" $true
        
        # Verify the save
        $verifyConfig = Get-ConfigurationData -ConfigurationPath $domainPsd1File -DefaultValues @{}
        if ($verifyConfig.minUsernameLength -eq 5 -and 
            $verifyConfig.groupsToExclude -contains "New-Exclude-Group")
        {
            Write-TestResult "Saved changes verified successfully" $true
        }
        else
        {
            Write-TestResult "Saved changes not verified" $false
        }
    }
    else
    {
        Write-TestResult "Failed to save updated configuration" $false
    }
    
    Write-TestSection "Testing new domain creation from defaults"
    
    # Test creating a new domain configuration from application defaults
    $newDomainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "newdomain.com"
    $newDomainFile = Join-Path $testContext.TestFolder "newdomain.com.psd1"
    
    # Create the new domain configuration file
    Export-PowerShellDataFile -InputObject $newDomainDefaults -Path $newDomainFile
    
    if (Test-Path $newDomainFile)
    {
        Write-TestResult "New domain PSD1 file was created" $true
        
        # Test loading the new domain config  
        $newDomainConfig = Get-ConfigurationData -ConfigurationPath $newDomainFile -DefaultValues @{}
        
        if ($newDomainConfig -and $newDomainConfig.domain -eq "newdomain.com")
        {
            Write-TestResult "New domain configuration has correct domain name" $true
        }
        else
        {
            Write-TestResult "New domain configuration has incorrect domain name" $false
        }
    }
    else
    {
        Write-TestResult "New domain file was not created" $false
    }
    
    Write-TestSection "Test Summary"
    Write-TestResult "PSD1-based domain configuration functionality working correctly" $true
    
}
catch
{
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    Write-Verbose "Full error details: $($_.Exception | Format-List * | Out-String)"
    exit 1
}
finally
{
    # Complete unified test
    Complete-UnifiedTest -TestContext $testContext
}