#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Legacy test runner - DEPRECATED: Use Test-Runner.ps1 instead
.DESCRIPTION
    This script is deprecated. Please use the new unified Test-Runner.ps1 for all testing.
    This legacy runner is maintained for backward compatibility only.
    
    The new Test-Runner.ps1 provides:
    - Advanced test categorization and filtering
    - Better reporting and error handling
    - Integration with the unified testing framework
    - Support for different test types and execution modes
.PARAMETER TestPattern
    Pattern to match test files (default: "test-*.ps1")
.PARAMETER ExcludePattern
    Pattern to exclude test files (default: "test-helper.ps1")
.PARAMETER ContinueOnError
    Continue running tests even if one fails
.PARAMETER Verbose
    Show verbose output from tests
.NOTES
    Author: Automated Test System
    Version: 1.0.0 (DEPRECATED)
    Compatible: PowerShell 5.1+
    
    MIGRATION NOTICE:
    Please migrate to Test-Runner.ps1 for enhanced functionality:
    - Old: .\run-all-tests.ps1
    - New: .\Test-Runner.ps1 -TestCategory all
    
    See Test-Runner.ps1 -ListCategories for available test categories
#>

[CmdletBinding()]
param(
    [string]$TestPattern = "test-*.ps1",
    [string]$ExcludePattern = "test-helper.ps1",
    [switch]$ContinueOnError,
    [switch]$ShowVerbose
)

# Check if new test runner exists and recommend its use
$newTestRunner = Join-Path $PSScriptRoot "Test-Runner.ps1"
if (Test-Path $newTestRunner) {
    Write-Host "=" * 80 -ForegroundColor Yellow
    Write-Host "DEPRECATION NOTICE" -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Yellow
    Write-Host "This script (run-all-tests.ps1) is deprecated." -ForegroundColor Red
    Write-Host "Please use the new unified Test-Runner.ps1 instead:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current command equivalent:" -ForegroundColor Cyan
    if ($TestPattern -eq "test-*.ps1" -and $ExcludePattern -eq "test-helper.ps1") {
        Write-Host "  .\Test-Runner.ps1 -TestCategory all" -ForegroundColor Green
    } else {
        Write-Host "  .\Test-Runner.ps1 -TestCategory specific -TestPattern '$TestPattern'" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Additional options:" -ForegroundColor Cyan
    Write-Host "  .\Test-Runner.ps1 -ListCategories    # See available test categories" -ForegroundColor Green
    Write-Host "  .\Test-Runner.ps1 -ListTests         # See all available tests" -ForegroundColor Green
    Write-Host "  .\Test-Runner.ps1 -TestCategory unit # Run only unit tests" -ForegroundColor Green
    Write-Host ""
    
    # Ask user if they want to proceed with legacy runner or switch
    $response = Read-Host "Continue with legacy runner? (y/N) [Recommended: N to use new runner]"
    if ($response -notmatch '^y|yes$') {
        Write-Host "Launching new Test-Runner.ps1..." -ForegroundColor Green
        
        # Build arguments for new test runner
        $newArgs = @()
        
        if ($TestPattern -ne "test-*.ps1") {
            $newArgs += @('-TestCategory', 'specific', '-TestPattern', $TestPattern)
        } else {
            $newArgs += @('-TestCategory', 'all')
        }
        
        if ($ContinueOnError) {
            $newArgs += '-ContinueOnError'
        }
        
        if ($ShowVerbose) {
            $newArgs += '-ShowVerbose'
        }
        
        try {
            & $newTestRunner @newArgs
            exit $LASTEXITCODE
        }
        catch {
            Write-Host "Error launching new test runner: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Falling back to legacy runner..." -ForegroundColor Yellow
        }
    }
    
    Write-Host "Continuing with legacy runner..." -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Yellow
}

# Load test helper functions
try
{
    . "$PSScriptRoot\test-helper.ps1"
    $psInfo = Test-PowerShellVersion
}
catch
{
    Write-Host "Failed to load test helper functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Display header
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "AUTOPILOT TEST SUITE" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor White
Write-Host "Unicode Support: $($psInfo.SupportsUnicode)" -ForegroundColor White
Write-Host "Test Pattern: $TestPattern" -ForegroundColor White
if ($ExcludePattern)
{
    Write-Host "Exclude Pattern: $ExcludePattern" -ForegroundColor White
}
Write-Host ""

# Get test files
$testFiles = Get-ChildItem -Path $PSScriptRoot -Filter $TestPattern | Where-Object {
    $_.Name -notlike $ExcludePattern -and $_.Length -gt 0
} | Sort-Object Name

if ($testFiles.Count -eq 0)
{
    Write-Host "No test files found matching pattern: $TestPattern" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($testFiles.Count) test files:" -ForegroundColor Yellow
foreach ($file in $testFiles)
{
    $sizeKB = [math]::Round($file.Length / 1024, 1)
    Write-Verbose "  - $($file.Name) ($sizeKB KB)"
}

# Test execution tracking
$testResults = @()
$totalTests = $testFiles.Count
$passedTests = 0
$failedTests = 0
$skippedTests = 0

# Execute tests
Write-TestSection "Running Tests"

foreach ($testFile in $testFiles)
{
    $testName = $testFile.BaseName
    $testPath = $testFile.FullName
    
    Write-Host "Running: $testName" -ForegroundColor Cyan
    Write-Host "Path: $testPath" -ForegroundColor Gray
    
    $testResult = @{
        Name      = $testName
        Path      = $testPath
        Status    = "Unknown"
        Duration  = $null
        Output    = ""
        Error     = $null
        StartTime = Get-Date
    }
    
    try
    {
        $startTime = Get-Date
        
        # Create a new PowerShell session for each test to ensure isolation
        $testArgs = @(
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', $testPath
        )
        
        if ($ShowVerbose)
        {
            $testArgs += '-Verbose'
        }
        
        # Run the test
        $output = & pwsh @testArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        $testResult.Duration = $duration
        $testResult.Output = $output -join "`n"
        
        if ($exitCode -eq 0)
        {
            $testResult.Status = "Passed"
            Write-TestResult "$testName completed successfully ($($duration.TotalSeconds.ToString('F2'))s)" -Success $true
            $passedTests++
        }
        else
        {
            $testResult.Status = "Failed"
            $testResult.Error = "Exit code: $exitCode"
            Write-TestResult "$testName failed with exit code $exitCode ($($duration.TotalSeconds.ToString('F2'))s)" -Success $false
            $failedTests++
            
            if ($output)
            {
                Write-Host "Output:" -ForegroundColor Yellow
                Write-Host $testResult.Output -ForegroundColor Gray
            }
        }
    }
    catch
    {
        $testResult.Status = "Error"
        $testResult.Error = $_.Exception.Message
        $testResult.Duration = (Get-Date) - $testResult.StartTime
        
        Write-TestResult "$testName failed with error: $($_.Exception.Message)" -Success $false
        $failedTests++
        
        if (-not $ContinueOnError)
        {
            Write-Host "Stopping test execution due to error. Use -ContinueOnError to continue." -ForegroundColor Red
            break
        }
    }
    
    $testResults += $testResult
    Write-Host ""
}

# Generate summary report
Write-TestSection "Test Results Summary"

$totalDuration = ($testResults | Where-Object { $_.Duration } | ForEach-Object { $_.Duration.TotalSeconds } | Measure-Object -Sum).Sum
if ($totalDuration)
{
    $totalSeconds = $totalDuration
}
else
{
    $totalSeconds = 0
}

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red
Write-Host "Skipped: $skippedTests" -ForegroundColor Yellow
Write-Host "Total Duration: $($totalSeconds.ToString('F2')) seconds" -ForegroundColor White

if ($passedTests -eq $totalTests)
{
    Write-Host ""
    Write-TestResult "ALL TESTS PASSED!" -Success $true
    $exitCode = 0
}
else
{
    Write-Host ""
    Write-TestResult "$failedTests tests failed" -Success $false
    $exitCode = 1
}

# Detailed results table
if ($testResults.Count -gt 0)
{
    Write-TestSection "Detailed Results"
    
    $tableData = $testResults | ForEach-Object {
        $statusSymbol = switch ($_.Status)
        {
            "Passed" { if ($psInfo.SupportsUnicode) { "✓" } else { "[PASS]" } }
            "Failed" { if ($psInfo.SupportsUnicode) { "✗" } else { "[FAIL]" } }
            "Error" { if ($psInfo.SupportsUnicode) { "⚠" } else { "[ERR]" } }
            default { "?" }
        }
        
        $durationStr = if ($_.Duration)
        { 
            "$($_.Duration.TotalSeconds.ToString('F2'))s" 
        }
        else
        { 
            "N/A" 
        }
        
        [PSCustomObject]@{
            Status   = $statusSymbol
            Test     = $_.Name
            Duration = $durationStr
            Error    = if ($_.Error) { $_.Error.Substring(0, [Math]::Min(50, $_.Error.Length)) } else { "" }
        }
    }
    
    $tableData | Format-Table -AutoSize
}

# Failed tests details
$failedTestsList = $testResults | Where-Object { $_.Status -ne "Passed" }
if ($failedTestsList.Count -gt 0)
{
    Write-TestSection "Failed Tests Details"
    
    foreach ($failedTest in $failedTestsList)
    {
        Write-Host "Test: $($failedTest.Name)" -ForegroundColor Red
        if ($failedTest.Error)
        {
            Write-Host "Error: $($failedTest.Error)" -ForegroundColor Yellow
        }
        if ($failedTest.Output -and $failedTest.Output.Trim())
        {
            Write-Host "Output:" -ForegroundColor Yellow
            $lines = $failedTest.Output -split "`n" | Select-Object -Last 10
            foreach ($line in $lines)
            {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
}

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Test run completed. Exit code: $exitCode" -ForegroundColor White
Write-Host "=" * 80 -ForegroundColor Cyan

exit $exitCode