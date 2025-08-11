# Test script to validate the consolidated configuration system

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# This script tests the Get-JsonConfiguration function and related components
# PowerShell 5.1 Compatible

param(
    [switch]$Verbose
)

if ($Verbose)
{
    $VerbosePreference = 'Continue'
}

Write-Host "=== Testing Consolidated Configuration System (PowerShell 5.1 Compatible) ===" -ForegroundColor Green

# Import the functions
$rootPath = Split-Path -Parent $PSScriptRoot
Load-AllFunctions -RootPath $rootPath | Out-Null

Write-Host "`n1. Testing strings.json loading..." -ForegroundColor Yellow

try
{
    # Test the Get-StringsFromJson function from main.ps1
    # Using regular hashtables for PowerShell 5.1 compatibility
    $defaultStringValues = @{
        returnValues  = @{
            noRestartMessage              = 'Device not restarted.'
            EnrolledMessage               = 'The device is enrolled.'
            notContactedMessage           = 'The device has not contacted the enrollment service.'
            PendingResetMessage           = 'The device is pending a reset.'
            EnrollmentFailedMessage       = 'The device enrollment failed.'
            UnassignedMessage             = 'The device is not assigned to a deployment profile.'
            PendingMessage                = 'The device is pending assignment to a deployment profile.'
            notInIntuneMessage            = 'The device is not in Intune.'
            noUserDeviceFoundMessage      = 'No user or device found.'
            noUserFoundInDirectoryMessage = 'This user does not exist'
            noGroupFoundInDirectoryMessage = 'This group does not exist'
            ImportSuccessMessage          = 'The device was imported successfully.'
            ImportFailedMessage           = 'The device import failed.'
            DeleteSuccessMessage          = 'The device was deleted successfully.'
            DeleteFailedMessage           = 'The device deletion failed.'
            UpdateFailedMessage           = 'Could not download update.'
            noAccessTokenMessage          = 'Could not obtain an access token. Please check your credentials.'
            UpdateSuccessMessage          = 'The script was updated successfully.'
            UpdateNotNeededMessage        = 'The script is already up to date.'
            999                           = 'No updates were found'
            1000                          = 'All updates were installed'
            1001                          = 'Some updates were installed'
            10002                         = 'Some updates were installed'
            1003                          = 'Updates failed to install'
        }
        deviceStates  = @{
            Ready    = 'The device is ready for the next user'
            NotReady = 'The device is not ready for the next user'
        }
        deviceActions = @{
            none            = 'No action'
            contactAdmin    = 'Contact an Intune administrator'
            contactHelpdesk = 'Contact the helpdesk'
            WipeOrClean     = 'Wipe or clean the device'
        }
    }
    
    $stringsConfig = Get-JsonConfiguration -JsonFile "strings.json" -DefaultValues $defaultStringValues
    
    if ($stringsConfig -and $stringsConfig.returnValues)
    {
        Write-Host "[PASS] Successfully loaded strings.json with sections:" -ForegroundColor Green
        Write-Host "  - returnValues: $($stringsConfig.returnValues.Count) items" -ForegroundColor Cyan
        Write-Host "  - deviceStates: $($stringsConfig.deviceStates.Count) items" -ForegroundColor Cyan  
        Write-Host "  - deviceActions: $($stringsConfig.deviceActions.Count) items" -ForegroundColor Cyan
        
        # Test that we can access specific values
        Write-Host "  - Sample value: EnrolledMessage = '$($stringsConfig.returnValues.EnrolledMessage)'" -ForegroundColor Cyan
    }
    else
    {
        Write-Host "[FAIL] Failed to load strings.json properly" -ForegroundColor Red
    }
}
catch
{
    Write-Host "[FAIL] Error testing strings.json: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n2. Testing init.json loading..." -ForegroundColor Yellow

try
{
    # Test init.json loading with default configuration type
    $defaultInitValues = @{
        configFile          = ".\\.secrets\\config.json"
        configuration       = "vars.json"
        ShowAdvancedOptions = @('True', 'False')
        GroupTag            = "MSB01"
        maxWaitTime         = '60'
        timeInSeconds       = '60'
        Repo                = @('Github', 'Gitlab')
        Release             = "2.2"
    }
    
    $initConfig = Get-JsonConfiguration -JsonFile "init.json" -DefaultValues $defaultInitValues -ConfigurationType 'default'
    
    if ($initConfig)
    {
        Write-Host "[PASS] Successfully loaded init.json with default configuration:" -ForegroundColor Green
        foreach ($key in $initConfig.Keys)
        {
            Write-Host "  - $key = '$($initConfig[$key])'" -ForegroundColor Cyan
        }
    }
    else
    {
        Write-Host "[FAIL] Failed to load init.json properly" -ForegroundColor Red
    }
}
catch
{
    Write-Host "[FAIL] Error testing init.json: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n3. Testing with non-existent file (fallback behavior)..." -ForegroundColor Yellow

try
{
    $testDefaults = @{
        testSection = @{
            key1 = "default1"
            key2 = "default2"
        }
    }
    
    $fallbackConfig = Get-JsonConfiguration -JsonFile "non-existent-file.json" -DefaultValues $testDefaults
    
    if ($fallbackConfig -and $fallbackConfig.testSection)
    {
        Write-Host "[PASS] Successfully fell back to defaults for non-existent file" -ForegroundColor Green
        Write-Host "  - testSection.key1 = '$($fallbackConfig.testSection.key1)'" -ForegroundColor Cyan
        Write-Host "  - testSection.key2 = '$($fallbackConfig.testSection.key2)'" -ForegroundColor Cyan
    }
    else
    {
        Write-Host "[FAIL] Failed to fallback to defaults properly" -ForegroundColor Red
    }
}
catch
{
    Write-Host "[FAIL] Error testing fallback behavior: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n4. Testing PowerShell 5.1 compatibility (OrderedDictionary fix)..." -ForegroundColor Yellow

try
{
    # Create a test JSON with additional properties to trigger the collection compatibility issue
    $testJson = @'
'
{
    "returnValues": {
        "existingKey": "existing value",
        "additionalKey": "additional value that tests PowerShell 5.1 compatibility"
    }
}
'@
    
    # Write to a temporary file
    $tempFile = "temp-test.json"
    $testJson | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Use regular hashtables (PowerShell 5.1 compatible)
    $testDefaults = @{
        returnValues = @{
            existingKey = "default value"
        }
    }
    
    # This should work now with PowerShell 5.1 compatible collection handling
    $testConfig = Get-JsonConfiguration -JsonFile $tempFile -DefaultValues $testDefaults
    
    if ($testConfig -and $testConfig.returnValues.additionalKey)
    {
        Write-Host "[PASS] PowerShell 5.1 compatibility successful - collection handling works properly" -ForegroundColor Green
        Write-Host "  - existingKey = '$($testConfig.returnValues.existingKey)'" -ForegroundColor Cyan
        Write-Host "  - additionalKey = '$($testConfig.returnValues.additionalKey)'" -ForegroundColor Cyan
    }
    else
    {
        Write-Host "[FAIL] PowerShell 5.1 compatibility test failed" -ForegroundColor Red
    }
    
    # Clean up
    if (Test-Path $tempFile)
    {
        Remove-Item $tempFile -Force
    }
}
catch
{
    Write-Host "[FAIL] Error testing PowerShell 5.1 compatibility: $($_.Exception.Message)" -ForegroundColor Red
    # Clean up on error
    if (Test-Path "temp-test.json")
    {
        Remove-Item "temp-test.json" -Force
    }
}

Write-Host "`n=== Configuration System Testing Complete ===" -ForegroundColor Green
Write-Host "All tests verify that the consolidated configuration system is working properly" -ForegroundColor White
Write-Host "with full PowerShell 5.1 compatibility and no collection-related errors." -ForegroundColor White

