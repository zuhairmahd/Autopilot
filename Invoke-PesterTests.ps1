<#
.SYNOPSIS
    Executes Pester tests for Autopilot project
.DESCRIPTION
    Runs Pester tests with standard configuration
    Supports filtering by test type, tags, and CI/CD integration
.PARAMETER TestType
    Type of tests to run: Unit, Integration, Comprehensive, All
.PARAMETER TestFile
    Path to a single test file to run (overrides TestType)
.PARAMETER EnableCodeCoverage
    Enable code coverage analysis
.PARAMETER CI
    Run in CI/CD mode with NUnit XML output
.PARAMETER Tags
    Filter tests by tags
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestType Unit
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestFile "tests\Integration\SettingsFunctions.Tests.ps1"
.EXAMPLE
    .\Invoke-PesterTests.ps1 -EnableCodeCoverage -CI
#>
[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Comprehensive', 'All')]
    [string]$TestType = 'All',
    [string]$TestFile,
    [switch]$EnableCodeCoverage,
    [switch]$CI,
    [string[]]$Tags = @()
)

$ErrorActionPreference = 'Stop'

# Import configuration
. "$PSScriptRoot\PesterConfiguration.ps1"

Write-Host "=" * 63 -ForegroundColor Cyan
Write-Host "  Autopilot Pester Test Suite" -ForegroundColor Cyan
Write-Host "=" * 63 -ForegroundColor Cyan

# Get Pester configuration
$config = Get-AutopilotPesterConfiguration -TestType $TestType -EnableCodeCoverage:$EnableCodeCoverage -CI:$CI

# Override path if specific test file requested
if ($TestFile)
{
    $resolvedPath = if ([System.IO.Path]::IsPathRooted($TestFile))
    {
        $TestFile
    }
    else
    {
        Join-Path $PSScriptRoot $TestFile
    }
    
    if (-not (Test-Path $resolvedPath))
    {
        Write-Host "ERROR: Test file not found: $resolvedPath" -ForegroundColor Red
        exit 1
    }
    
    $config.Run.Path = $resolvedPath
    Write-Host "`nRunning single test file: $TestFile" -ForegroundColor Yellow
}

# Apply tag filter if specified
if ($Tags.Count -gt 0)
{
    $config.Filter.Tag = $Tags
}

# Display configuration
Write-Host "`nTest Configuration:" -ForegroundColor Cyan
Write-Host "  Test Type: $TestType" -ForegroundColor White
Write-Host "  Test Path ($($config.Run.Path.DESCRIPTION)): $($config.Run.Path.Value)" -ForegroundColor White
Write-Host "  Code Coverage: $($config.CodeCoverage.Enabled)" -ForegroundColor White
if ($Tags.Count -gt 0)
{
    Write-Host "  Tags: $($Tags -join ', ')" -ForegroundColor White
}
Write-Host ""

# Run Pester
$startTime = Get-Date
Write-Host "Starting Pester tests..." -ForegroundColor Cyan

try
{
    $result = Invoke-Pester -Configuration $config
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # Display results
    Write-Host "`n" -NoNewline
    Write-Host "=" * 63 -ForegroundColor Cyan
    Write-Host "  Test Results" -ForegroundColor Cyan
    Write-Host "=" * 63 -ForegroundColor Cyan
    Write-Host "  Total Tests: $($result.TotalCount)" -ForegroundColor White
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Gray
    Write-Host "  Duration: $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor White
    
    # Display failed test details if any
    if ($result.FailedCount -gt 0)
    {
        Write-Host "`n  Failed Tests:" -ForegroundColor Red
        
        # Group failed tests by file
        $failedByFile = $result.Failed | Group-Object -Property { 
            if ($_.ScriptBlock.File)
            {
                Split-Path $_.ScriptBlock.File -Leaf
            }
            else
            {
                "Unknown File"
            }
        } | Sort-Object Name
        
        foreach ($fileGroup in $failedByFile)
        {
            Write-Host "`n    $($fileGroup.Name) ($($fileGroup.Count) failure$(if ($fileGroup.Count -ne 1) {'s'})):" -ForegroundColor Yellow
            foreach ($test in $fileGroup.Group)
            {
                Write-Host "      - $($test.ExpandedName)" -ForegroundColor Red
                if ($test.ErrorRecord)
                {
                    Write-Host "        Error: $($test.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
                }
            }
        }
        Write-Host ""
    }
    
    if ($config.CodeCoverage.Enabled)
    {
        $coverage = $result.CodeCoverage
        $coveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0)
        {
            ($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100
        }
        else { 0 }
        
        Write-Host "`nCode Coverage:" -ForegroundColor Cyan
        Write-Host "  Commands Analyzed: $($coverage.NumberOfCommandsAnalyzed)" -ForegroundColor White
        Write-Host "  Commands Executed: $($coverage.NumberOfCommandsExecuted)" -ForegroundColor White
        Write-Host "  Coverage: $($coveragePercent.ToString('F2'))%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
        Write-Host "  Report: $($config.CodeCoverage.OutputPath)" -ForegroundColor Gray
    }
    
    if ($config.TestResult.Enabled)
    {
        Write-Host "`nTest Results XML: $($config.TestResult.OutputPath)" -ForegroundColor Gray
    }
    
    Write-Host "=" * 63 -ForegroundColor Cyan
    Write-Host ""
    
    # Exit with appropriate code
    exit $result.FailedCount
}
catch
{
    Write-Host "`nERROR: Pester execution failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
