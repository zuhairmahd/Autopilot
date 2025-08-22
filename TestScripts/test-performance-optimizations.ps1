#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests the performance optimizations implemented for startup improvement.

.DESCRIPTION
    Validates that the caching, conditional flattening, and other optimizations
    work correctly and provide the expected performance improvements.

.NOTES
    Part of the performance optimization initiative addressing issue #115.
    Tests caching in Get-ApplicationDefaults, conditional flattening in MergeSettings.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Import test helper
. "$PSScriptRoot/test-helper.ps1"

Write-Host "=== Performance Optimizations Test ===" -ForegroundColor Yellow
Write-Host "Testing caching, conditional flattening, and optimization functions"
Write-Host ""

$testResults = @()

# Test 1: Default Value Caching
Write-Host "Test 1: Default Value Caching" -ForegroundColor Cyan

try {
    # Import the function
    . "$PSScriptRoot/../functions/setupFunctions/Get-ApplicationDefaults.ps1"
    
    # Clear any existing cache
    if (Get-Variable -Name "script:defaultsCache" -Scope Script -ErrorAction SilentlyContinue) {
        Remove-Variable -Name "script:defaultsCache" -Scope Script
    }
    
    # First call - should create cache
    $start1 = Get-Date
    $result1 = Get-ApplicationDefaults -DefaultType "Settings" -Version "test.1.0"
    $duration1 = (Get-Date) - $start1
    
    # Second call - should use cache
    $start2 = Get-Date
    $result2 = Get-ApplicationDefaults -DefaultType "Settings" -Version "test.1.0"
    $duration2 = (Get-Date) - $start2
    
    # Verify results are identical
    $identical = $true
    if ($result1.GetType() -ne $result2.GetType()) {
        $identical = $false
    } elseif ($result1 -is [hashtable] -and $result2 -is [hashtable]) {
        if ($result1.Count -ne $result2.Count) {
            $identical = $false
        }
    }
    
    # Cache should make second call faster
    $cacheEffective = $duration2.TotalMilliseconds -lt $duration1.TotalMilliseconds
    
    if ($result1 -and $result2 -and $identical -and $cacheEffective) {
        Write-Host "  ✓ Caching works correctly" -ForegroundColor Green
        Write-Host "    First call: $([math]::Round($duration1.TotalMilliseconds, 2))ms" -ForegroundColor Gray
        Write-Host "    Second call: $([math]::Round($duration2.TotalMilliseconds, 2))ms" -ForegroundColor Gray
        Write-Host "    Cache improvement: $([math]::Round((($duration1.TotalMilliseconds - $duration2.TotalMilliseconds) / $duration1.TotalMilliseconds) * 100, 1))%" -ForegroundColor Green
        $testResults += @{ Test = "Default Value Caching"; Result = "PASS"; Details = "Cache effective" }
    } else {
        Write-Host "  ✗ Caching failed" -ForegroundColor Red
        Write-Host "    Identical results: $identical" -ForegroundColor Gray
        Write-Host "    Cache effective: $cacheEffective" -ForegroundColor Gray
        $testResults += @{ Test = "Default Value Caching"; Result = "FAIL"; Details = "Cache not effective" }
    }
} catch {
    Write-Host "  ✗ Caching test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Default Value Caching"; Result = "FAIL"; Details = $_.Exception.Message }
}

Write-Host ""

# Test 2: Conditional Flattening in MergeSettings
Write-Host "Test 2: Conditional Flattening in MergeSettings" -ForegroundColor Cyan

try {
    # Import required functions
    . "$PSScriptRoot/../functions/setupFunctions/MergeSettings.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertFrom-JsonToHashtable.ps1"
    . "$PSScriptRoot/../functions/utilityFunctions/Write-Log.ps1"
    
    # Set up log file for the conversion function
    $global:logFile = [System.IO.Path]::GetTempFileName()
    
    # Test case 1: Simple settings (should skip flattening)
    $simpleLocal = @{
        setting1 = "value1"
        setting2 = "value2"
        setting3 = 123
    }
    
    $simpleGlobal = @{
        setting2 = "globalValue2"
        setting4 = "value4"
    }
    
    $start1 = Get-Date
    $merged1 = MergeSettings -localSettings $simpleLocal -globalSettings $simpleGlobal -Verbose
    $duration1 = (Get-Date) - $start1
    
    # Verify merge worked correctly
    $mergeCorrect1 = ($merged1.setting1 -eq "value1") -and 
                     ($merged1.setting2 -eq "globalValue2") -and 
                     ($merged1.setting3 -eq 123) -and 
                     ($merged1.setting4 -eq "value4")
    
    # Test case 2: Complex settings (should use flattening)
    $complexLocal = @{
        simple = "value1"
        nested = @{
            subkey1 = "subvalue1"
            subkey2 = "subvalue2"
        }
    }
    
    $complexGlobal = @{
        simple = "globalValue"
        nested = @{
            subkey2 = "globalSubvalue2"
            subkey3 = "subvalue3"
        }
    }
    
    $start2 = Get-Date
    $merged2 = MergeSettings -localSettings $complexLocal -globalSettings $complexGlobal -Verbose
    $duration2 = (Get-Date) - $start2
    
    # Verify complex merge worked
    $mergeCorrect2 = $merged2.simple -eq "globalValue"
    
    if ($mergeCorrect1 -and $mergeCorrect2) {
        Write-Host "  ✓ Conditional flattening works correctly" -ForegroundColor Green
        Write-Host "    Simple merge: $([math]::Round($duration1.TotalMilliseconds, 2))ms" -ForegroundColor Gray
        Write-Host "    Complex merge: $([math]::Round($duration2.TotalMilliseconds, 2))ms" -ForegroundColor Gray
        $testResults += @{ Test = "Conditional Flattening"; Result = "PASS"; Details = "Both simple and complex merges work" }
    } else {
        Write-Host "  ✗ Conditional flattening failed" -ForegroundColor Red
        Write-Host "    Simple merge correct: $mergeCorrect1" -ForegroundColor Gray
        Write-Host "    Complex merge correct: $mergeCorrect2" -ForegroundColor Gray
        $testResults += @{ Test = "Conditional Flattening"; Result = "FAIL"; Details = "Merge logic incorrect" }
    }
    
    # Clean up log file
    if ($global:logFile -and (Test-Path $global:logFile)) {
        Remove-Item $global:logFile -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "  ✗ Conditional flattening test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Conditional Flattening"; Result = "FAIL"; Details = $_.Exception.Message }
}

Write-Host ""

# Test 3: Optimized Test-SettingsJsonExists
Write-Host "Test 3: Optimized Test-SettingsJsonExists" -ForegroundColor Cyan

try {
    # Import required functions
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/Test-SettingsJsonExists.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/Write-SafeLog.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/Get-ApplicationDefaults.ps1"
    . "$PSScriptRoot/../functions/utilityFunctions/Write-Log.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertTo-OrderedJson.ps1"
    
    # Test with a temporary file
    $tempSettingsFile = [System.IO.Path]::GetTempFileName()
    
    # Measure the function execution
    $start = Get-Date
    $result = Test-SettingsJsonExists -SettingsFile $tempSettingsFile  # Remove -Domain parameter
    $duration = (Get-Date) - $start
    
    # Clean up
    if (Test-Path $tempSettingsFile) {
        Remove-Item $tempSettingsFile -Force
    }
    
    if ($result -and $result.Settings) {
        Write-Host "  ✓ Optimized Test-SettingsJsonExists works correctly" -ForegroundColor Green
        Write-Host "    Execution time: $([math]::Round($duration.TotalMilliseconds, 2))ms" -ForegroundColor Gray
        $testResults += @{ Test = "Optimized Test-SettingsJsonExists"; Result = "PASS"; Details = "Function executed successfully" }
    } else {
        Write-Host "  ✗ Optimized Test-SettingsJsonExists failed" -ForegroundColor Red
        $testResults += @{ Test = "Optimized Test-SettingsJsonExists"; Result = "FAIL"; Details = "Function returned invalid result" }
    }
} catch {
    Write-Host "  ✗ Optimized Test-SettingsJsonExists test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Optimized Test-SettingsJsonExists"; Result = "FAIL"; Details = $_.Exception.Message }
}

Write-Host ""

# Test 4: Performance Comparison
Write-Host "Test 4: Performance Impact Analysis" -ForegroundColor Cyan

try {
    # Simulate multiple default value requests (testing caching impact)
    $iterations = 10
    $totalTime = 0
    
    for ($i = 1; $i -le $iterations; $i++) {
        $start = Get-Date
        $result = Get-ApplicationDefaults -DefaultType "Global" -Version "test.1.0"
        $duration = (Get-Date) - $start
        $totalTime += $duration.TotalMilliseconds
    }
    
    $avgTime = $totalTime / $iterations
    
    Write-Host "  ✓ Multiple default value requests performance" -ForegroundColor Green
    Write-Host "    $iterations iterations, Average: $([math]::Round($avgTime, 2))ms per call" -ForegroundColor Gray
    
    if ($avgTime -lt 10) {  # Expect each cached call to be under 10ms
        Write-Host "    Performance target met (< 10ms per call)" -ForegroundColor Green
        $testResults += @{ Test = "Performance Impact"; Result = "PASS"; Details = "Average time $([math]::Round($avgTime, 2))ms" }
    } else {
        Write-Host "    Performance target not met (>= 10ms per call)" -ForegroundColor Yellow
        $testResults += @{ Test = "Performance Impact"; Result = "WARN"; Details = "Average time $([math]::Round($avgTime, 2))ms" }
    }
} catch {
    Write-Host "  ✗ Performance impact test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Performance Impact"; Result = "FAIL"; Details = $_.Exception.Message }
}

Write-Host ""

# Test Summary
Write-Host "=== Test Summary ===" -ForegroundColor Yellow
$passed = ($testResults | Where-Object { $_.Result -eq "PASS" }).Count
$failed = ($testResults | Where-Object { $_.Result -eq "FAIL" }).Count
$warned = ($testResults | Where-Object { $_.Result -eq "WARN" }).Count
$total = $testResults.Count

$testResults | ForEach-Object {
    $color = switch ($_.Result) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
    }
    Write-Host "  $($_.Result): $($_.Test) - $($_.Details)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Results: $passed passed, $failed failed, $warned warnings out of $total tests" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -eq 0) {
    Write-Host "✓ All performance optimization tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some performance optimization tests failed!" -ForegroundColor Red
    exit 1
}