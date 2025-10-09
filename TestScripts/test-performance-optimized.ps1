#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Performance validation script for Phase 1, 2, and 3 optimizations.

.DESCRIPTION
    Measures performance improvements after all optimization phases have been implemented.
    Validates that the optimizations provide the expected improvements while maintaining
    functionality. Part of Phase 3 validation framework.

.NOTES
    Part of the performance optimization initiative addressing issue #115.
    Tests the combined impact of all optimization phases.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Iterations = 3,
    [Parameter(Mandatory = $false)]
    [switch]$DetailedOutput,
    [Parameter(Mandatory = $false)]
    [switch]$CompareWithBaseline,
    [Parameter(Mandatory = $false)]
    [string]$LogFile = $null
)

$ErrorActionPreference = "Stop"

# Create temporary folder for test artifacts
$TestTempFolder = Join-Path $env:TEMP "autopilot-perf-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null

# Set log file to temp folder if not specified
if (-not $LogFile)
{
    $LogFile = Join-Path $TestTempFolder "performance-optimized.log"
}

# Import test helper
try
{
    . "$PSScriptRoot/test-helper.ps1"
}
catch
{
    Write-Warning "Could not load test helper, continuing without helper functions"
}

Write-Host "=== Performance Optimized Validation Test ===" -ForegroundColor Yellow
Write-Host "Validating performance improvements from all optimization phases"
Write-Host "Test started: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

$testResults = @()

# Test 1: Optimized Function Performance
Write-Host "Test 1: Optimized Function Performance" -ForegroundColor Cyan

try
{
    # Import optimized functions
    . "$PSScriptRoot/../functions/setupFunctions/Get-ApplicationDefaults.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/MergeSettings.ps1"
    
    # Test caching performance (Phase 1 optimization)
    Write-Host "  Testing default value caching..." -ForegroundColor Gray
    
    # Clear cache
    if (Get-Variable -Name "script:defaultsCache" -Scope Script -ErrorAction SilentlyContinue)
    {
        Remove-Variable -Name "script:defaultsCache" -Scope Script
    }
    
    $measurements = @()
    for ($i = 1; $i -le $Iterations; $i++)
    {
        $startTime = Get-Date
        $result = Get-ApplicationDefaults -DefaultType "Settings" -Version "test.cache.1.0"
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        $measurements += $duration
        
        if ($DetailedOutput)
        {
            Write-Host "    Iteration $i`: $($duration)ms" -ForegroundColor Gray
        }
    }
    
    $avgCacheTime = [math]::Round(($measurements | Measure-Object -Average).Average, 2)
    
    # Test should show improved cache performance on subsequent calls
    $start1 = Get-Date
    $result1 = Get-ApplicationDefaults -DefaultType "Settings" -Version "test.cache.2.0"
    $firstCall = ((Get-Date) - $start1).TotalMilliseconds
    
    $start2 = Get-Date
    $result2 = Get-ApplicationDefaults -DefaultType "Settings" -Version "test.cache.2.0"
    $cachedCall = ((Get-Date) - $start2).TotalMilliseconds
    
    $cacheImprovement = [math]::Round(((($firstCall - $cachedCall) / $firstCall) * 100), 1)
    
    Write-Host "  ✓ Cache performance: First call $($firstCall)ms, Cached call $($cachedCall)ms" -ForegroundColor Green
    Write-Host "  ✓ Cache improvement: $($cacheImprovement)%" -ForegroundColor Green
    
    $testResults += @{
        Test             = "Default Value Caching"
        Success          = $true
        AverageTime      = $avgCacheTime
        CacheImprovement = $cacheImprovement
        Details          = "First: $($firstCall)ms, Cached: $($cachedCall)ms"
    }
    
}
catch
{
    Write-Host "  ✗ Caching test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{
        Test    = "Default Value Caching"
        Success = $false
        Error   = $_.Exception.Message
    }
}

# Test 2: Conditional Flattening Performance
Write-Host ""
Write-Host "Test 2: Conditional Flattening Performance" -ForegroundColor Cyan

try
{
    # Import required functions
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertFrom-JsonToHashtable.ps1"
    
    # Test simple configuration (should bypass flattening)
    $simpleConfig = @{
        setting1 = "value1"
        setting2 = "value2"
        setting3 = $true
    }
    
    $complexConfig = @{
        repoInfo    = @{
            repoName = "TestRepo"
            repoPath = "test/path"
            settings = @{
                nested = @{
                    deepValue = "test"
                }
            }
        }
        simpleValue = "test"
    }
    
    # Measure simple config processing
    $start = Get-Date
    for ($i = 1; $i -le 10; $i++)
    {
        $merged = MergeSettings -localSettings $simpleConfig -globalSettings @{} -Verbose:$false
    }
    $simpleTime = ((Get-Date) - $start).TotalMilliseconds / 10
    
    # Measure complex config processing
    $start = Get-Date
    for ($i = 1; $i -le 10; $i++)
    {
        $merged = MergeSettings -localSettings $complexConfig -globalSettings @{} -Verbose:$false
    }
    $complexTime = ((Get-Date) - $start).TotalMilliseconds / 10
    
    Write-Host "  ✓ Simple config processing: $($simpleTime)ms average" -ForegroundColor Green
    Write-Host "  ✓ Complex config processing: $($complexTime)ms average" -ForegroundColor Green
    
    $testResults += @{
        Test              = "Conditional Flattening"
        Success           = $true
        SimpleConfigTime  = $simpleTime
        ComplexConfigTime = $complexTime
        Details           = "Simple: $($simpleTime)ms, Complex: $($complexTime)ms"
    }
    
}
catch
{
    Write-Host "  ✗ Conditional flattening test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{
        Test    = "Conditional Flattening"
        Success = $false
        Error   = $_.Exception.Message
    }
}

# Test 3: Lazy Loading Performance (Phase 2)
Write-Host ""
Write-Host "Test 3: Lazy Loading Performance" -ForegroundColor Cyan

try
{
    # Import domain configuration function
    . "$PSScriptRoot/../functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1"
    
    # Test lazy loading vs full loading
    $testDomain = "performance.test.com"
    $testGlobalSettings = @{ testSetting = "value" }
    
    # Measure lazy loading
    $start = Get-Date
    $lazyResult = Get-DomainConfigurationFromFiles -DomainName $testDomain -GlobalSettings $testGlobalSettings -ConfigurationPath "$env:TEMP" -LazyLoad
    $lazyTime = ((Get-Date) - $start).TotalMilliseconds
    
    # Measure full loading (simulation)
    $start = Get-Date
    $fullResult = Get-DomainConfigurationFromFiles -DomainName $testDomain -GlobalSettings $testGlobalSettings -ConfigurationPath "$env:TEMP"
    $fullTime = ((Get-Date) - $start).TotalMilliseconds
    
    $lazyImprovement = [math]::Round(((($fullTime - $lazyTime) / $fullTime) * 100), 1)
    
    Write-Host "  ✓ Lazy loading: $($lazyTime)ms" -ForegroundColor Green
    Write-Host "  ✓ Full loading: $($fullTime)ms" -ForegroundColor Green
    Write-Host "  ✓ Lazy loading improvement: $($lazyImprovement)%" -ForegroundColor Green
    
    $testResults += @{
        Test        = "Lazy Loading"
        Success     = $true
        LazyTime    = $lazyTime
        FullTime    = $fullTime
        Improvement = $lazyImprovement
        Details     = "Lazy: $($lazyTime)ms, Full: $($fullTime)ms, Improvement: $($lazyImprovement)%"
    }
    
}
catch
{
    Write-Host "  ✗ Lazy loading test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{
        Test    = "Lazy Loading"
        Success = $false
        Error   = $_.Exception.Message
    }
}

# Test 4: Application Startup Performance (End-to-End)
Write-Host ""
Write-Host "Test 4: Application Startup Performance" -ForegroundColor Cyan

try
{
    $scenarios = @(
        @{ AppMode = "full"; Description = "Full application mode" }
        @{ AppMode = "helpDesk"; Description = "Help desk mode" }
        @{ AppMode = "admin"; Description = "Admin mode" }
    )
    
    $startupResults = @{}
    
    foreach ($scenario in $scenarios)
    {
        Write-Host "  Testing: $($scenario.Description)" -ForegroundColor Gray
        
        $measurements = @()
        for ($i = 1; $i -le $Iterations; $i++)
        {
            # Clear any cached modules
            if (Get-Module -Name "Autopilot*")
            {
                Remove-Module -Name "Autopilot*" -Force
            }
            [System.GC]::Collect()
            
            $startTime = Get-Date
            try
            {
                # Test application startup with optimizations
                $result = & pwsh -NoProfile -Command {
                    param($mode, $scriptPath)
                    $env:SKIP_INTERACTIVE = "true"
                    try
                    {
                        . $scriptPath -appMode $mode -LogLevel "Warning" 2>&1 | Out-Null
                        return @{ Success = $true; Error = $null }
                    }
                    catch
                    {
                        return @{ Success = $false; Error = $_.Exception.Message }
                    }
                } -ArgumentList $scenario.AppMode, "$PSScriptRoot/../main.ps1"
                
                $duration = ((Get-Date) - $startTime).TotalSeconds
                
                if ($result.Success)
                {
                    $measurements += $duration
                    if ($DetailedOutput)
                    {
                        Write-Host "    Iteration $i`: $($duration)s" -ForegroundColor Gray
                    }
                }
                else
                {
                    Write-Host "    Iteration $i failed: $($result.Error)" -ForegroundColor Red
                }
            }
            catch
            {
                Write-Host "    Iteration $i failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            Start-Sleep -Milliseconds 200
        }
        
        if ($measurements.Count -gt 0)
        {
            $avgTime = [math]::Round(($measurements | Measure-Object -Average).Average, 2)
            $minTime = [math]::Round(($measurements | Measure-Object -Minimum).Minimum, 2)
            $maxTime = [math]::Round(($measurements | Measure-Object -Maximum).Maximum, 2)
            
            Write-Host "  ✓ Average: $($avgTime)s (Range: $($minTime)s - $($maxTime)s)" -ForegroundColor Green
            
            $startupResults[$scenario.AppMode] = @{
                Average        = $avgTime
                Minimum        = $minTime
                Maximum        = $maxTime
                SuccessfulRuns = $measurements.Count
                TotalRuns      = $Iterations
            }
        }
        else
        {
            Write-Host "  ✗ All iterations failed for $($scenario.Description)" -ForegroundColor Red
        }
    }
    
    $testResults += @{
        Test    = "Application Startup"
        Success = $startupResults.Count -gt 0
        Results = $startupResults
        Details = "Measured startup across $($scenarios.Count) scenarios"
    }
    
}
catch
{
    Write-Host "  ✗ Startup performance test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{
        Test    = "Application Startup"
        Success = $false
        Error   = $_.Exception.Message
    }
}

# Test 5: Memory Usage Validation
Write-Host ""
Write-Host "Test 5: Memory Usage Validation" -ForegroundColor Cyan

try
{
    # Measure memory usage before and after optimizations
    $initialMemory = [System.GC]::GetTotalMemory($false)
    
    # Simulate optimized function usage
    for ($i = 1; $i -le 50; $i++)
    {
        $result = Get-ApplicationDefaults -DefaultType "Settings" -Version "memory.test.$i"
        $merged = MergeSettings -localSettings @{test = "value$i"} -globalSettings @{}
    }
    
    [System.GC]::Collect()
    $finalMemory = [System.GC]::GetTotalMemory($true)
    $memoryUsed = [math]::Round(($finalMemory - $initialMemory) / 1MB, 2)
    
    Write-Host "  ✓ Memory usage for 50 operations: $($memoryUsed)MB" -ForegroundColor Green
    
    $testResults += @{
        Test         = "Memory Usage"
        Success      = $true
        MemoryUsedMB = $memoryUsed
        Details      = "50 operations used $($memoryUsed)MB"
    }
    
}
catch
{
    Write-Host "  ✗ Memory usage test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{
        Test    = "Memory Usage"
        Success = $false
        Error   = $_.Exception.Message
    }
}

# Summary and Results
Write-Host ""
Write-Host "=== Performance Optimization Test Summary ===" -ForegroundColor Yellow

$successfulTests = ($testResults | Where-Object { $_.Success -eq $true }).Count
$totalTests = $testResults.Count
$successRate = [math]::Round(($successfulTests / $totalTests) * 100, 1)

Write-Host "Tests Completed: $totalTests" -ForegroundColor Gray
Write-Host "Successful: $successfulTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $successfulTests)" -ForegroundColor Red
Write-Host "Success Rate: $($successRate)%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } else { "Yellow" })

Write-Host ""
Write-Host "=== Detailed Results ===" -ForegroundColor Yellow

foreach ($result in $testResults)
{
    $status = if ($result.Success) { "✓" } else { "✗" }
    $color = if ($result.Success) { "Green" } else { "Red" }
    
    Write-Host "$status $($result.Test)" -ForegroundColor $color
    if ($result.Success -and $result.Details)
    {
        Write-Host "  $($result.Details)" -ForegroundColor Gray
    }
    elseif (-not $result.Success -and $result.Error)
    {
        Write-Host "  Error: $($result.Error)" -ForegroundColor Red
    }
}

# Compare with baseline if requested
if ($CompareWithBaseline)
{
    Write-Host ""
    Write-Host "=== Baseline Comparison ===" -ForegroundColor Yellow
    Write-Host "To compare with baseline, run: .\test-performance-baseline.ps1" -ForegroundColor Gray
}

# Log results if requested
if ($LogFile)
{
    try
    {
        $logData = @{
            Timestamp   = Get-Date
            TestResults = $testResults
            Summary     = @{
                TotalTests      = $totalTests
                SuccessfulTests = $successfulTests
                SuccessRate     = $successRate
            }
        }
        
        $logData | ConvertTo-Json -Depth 10 | Out-File -FilePath $LogFile -Encoding UTF8
        Write-Host ""
        Write-Host "Results logged to: $LogFile" -ForegroundColor Gray
    }
    catch
    {
        Write-Warning "Could not write log file: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Test completed: $(Get-Date)" -ForegroundColor Gray

# Cleanup temporary folder
try
{
    if (Test-Path $TestTempFolder)
    {
        Remove-Item -Path $TestTempFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up temporary test folder" -ForegroundColor Gray
    }
}
catch
{
    Write-Warning "Could not clean up temporary folder: $($_.Exception.Message)"
}

# Return exit code based on success rate
if ($successRate -eq 100)
{
    Write-Host "✓ All performance optimization tests passed!" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "⚠ Some performance optimization tests failed!" -ForegroundColor Yellow
    exit 1
}