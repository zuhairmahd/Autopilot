<#
.SYNOPSIS
    Advanced test configuration and runner for main.ps1
.DESCRIPTION
    This script provides advanced testing capabilities including:
    - Code coverage analysis
    - Test categorization
    - Performance testing
    - Mock verification
    - Integration with CI/CD pipelines
.NOTES
    Author: GitHub Copilot
    Date: May 25, 2025
    PowerShell Version: 5.1+ compatible
#>

[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'All')]
    [string]$TestType = 'All',
    
    [switch]$CodeCoverage,
    
    [switch]$Performance,
    
    [string]$OutputFormat = 'NUnitXml',
    
    [string]$ReportPath = '.\TestReports',
    
    [switch]$CI,
    
    [int]$TimeoutMinutes = 10
)

# Set execution policy for CI environments
if ($CI) {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
}

Write-Host "=== Advanced Test Runner for main.ps1 ===" -ForegroundColor Cyan
Write-Host "Test Type: $TestType" -ForegroundColor Yellow
Write-Host "Code Coverage: $($CodeCoverage.IsPresent)" -ForegroundColor Yellow
Write-Host "Performance Testing: $($Performance.IsPresent)" -ForegroundColor Yellow

# Ensure required modules are available
$requiredModules = @('Pester')
if ($Performance) {
    $requiredModules += 'PSBenchmark'
}

foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Force -SkipPublisherCheck -Scope CurrentUser
        }
        catch {
            Write-Warning "Failed to install $module. Some features may not be available."
        }
    }
}

# Import required modules
Import-Module Pester -Force

# Create report directory
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

try {
    # Set timeout for test execution
    $timeout = New-TimeSpan -Minutes $TimeoutMinutes
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Configure Pester based on version and requirements
    $pesterVersion = (Get-Module Pester).Version.Major
    
    if ($pesterVersion -ge 5) {
        Write-Host "Configuring Pester 5.x..." -ForegroundColor Green
        
        $config = New-PesterConfiguration
        
        # Basic configuration
        $config.Run.Path = '.\main.Tests.ps1'
        $config.Output.Verbosity = 'Detailed'
        
        # Test filtering based on TestType
        switch ($TestType) {
            'Unit' {
                $config.Filter.Tag = 'Unit'
                Write-Host "Running Unit tests only" -ForegroundColor Yellow
            }
            'Integration' {
                $config.Filter.Tag = 'Integration'
                Write-Host "Running Integration tests only" -ForegroundColor Yellow
            }
            'All' {
                Write-Host "Running all tests" -ForegroundColor Yellow
            }
        }
        
        # Test results configuration
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = Join-Path $ReportPath "TestResults.xml"
        $config.TestResult.OutputFormat = $OutputFormat
        
        # Code coverage configuration
        if ($CodeCoverage) {
            Write-Host "Enabling code coverage analysis..." -ForegroundColor Yellow
            $config.CodeCoverage.Enabled = $true
            $config.CodeCoverage.Path = '.\main.ps1'
            $config.CodeCoverage.OutputPath = Join-Path $ReportPath "CodeCoverage.xml"
            $config.CodeCoverage.OutputFormat = 'JaCoCo'
        }
        
        # Performance configuration
        if ($Performance) {
            Write-Host "Enabling performance monitoring..." -ForegroundColor Yellow
            # Custom performance tracking will be handled in the tests
        }
        
        # Run tests with timeout
        $job = Start-Job -ScriptBlock {
            param($config)
            Import-Module Pester -Force
            Invoke-Pester -Configuration $config
        } -ArgumentList $config
        
        # Wait for completion or timeout
        $completed = Wait-Job $job -Timeout $timeout
        
        if ($completed) {
            $results = Receive-Job $job
            Remove-Job $job
        }
        else {
            Write-Error "Test execution timed out after $TimeoutMinutes minutes"
            Stop-Job $job
            Remove-Job $job
            exit 1
        }
    }
    else {
        # Pester 4.x fallback
        Write-Host "Using Pester 4.x..." -ForegroundColor Yellow
        
        $pesterParams = @{
            Script = '.\main.Tests.ps1'
            OutputFile = Join-Path $ReportPath "TestResults.xml"
            OutputFormat = $OutputFormat
            PassThru = $true
        }
        
        if ($CodeCoverage) {
            $pesterParams.CodeCoverage = '.\main.ps1'
            $pesterParams.CodeCoverageOutputFile = Join-Path $ReportPath "CodeCoverage.xml"
        }
        
        $results = Invoke-Pester @pesterParams
    }
    
    $stopwatch.Stop()
    
    # Generate detailed report
    Write-Host "`n=== Detailed Test Report ===" -ForegroundColor Cyan
    Write-Host "Execution Time: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host "Total Tests: $($results.TotalCount)" -ForegroundColor White
    Write-Host "Passed: $($results.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Skipped: $($results.SkippedCount)" -ForegroundColor Yellow
    Write-Host "Pending: $(if ($results.PendingCount) { $results.PendingCount } else { 0 })" -ForegroundColor Yellow
    
    # Success rate calculation
    if ($results.TotalCount -gt 0) {
        $successRate = [math]::Round(($results.PassedCount / $results.TotalCount) * 100, 2)
        Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 95) { 'Green' } elseif ($successRate -ge 80) { 'Yellow' } else { 'Red' })
    }
    
    # Code coverage report
    if ($CodeCoverage -and $results.CodeCoverage) {
        Write-Host "`n=== Code Coverage Report ===" -ForegroundColor Cyan
        $coverage = $results.CodeCoverage
        $coveragePercent = [math]::Round(($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100, 2)
        Write-Host "Commands Analyzed: $($coverage.NumberOfCommandsAnalyzed)" -ForegroundColor White
        Write-Host "Commands Executed: $($coverage.NumberOfCommandsExecuted)" -ForegroundColor White
        Write-Host "Coverage Percentage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
        
        if ($coverage.MissedCommands.Count -gt 0) {
            Write-Host "`nMissed Commands:" -ForegroundColor Yellow
            $coverage.MissedCommands | Select-Object -First 10 | ForEach-Object {
                Write-Host "  Line $($_.Line): $($_.Command)" -ForegroundColor DarkYellow
            }
            if ($coverage.MissedCommands.Count -gt 10) {
                Write-Host "  ... and $($coverage.MissedCommands.Count - 10) more" -ForegroundColor DarkYellow
            }
        }
    }
    
    # Failed tests details
    if ($results.FailedCount -gt 0) {
        Write-Host "`n=== Failed Tests Details ===" -ForegroundColor Red
        foreach ($failedTest in ($results.Failed | Select-Object -First 5)) {
            Write-Host "❌ $($failedTest.Describe) > $($failedTest.Context) > $($failedTest.Name)" -ForegroundColor Red
            Write-Host "   Error: $($failedTest.FailureMessage)" -ForegroundColor DarkRed
            if ($failedTest.ErrorRecord) {
                Write-Host "   Location: $($failedTest.ErrorRecord.InvocationInfo.ScriptName):$($failedTest.ErrorRecord.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkRed
            }
            Write-Host ""
        }
        if ($results.FailedCount -gt 5) {
            Write-Host "... and $($results.FailedCount - 5) more failed tests. Check the full report for details." -ForegroundColor DarkRed
        }
    }
    
    # Generate summary report file
    $summaryReport = @{
        TestSuite = "main.ps1"
        ExecutionTime = $stopwatch.Elapsed.ToString()
        Results = @{
            Total = $results.TotalCount
            Passed = $results.PassedCount
            Failed = $results.FailedCount
            Skipped = $results.SkippedCount
            Pending = if ($results.PendingCount) { $results.PendingCount } else { 0 }
            SuccessRate = if ($results.TotalCount -gt 0) { [math]::Round(($results.PassedCount / $results.TotalCount) * 100, 2) } else { 0 }
        }
        CodeCoverage = if ($CodeCoverage -and $results.CodeCoverage) {
            @{
                Enabled = $true
                CommandsAnalyzed = $results.CodeCoverage.NumberOfCommandsAnalyzed
                CommandsExecuted = $results.CodeCoverage.NumberOfCommandsExecuted
                CoveragePercent = [math]::Round(($results.CodeCoverage.NumberOfCommandsExecuted / $results.CodeCoverage.NumberOfCommandsAnalyzed) * 100, 2)
            }
        } else {
            @{ Enabled = $false }
        }
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $summaryReport | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $ReportPath "TestSummary.json") -Encoding UTF8
    
    # CI/CD integration
    if ($CI) {
        Write-Host "`n=== CI/CD Integration ===" -ForegroundColor Cyan
        
        # Output test results in a format that CI systems can understand
        if ($results.FailedCount -eq 0) {
            Write-Host "##vso[task.complete result=Succeeded;]All tests passed" -ForegroundColor Green
        }
        else {
            Write-Host "##vso[task.complete result=Failed;]$($results.FailedCount) tests failed" -ForegroundColor Red
        }
        
        # Set environment variables for downstream tasks
        Write-Host "##vso[task.setvariable variable=TestsPassed]$($results.PassedCount)"
        Write-Host "##vso[task.setvariable variable=TestsFailed]$($results.FailedCount)"
        Write-Host "##vso[task.setvariable variable=TestsTotal]$($results.TotalCount)"
        
        if ($CodeCoverage -and $results.CodeCoverage) {
            Write-Host "##vso[task.setvariable variable=CodeCoveragePercent]$([math]::Round(($results.CodeCoverage.NumberOfCommandsExecuted / $results.CodeCoverage.NumberOfCommandsAnalyzed) * 100, 2))"
        }
    }
    
    Write-Host "`nReports generated in: $ReportPath" -ForegroundColor Green
    Get-ChildItem $ReportPath | ForEach-Object {
        Write-Host "  📄 $($_.Name)" -ForegroundColor Gray
    }
    
    # Exit with appropriate code
    exit $(if ($results.FailedCount -gt 0) { 1 } else { 0 })
}
catch {
    Write-Error "Test execution failed: $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
finally {
    if ($stopwatch) {
        $stopwatch.Stop()
    }
    Write-Host "`n=== Test Execution Complete ===" -ForegroundColor Cyan
}
