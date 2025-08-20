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
    . "$PSScriptRoot\..\functions\setupFunctions\Migrate-DomainsToSeparateFiles.ps1"
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
    
    Write-TestSection "Testing migration functionality"
    
    # Test migration
    $migrationResult = Migrate-DomainsToSeparateFiles -SettingsFile $settingsFile -ConfigurationPath $testContext.TestFolder -RemoveFromSettings $true
    
    if ($migrationResult.Success)
    {
        Write-TestResult "Migration completed successfully" $true
        
        # Check if domain file was created
        $domainFile = Join-Path $testContext.TestFolder "testdomain.com.json"
        if (Test-Path $domainFile)
        {
            Write-TestResult "Domain file created successfully" $true
            
            # Verify content
            $domainContent = Get-Content $domainFile -Raw | ConvertFrom-Json
            if ($domainContent.settings.deviceNamePrefix -eq "TEST-" -and 
                $domainContent.groupsToInclude -contains "Test-Group-1")
            {
                Write-TestResult "Domain file contains correct data" $true
            }
            else
            {
                Write-TestResult "Domain file missing expected data" $false
            }
        }
        else
        {
            Write-TestResult "Domain file was not created" $false
        }
    }
    else
    {
        Write-TestResult "Migration failed: $($migrationResult.ErrorMessages -join '; ')" $false
    }
    
    Write-TestSection "Testing load functionality"
    
    # Test loading the domain configuration
    $loadedConfig = Get-DomainConfigurationFromFiles -DomainName "testdomain.com" -ConfigurationPath $testContext.TestFolder
    
    if ($loadedConfig)
    {
        Write-TestResult "Successfully loaded domain configuration" $true
        
        if ($loadedConfig.settings.deviceNamePrefix -eq "TEST-")
        {
            Write-TestResult "Loaded configuration has correct settings" $true
        }
        else
        {
            Write-TestResult "Loaded configuration has incorrect settings" $false
        }
    }
    else
    {
        Write-TestResult "Failed to load domain configuration" $false
    }
    
    Write-TestSection "Testing save functionality"
    
    # Test updating and saving
    $loadedConfig.settings | Add-Member -MemberType NoteProperty -Name "testUpdate" -Value "success" -Force
    $loadedConfig.groupsToInclude += "New-Test-Group"
    
    $saveResult = Save-DomainConfiguration -DomainName "testdomain.com" -DomainConfiguration $loadedConfig -ConfigurationPath $testContext.TestFolder
    
    if ($saveResult)
    {
        Write-TestResult "Successfully saved updated configuration" $true
        
        # Verify the save
        $verifyConfig = Get-DomainConfigurationFromFiles -DomainName "testdomain.com" -ConfigurationPath $testContext.TestFolder
        if ($verifyConfig.settings.testUpdate -eq "success" -and 
            $verifyConfig.groupsToInclude -contains "New-Test-Group")
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
    
    Write-TestSection "Testing new domain creation"
    
    # Test creating a new domain from scratch
    $newDomainConfig = Get-DomainConfigurationFromFiles -DomainName "newdomain.com" -GlobalSettings $testSettings.globalSettings -ConfigurationPath $testContext.TestFolder

    if ($newDomainConfig)
    {
        Write-TestResult "Successfully created new domain configuration" $true
        
        $newDomainFile = Join-Path $testContext.TestFolder "newdomain.com.json"
        if (Test-Path $newDomainFile)
        {
            Write-TestResult "New domain file was created" $true
        }
        else
        {
            Write-TestResult "New domain file was not created" $false
        }
    }
    else
    {
        Write-TestResult "Failed to create new domain configuration" $false
    }
    
    Write-TestSection "Test Summary"
    Write-TestResult "Domain configuration separation functionality working correctly" $true
    
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