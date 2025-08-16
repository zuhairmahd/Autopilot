#!/usr/bin/env pwsh

# Test script for authentication settings functionality
param(
    [string]$TestFolder = $null
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "Authentication Settings Test"
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    # Load all functions at script level (same pattern as main.ps1)
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
        foreach ($function in $functions) {
            . $function.FullName
        }
        Write-TestResult "Functions loaded successfully" $true
    } else {
        Write-TestResult "Functions folder not found" $false
        exit 1
    }
    
    # Set up global variables needed by the functions
    $tempDir = if ($IsWindows) { $env:TEMP } else { "/tmp" }
    $global:logFile = Join-Path $tempDir "test.log"
    $global:LogFile = Join-Path $tempDir "test.log"
    $global:jsonDepth = 10

    # All functions loaded successfully
    Write-TestResult "Functions loaded successfully" $true

    # Change to test directory
    Push-Location $TestFolder

    Write-TestSection "Testing Test-AuthDefaults function"
    
    # Create a test settings file
    $testSettingsFile = "test-settings.json"
    
    # Create basic settings without auth section
    $basicSettings = @{
        description = "Test settings for auth defaults"
        version = "1.0.0"
        globalSettings = @{
            appMode = "test"
        }
    }
    
    $basicSettings | ConvertTo-Json -Depth 5 | Set-Content -Path $testSettingsFile -Force
    Write-TestResult "Basic settings file created" -Success $true
    
    # Test adding auth defaults
    $success = Test-AuthDefaults -SettingsFile $testSettingsFile -Silent
    if ($success) {
        Write-TestResult "Test-AuthDefaults executed successfully" -Success $true
        
        # Verify auth section was added
        $settingsContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
        
        if ($settingsContent.auth) {
            Write-TestResult "Auth section was added" -Success $true
            
            # Check for required auth properties
            $requiredProps = @('changePwOnNextStart', 'authType', 'noSaveRefreshToken', 'forceNewToken', 'renewalLeadTime', 'scope', 'cacheType', 'secureString', 'delegated')
            $missingProps = @()
            
            foreach ($prop in $requiredProps) {
                if (-not ($settingsContent.auth.PSObject.Properties.Name -contains $prop)) {
                    $missingProps += $prop
                }
            }
            
            if ($missingProps.Count -eq 0) {
                Write-TestResult "All required auth properties present" -Success $true
            } else {
                Write-TestResult "Missing auth properties: $($missingProps -join ', ')" -Success $false
            }
            
            # Check scope array
            if ($settingsContent.auth.scope -is [array] -and $settingsContent.auth.scope.Count -gt 0) {
                Write-TestResult "Auth scope array properly configured ($($settingsContent.auth.scope.Count) scopes)" -Success $true
            } else {
                Write-TestResult "Auth scope array not properly configured" -Success $false
            }
            
        } else {
            Write-TestResult "Auth section was not added" -Success $false
        }
    } else {
        Write-TestResult "Test-AuthDefaults failed" -Success $false
    }

    Write-TestSection "Testing Get-AuthDefaults function"
    
    $authDefaults = Get-AuthDefaults
    if ($authDefaults) {
        Write-TestResult "Get-AuthDefaults returned data" -Success $true
        
        # Check for required properties
        if ($authDefaults.ContainsKey('authType') -and $authDefaults.ContainsKey('scope')) {
            Write-TestResult "Required auth properties found in defaults" -Success $true
        } else {
            Write-TestResult "Required auth properties missing from defaults" -Success $false
        }
        
        # Check scope array
        if ($authDefaults.scope -is [array] -and $authDefaults.scope.Count -gt 0) {
            Write-TestResult "Default scope array properly configured" -Success $true
        } else {
            Write-TestResult "Default scope array not properly configured" -Success $false
        }
        
    } else {
        Write-TestResult "Get-AuthDefaults returned null" -Success $false
    }

    Write-TestSection "Testing Show-SettingsEditor with Auth type"
    
    # Create proper settings file with auth section
    $success = Test-AuthDefaults -SettingsFile $testSettingsFile -Silent
    
    # Test preset values for auth settings
    $presetAuthValues = @{
        'authType' = 'PublicAuthFlow'
        'delegated' = $true
        'noSaveRefreshToken' = $false
    }
    
    $success = Show-SettingsEditor -SettingsType "Auth" -SettingsFile $testSettingsFile -Silent -PresetValues $presetAuthValues
    
    if ($success) {
        Write-TestResult "Show-SettingsEditor Auth type executed successfully" -Success $true
        
        # Verify the preset values were applied
        $settingsContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
        
        if ($settingsContent.auth.authType -eq 'PublicAuthFlow' -and 
            $settingsContent.auth.delegated -eq $true -and
            $settingsContent.auth.noSaveRefreshToken -eq $false) {
            Write-TestResult "Preset auth values were applied correctly" -Success $true
        } else {
            Write-TestResult "Preset auth values were not applied correctly" -Success $false
        }
        
    } else {
        Write-TestResult "Show-SettingsEditor Auth type failed" -Success $false
    }

    Write-TestSection "Testing Update-Setting function for Auth"
    
    # Test individual auth setting update
    $updateSuccess = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "renewalLeadTime" -SettingValue 10
    
    if ($updateSuccess) {
        Write-TestResult "Update-Setting (Auth) executed successfully" -Success $true
        
        # Verify the update
        $settingsContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
        
        if ($settingsContent.auth.renewalLeadTime -eq 10) {
            Write-TestResult "Auth setting update verified" -Success $true
        } else {
            Write-TestResult "Auth setting update not verified" -Success $false
        }
    } else {
        Write-TestResult "Update-Setting (Auth) failed" -Success $false
    }

    Write-TestSection "Testing array storage fix"
    
    # Test single-item array preservation
    $singleItemArray = @('single-scope')
    $updateSuccess = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "scope" -SettingValue $singleItemArray
    
    if ($updateSuccess) {
        $settingsContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
        
        if ($settingsContent.auth.scope -is [array] -and $settingsContent.auth.scope.Count -eq 1) {
            Write-TestResult "Single-item array preserved as array" -Success $true
        } else {
            Write-TestResult "Single-item array not preserved properly (type: $($settingsContent.auth.scope.GetType().Name))" -Success $false
        }
    } else {
        Write-TestResult "Array storage test failed" -Success $false
    }

    Write-TestSection "Test Results Summary"
    Write-Host "Authentication settings functionality test complete." -ForegroundColor Green
    
} catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" -Success $false
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Pop-Location
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nAuth settings test completed!" -ForegroundColor Green
exit 0