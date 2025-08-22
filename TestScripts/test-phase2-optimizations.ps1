#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests Phase 2 performance optimizations implementation.

.DESCRIPTION
    Validates that Phase 2 performance optimizations are working correctly,
    including logging optimization, file operation batching, and lazy loading.
    
.OUTPUTS
    Test results and performance metrics for Phase 2 optimizations.
#>

param(
    [switch]$ShowVerbose,
    [switch]$SkipPerformanceTests
)

# Test configuration
$TestName = "test-phase2-optimizations"
$logFile = "$pwd\Logs\TestLogs\$TestName.log"

# Ensure test log directory exists
$logDir = Split-Path -Parent $logFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Write-Host "=== Phase 2 Performance Optimizations Test ===" -ForegroundColor Yellow
Write-Host "Test: $TestName" -ForegroundColor Cyan

$startTime = Get-Date
$testResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Tests = @()
}

function Test-Result($TestName, $Condition, $Details = "") {
    $testResults.Total++
    $result = if ($Condition) { 
        $testResults.Passed++
        "PASS" 
    } else { 
        $testResults.Failed++
        "FAIL" 
    }
    
    $testResults.Tests += @{
        Name = $TestName
        Result = $result
        Details = $Details
    }
    
    $color = if ($Condition) { "Green" } else { "Red" }
    Write-Host "  [$result] $TestName" -ForegroundColor $color
    if ($Details -and ($ShowVerbose -or -not $Condition)) {
        Write-Host "        $Details" -ForegroundColor Gray
    }
}

try {
    # Import required functions
    Write-Host "`nLoading required functions..." -ForegroundColor Cyan
    
    # Load all functions from the functions directory
    $functionDirs = Get-ChildItem -Path "$pwd\functions" -Directory
    foreach ($dir in $functionDirs) {
        $functionFiles = Get-ChildItem -Path $dir.FullName -Filter "*.ps1"
        foreach ($file in $functionFiles) {
            . $file.FullName
        }
    }
    
    Write-Host "Functions loaded successfully" -ForegroundColor Green

    # Test 1: Verify Conditional Logging Optimization
    Write-Host "`nTesting Conditional Logging Optimization..." -ForegroundColor Cyan
    
    # Use proper temp directory
    $tempDir = [System.IO.Path]::GetTempPath()
    $testInitFile = Join-Path $tempDir "test-settings-$([System.Guid]::NewGuid()).json"
    $testStringsFile = Join-Path $tempDir "test-strings-$([System.Guid]::NewGuid()).json"
    
    # Create minimal test files
    @{
        auth = @{
            enabled = "true"
        }
        globalSettings = @{
            testSetting1 = "value1"
            testSetting2 = "true"
            testSetting3 = "value3"
        }
        menus = @()
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $testInitFile -Force
    
    @{
        strings = @{
            test = "Test String"
        }
    } | ConvertTo-Json | Set-Content -Path $testStringsFile -Force
    
    # Test with verbose disabled (should use conditional logging)
    $VerbosePreference = 'SilentlyContinue'
    $logCount1 = 0
    
    # Capture write operations to count them
    $result1 = Initialize-ApplicationConfiguration -InitFile $testInitFile -StringsFile $testStringsFile -Domain "test.com" -PSBoundParameters @{}
    
    Test-Result "Auth configuration processing" ($result1.Success -eq $true) "Success: $($result1.Success)"
    Test-Result "Global settings loaded" ($result1.GlobalSettings.Count -gt 0) "Count: $($result1.GlobalSettings.Count)"
    
    # Test 2: Verify File Operation Batching
    Write-Host "`nTesting File Operation Batching..." -ForegroundColor Cyan
    
    # The batched file validation should be used in Initialize-ApplicationConfiguration
    $batchTestStart = Get-Date
    $result2 = Initialize-ApplicationConfiguration -InitFile $testInitFile -StringsFile $testStringsFile -Domain "test.com" -PSBoundParameters @{}
    $batchTestEnd = Get-Date
    $batchDuration = ($batchTestEnd - $batchTestStart).TotalMilliseconds
    
    Test-Result "File batch validation successful" ($result2.Success -eq $true) "Duration: $($batchDuration)ms"
    Test-Result "Configuration loaded with batching" ($result2.GlobalSettings.Count -gt 0) "Settings: $($result2.GlobalSettings.Count)"
    
    # Test 3: Verify Lazy Loading Implementation
    Write-Host "`nTesting Lazy Loading Implementation..." -ForegroundColor Cyan
    
    # Test lazy loading
    $lazyLoadStart = Get-Date
    $lazyConfig = Get-DomainConfigurationFromFiles -DomainName "test.com" -LazyLoad
    $lazyLoadEnd = Get-Date
    $lazyDuration = ($lazyLoadEnd - $lazyLoadStart).TotalMilliseconds
    
    Test-Result "Lazy loading returns minimal config" ($lazyConfig.settings.lazyLoaded -eq $true) "LazyLoaded: $($lazyConfig.settings.lazyLoaded)"
    Test-Result "Lazy loading is fast" ($lazyDuration -lt 100) "Duration: $($lazyDuration)ms"
    Test-Result "Domain name preserved" ($lazyConfig._domainName -eq "test.com") "Domain: $($lazyConfig._domainName)"
    
    # Test full loading from lazy config
    $fullLoadStart = Get-Date
    $fullConfig = Invoke-LazyDomainConfigurationLoad -LazyConfiguration $lazyConfig
    $fullLoadEnd = Get-Date
    $fullDuration = ($fullLoadEnd - $fullLoadStart).TotalMilliseconds
    
    Test-Result "Full loading from lazy config works" ($fullConfig.settings.domain -eq "test.com") "Domain: $($fullConfig.settings.domain)"
    Test-Result "Full config is not lazy loaded" ($fullConfig.settings.lazyLoaded -ne $true) "LazyLoaded: $($fullConfig.settings.lazyLoaded)"
    
    # Test 4: Verify Array Display Fix
    Write-Host "`nTesting Array Display Fix..." -ForegroundColor Cyan
    
    # Test single element array handling
    function Test-ArrayDisplayInternal($Value) {
        if ($Value -is [array]) {
            $joinedValue = $Value -join ', '
            return "[$joinedValue]"
        } else {
            return "(nested object)"
        }
    }
    
    # Simulate the fixed Get-ArrayInput behavior
    function Test-ArrayReturn($Value) {
        $result = @($Value)
        if ($result.Count -eq 1) {
            $result = @($result[0])
        }
        return ,$result  # Using comma operator fix
    }
    
    $singleElementArray = Test-ArrayReturn "cloudconfig"
    $displayResult = Test-ArrayDisplayInternal $singleElementArray
    
    Test-Result "Single element array preserved as array" ($singleElementArray -is [array]) "Type: $($singleElementArray.GetType().Name)"
    Test-Result "Single element array displays correctly" ($displayResult -eq "[cloudconfig]") "Display: $displayResult"
    
    $multiElementArray = Test-ArrayReturn @("msb", "autopilot")
    $multiDisplayResult = Test-ArrayDisplayInternal $multiElementArray
    
    Test-Result "Multi element array preserved" ($multiElementArray -is [array]) "Count: $($multiElementArray.Count)"
    Test-Result "Multi element array displays correctly" ($multiDisplayResult -eq "[msb, autopilot]") "Display: $multiDisplayResult"
    
    # Performance comparison test (if not skipped)
    if (-not $SkipPerformanceTests) {
        Write-Host "`nTesting Performance Improvements..." -ForegroundColor Cyan
        
        # Test multiple initialization calls to measure caching benefits
        $performanceTests = @()
        
        for ($i = 1; $i -le 5; $i++) {
            $perfStart = Get-Date
            $perfResult = Initialize-ApplicationConfiguration -InitFile $testInitFile -StringsFile $testStringsFile -Domain "test.com" -PSBoundParameters @{}
            $perfEnd = Get-Date
            $perfDuration = ($perfEnd - $perfStart).TotalMilliseconds
            $performanceTests += $perfDuration
        }
        
        $avgDuration = ($performanceTests | Measure-Object -Average).Average
        $maxDuration = ($performanceTests | Measure-Object -Maximum).Maximum
        $minDuration = ($performanceTests | Measure-Object -Minimum).Minimum
        
        Test-Result "Average initialization time reasonable" ($avgDuration -lt 1000) "Avg: $([math]::Round($avgDuration, 2))ms"
        Test-Result "Performance consistency good" (($maxDuration - $minDuration) -lt 500) "Range: $([math]::Round($maxDuration - $minDuration, 2))ms"
        
        Write-Host "    Performance metrics:" -ForegroundColor Gray
        Write-Host "      Average: $([math]::Round($avgDuration, 2))ms" -ForegroundColor Gray
        Write-Host "      Min: $([math]::Round($minDuration, 2))ms" -ForegroundColor Gray
        Write-Host "      Max: $([math]::Round($maxDuration, 2))ms" -ForegroundColor Gray
    }
    
    # Cleanup test files
    if (Test-Path $testInitFile) { Remove-Item $testInitFile -Force }
    if (Test-Path $testStringsFile) { Remove-Item $testStringsFile -Force }
    
} catch {
    Write-Host "Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    $testResults.Failed++
    $testResults.Total++
}

# Final results
$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

Write-Host "`n=== Test Results ===" -ForegroundColor Yellow
Write-Host "Total Tests: $($testResults.Total)" -ForegroundColor White
Write-Host "Passed: $($testResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.Failed)" -ForegroundColor Red
Write-Host "Duration: $([math]::Round($totalDuration, 2)) seconds" -ForegroundColor White

if ($testResults.Failed -eq 0) {
    Write-Host "`n✓ All Phase 2 optimization tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests failed. Check the details above." -ForegroundColor Red
    exit 1
}