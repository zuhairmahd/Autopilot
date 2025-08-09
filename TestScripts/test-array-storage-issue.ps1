#!/usr/bin/env pwsh

# Test script to verify array storage issue with single entries
param(
    [string]$TestFolder = "$PWD\test-array-storage-temp"
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Load functions at script level (same pattern as main.ps1)
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder) {
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
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
} else {
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "Array Storage Issue Test"
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    Write-TestResult "Functions loaded successfully" -Success $true

    # Change to test directory
    Push-Location $TestFolder

    Write-TestSection "Testing array storage for single entries"
    
    # Create a test settings file
    $testSettingsFile = "test-settings.json"
    $success = Test-SettingsJsonExists -SettingsFile $testSettingsFile -Silent -DomainName "test.com"
    
    if (-not $success) {
        Write-TestResult "Failed to create test settings file" -Success $false
        exit 1
    }

    Write-TestResult "Test settings file created" -Success $true

    # Test 1: Test array input with single value using Show-SettingsEditor
    Write-TestSection "Test 1: Single value array input"
    
    # Simulate array input with single value
    $presetValues = @{
        'userPatternsToExclude' = @('single-pattern')
        'desiredAutopilotProfiles' = @('single-profile') 
    }
    
    $success = Show-SettingsEditor -SettingsType "Domain" -DomainName "test.com" -SettingsFile $testSettingsFile -Silent -PresetValues $presetValues
    
    if ($success) {
        Write-TestResult "Settings editor executed successfully" -Success $true
        
        # Load and inspect the saved settings
        $settingsContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
        
        # Check userPatternsToExclude
        $userPatterns = $settingsContent.domains."test.com".settings.userPatternsToExclude
        Write-Host "userPatternsToExclude type: $($userPatterns.GetType().Name)" -ForegroundColor Cyan
        Write-Host "userPatternsToExclude value: $userPatterns" -ForegroundColor Gray
        
        if ($userPatterns -is [array]) {
            Write-TestResult "userPatternsToExclude stored as array (CORRECT)" -Success $true
            Write-Host "  Array length: $($userPatterns.Length)" -ForegroundColor Green
        } else {
            Write-TestResult "userPatternsToExclude stored as string (ISSUE FOUND)" -Success $false
            Write-Host "  Value: '$userPatterns'" -ForegroundColor Red
        }
        
        # Check desiredAutopilotProfiles
        $autopilotProfiles = $settingsContent.domains."test.com".settings.desiredAutopilotProfiles
        Write-Host "desiredAutopilotProfiles type: $($autopilotProfiles.GetType().Name)" -ForegroundColor Cyan
        Write-Host "desiredAutopilotProfiles value: $autopilotProfiles" -ForegroundColor Gray
        
        if ($autopilotProfiles -is [array]) {
            Write-TestResult "desiredAutopilotProfiles stored as array (CORRECT)" -Success $true
            Write-Host "  Array length: $($autopilotProfiles.Length)" -ForegroundColor Green
        } else {
            Write-TestResult "desiredAutopilotProfiles stored as string (ISSUE FOUND)" -Success $false
            Write-Host "  Value: '$autopilotProfiles'" -ForegroundColor Red
        }
        
    } else {
        Write-TestResult "Settings editor failed" -Success $false
    }

    # Test 2: Direct JSON manipulation test
    Write-TestSection "Test 2: Direct JSON storage test"
    
    # Create test data with single-item arrays
    $testData = @{
        singleItemArray = @('single-item')
        multiItemArray = @('item1', 'item2')
        emptyArray = @()
        stringValue = 'just-a-string'
    }
    
    # Convert to JSON and back
    $jsonString = $testData | ConvertTo-Json -Depth 5
    Write-Host "JSON string:" -ForegroundColor Cyan
    Write-Host $jsonString -ForegroundColor Gray
    
    $parsedData = $jsonString | ConvertFrom-Json
    
    # Check if single-item array is preserved
    Write-Host "`nAfter JSON round-trip:" -ForegroundColor Cyan
    Write-Host "singleItemArray type: $($parsedData.singleItemArray.GetType().Name)" -ForegroundColor Yellow
    Write-Host "singleItemArray value: $($parsedData.singleItemArray)" -ForegroundColor Gray
    
    if ($parsedData.singleItemArray -is [array]) {
        Write-TestResult "Single-item array preserved through JSON conversion" -Success $true
    } else {
        Write-TestResult "Single-item array converted to string (PowerShell/JSON behavior)" -Success $false
    }
    
    # Test 3: Test scope array specifically from settings.json
    Write-TestSection "Test 3: Auth scope array test"
    
    $authScopes = $settingsContent.auth.scope
    Write-Host "Auth scope type: $($authScopes.GetType().Name)" -ForegroundColor Cyan
    Write-Host "Auth scope count: $($authScopes.Count)" -ForegroundColor Gray
    
    if ($authScopes -is [array] -and $authScopes.Count -gt 1) {
        Write-TestResult "Auth scope array preserved correctly" -Success $true
    } else {
        Write-TestResult "Auth scope array has issues" -Success $false
    }

    Write-TestSection "Test Results Summary"
    Write-Host "Array storage behavior analysis complete." -ForegroundColor Green
    Write-Host "Check the results above to understand how arrays are handled." -ForegroundColor Yellow
    
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

Write-Host "`nArray storage test completed!" -ForegroundColor Green
exit 0