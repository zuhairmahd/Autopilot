#!/usr/bin/env pwsh

# Test script for array verification in Update-AuthSetting
param(
    [string]$TestFolder = "$PWD\test-array-verification-temp"
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "Array Verification Test"
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    # Load all functions using the helper
    $rootPath = Split-Path -Parent $PSScriptRoot
    $loadSuccess = Load-AllFunctions -RootPath $rootPath

    if (-not $loadSuccess) {
        Write-TestResult "Failed to load functions" -Success $false
        exit 1
    }

    Write-TestResult "Functions loaded successfully" -Success $true

    # Change to test directory
    Push-Location $TestFolder

    Write-TestSection "Testing Array Verification in Update-AuthSetting"
    
    # Create a test settings file with auth section
    $testSettingsFile = "test-settings.json"
    
    $settings = @{
        description = "Test settings for array verification"
        version = "1.0.0"
        auth = @{
            changePwOnNextStart = $false
            authType = "PublicAuthFlow"
            delegated = $true
            scope = @("offline_access", "openid")
        }
    }
    
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $testSettingsFile -Force
    Write-TestResult "Test settings file created" -Success $true
    
    # Test 1: Update with identical array
    Write-TestSubSection "Test 1: Update with identical array"
    $identicalScope = @("offline_access", "openid")
    $result1 = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "scope" -SettingValue $identicalScope -Verbose
    Write-TestResult "Identical array update" -Success $result1
    
    # Test 2: Update with different array
    Write-TestSubSection "Test 2: Update with different array"
    $differentScope = @("offline_access", "openid", "Device.ReadWrite.All")
    $result2 = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "scope" -SettingValue $differentScope -Verbose
    Write-TestResult "Different array update" -Success $result2
    
    # Test 3: Update with single item array
    Write-TestSubSection "Test 3: Update with single item array"
    $singleScope = @("offline_access")
    $result3 = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "scope" -SettingValue $singleScope -Verbose
    Write-TestResult "Single item array update" -Success $result3
    
    # Test 4: Verify final state
    Write-TestSubSection "Test 4: Verify final state"
    $finalContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
    $finalScope = $finalContent.auth.scope
    $isCorrectType = $finalScope -is [array]
    $hasCorrectValue = $finalScope.Count -eq 1 -and $finalScope[0] -eq "offline_access"
    
    Write-Host "Final scope type: $($finalScope.GetType().Name)" -ForegroundColor Cyan
    Write-Host "Final scope value: $($finalScope -join ', ')" -ForegroundColor Cyan
    Write-TestResult "Final state verification" -Success ($isCorrectType -and $hasCorrectValue)
    
    # Test 5: Test scalar value update (for comparison)
    Write-TestSubSection "Test 5: Test scalar value update"
    $result5 = Update-AuthSetting -SettingsFile $testSettingsFile -SettingName "delegated" -SettingValue $false -Verbose
    Write-TestResult "Scalar value update" -Success $result5
    
    Write-TestSection "Array Verification Test Completed"
    
} catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" -Success $false
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up
    Pop-Location
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force
    }
}

Write-Host "`nArray verification test completed successfully!" -ForegroundColor Green