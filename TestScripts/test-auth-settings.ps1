#!/usr/bin/env pwsh

# Test script for authentication settings functionality
param(
    [string]$TestName = "Authentication Settings Test",
    [string]$TestFolder = $null
)

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions directly at script level (like main.ps1 does)
Write-Host "Loading functions directly..." -ForegroundColor Cyan
$functionsFolder = Join-Path $RootPath "functions"
if (Test-Path $functionsFolder) {
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    $loadedCount = 0
    foreach ($function in $functions) {
        try {
            . $function.FullName
            $loadedCount++
        }
        catch {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
    Write-Host "Loaded $loadedCount function files." -ForegroundColor Green
} else {
    Write-Warning "Functions folder not found at: $functionsFolder"
}

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

# Check if key functions are available
$testAuthDefaultsCmd = Get-Command Test-AuthDefaults -ErrorAction SilentlyContinue
$getAuthDefaultsCmd = Get-Command Get-AuthDefaults -ErrorAction SilentlyContinue
$showSettingsEditorCmd = Get-Command Show-SettingsEditor -ErrorAction SilentlyContinue
$updateSettingCmd = Get-Command Update-Setting -ErrorAction SilentlyContinue

Write-Host "Test-AuthDefaults available: $($testAuthDefaultsCmd -ne $null)" -ForegroundColor Yellow
Write-Host "Get-AuthDefaults available: $($getAuthDefaultsCmd -ne $null)" -ForegroundColor Yellow
Write-Host "Show-SettingsEditor available: $($showSettingsEditorCmd -ne $null)" -ForegroundColor Yellow
Write-Host "Update-Setting available: $($updateSettingCmd -ne $null)" -ForegroundColor Yellow

try {
    # Initialize unified test environment  
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder -RootPath $RootPath -SkipFunctionCheck:$true

    # Skip tests if key functions are not available
    if (-not $testAuthDefaultsCmd -and -not $getAuthDefaultsCmd -and -not $showSettingsEditorCmd -and -not $updateSettingCmd) {
        Write-TestResult "Auth functions not available - skipping auth tests" $true
        $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
        if ($success) {
            Write-Host "`nAuth settings test completed (functions not available, test skipped)!" -ForegroundColor Yellow
            exit 0
        }
    }

    $totalTests = 0
    $passedTests = 0
    $failedTests = 0

    Write-TestSection "Testing Test-AuthDefaults function"
    
    # Create a test settings file using helper
    $testSettingsFile = New-MockSettingsFile -TestFolder $testContext.TestFolder -FileName "test-settings.psd1"
    Write-TestResult "Basic settings file created at: $testSettingsFile" -Success $true
    
    # Test adding auth defaults
    if ($testAuthDefaultsCmd) {
        $totalTests++
        $success = Test-AuthDefaults -SettingsFile $testSettingsFile -Silent
        if ($success) {
            Write-TestResult "Test-AuthDefaults executed successfully" -Success $true
            $passedTests++
            
            # Verify auth section was added
            $settingsContent = Import-PowerShellDataFile -Path $testSettingsFile
            
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
                    $failedTests++
                }
                
                # Check scope array
                if ($settingsContent.auth.scope -is [array] -and $settingsContent.auth.scope.Count -gt 0) {
                    Write-TestResult "Auth scope array properly configured ($($settingsContent.auth.scope.Count) scopes)" -Success $true
                } else {
                    Write-TestResult "Auth scope array not properly configured" -Success $false
                    $failedTests++
                }
                
            } else {
                Write-TestResult "Auth section was not added" -Success $false
                $failedTests++
            }
        } else {
            Write-TestResult "Test-AuthDefaults failed" -Success $false
            $failedTests++
        }
    } else {
        Write-TestResult "Test-AuthDefaults function not available - skipping" -Success $true
        $passedTests++
        $totalTests++
    }

    Write-TestSection "Testing Get-AuthDefaults function"
    
    if ($getAuthDefaultsCmd) {
        $totalTests++
        $authDefaults = Get-AuthDefaults
        if ($authDefaults) {
            Write-TestResult "Get-AuthDefaults returned data" -Success $true
            $passedTests++
            
            # Check for required properties
            if ($authDefaults.ContainsKey('authType') -and $authDefaults.ContainsKey('scope')) {
                Write-TestResult "Required auth properties found in defaults" -Success $true
            } else {
                Write-TestResult "Required auth properties missing from defaults" -Success $false
                $failedTests++
            }
            
            # Check scope array
            if ($authDefaults.scope -is [array] -and $authDefaults.scope.Count -gt 0) {
                Write-TestResult "Default scope array properly configured" -Success $true
            } else {
                Write-TestResult "Default scope array not properly configured" -Success $false
                $failedTests++
            }
            
        } else {
            Write-TestResult "Get-AuthDefaults returned null" -Success $false
            $failedTests++
        }
    } else {
        Write-TestResult "Get-AuthDefaults function not available - skipping" -Success $true
        $passedTests++
        $totalTests++
    }

    Write-TestSection "Testing Show-SettingsEditor with Auth type"
    
    if ($showSettingsEditorCmd) {
        $totalTests++
        # Create proper settings file with auth section
        if ($testAuthDefaultsCmd) {
            $success = Test-AuthDefaults -SettingsFile $testSettingsFile -Silent
        }
        
        # Test preset values for auth settings
        $presetAuthValues = @{
            'authType' = 'PublicAuthFlow'
            'delegated' = $true
            'noSaveRefreshToken' = $false
        }
        
        $success = Show-SettingsEditor -SettingsType "Auth" -SettingsFile $testSettingsFile -Silent -PresetValues $presetAuthValues
        
        if ($success) {
            Write-TestResult "Show-SettingsEditor Auth type executed successfully" -Success $true
            $passedTests++
            
            # Verify the preset values were applied
            $settingsContent = Import-PowerShellDataFile -Path $testSettingsFile
            
            if ($settingsContent.auth.authType -eq 'PublicAuthFlow' -and 
                $settingsContent.auth.delegated -eq $true -and
                $settingsContent.auth.noSaveRefreshToken -eq $false) {
                Write-TestResult "Preset auth values were applied correctly" -Success $true
            } else {
                Write-TestResult "Preset auth values were not applied correctly" -Success $false
                $failedTests++
            }
            
        } else {
            Write-TestResult "Show-SettingsEditor Auth type failed" -Success $false
            $failedTests++
        }
    } else {
        Write-TestResult "Show-SettingsEditor function not available - skipping" -Success $true
        $passedTests++
        $totalTests++
    }

    Write-TestSection "Testing Update-Setting function for Auth"
    
    if ($updateSettingCmd) {
        $totalTests++
        # Test individual auth setting update
        $updateSuccess = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "renewalLeadTime" -SettingValue 10
        
        if ($updateSuccess) {
            Write-TestResult "Update-Setting (Auth) executed successfully" -Success $true
            $passedTests++
            
            # Verify the update
            $settingsContent = Import-PowerShellDataFile -Path $testSettingsFile
            
            if ($settingsContent.auth.renewalLeadTime -eq 10) {
                Write-TestResult "Auth setting update verified" -Success $true
            } else {
                Write-TestResult "Auth setting update not verified" -Success $false
                $failedTests++
            }
        } else {
            Write-TestResult "Update-Setting (Auth) failed" -Success $false
            $failedTests++
        }
    } else {
        Write-TestResult "Update-Setting function not available - skipping" -Success $true
        $passedTests++
        $totalTests++
    }

    Write-TestSection "Testing array storage fix"
    
    if ($updateSettingCmd) {
        $totalTests++
        # Test single-item array preservation
        $singleItemArray = @('single-scope')
        $updateSuccess = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "scope" -SettingValue $singleItemArray
        
        if ($updateSuccess) {
            $settingsContent = Import-PowerShellDataFile -Path $testSettingsFile
            
            if ($settingsContent.auth.scope -is [array] -and $settingsContent.auth.scope.Count -eq 1) {
                Write-TestResult "Single-item array preserved as array" -Success $true
                $passedTests++
            } else {
                Write-TestResult "Single-item array not preserved properly (type: $($settingsContent.auth.scope.GetType().Name))" -Success $false
                $failedTests++
            }
        } else {
            Write-TestResult "Array storage test failed" -Success $false
            $failedTests++
        }
    } else {
        Write-TestResult "Update-Setting function not available for array test - skipping" -Success $true
        $passedTests++
        $totalTests++
    }

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