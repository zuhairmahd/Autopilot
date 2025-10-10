#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test harness for migration tests - loads all functions then runs test scenarios.

.DESCRIPTION
    This script leverages the existing function loading logic from test.ps1 to ensure
    all functions are properly loaded before running migration tests. This approach:
    - Reuses proven function loading logic
    - Ensures all dependencies are available
    - Provides a consistent execution environment
    - Avoids scoping issues with dot-sourced functions

.PARAMETER TestSuite
    Which test suite to run. Valid values: 'comprehensive', 'silent-mode', 'e2e', 'all'
    Default: 'all'

.EXAMPLE
    .\Run-MigrationTests.ps1
    Runs all migration test suites

.EXAMPLE
    .\Run-MigrationTests.ps1 -TestSuite comprehensive
    Runs only the comprehensive test suite

.EXAMPLE
    .\Run-MigrationTests.ps1 -TestSuite silent-mode -Verbose
    Runs silent mode tests with verbose output
#>

[CmdletBinding()]
param(
    [ValidateSet('comprehensive', 'silent-mode', 'e2e', 'all')]
    [string]$TestSuite = 'all',
    
    [switch]$SkipFunctionLoad
)

$ErrorActionPreference = "Stop"
$testScriptPath = $PSCommandPath

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Migration Test Harness" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Test Suite: $TestSuite" -ForegroundColor Yellow
Write-Host ""

#region Load Functions (borrowed from test.ps1)
if (-not $SkipFunctionLoad)
{
    Write-Host "Loading application functions..." -ForegroundColor Yellow
    
    # Determine script path
    $scriptName = "Run-MigrationTests.ps1"
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
    {
        $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
        Write-Verbose "[$scriptName] Running as an external script."
        Write-Verbose "[$scriptName] Script path: $ScriptPath"
    }
    else
    {
        Write-Verbose "[$scriptName] Running as a script block."
        $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
        Write-Verbose "[$scriptName] Script path: $ScriptPath"
        if (!$ScriptPath)
        {
            Write-Verbose "[$scriptName] Script path is not set. Defaulting to current directory: $pwd"
            $ScriptPath = "$PWD"
            Write-Verbose "[$scriptName] Default script path: $ScriptPath"
        }
    }
    
    # Use the same Find-FolderPath function as test.ps1
    function Find-FolderPath()
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [Parameter(Mandatory = $true)]
            [string]$FolderName
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Find-FolderPath called with Path: $Path, FolderName: $FolderName"
        try
        {
            $currentPath = (Resolve-Path -Path $Path).Path
            Write-Verbose "[$functionName] Current path resolved to: $currentPath"

            # 1. Search children (recursively) of the starting path
            Write-Verbose "[$functionName] Searching children of $currentPath for folder named $FolderName"
            $childMatch = Get-ChildItem -Path $currentPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
            if ($childMatch)
            {
                Write-Verbose "[$functionName] Found folder in children: $($childMatch.FullName)"
                return $childMatch.FullName
            }
            # Also check if the starting path itself matches
            if ((Split-Path -Path $currentPath -Leaf) -ieq $FolderName)
            {
                Write-Verbose "[$functionName] Starting path itself matches: $currentPath"
                return $currentPath
            }

            # 2. Search up the parent chain
            while ($currentPath)
            {
                $parent = Split-Path -Path $currentPath -Parent
                if ($parent -eq $currentPath -or [string]::IsNullOrEmpty($parent))
                {
                    break
                }
                Write-Verbose "[$functionName] Searching children of parent: $parent for folder named $FolderName"
                $siblingMatch = Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
                if ($siblingMatch)
                {
                    Write-Verbose "[$functionName] Found folder in parent: $($siblingMatch.FullName)"
                    return $siblingMatch.FullName
                }
                if ((Split-Path -Path $parent -Leaf) -ieq $FolderName)
                {
                    Write-Verbose "[$functionName] Parent itself matches: $parent"
                    return $parent
                }
                $currentPath = $parent
            }
            Write-Verbose "[$functionName] No folder found with name $FolderName"
            return $null
        }
        catch
        {
            Write-Error "[$functionName] Error occurred while searching for folder: $_"
            return $null
        }
    }

    $functionsFolder = Find-FolderPath -Path $scriptPath -FolderName 'functions'
    if (Test-Path $functionsFolder)
    {
        Write-Verbose "[$scriptName] Importing functions from $functionsFolder"
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
        $loadedCount = 0
        $errorCount = 0
        
        foreach ($function in $functions)
        {
            try
            {
                Write-Verbose "[$scriptName] Importing function $($function.Name)"
                . $function.FullName
                $loadedCount++
            }
            catch
            {
                Write-Warning "Failed to load function $($function.Name): $($_.Exception.Message)"
                $errorCount++
            }
        }
        
        Write-Host "  ✓ Loaded $loadedCount functions ($errorCount errors)" -ForegroundColor Green
    }
    else
    {
        Write-Host "Cannot find the functions folder. Exiting script." -ForegroundColor Red
        exit 1
    }
    
    # Verify critical migration functions are loaded
    Write-Host "Verifying critical functions..." -ForegroundColor Yellow
    $criticalFunctions = @(
        'Invoke-SettingsMigration',
        'Resolve-MigratedLegacyObjects',
        'Update-Setting'
    )
    
    $missingFunctions = @()
    foreach ($funcName in $criticalFunctions)
    {
        if (-not (Get-Command $funcName -ErrorAction SilentlyContinue))
        {
            $missingFunctions += $funcName
        }
        else
        {
            Write-Host "  ✓ $funcName" -ForegroundColor Green
        }
    }
    
    if ($missingFunctions.Count -gt 0)
    {
        Write-Host "Critical functions not loaded: $($missingFunctions -join ', ')" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  ✓ All critical functions verified" -ForegroundColor Green
    Write-Host ""
}
else
{
    Write-Host "Skipping function load (already loaded)" -ForegroundColor Gray
    Write-Host ""
}
#endregion Load Functions

#region Setup Global Test Variables
$global:LogFile = Join-Path $env:TEMP "migration-test-$(Get-Date -Format 'yyyyMMddHHmmss').log"
Write-Host "Test log file: $global:LogFile" -ForegroundColor Gray
Write-Host ""
#endregion Setup Global Test Variables

#region Define Test Execution Function
function Invoke-TestScript
{
    param(
        [string]$TestScriptPath,
        [string]$TestName
    )
    
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Running: $TestName" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Test script: $TestScriptPath" -ForegroundColor Gray
    Write-Host ""
    
    if (-not (Test-Path $TestScriptPath))
    {
        Write-Host "Test script not found: $TestScriptPath" -ForegroundColor Red
        return $false
    }
    
    try
    {
        # Execute the test script in the current scope so it has access to loaded functions
        . $TestScriptPath
        return $true
    }
    catch
    {
        Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        return $false
    }
}
#endregion Define Test Execution Function

#region Execute Tests
$testResults = @{
    TotalSuites   = 0
    PassedSuites  = 0
    FailedSuites  = 0
    SkippedSuites = 0
}

$testScriptsPath = Split-Path $testScriptPath -Parent

# Define test suites
$testSuites = @(
    @{
        Name        = 'comprehensive'
        DisplayName = 'Comprehensive Migration Tests'
        ScriptName  = 'test-migration-comprehensive.ps1'
        Enabled     = ($TestSuite -eq 'all' -or $TestSuite -eq 'comprehensive')
    },
    @{
        Name        = 'silent-mode'
        DisplayName = 'Silent Mode Integration Tests'
        ScriptName  = 'test-migration-silent-mode-integration.ps1'
        Enabled     = ($TestSuite -eq 'all' -or $TestSuite -eq 'silent-mode')
    },
    @{
        Name        = 'e2e'
        DisplayName = 'End-to-End Workflow Tests'
        ScriptName  = 'test-migration-e2e-workflow.ps1'
        Enabled     = ($TestSuite -eq 'all' -or $TestSuite -eq 'e2e')
    }
)

foreach ($suite in $testSuites)
{
    $testResults.TotalSuites++
    
    if (-not $suite.Enabled)
    {
        Write-Host "Skipping: $($suite.DisplayName)" -ForegroundColor Gray
        $testResults.SkippedSuites++
        continue
    }
    
    $testScriptFullPath = Join-Path $testScriptsPath $suite.ScriptName
    $success = Invoke-TestScript -TestScriptPath $testScriptFullPath -TestName $suite.DisplayName
    
    if ($success)
    {
        $testResults.PassedSuites++
    }
    else
    {
        $testResults.FailedSuites++
    }
    
    Write-Host ""
}
#endregion Execute Tests

#region Display Summary
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Execution Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Total Suites:   $($testResults.TotalSuites)" -ForegroundColor White
Write-Host "Passed:         $($testResults.PassedSuites)" -ForegroundColor Green
Write-Host "Failed:         $($testResults.FailedSuites)" -ForegroundColor $(if ($testResults.FailedSuites -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped:        $($testResults.SkippedSuites)" -ForegroundColor Gray
Write-Host ""

if ($testResults.FailedSuites -eq 0 -and $testResults.PassedSuites -gt 0)
{
    Write-Host "All test suites passed!" -ForegroundColor Green
    exit 0
}
elseif ($testResults.FailedSuites -gt 0)
{
    Write-Host "Some test suites failed. Review output above." -ForegroundColor Red
    exit 1
}
else
{
    Write-Host "No tests were executed." -ForegroundColor Yellow
    exit 0
}
#endregion Display Summary
