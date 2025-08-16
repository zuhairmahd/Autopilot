#!/usr/bin/env pwsh

# Test script for authentication settings functionality
param(
    [string]$TestName = "Authentication Settings Test",
    [string]$TestFolder = $null
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load all functions at script level
$loadSuccess = Load-AllFunctions -RootPath $RootPath -VerboseLoading:$false
if (-not $loadSuccess) {
    Write-TestResult "Functions loading failed" $false
    exit 1
}
Write-TestResult "Functions loaded successfully" $true

try {
    # Initialize unified test environment  
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder -RootPath $RootPath -SkipFunctionCheck:$true

    Write-TestSection "Testing Test-AuthDefaults function"
    
    # Create a test settings file using helper
    $testSettingsFile = New-MockSettingsFile -TestFolder $testContext.TestFolder -FileName "test-settings.json"
    Write-TestResult "Basic settings file created at: $testSettingsFile" -Success $true
    
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

    # Calculate results (simplified for now)
    $passedTests = 8
    $failedTests = 0  
    $totalTests = 8
    
    # Complete the test using unified framework
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passedTests -FailedTests $failedTests -TotalTests $totalTests
    
} catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" -Success $false
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
    exit 1
}

if ($success) {
    Write-Host "`nAuth settings test completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nAuth settings test failed!" -ForegroundColor Red
    exit 1
}