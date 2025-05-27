<#
.SYNOPSIS
    Test runner script for main.ps1 Pester tests
.DESCRIPTION
    This script runs the Pester tests for main.ps1 and generates a test report.
    It ensures Pester is installed and handles test execution with proper error handling.
.NOTES
    Author: GitHub Copilot
    Date: May 25, 2025
    PowerShell Version: 5.1+ compatible
#>

[CmdletBinding()]
param(
    [string]$TestPath = ".\main.Tests.ps1",
    [string]$OutputPath = ".\TestResults",
    [switch]$PassThru,
    [switch]$Detailed
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

Write-Host "=== Main.ps1 Pester Test Runner ===" -ForegroundColor Cyan
Write-Host "Starting test execution..." -ForegroundColor Green

try {
    # Check if Pester is installed
    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $pesterModule) {
        Write-Host "Pester module not found. Installing Pester..." -ForegroundColor Yellow
        try {
            Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
            Write-Host "Pester installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install Pester: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Host "Found Pester version: $($pesterModule.Version)" -ForegroundColor Green
        
        # Check if we have Pester 5.x (recommended)
        if ($pesterModule.Version.Major -lt 5) {
            Write-Warning "Pester version $($pesterModule.Version) detected. Consider upgrading to Pester 5.x for better features."
        }
    }
    
    # Import Pester module
    Import-Module Pester -Force
    
    # Verify test file exists
    if (-not (Test-Path $TestPath)) {
        Write-Error "Test file not found: $TestPath"
        exit 1
    }
    
    Write-Host "Running tests from: $TestPath" -ForegroundColor Cyan
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
    }
    
    # Configure Pester settings based on version
    $pesterVersion = (Get-Module Pester).Version.Major
    
    if ($pesterVersion -ge 5) {
        # Pester 5.x configuration
        Write-Host "Using Pester 5.x configuration..." -ForegroundColor Yellow
        
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $TestPath
        $pesterConfig.Output.Verbosity = if ($Detailed) { 'Detailed' } else { 'Normal' }
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "TestResults.xml"
        $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
        $pesterConfig.CodeCoverage.Enabled = $false  # Disable for now as it may cause issues with dot-sourced scripts
          # Run tests
        $testResults = Invoke-Pester -Configuration $pesterConfig
        
        # Debug: Log the result object type and available properties
        Write-Verbose "Pester result object type: $($testResults.GetType().FullName)"
        Write-Verbose "Available properties: $($testResults | Get-Member -MemberType Property | Select-Object -ExpandProperty Name | Out-String)"
    }
    else {
        # Pester 4.x configuration
        Write-Host "Using Pester 4.x configuration..." -ForegroundColor Yellow
        
        $testResults = Invoke-Pester -Script $TestPath `
            -OutputFile (Join-Path $OutputPath "TestResults.xml") `
            -OutputFormat NUnitXml `
            -PassThru
    }
      # Display results summary
    Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan
    
    # Handle different Pester result object structures
    if ($pesterVersion -ge 5) {
        # Pester 5.x uses different property names
        $totalTests = if ($testResults.Tests) { $testResults.Tests.Count } else { $testResults.TotalCount }
        $passedTests = if ($testResults.Tests) { ($testResults.Tests | Where-Object { $_.Result -eq 'Passed' }).Count } else { $testResults.PassedCount }
        $failedTests = if ($testResults.Tests) { ($testResults.Tests | Where-Object { $_.Result -eq 'Failed' }).Count } else { $testResults.FailedCount }
        $skippedTests = if ($testResults.Tests) { ($testResults.Tests | Where-Object { $_.Result -eq 'Skipped' }).Count } else { $testResults.SkippedCount }
        
        Write-Host "Total Tests: $totalTests" -ForegroundColor White
        Write-Host "Passed: $passedTests" -ForegroundColor Green
        Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { 'Red' } else { 'Green' })
        Write-Host "Skipped: $skippedTests" -ForegroundColor Yellow
        
        if ($failedTests -gt 0) {
            Write-Host "`n=== Failed Tests ===" -ForegroundColor Red
            $failedTestList = $testResults.Tests | Where-Object { $_.Result -eq 'Failed' }
            foreach ($failedTest in $failedTestList) {
                Write-Host "❌ $($failedTest.ExpandedName)" -ForegroundColor Red
                if ($Detailed -and $failedTest.ErrorRecord) {
                    Write-Host "   Error: $($failedTest.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
                }
            }
        }
        
        $hasFailures = $failedTests -gt 0
    }
    else {
        # Pester 4.x properties
        Write-Host "Total Tests: $($testResults.TotalCount)" -ForegroundColor White
        Write-Host "Passed: $($testResults.PassedCount)" -ForegroundColor Green
        Write-Host "Failed: $($testResults.FailedCount)" -ForegroundColor $(if ($testResults.FailedCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow
        
        if ($testResults.FailedCount -gt 0) {
            Write-Host "`n=== Failed Tests ===" -ForegroundColor Red
            foreach ($failedTest in $testResults.Failed) {
                Write-Host "❌ $($failedTest.Describe) - $($failedTest.Context) - $($failedTest.Name)" -ForegroundColor Red
                if ($Detailed) {
                    Write-Host "   Error: $($failedTest.FailureMessage)" -ForegroundColor DarkRed
                }
            }
        }
        
        $hasFailures = $testResults.FailedCount -gt 0
    }
    
    # Check for test result file
    $resultFile = Join-Path $OutputPath "TestResults.xml"
    if (Test-Path $resultFile) {
        Write-Host "`nTest results saved to: $resultFile" -ForegroundColor Green
    }
    
    # Return results if PassThru is specified
    if ($PassThru) {
        return $testResults
    }
      # Exit with appropriate code
    if ($hasFailures) {
        Write-Host "`nTests completed with failures." -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "`nAll tests passed successfully! ✅" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "An error occurred during test execution: $($_.Exception.Message)"
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
finally {
    Write-Host "`n=== Test Execution Complete ===" -ForegroundColor Cyan
}
