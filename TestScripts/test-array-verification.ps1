#!/usr/bin/env pwsh

# Test script for array verification in Update-Setting function
param(
    [string]$TestName = "Array Verification Test",
    [string]$TestFolder = $null
)

# Use unified test framework
try
{
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    $psInfo = Test-PowerShellVersion
    Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan
    
    # Determine paths
    $RootPath = Split-Path -Parent $PSScriptRoot
    
    # Load all functions at script level (same as main.ps1)
    $loadSuccess = Load-AllFunctions -RootPath $RootPath -VerboseLoading:$false
    if (-not $loadSuccess) {
        Write-TestResult "Functions loading failed" $false
        exit 1
    }
    Write-TestResult "Functions loaded successfully" $true
    
    # Initialize unified test environment  
    $global:testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder -RootPath $RootPath -SkipFunctionCheck:$true
    
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
    
    # Create a test settings file with auth section using the helper
    $testSettingsFile = New-MockSettingsFile -TestFolder $testContext.TestFolder -FileName "test-settings.json" -IncludeAuth
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