#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Unified Test Runner for the Windows Autopilot Management Tool
.DESCRIPTION
    This is the single point of entry for all testing in the Windows Autopilot Management Tool.
    It provides comprehensive test discovery, categorization, and execution with advanced filtering
    and reporting capabilities. All testing should go through this runner.
.PARAMETER TestCategory
    Category of tests to run. Available categories:
    - all: Run all tests (default)
    - unit: Individual component tests
    - integration: Cross-component integration tests  
    - comprehensive: Full workflow and end-to-end tests
    - validation: Final validation and verification tests
    - demo: Interactive demonstration scripts
    - syntax: Quick syntax and loading validation
    - core: Essential functionality tests
    - enhanced: Enhanced functionality tests (new test scripts)
    - specialized: Specialized and advanced functionality tests
    - specific: Run specific tests by pattern (requires -TestPattern)
.PARAMETER TestPattern
    Specific pattern to match test files (e.g., "test-menu*", "test-auth*")
    Only used when TestCategory is 'specific'
.PARAMETER ExcludePattern
    Pattern to exclude test files (default excludes helper and runner files)
.PARAMETER ListTests
    List available tests by category without running them
.PARAMETER ListCategories
    List all available test categories and their descriptions
.PARAMETER ContinueOnError
    Continue running tests even if one fails
.PARAMETER ShowVerbose
    Show verbose output from individual tests
.PARAMETER DryRun
    Show what tests would be run without actually executing them
.PARAMETER ParallelExecution
    Run tests in parallel where safe (not implemented yet)
.PARAMETER OutputFormat
    Output format for results: Console (default), JSON, XML
.PARAMETER LogLevel
    Logging level: Minimal, Normal (default), Verbose, Debug
.NOTES
    Author: Windows Autopilot Management Tool Team
    Version: 2.0.0
    Compatible: PowerShell 5.1+
    
    This runner replaces individual test script execution and provides:
    - Automatic test discovery and categorization
    - Advanced filtering and selection
    - Comprehensive reporting and logging
    - Integration with the unified test framework
    
.EXAMPLE
    # Run all tests
    .\Test-Runner.ps1
    
.EXAMPLE
    # Run only unit tests
    .\Test-Runner.ps1 -TestCategory unit
    
.EXAMPLE
    # Run integration tests with verbose output
    .\Test-Runner.ps1 -TestCategory integration -ShowVerbose
    
.EXAMPLE
    # Run specific menu tests
    .\Test-Runner.ps1 -TestCategory specific -TestPattern "test-menu*"
    
.EXAMPLE
    # List available tests
    .\Test-Runner.ps1 -ListTests
    
.EXAMPLE
    # Quick syntax validation
    .\Test-Runner.ps1 -TestCategory syntax
#>

[CmdletBinding()]
param(
    [ValidateSet('all', 'unit', 'integration', 'comprehensive', 'validation', 'demo', 'syntax', 'core', 'specific', 'enhanced', 'specialized')]
    [string]$TestCategory = 'all',
    
    [string]$TestPattern = $null,
    [string]$ExcludePattern = "test-helper.ps1,Test-Runner.ps1,run-all-tests.ps1",
    [switch]$ListTests,
    [switch]$ListCategories,
    [switch]$ContinueOnError,
    [switch]$ShowVerbose,
    [switch]$DryRun,
    [switch]$ParallelExecution,
    
    [ValidateSet('Console', 'JSON', 'XML')]
    [string]$OutputFormat = 'Console',
    
    [ValidateSet('Minimal', 'Normal', 'Verbose', 'Debug')]
    [string]$LogLevel = 'Normal'
)

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

# Test Registry - Central definition of all test categories and their patterns
$TestRegistry = @{
    'syntax'        = @{
        Description       = 'Quick syntax validation and function loading tests'
        Pattern           = 'test-syntax.ps1'
        Priority          = 1
        EstimatedDuration = '< 5 seconds'
        Dependencies      = @()
    }
    'core'          = @{
        Description       = 'Essential functionality tests required for basic operation'
        Pattern           = 'test-core-validation.ps1,test-function-loading-validation.ps1,test-simple-function-loading.ps1'
        Priority          = 2
        EstimatedDuration = '30-60 seconds'
        Dependencies      = @('syntax')
    }
    'unit'          = @{
        Description       = 'Individual component and function tests'
        Pattern           = 'test-settings-functions.ps1,test-json-merge.ps1,test-password-change.ps1,test-temporary-encryption.ps1,test-array-verification.ps1,test-array-storage-issue.ps1,test-getappassignmenttypes.ps1,test-checknextuserreadiness.ps1,test-corporate-device-identifier.ps1,test-backward-compatibility.ps1'
        Priority          = 3
        EstimatedDuration = '2-4 minutes'
        Dependencies      = @('syntax', 'core')
    }
    'integration'   = @{
        Description       = 'Cross-component integration and workflow tests'
        Pattern           = 'test-menu-inclusions.ps1,test-menu-logic-validation.ps1,test-menu-search-logic.ps1,test-configuration-system1.ps1,test-settings-integration.ps1,test-auth-settings.ps1,test-migration-callers.ps1,test-menu-inclusions-integration.ps1,test-e2e-appmode.ps1'
        Priority          = 4
        EstimatedDuration = '3-5 minutes'
        Dependencies      = @('syntax', 'core', 'unit')
    }
    'comprehensive' = @{
        Description       = 'Full workflow and end-to-end comprehensive tests'
        Pattern           = 'test-comprehensive.ps1,test-menu-system-comprehensive.ps1,test-configuration-comprehensive.ps1,test-appmode-comprehensive.ps1,test-auth-flows-comprehensive.ps1,test-autopilot-import-comprehensive.ps1,test-device-lookup-comprehensive.ps1,test-main-integration.ps1,test-menu-inclusions-e2e.ps1'
        Priority          = 5
        EstimatedDuration = '5-8 minutes'
        Dependencies      = @('syntax', 'core', 'unit', 'integration')
    }
    'validation'    = @{
        Description       = 'Final validation and verification tests'
        Pattern           = 'final-validation.ps1,final-validation-comprehensive.ps1,final-validation-issue-91.ps1,final-verification.ps1'
        Priority          = 6
        EstimatedDuration = '2-3 minutes'
        Dependencies      = @('syntax', 'core')
    }
    'demo'          = @{
        Description       = 'Interactive demonstration and showcase scripts'
        Pattern           = 'demo-*.ps1'
        Priority          = 7
        EstimatedDuration = 'Variable (interactive)'
        Dependencies      = @()
    }
    'enhanced'      = @{
        Description       = 'Enhanced functionality tests (new test scripts)'
        Pattern           = 'test-enhanced-menu-functions.ps1,test-new-utility-functions.ps1,test-graph-encryption-functions.ps1'
        Priority          = 4
        EstimatedDuration = '2-3 minutes'
        Dependencies      = @('syntax', 'core')
    }
    'specialized'   = @{
        Description       = 'Specialized and advanced functionality tests'
        Pattern           = 'test-appmode-refactored.ps1,test-appmode-wizard.ps1,test-autoupdate-wizard.ps1,test-firstrun-wizard.ps1,test-mnemonic-navigation.ps1,test-settings-editor.ps1,test-settings-menu.ps1,test-device-selection.ps1,test-delegated-auth-update.ps1,test-group-assignment-fixes.ps1,test-update-setting-unified.ps1,test-authentication-types.ps1'
        Priority          = 5
        EstimatedDuration = '4-6 minutes'
        Dependencies      = @('syntax', 'core', 'unit')
    }
}

function Get-TestFilesByCategory
{
    <#
    .SYNOPSIS
        Gets test files for a specific category based on the test registry
    #>
    param(
        [string]$Category
    )
    
    if (-not $TestRegistry.ContainsKey($Category))
    {
        throw "Unknown test category: $Category"
    }
    
    $categoryInfo = $TestRegistry[$Category]
    $patterns = $categoryInfo.Pattern -split ','
    $testFiles = @()
    
    foreach ($pattern in $patterns)
    {
        $pattern = $pattern.Trim()
        if ($pattern.EndsWith('.ps1'))
        {
            # Exact file match
            $file = Get-ChildItem -Path $PSScriptRoot -Filter $pattern -ErrorAction SilentlyContinue
            if ($file)
            {
                $testFiles += $file
            }
        }
        else
        {
            # Wildcard pattern
            $files = Get-ChildItem -Path $PSScriptRoot -Filter "$pattern*.ps1" -ErrorAction SilentlyContinue
            $testFiles += $files
        }
    }
    
    # Apply exclusions
    $excludePatterns = $ExcludePattern -split ','
    foreach ($excludePattern in $excludePatterns)
    {
        $excludePattern = $excludePattern.Trim()
        $testFiles = $testFiles | Where-Object { $_.Name -notlike $excludePattern }
    }
    
    return $testFiles | Sort-Object Name | Get-Unique
}

function Get-AllTestFiles
{
    <#
    .SYNOPSIS
        Gets all test files, excluding helpers and runners
    #>
    
    $allFiles = Get-ChildItem -Path $PSScriptRoot -Filter "test-*.ps1" -ErrorAction SilentlyContinue
    
    # Apply exclusions
    $excludePatterns = $ExcludePattern -split ','
    foreach ($excludePattern in $excludePatterns)
    {
        $excludePattern = $excludePattern.Trim()
        $allFiles = $allFiles | Where-Object { $_.Name -notlike $excludePattern }
    }
    
    return $allFiles | Sort-Object Name
}

function Show-TestCategories
{
    <#
    .SYNOPSIS
        Displays all available test categories and their descriptions
    #>
    
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "AVAILABLE TEST CATEGORIES" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
    
    $sortedCategories = $TestRegistry.GetEnumerator() | Sort-Object { $_.Value.Priority }
    
    foreach ($category in $sortedCategories)
    {
        $name = $category.Key
        $info = $category.Value
        
        Write-Host "Category: $name" -ForegroundColor Yellow
        Write-Host "  Description: $($info.Description)" -ForegroundColor White
        Write-Host "  Priority: $($info.Priority)" -ForegroundColor Gray
        Write-Host "  Estimated Duration: $($info.EstimatedDuration)" -ForegroundColor Gray
        
        if ($info.Dependencies.Count -gt 0)
        {
            Write-Host "  Dependencies: $($info.Dependencies -join ', ')" -ForegroundColor Gray
        }
        
        # Show test count
        try
        {
            $testCount = (Get-TestFilesByCategory -Category $name).Count
            Write-Host "  Tests: $testCount files" -ForegroundColor Cyan
        }
        catch
        {
            Write-Host "  Tests: Unable to determine count" -ForegroundColor Red
        }
        
        Write-Host ""
    }
    
    Write-Host "Special Categories:" -ForegroundColor Yellow
    Write-Host "  all: Run all available tests" -ForegroundColor White
    Write-Host "  specific: Run tests matching a specific pattern (requires -TestPattern)" -ForegroundColor White
    Write-Host ""
}

function Show-TestListing
{
    <#
    .SYNOPSIS
        Lists all available tests organized by category
    #>
    
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "AVAILABLE TESTS BY CATEGORY" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
    
    $sortedCategories = $TestRegistry.GetEnumerator() | Sort-Object { $_.Value.Priority }
    $totalTests = 0
    
    foreach ($category in $sortedCategories)
    {
        $name = $category.Key
        $info = $category.Value
        
        Write-Host "[$name] - $($info.Description)" -ForegroundColor Yellow
        
        try
        {
            $tests = Get-TestFilesByCategory -Category $name
            if ($tests.Count -gt 0)
            {
                foreach ($test in $tests)
                {
                    $sizeKB = [math]::Round($test.Length / 1024, 1)
                    Write-Host "  ✓ $($test.Name) ($sizeKB KB)" -ForegroundColor Green
                }
                $totalTests += $tests.Count
                Write-Host "  Subtotal: $($tests.Count) tests" -ForegroundColor Cyan
            }
            else
            {
                Write-Host "  No tests found for this category" -ForegroundColor Gray
            }
        }
        catch
        {
            Write-Host "  Error loading tests: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host ""
    }
    
    # Show unategorized tests
    $allTests = Get-AllTestFiles
    $categorizedTests = @()
    
    foreach ($category in $TestRegistry.Keys)
    {
        try
        {
            $categorizedTests += Get-TestFilesByCategory -Category $category
        }
        catch
        {
            # Skip categories with errors
        }
    }
    
    $uncategorizedTests = $allTests | Where-Object { 
        $testName = $_.Name
        $isCategorized = $categorizedTests | Where-Object { $_.Name -eq $testName }
        return -not $isCategorized
    }
    
    if ($uncategorizedTests.Count -gt 0)
    {
        Write-Host "[uncategorized] - Tests not assigned to a category" -ForegroundColor Magenta
        foreach ($test in $uncategorizedTests)
        {
            $sizeKB = [math]::Round($test.Length / 1024, 1)
            Write-Host "  ? $($test.Name) ($sizeKB KB)" -ForegroundColor Yellow
        }
        $totalTests += $uncategorizedTests.Count
        Write-Host "  Subtotal: $($uncategorizedTests.Count) tests" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "Total Available Tests: $totalTests" -ForegroundColor White
    Write-Host "=" * 80 -ForegroundColor Cyan
}

function Invoke-TestExecution
{
    <#
    .SYNOPSIS
        Executes the selected tests with comprehensive reporting
    #>
    param(
        [array]$TestFiles,
        [string]$CategoryName
    )
    
    if ($TestFiles.Count -eq 0)
    {
        Write-Host "No test files found for category: $CategoryName" -ForegroundColor Red
        return @{
            TotalTests   = 0
            PassedTests  = 0
            FailedTests  = 0
            SkippedTests = 0
            Duration     = [TimeSpan]::Zero
            Results      = @()
        }
    }
    
    # Display execution header
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "EXECUTING TESTS: $CategoryName" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor White
    Write-Host "Unicode Support: $($psInfo.SupportsUnicode)" -ForegroundColor White
    Write-Host "Log Level: $LogLevel" -ForegroundColor White
    Write-Host "Tests to Run: $($TestFiles.Count)" -ForegroundColor White
    Write-Host ""
    
    if ($DryRun)
    {
        Write-Host "DRY RUN - Tests that would be executed:" -ForegroundColor Yellow
        foreach ($file in $TestFiles)
        {
            Write-Host "  - $($file.Name)" -ForegroundColor Cyan
        }
        return @{
            TotalTests   = $TestFiles.Count
            PassedTests  = 0
            FailedTests  = 0
            SkippedTests = $TestFiles.Count
            Duration     = [TimeSpan]::Zero
            Results      = @()
        }
    }
    
    # Test execution tracking
    $testResults = @()
    $totalTests = $TestFiles.Count
    $passedTests = 0
    $failedTests = 0
    $skippedTests = 0
    $startTime = Get-Date
    
    # Execute tests
    Write-TestSection "Running Tests"
    
    for ($i = 0; $i -lt $TestFiles.Count; $i++)
    {
        $testFile = $TestFiles[$i]
        $testName = $testFile.BaseName
        $testPath = $testFile.FullName
        $progress = [math]::Round(($i / $totalTests) * 100, 1)
        
        Write-Host "[$($i + 1)/$totalTests] ($progress%) Running: $testName" -ForegroundColor Cyan
        if ($LogLevel -in @('Verbose', 'Debug'))
        {
            Write-Host "Path: $testPath" -ForegroundColor Gray
        }
        
        $testResult = @{
            Name      = $testName
            Path      = $testPath
            Status    = "Unknown"
            Duration  = $null
            Output    = ""
            Error     = $null
            StartTime = Get-Date
            Category  = $CategoryName
        }
        
        try
        {
            $testStartTime = Get-Date
            
            # Create test arguments
            $testArgs = @(
                '-NoProfile'
                '-ExecutionPolicy', 'Bypass'
                '-File', $testPath
            )
            
            # Add verbosity based on log level
            if ($ShowVerbose -or $LogLevel -in @('Verbose', 'Debug'))
            {
                $testArgs += '-Verbose'
            }
            
            # Run the test in isolated session
            $output = & pwsh @testArgs 2>&1
            $exitCode = $LASTEXITCODE
            
            $testEndTime = Get-Date
            $duration = $testEndTime - $testStartTime
            
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
                
                if ($LogLevel -in @('Verbose', 'Debug') -and $testResult.Output)
                {
                    Write-Host "Test Output:" -ForegroundColor Yellow
                    $outputLines = $testResult.Output -split "`n" | Select-Object -Last 5
                    foreach ($line in $outputLines)
                    {
                        Write-Host "  $line" -ForegroundColor Gray
                    }
                }
                
                if (-not $ContinueOnError)
                {
                    Write-Host "Stopping test execution due to failure. Use -ContinueOnError to continue." -ForegroundColor Red
                    break
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
        
        # Show progress for long test runs
        if ($totalTests -gt 5 -and $LogLevel -ne 'Minimal')
        {
            Write-Host ""
        }
    }
    
    $totalDuration = (Get-Date) - $startTime
    
    return @{
        TotalTests   = $totalTests
        PassedTests  = $passedTests
        FailedTests  = $failedTests
        SkippedTests = $skippedTests
        Duration     = $totalDuration
        Results      = $testResults
        Category     = $CategoryName
    }
}

function Write-TestSummary
{
    <#
    .SYNOPSIS
        Writes comprehensive test execution summary
    #>
    param(
        [hashtable]$ExecutionResult
    )
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "TEST EXECUTION SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    $total = $ExecutionResult.TotalTests
    $passed = $ExecutionResult.PassedTests
    $failed = $ExecutionResult.FailedTests
    $skipped = $ExecutionResult.SkippedTests
    $duration = $ExecutionResult.Duration
    
    Write-Host "Category: $($ExecutionResult.Category)" -ForegroundColor White
    Write-Host "Total Tests: $total" -ForegroundColor White
    Write-Host "Passed: $passed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor Red
    Write-Host "Skipped: $skipped" -ForegroundColor Yellow
    
    if ($total -gt 0)
    {
        $successRate = ($passed / $total * 100).ToString('F1')
        Write-Host "Success Rate: $successRate%" -ForegroundColor Cyan
    }
    
    Write-Host "Total Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
    
    # Overall result
    $success = $failed -eq 0 -and $total -gt 0
    Write-Host ""
    Write-TestResult "Overall Result: $(if ($success) { 'SUCCESS' } else { 'FAILURE' })" -Success $success
    
    # Detailed results table for failed tests
    $failedTests = $ExecutionResult.Results | Where-Object { $_.Status -ne "Passed" }
    if ($failedTests.Count -gt 0 -and $LogLevel -ne 'Minimal')
    {
        Write-TestSection "Failed Tests Details"
        
        foreach ($failedTest in $failedTests)
        {
            Write-Host "Test: $($failedTest.Name)" -ForegroundColor Red
            if ($failedTest.Error)
            {
                Write-Host "Error: $($failedTest.Error)" -ForegroundColor Yellow
            }
            if ($failedTest.Output -and $failedTest.Output.Trim() -and $LogLevel -in @('Verbose', 'Debug'))
            {
                Write-Host "Output (last 3 lines):" -ForegroundColor Yellow
                $lines = $failedTest.Output -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 3
                foreach ($line in $lines)
                {
                    Write-Host "  $line" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
    }
    
    Write-Host "=" * 80 -ForegroundColor Cyan
}

# Main execution logic
try
{
    # Handle list operations
    if ($ListCategories)
    {
        Show-TestCategories
        exit 0
    }
    
    if ($ListTests)
    {
        Show-TestListing
        exit 0
    }
    
    # Validate specific category requirements
    if ($TestCategory -eq 'specific' -and -not $TestPattern)
    {
        Write-Host "Error: -TestPattern is required when using -TestCategory 'specific'" -ForegroundColor Red
        Write-Host "Example: -TestCategory specific -TestPattern 'test-menu*'" -ForegroundColor Yellow
        exit 1
    }
    
    # Get test files based on category
    $testFiles = @()
    
    if ($TestCategory -eq 'all')
    {
        # Get all tests from all categories
        Write-TestSection "Discovering All Tests"
        
        foreach ($category in $TestRegistry.Keys)
        {
            try
            {
                $categoryTests = Get-TestFilesByCategory -Category $category
                $testFiles += $categoryTests
                Write-Host "Found $($categoryTests.Count) tests in category: $category" -ForegroundColor Cyan
            }
            catch
            {
                Write-Warning "Error loading category '$category': $($_.Exception.Message)"
            }
        }
        
        # Remove duplicates and sort
        $testFiles = $testFiles | Sort-Object Name | Get-Unique
        $categoryName = "All Categories"
        
    }
    elseif ($TestCategory -eq 'specific')
    {
        # Pattern-based selection
        Write-TestSection "Pattern-Based Test Discovery"
        Write-Host "Pattern: $TestPattern" -ForegroundColor Yellow
        
        $testFiles = Get-ChildItem -Path $PSScriptRoot -Filter $TestPattern -ErrorAction SilentlyContinue
        
        # Apply exclusions
        $excludePatterns = $ExcludePattern -split ','
        foreach ($excludePattern in $excludePatterns)
        {
            $excludePattern = $excludePattern.Trim()
            $testFiles = $testFiles | Where-Object { $_.Name -notlike $excludePattern }
        }
        
        $categoryName = "Pattern: $TestPattern"
        
    }
    else
    {
        # Category-based selection
        Write-TestSection "Category-Based Test Discovery"
        Write-Host "Category: $TestCategory" -ForegroundColor Yellow
        
        if (-not $TestRegistry.ContainsKey($TestCategory))
        {
            Write-Host "Error: Unknown test category '$TestCategory'" -ForegroundColor Red
            Write-Host "Use -ListCategories to see available categories" -ForegroundColor Yellow
            exit 1
        }
        
        $testFiles = Get-TestFilesByCategory -Category $TestCategory
        $categoryName = $TestCategory
    }
    
    Write-Host "Discovered $($testFiles.Count) test files" -ForegroundColor Green
    
    if ($testFiles.Count -eq 0)
    {
        Write-Host "No tests found matching the specified criteria" -ForegroundColor Yellow
        exit 0
    }
    
    # Execute tests
    $executionResult = Invoke-TestExecution -TestFiles $testFiles -CategoryName $categoryName
    
    # Write summary
    Write-TestSummary -ExecutionResult $executionResult
    
    # Set exit code based on results
    $exitCode = if ($executionResult.FailedTests -eq 0 -and $executionResult.TotalTests -gt 0)
    {
        0 
    }
    else
    {
        1 
    }
    
    Write-Host "Test Runner completed. Exit code: $exitCode" -ForegroundColor White
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    exit $exitCode
}
catch
{
    Write-Host "Test Runner encountered an error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 2
}