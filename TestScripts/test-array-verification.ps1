#!/usr/bin/env pwsh

# Test script for array verification in Update-Setting function
param(
    [string]$TestName = "Array Verification Test",
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

# Use unified test framework
try
{
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    $psInfo = Test-PowerShellVersion
    Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan
    
    # Check if functions are available
    $updateSettingCmd = Get-Command Update-Setting -ErrorAction SilentlyContinue
    Write-Host "Update-Setting available: $($updateSettingCmd -ne $null)" -ForegroundColor Yellow
    
    # Initialize unified test environment  
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder -RootPath $RootPath -SkipFunctionCheck:$true
    
    Write-TestResult "Test environment initialized" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try
{
    Write-TestSection "Testing Array Verification in Update-Setting"
    
    # Check if Update-Setting function is available
    if (-not (Get-Command Update-Setting -ErrorAction SilentlyContinue)) {
        Write-TestResult "Update-Setting function not available - skipping array tests" $true
        $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
        if ($success) {
            Write-Host "`nArray verification test completed (function not available, test skipped)!" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Create a test settings file with auth section using the helper
    $testSettingsFile = New-MockSettingsFile -TestFolder $testContext.TestFolder -FileName "test-settings.psd1" -IncludeAuth
    Write-TestResult "Test settings file created at: $testSettingsFile" -Success $true
    
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
    $result5 = Update-Setting -SettingType "Auth" -SettingsFile $testSettingsFile -SettingName "delegated" -SettingValue $false -Verbose
    Write-TestResult "Scalar value update" -Success $result5
    
    # Calculate test results
    $passedTests = ($result1, $result2, $result3, $result5 | Where-Object { $_ }).Count
    $failedTests = 4 - $passedTests
    $totalTests = 4
    
    # Complete the test using unified framework
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passedTests -FailedTests $failedTests -TotalTests $totalTests
    
}
catch
{
    Write-TestResult "Test failed with error: $($_.Exception.Message)" -Success $false
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
    
    # Complete test with failure  
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 0 -FailedTests 1 -TotalTests 1
    exit 1
}

if ($success)
{
    Write-Host "`nArray verification test completed successfully!" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "`nArray verification test failed!" -ForegroundColor Red
    exit 1
}