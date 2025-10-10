#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Performance baseline measurement script for application startup optimization.

.DESCRIPTION
    Measures startup time and performance metrics across different application modes 
    to establish baseline before and validate improvements after optimization.

.NOTES
    Part of the performance optimization initiative addressing issue #115.
    Measures startup times, function loading performance, and memory usage.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Iterations = 3,
    [Parameter(Mandatory = $false)]
    [switch]$DetailedOutput,
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "performance-baseline.log"
)

$ErrorActionPreference = "Stop"

# Performance measurement function
function Measure-StartupPerformance
{
    param(
        [string]$AppMode,
        [string]$Description,
        [int]$Iterations = 3
    )
    
    $measurements = @()
    
    for ($i = 1; $i -le $Iterations; $i++)
    {
        Write-Host "  [$i/$Iterations] Testing $Description..." -ForegroundColor Cyan
        
        # Clear any cached modules or variables from previous runs
        if (Get-Module -Name "Autopilot*")
        {
            Remove-Module -Name "Autopilot*" -Force
        }
        [System.GC]::Collect()
        
        $startTime = Get-Date
        $startMemory = [System.GC]::GetTotalMemory($false)
        
        try
        {
            # Test application startup with minimal interaction
            $result = & pwsh -NoProfile -Command {
                param($mode, $scriptPath)
                $startTime = Get-Date
                
                try
                {
                    # Load the application in test mode to avoid interactive prompts
                    . $scriptPath -appMode $mode -LogLevel "Warning" -testMode 2>&1 | Out-Null
                    $endTime = Get-Date
                    return @{
                        Success  = $true
                        Duration = ($endTime - $startTime).TotalSeconds
                        Error    = $null
                    }
                }
                catch
                {
                    $endTime = Get-Date
                    return @{
                        Success  = $false
                        Duration = ($endTime - $startTime).TotalSeconds
                        Error    = $_.Exception.Message
                    }
                }
            } -ArgumentList $AppMode, "$PSScriptRoot/../main.ps1"
            
            $endTime = Get-Date
            $endMemory = [System.GC]::GetTotalMemory($false)
            
            if ($result.Success)
            {
                $duration = $result.Duration
                $memoryUsed = [math]::Round(($endMemory - $startMemory) / 1MB, 2)
                
                $measurements += @{
                    Iteration    = $i
                    Duration     = $duration
                    MemoryUsedMB = $memoryUsed
                    Success      = $true
                }
                
                Write-Host "    Duration: $([math]::Round($duration, 2))s, Memory: ${memoryUsed}MB" -ForegroundColor Green
            }
            else
            {
                Write-Host "    Failed: $($result.Error)" -ForegroundColor Red
                $measurements += @{
                    Iteration    = $i
                    Duration     = $result.Duration
                    MemoryUsedMB = 0
                    Success      = $false
                    Error        = $result.Error
                }
            }
        }
        catch
        {
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            Write-Host "    Failed: $($_.Exception.Message)" -ForegroundColor Red
            $measurements += @{
                Iteration    = $i
                Duration     = $duration
                MemoryUsedMB = 0
                Success      = $false
                Error        = $_.Exception.Message
            }
        }
        
        Start-Sleep -Milliseconds 500  # Brief pause between iterations
    }
    
    return $measurements
}

# Test scenarios
$scenarios = @(
    @{ AppMode = "full"; Description = "Full application mode" }
    @{ AppMode = "helpDesk"; Description = "Help desk mode" }
    @{ AppMode = "admin"; Description = "Admin mode" }
    @{ AppMode = "registration"; Description = "Registration mode" }
)

Write-Host "=== Application Startup Performance Baseline ===" -ForegroundColor Yellow
Write-Host "Measuring startup performance across $($scenarios.Count) scenarios with $Iterations iterations each"
Write-Host "Test started: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

$allResults = @{}

foreach ($scenario in $scenarios)
{
    Write-Host "Testing: $($scenario.Description)" -ForegroundColor Yellow
    
    $measurements = Measure-StartupPerformance -AppMode $scenario.AppMode -Description $scenario.Description -Iterations $Iterations
    $allResults[$scenario.AppMode] = $measurements
    
    # Calculate statistics for successful runs
    $successfulRuns = $measurements | Where-Object { $_.Success -eq $true }
    if ($successfulRuns.Count -gt 0)
    {
        $avgDuration = [math]::Round(($successfulRuns | Measure-Object -Property Duration -Average).Average, 2)
        $minDuration = [math]::Round(($successfulRuns | Measure-Object -Property Duration -Minimum).Minimum, 2)
        $maxDuration = [math]::Round(($successfulRuns | Measure-Object -Property Duration -Maximum).Maximum, 2)
        $avgMemory = [math]::Round(($successfulRuns | Measure-Object -Property MemoryUsedMB -Average).Average, 2)
        
        Write-Host "  Average: ${avgDuration}s (Range: ${minDuration}s - ${maxDuration}s)" -ForegroundColor Green
        Write-Host "  Avg Memory: ${avgMemory}MB" -ForegroundColor Green
        Write-Host "  Success Rate: $($successfulRuns.Count)/$($measurements.Count) ($([math]::Round(($successfulRuns.Count / $measurements.Count) * 100, 1))%)" -ForegroundColor Green
    }
    else
    {
        Write-Host "  All iterations failed" -ForegroundColor Red
    }
    Write-Host ""
}

# Overall summary
Write-Host "=== Performance Summary ===" -ForegroundColor Yellow
$overallStats = @()

foreach ($scenario in $scenarios)
{
    $measurements = $allResults[$scenario.AppMode]
    $successfulRuns = $measurements | Where-Object { $_.Success -eq $true }
    
    if ($successfulRuns.Count -gt 0)
    {
        $avgDuration = [math]::Round(($successfulRuns | Measure-Object -Property Duration -Average).Average, 2)
        $avgMemory = [math]::Round(($successfulRuns | Measure-Object -Property MemoryUsedMB -Average).Average, 2)
        
        $overallStats += [PSCustomObject]@{
            Mode        = $scenario.AppMode
            Description = $scenario.Description
            AvgDuration = $avgDuration
            AvgMemoryMB = $avgMemory
            SuccessRate = "$($successfulRuns.Count)/$($measurements.Count)"
        }
    }
}

if ($overallStats.Count -gt 0)
{
    $overallStats | Format-Table -Property Mode, Description, AvgDuration, AvgMemoryMB, SuccessRate -AutoSize
    
    $totalAvgDuration = [math]::Round(($overallStats | Measure-Object -Property AvgDuration -Average).Average, 2)
    $totalAvgMemory = [math]::Round(($overallStats | Measure-Object -Property AvgMemoryMB -Average).Average, 2)
    
    Write-Host "Overall Average Startup Time: ${totalAvgDuration}s" -ForegroundColor Cyan
    Write-Host "Overall Average Memory Usage: ${totalAvgMemory}MB" -ForegroundColor Cyan
}

# Save detailed results if requested
if ($DetailedOutput)
{
    $detailedResults = @{
        TestDate  = Get-Date
        Scenarios = $scenarios
        Results   = $allResults
        Summary   = $overallStats
    }
    
    $jsonOutput = $detailedResults | ConvertTo-Json -Depth 5
    $jsonOutput | Out-File -FilePath $LogFile -Encoding UTF8
    Write-Host "Detailed results saved to: $LogFile" -ForegroundColor Gray
}

Write-Host "Performance baseline measurement completed: $(Get-Date)" -ForegroundColor Gray

# Return summary for automation
return @{
    OverallStats     = $overallStats
    TotalAvgDuration = $totalAvgDuration
    TotalAvgMemory   = $totalAvgMemory
    AllResults       = $allResults
}