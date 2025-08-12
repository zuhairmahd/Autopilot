# Test script to verify the delegated auth property update functionality
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-delegated-auth-temp"
)

Write-Host "Testing Delegated Authentication Property Update" -ForegroundColor Green
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder)
{
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Set up test environment
$settingsFile = "$TestFolder\settings.json"

try
{
    # Load the functions
    Write-TestSection "`n1. Loading functions..."
    
    # Load all functions from the functions directory
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder)
    {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions)
        {
            . $function.FullName
        }
        Write-Host "[PASS] Functions loaded successfully" -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] Functions folder not found: $functionsFolder" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n2. Creating initial settings.json..." -ForegroundColor Cyan
    
    # Create a sample settings.json with Delegated = false
    $initialSettings = @{
        description    = "Test settings file"
        version        = "1.3.0.0"
        auth           = @{
            Delegated       = $false
            authType        = "PublicAuthFlow"
            renewalLeadTime = 5
        }
        globalSettings = @{
            configFile = ".\.secrets\config.json"
            autoUpdate = $true
        }
        domains        = @{}
    }
    
    $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -Force
    
    if (Test-Path $settingsFile)
    {
        $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        Write-Host "[PASS] Initial settings.json created with Delegated = $($settings.auth.Delegated)" -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] Failed to create initial settings.json" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n3. Testing Update-AuthSetting function..." -ForegroundColor Cyan
    
    # Test updating Delegated to true
    $success = Update-AuthSetting -SettingsFile $settingsFile -SettingName "Delegated" -SettingValue $true
    
    if ($success)
    {
        Write-Host "[PASS] Update-AuthSetting function completed successfully" -ForegroundColor Green
        
        # Verify the setting was updated
        $updatedSettings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        if ($updatedSettings.auth.Delegated -eq $true)
        {
            Write-Host "[PASS] Delegated property updated correctly to: $($updatedSettings.auth.Delegated)" -ForegroundColor Green
        }
        else
        {
            Write-Host "[FAIL] Delegated property was not updated correctly. Current value: $($updatedSettings.auth.Delegated)" -ForegroundColor Red
        }
        
        # Verify other auth properties are preserved
        if ($updatedSettings.auth.authType -eq "PublicAuthFlow" -and $updatedSettings.auth.renewalLeadTime -eq 5)
        {
            Write-Host "[PASS] Other auth properties preserved" -ForegroundColor Green
        }
        else
        {
            Write-Host "[FAIL] Other auth properties were modified unexpectedly" -ForegroundColor Red
        }
        
        # Verify other sections are preserved
        if ($updatedSettings.globalSettings.autoUpdate -eq $true)
        {
            Write-Host "[PASS] Other settings sections preserved" -ForegroundColor Green
        }
        else
        {
            Write-Host "[FAIL] Other settings sections were modified unexpectedly" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "[FAIL] Update-AuthSetting function failed" -ForegroundColor Red
    }

    Write-Host "`n4. Testing First Run Wizard integration..." -ForegroundColor Cyan
    
    # Reset settings to Delegated = false
    $initialSettings.auth.Delegated = $false
    $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -Force
    Write-Host "Reset settings to Delegated = false" -ForegroundColor Yellow
    
    # Create minimal config and strings files for wizard
    $configFile = "$TestFolder\.secrets\config.json"
    $stringsFile = "$TestFolder\strings.json"
    
    # Run the wizard in silent mode (which should set Delegated = true by default)
    $wizardSuccess = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $settingsFile -StringsFile $stringsFile -Silent
    
    if ($wizardSuccess)
    {
        Write-Host "[PASS] First Run Wizard completed successfully" -ForegroundColor Green
        
        # Check if Delegated property was updated to true
        $finalSettings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        if ($finalSettings.auth.Delegated -eq $true)
        {
            Write-Host "[PASS] First Run Wizard correctly updated Delegated property to: $($finalSettings.auth.Delegated)" -ForegroundColor Green
        }
        else
        {
            Write-Host "[FAIL] First Run Wizard did not update Delegated property. Current value: $($finalSettings.auth.Delegated)" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "[FAIL] First Run Wizard failed" -ForegroundColor Red
    }

    Write-Host "`n5. Testing edge cases..." -ForegroundColor Cyan
    
    # Test with non-existent file
    $nonExistentFile = "$TestFolder\nonexistent.json"
    $edgeTestSuccess = Update-AuthSetting -SettingsFile $nonExistentFile -SettingName "Delegated" -SettingValue $true
    if (-not $edgeTestSuccess)
    {
        Write-Host "[PASS] Function correctly handles non-existent file" -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] Function should fail with non-existent file" -ForegroundColor Red
    }
    
    # Test with invalid JSON file
    $invalidJsonFile = "$TestFolder\invalid.json"
    "{ invalid json }" | Set-Content -Path $invalidJsonFile -Force
    $invalidJsonTestSuccess = Update-AuthSetting -SettingsFile $invalidJsonFile -SettingName "Delegated" -SettingValue $true
    if (-not $invalidJsonTestSuccess)
    {
        Write-Host "[PASS] Function correctly handles invalid JSON" -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] Function should fail with invalid JSON" -ForegroundColor Red
    }

    Write-Host "`n[PASS] All tests completed successfully!" -ForegroundColor Green

}
catch
{
    Write-Host "`n[FAIL] Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
}
finally
{
    # Clean up test folder
    if (Test-Path $TestFolder)
    {
        try
        {
            Remove-Item -Path $TestFolder -Recurse -Force
            Write-Host "`n[PASS] Test folder cleaned up" -ForegroundColor Green
        }
        catch
        {
            Write-Host "`n⚠ Could not clean up test folder: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
