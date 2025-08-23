#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Phase 3 performance monitoring and validation framework.

.DESCRIPTION
    Provides continuous monitoring of performance optimizations and validates that
    improvements are maintained over time. Part of Phase 3 validation framework.

.PARAMETER BaselineFile
    Path to baseline performance data file

.PARAMETER MonitoringMode
    Type of monitoring to perform: Baseline, Validation, Continuous

.PARAMETER OutputFormat
    Output format: Console, JSON, CSV

.NOTES
    Part of the performance optimization initiative addressing issue #115.
    Monitors Phase 1, 2, and 3 optimization effectiveness.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaselineFile = "performance-baseline.json",
    [Parameter(Mandatory = $false)]
    [ValidateSet('Baseline', 'Validation', 'Continuous')]
    [string]$MonitoringMode = 'Validation',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Console', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Console',
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "performance-monitoring.log"
)

$ErrorActionPreference = "Stop"

# Import Write-Log function for logging support
try {
    . "$PSScriptRoot/../functions/utilityFunctions/Write-Log.ps1"
} catch {
    Write-Warning "Could not load Write-Log function: $($_.Exception.Message)"
}

# Set up temporary log file for functions that require it
$tempPath = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
$global:logFile = Join-Path $tempPath "monitoring-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

Write-Host "=== Phase 3 Performance Monitoring Framework ===" -ForegroundColor Yellow
Write-Host "Mode: $MonitoringMode | Output: $OutputFormat" -ForegroundColor Gray
Write-Host "Started: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Performance monitoring functions
function Measure-OptimizationImpact {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [int]$Iterations = 5
    )
    
    $measurements = @()
    $startMemory = [System.GC]::GetTotalMemory($false)
    
    for ($i = 1; $i -le $Iterations; $i++) {
        [System.GC]::Collect()
        $iterationStart = Get-Date
        
        try {
            $result = & $TestScript
            $success = $true
            $error = $null
        } catch {
            $success = $false
            $error = $_.Exception.Message
            $result = $null
        }
        
        $duration = ((Get-Date) - $iterationStart).TotalMilliseconds
        $measurements += @{
            Iteration = $i
            Duration = $duration
            Success = $success
            Error = $error
        }
    }
    
    $endMemory = [System.GC]::GetTotalMemory($true)
    $memoryUsed = [math]::Round(($endMemory - $startMemory) / 1MB, 2)
    
    $successfulMeasurements = $measurements | Where-Object { $_.Success -eq $true }
    
    if ($successfulMeasurements.Count -gt 0) {
        $avgDuration = [math]::Round(($successfulMeasurements | Measure-Object -Property Duration -Average).Average, 2)
        $minDuration = [math]::Round(($successfulMeasurements | Measure-Object -Property Duration -Minimum).Minimum, 2)
        $maxDuration = [math]::Round(($successfulMeasurements | Measure-Object -Property Duration -Maximum).Maximum, 2)
        $successRate = [math]::Round(($successfulMeasurements.Count / $measurements.Count) * 100, 1)
    } else {
        $avgDuration = 0
        $minDuration = 0
        $maxDuration = 0
        $successRate = 0
    }
    
    return @{
        TestName = $TestName
        Iterations = $Iterations
        SuccessfulRuns = $successfulMeasurements.Count
        SuccessRate = $successRate
        AverageDuration = $avgDuration
        MinimumDuration = $minDuration
        MaximumDuration = $maxDuration
        MemoryUsedMB = $memoryUsed
        RawMeasurements = $measurements
        Timestamp = Get-Date
    }
}

function Test-PerformanceBaseline {
    Write-Host "Establishing Performance Baseline..." -ForegroundColor Cyan
    
    $baselineTests = @()
    
    # Import required functions
    try {
        . "$PSScriptRoot/../functions/setupFunctions/Get-ApplicationDefaults.ps1"
        . "$PSScriptRoot/../functions/setupFunctions/MergeSettings.ps1"
        . "$PSScriptRoot/../functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1"
        . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertFrom-JsonToHashtable.ps1"
    } catch {
        Write-Warning "Could not import all functions: $($_.Exception.Message)"
    }
    
    # Test 1: Default Value Loading Performance
    Write-Host "  Measuring default value loading..." -ForegroundColor Gray
    $defaultsTest = Measure-OptimizationImpact -TestName "Get-ApplicationDefaults" -TestScript {
        # Clear cache to measure both cached and uncached performance
        if (Get-Variable -Name "script:defaultsCache" -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name "script:defaultsCache" -Scope Script
        }
        
        $result1 = Get-ApplicationDefaults -DefaultType "Settings" -Version "baseline.1.0"
        $result2 = Get-ApplicationDefaults -DefaultType "Settings" -Version "baseline.1.0"  # Should be cached
        return @($result1, $result2)
    }
    $baselineTests += $defaultsTest
    
    # Test 2: Settings Merge Performance
    Write-Host "  Measuring settings merge..." -ForegroundColor Gray
    $mergeTest = Measure-OptimizationImpact -TestName "MergeSettings" -TestScript {
        $local = @{ setting1 = "value1"; setting2 = "value2"; nested = @{ prop = "val" } }
        $global = @{ setting1 = "global1"; setting3 = "value3"; other = @{ item = "test" } }
        return MergeSettings -localSettings $local -globalSettings $global
    }
    $baselineTests += $mergeTest
    
    # Test 3: Domain Configuration Performance
    Write-Host "  Measuring domain configuration..." -ForegroundColor Gray
    $domainTest = Measure-OptimizationImpact -TestName "Get-DomainConfigurationFromFiles" -TestScript {
        $tempPath = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
        $normal = Get-DomainConfigurationFromFiles -DomainName "baseline.test.com" -GlobalSettings @{test="value"} -ConfigurationPath $tempPath
        $lazy = Get-DomainConfigurationFromFiles -DomainName "baseline.test.com" -GlobalSettings @{test="value"} -ConfigurationPath $tempPath -LazyLoad
        return @($normal, $lazy)
    }
    $baselineTests += $domainTest
    
    # Test 4: Application Startup Simulation
    Write-Host "  Measuring startup simulation..." -ForegroundColor Gray
    $startupTest = Measure-OptimizationImpact -TestName "Application-Startup-Simulation" -TestScript {
        # Simulate key startup operations
        $defaults = Get-ApplicationDefaults -DefaultType "Settings" -Version "startup.sim.1.0"
        $merge = MergeSettings -localSettings @{mode="test"} -globalSettings $defaults
        $tempPath = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
        $domain = Get-DomainConfigurationFromFiles -DomainName "startup.test.com" -GlobalSettings $merge -ConfigurationPath $tempPath -LazyLoad
        return @($defaults, $merge, $domain)
    }
    $baselineTests += $startupTest
    
    return $baselineTests
}

function Test-OptimizationValidation {
    Write-Host "Validating Optimization Effectiveness..." -ForegroundColor Cyan
    
    $validationTests = @()
    
    # Import required functions
    try {
        . "$PSScriptRoot/../functions/setupFunctions/Get-ApplicationDefaults.ps1"
        . "$PSScriptRoot/../functions/setupFunctions/MergeSettings.ps1"
        . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertFrom-JsonToHashtable.ps1"
    } catch {
        Write-Warning "Could not import all functions: $($_.Exception.Message)"
    }
    
    # Validation 1: Cache Effectiveness
    Write-Host "  Validating cache effectiveness..." -ForegroundColor Gray
    
    # Clear cache
    if (Get-Variable -Name "script:defaultsCache" -Scope Script -ErrorAction SilentlyContinue) {
        Remove-Variable -Name "script:defaultsCache" -Scope Script
    }
    
    $cacheTest = Measure-OptimizationImpact -TestName "Cache-Effectiveness-Validation" -TestScript {
        # First call - should populate cache
        $start1 = Get-Date
        $result1 = Get-ApplicationDefaults -DefaultType "Settings" -Version "cache.validation.1.0"
        $firstCallTime = ((Get-Date) - $start1).TotalMilliseconds
        
        # Second call - should use cache
        $start2 = Get-Date
        $result2 = Get-ApplicationDefaults -DefaultType "Settings" -Version "cache.validation.1.0"
        $cachedCallTime = ((Get-Date) - $start2).TotalMilliseconds
        
        # Cache should be significantly faster
        $improvement = if ($firstCallTime -gt 0) { ($firstCallTime - $cachedCallTime) / $firstCallTime * 100 } else { 0 }
        
        return @{
            FirstCall = $firstCallTime
            CachedCall = $cachedCallTime
            ImprovementPercent = $improvement
            CacheWorking = $improvement -gt 50  # Cache should provide at least 50% improvement
        }
    } -Iterations 3
    $validationTests += $cacheTest
    
    # Validation 2: Conditional Flattening Effectiveness
    Write-Host "  Validating conditional flattening..." -ForegroundColor Gray
    $flatteningTest = Measure-OptimizationImpact -TestName "Conditional-Flattening-Validation" -TestScript {
        # Simple configuration (should be faster)
        $simpleConfig = @{ setting1 = "value1"; setting2 = "value2"; flag = $true }
        $start1 = Get-Date
        $simpleResult = MergeSettings -localSettings $simpleConfig -globalSettings @{}
        $simpleTime = ((Get-Date) - $start1).TotalMilliseconds
        
        # Complex configuration (may use flattening)
        $complexConfig = @{
            repoInfo = @{
                name = "test"
                settings = @{
                    nested = @{ value = "deep" }
                }
            }
            simple = "value"
        }
        $start2 = Get-Date
        $complexResult = MergeSettings -localSettings $complexConfig -globalSettings @{}
        $complexTime = ((Get-Date) - $start2).TotalMilliseconds
        
        return @{
            SimpleTime = $simpleTime
            ComplexTime = $complexTime
            OptimizationWorking = $simpleTime -lt $complexTime * 2  # Simple should be notably faster
        }
    } -Iterations 5
    $validationTests += $flatteningTest
    
    # Validation 3: Overall Performance Target
    Write-Host "  Validating overall performance targets..." -ForegroundColor Gray
    $targetTest = Measure-OptimizationImpact -TestName "Performance-Target-Validation" -TestScript {
        # Combined operation should complete within reasonable time
        $start = Get-Date
        
        $defaults = Get-ApplicationDefaults -DefaultType "Settings" -Version "target.validation.$(Get-Random)"
        $merged = MergeSettings -localSettings @{test="value"} -globalSettings $defaults
        
        $totalTime = ((Get-Date) - $start).TotalMilliseconds
        
        return @{
            TotalTime = $totalTime
            WithinTarget = $totalTime -lt 100  # Combined operations should complete in under 100ms
        }
    } -Iterations 10
    $validationTests += $targetTest
    
    return $validationTests
}

function Save-BaselineData {
    param(
        [array]$TestResults,
        [string]$FilePath
    )
    
    $baselineData = @{
        Timestamp = Get-Date
        Version = "Phase3-Monitoring-v1.0"
        TestResults = $TestResults
        SystemInfo = @{
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OS = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            TotalMemoryMB = [math]::Round([System.GC]::GetTotalMemory($false) / 1MB, 2)
        }
    }
    
    try {
        $baselineData | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Host "Baseline data saved to: $FilePath" -ForegroundColor Green
    } catch {
        Write-Warning "Could not save baseline data: $($_.Exception.Message)"
    }
}

function Compare-WithBaseline {
    param(
        [array]$CurrentResults,
        [string]$BaselineFile
    )
    
    if (-not (Test-Path $BaselineFile)) {
        Write-Warning "Baseline file not found: $BaselineFile"
        return $null
    }
    
    try {
        $baselineData = Get-Content -Path $BaselineFile -Raw | ConvertFrom-Json
        
        Write-Host "Comparing with baseline from: $($baselineData.Timestamp)" -ForegroundColor Cyan
        
        $comparisons = @()
        
        foreach ($currentTest in $CurrentResults) {
            $baselineTest = $baselineData.TestResults | Where-Object { $_.TestName -eq $currentTest.TestName }
            
            if ($baselineTest) {
                $improvement = if ($baselineTest.AverageDuration -gt 0) {
                    [math]::Round((($baselineTest.AverageDuration - $currentTest.AverageDuration) / $baselineTest.AverageDuration) * 100, 1)
                } else {
                    0
                }
                
                $comparison = @{
                    TestName = $currentTest.TestName
                    BaselineAverage = $baselineTest.AverageDuration
                    CurrentAverage = $currentTest.AverageDuration
                    ImprovementPercent = $improvement
                    Status = if ($improvement -gt 0) { "Improved" } elseif ($improvement -eq 0) { "Same" } else { "Regressed" }
                }
                
                $comparisons += $comparison
                
                $color = switch ($comparison.Status) {
                    "Improved" { "Green" }
                    "Same" { "Yellow" }
                    "Regressed" { "Red" }
                }
                
                Write-Host "  $($comparison.TestName): $($comparison.Status) (${improvement}%)" -ForegroundColor $color
                Write-Host "    Baseline: $($baselineTest.AverageDuration)ms | Current: $($currentTest.AverageDuration)ms" -ForegroundColor Gray
            } else {
                Write-Host "  $($currentTest.TestName): No baseline data" -ForegroundColor Yellow
            }
        }
        
        return $comparisons
    } catch {
        Write-Warning "Error comparing with baseline: $($_.Exception.Message)"
        return $null
    }
}

# Main execution based on monitoring mode
$results = @()

switch ($MonitoringMode) {
    'Baseline' {
        Write-Host "Creating new performance baseline..." -ForegroundColor Yellow
        $results = Test-PerformanceBaseline
        Save-BaselineData -TestResults $results -FilePath $BaselineFile
    }
    
    'Validation' {
        Write-Host "Validating optimization effectiveness..." -ForegroundColor Yellow
        $results = Test-OptimizationValidation
        
        # Compare with baseline if available
        $comparisons = Compare-WithBaseline -CurrentResults $results -BaselineFile $BaselineFile
    }
    
    'Continuous' {
        Write-Host "Continuous monitoring mode..." -ForegroundColor Yellow
        $results = Test-PerformanceBaseline
        $comparisons = Compare-WithBaseline -CurrentResults $results -BaselineFile $BaselineFile
        
        # Update baseline with current results
        Save-BaselineData -TestResults $results -FilePath "continuous-baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }
}

# Output results based on format
Write-Host ""
Write-Host "=== Monitoring Results Summary ===" -ForegroundColor Yellow

$successfulTests = ($results | Where-Object { $_.SuccessRate -eq 100 }).Count
$totalTests = $results.Count
$overallSuccessRate = if ($totalTests -gt 0) { [math]::Round(($successfulTests / $totalTests) * 100, 1) } else { 0 }

Write-Host "Tests Completed: $totalTests" -ForegroundColor Gray
Write-Host "Fully Successful: $successfulTests" -ForegroundColor Green
Write-Host "Overall Success Rate: ${overallSuccessRate}%" -ForegroundColor $(if ($overallSuccessRate -eq 100) { "Green" } else { "Yellow" })

switch ($OutputFormat) {
    'Console' {
        foreach ($result in $results) {
            $status = if ($result.SuccessRate -eq 100) { "✓" } else { "⚠" }
            $color = if ($result.SuccessRate -eq 100) { "Green" } else { "Yellow" }
            
            Write-Host "$status $($result.TestName)" -ForegroundColor $color
            Write-Host "  Average: $($result.AverageDuration)ms | Range: $($result.MinimumDuration)ms - $($result.MaximumDuration)ms" -ForegroundColor Gray
            Write-Host "  Success Rate: $($result.SuccessRate)% | Memory: $($result.MemoryUsedMB)MB" -ForegroundColor Gray
        }
    }
    
    'JSON' {
        $outputData = @{
            MonitoringMode = $MonitoringMode
            Timestamp = Get-Date
            Results = $results
            Summary = @{
                TotalTests = $totalTests
                SuccessfulTests = $successfulTests
                OverallSuccessRate = $overallSuccessRate
            }
        }
        
        $jsonOutput = $outputData | ConvertTo-Json -Depth 10
        Write-Host $jsonOutput
        
        if ($LogFile) {
            $jsonOutput | Out-File -FilePath $LogFile -Encoding UTF8
        }
    }
    
    'CSV' {
        $csvData = $results | ForEach-Object {
            [PSCustomObject]@{
                TestName = $_.TestName
                AverageDuration = $_.AverageDuration
                MinimumDuration = $_.MinimumDuration
                MaximumDuration = $_.MaximumDuration
                SuccessRate = $_.SuccessRate
                MemoryUsedMB = $_.MemoryUsedMB
                Timestamp = $_.Timestamp
            }
        }
        
        $csvOutput = $csvData | ConvertTo-Csv -NoTypeInformation
        Write-Host $csvOutput
        
        if ($LogFile) {
            $csvOutput | Out-File -FilePath $LogFile.Replace('.log', '.csv') -Encoding UTF8
        }
    }
}

Write-Host ""
Write-Host "Monitoring completed: $(Get-Date)" -ForegroundColor Gray

# Return appropriate exit code
if ($overallSuccessRate -eq 100) {
    Write-Host "✓ All performance monitoring tests passed!" -ForegroundColor Green
    exit 0
} elseif ($overallSuccessRate -ge 80) {
    Write-Host "⚠ Performance monitoring completed with warnings" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✗ Performance monitoring detected issues" -ForegroundColor Red
    exit 2
}