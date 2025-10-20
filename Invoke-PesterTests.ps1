<#
.SYNOPSIS
    Executes Pester tests for Autopilot project
.DESCRIPTION
    Runs Pester tests with standard configuration
    Supports filtering by test type, tags, and CI/CD integration
    
    When using -TestFile parameter, the script will:
    - First attempt to resolve the exact path provided
    - If not found, search the tests folder for an exact filename match
    - If still not found, perform a fuzzy search and present similar files for selection
.PARAMETER TestType
    Type of tests to run: Unit, Integration, Comprehensive, All
.PARAMETER OutputVerbosity
    Level of output detail: None, Minimal, Normal, Detailed     
.PARAMETER TestFile
    Path or filename of a single test file to run (overrides TestType)
    Can be:
    - Full path: "c:\path\to\test.Tests.ps1"
    - Relative path: "tests\Integration\SettingsFunctions.Tests.ps1"
    - Just filename: "SettingsFunctions.Tests.ps1"
    
    If the file is not found, a fuzzy search will offer similar files for selection.
.PARAMETER EnableCodeCoverage
    Enable code coverage analysis
.PARAMETER ShowMissedCommands
    Show detailed list of commands without coverage (requires -EnableCodeCoverage)
.PARAMETER CI
    Run in CI/CD mode with NUnit XML output
.PARAMETER Tags
    Filter tests by tags
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestType Unit
    Runs all unit tests
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestFile "tests\Integration\SettingsFunctions.Tests.ps1"
    Runs a specific test file using full relative path
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestFile "SettingsFunctions.Tests.ps1"
    Runs a specific test file using just the filename (will search tests folder)
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestFile "Settings"
    Searches for test files matching "Settings" and presents a selection menu
.EXAMPLE
    .\Invoke-PesterTests.ps1 -EnableCodeCoverage -CI
    Runs all tests with code coverage in CI mode
.EXAMPLE
    .\Invoke-PesterTests.ps1 -EnableCodeCoverage -ShowMissedCommands
    Runs tests with detailed code coverage information
#>
[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [ValidateSet('Unit', 'Integration', 'Comprehensive', 'All')]
    [string]$TestType = 'All',
    [ValidateSet('None', 'Minimal', 'Normal', 'Detailed')]
    [string]$OutputVerbosity = 'Normal',
    [string]$TestFile,
    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'CodeCoverage')]
    [switch]$EnableCodeCoverage,
    [Parameter(ParameterSetName = 'CodeCoverage', Mandatory = $false)]
    [ValidateScript({
            if ($_ -and -not $EnableCodeCoverage)
            {
                throw "-ShowCodeCoverageDetails requires -EnableCodeCoverage to be specified"
            }
            return $true
        })]
    [switch]$ShowCodeCoverageDetails,
    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'CodeCoverage')]
    [switch]$CI,
    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'CodeCoverage')]
    [string[]]$Tags = @()
)

$ErrorActionPreference = 'Stop'

# Import configuration
. "$PSScriptRoot\PesterConfiguration.ps1"

Write-Host "=" * 63 -ForegroundColor Cyan
Write-Host "  Autopilot Pester Test Suite" -ForegroundColor Cyan
Write-Host "=" * 63 -ForegroundColor Cyan

# Get Pester configuration
$config = Get-AutopilotPesterConfiguration -TestType $TestType -EnableCodeCoverage:$EnableCodeCoverage -CI:$CI -OutputVerbosity $OutputVerbosity

# Helper function for fuzzy string matching
function Get-FuzzyMatchScore
{
    param(
        [string]$SearchTerm,
        [string]$Candidate
    )
    
    $searchLower = $SearchTerm.ToLower()
    $candidateLower = $Candidate.ToLower()
    
    # Exact match gets highest score
    if ($candidateLower -eq $searchLower)
    {
        return 1000
    }
    
    # Contains exact search term
    if ($candidateLower.Contains($searchLower))
    {
        return 500 + (100 - $candidateLower.IndexOf($searchLower))
    }
    
    # Calculate sequential character matching score
    $score = 0
    $searchChars = $searchLower.ToCharArray()
    
    # Sequential character matching
    $lastIndex = -1
    foreach ($char in $searchChars)
    {
        $index = $candidateLower.IndexOf($char, $lastIndex + 1)
        if ($index -ge 0)
        {
            $score += 10
            if ($index -eq $lastIndex + 1)
            {
                $score += 5  # Bonus for consecutive characters
            }
            $lastIndex = $index
        }
    }
    
    # Penalize length difference
    $lengthDiff = [Math]::Abs($searchLower.Length - $candidateLower.Length)
    $score -= $lengthDiff
    
    return $score
}

# Helper function to search for test files
function Find-TestFile
{
    param(
        [string]$FileName,
        [string]$TestsPath
    )
    
    Write-Host ""
    Write-Host "Searching for test file in tests folder..." -ForegroundColor Yellow
    
    # Get all test files recursively
    $allTestFiles = Get-ChildItem -Path $TestsPath -Filter "*.Tests.ps1" -Recurse -File
    
    # Extract just the filename from the search term for exact matching
    $searchFileName = Split-Path -Leaf $FileName
    
    # Try exact filename match first
    $exactMatch = $allTestFiles | Where-Object { $_.Name -eq $searchFileName }
    if ($exactMatch)
    {
        if ($exactMatch.Count -eq 1)
        {
            Write-Host "Found exact match: $($exactMatch.FullName)" -ForegroundColor Green
            return $exactMatch.FullName
        }
        else
        {
            Write-Host "Found multiple exact matches:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $exactMatch.Count; $i++)
            {
                $relativePath = $exactMatch[$i].FullName.Replace($TestsPath, "tests")
                Write-Host "  [$($i + 1)] $relativePath" -ForegroundColor White
            }
            
            Write-Host ""
            $choice = Read-Host "Select a file (1-$($exactMatch.Count)) or 'q' to quit"
            
            if ($choice -eq 'q')
            {
                return $null
            }
            
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $exactMatch.Count)
            {
                return $exactMatch[$index].FullName
            }
            else
            {
                Write-Host "Invalid selection" -ForegroundColor Red
                return $null
            }
        }
    }
    
    # No exact match - perform fuzzy search
    Write-Host "No exact match found. Searching for similar files..." -ForegroundColor Yellow
    
    $scoredFiles = $allTestFiles | ForEach-Object {
        $score = Get-FuzzyMatchScore -SearchTerm $searchFileName -Candidate $_.Name
        [PSCustomObject]@{
            File  = $_
            Score = $score
        }
    } | Where-Object { $_.Score -gt 0 } | Sort-Object -Property Score -Descending | Select-Object -First 10
    
    if ($scoredFiles.Count -eq 0)
    {
        Write-Host "No similar test files found" -ForegroundColor Red
        return $null
    }
    
    Write-Host ""
    Write-Host "Found $($scoredFiles.Count) similar test file(s):" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $scoredFiles.Count; $i++)
    {
        $file = $scoredFiles[$i].File
        $relativePath = $file.FullName.Replace($TestsPath, "tests").TrimStart('\')
        Write-Host "  [$($i + 1)] $relativePath" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "  [q] Quit" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "Select a file (1-$($scoredFiles.Count)) or 'q' to quit"
    
    if ($choice -eq 'q')
    {
        return $null
    }
    
    try
    {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $scoredFiles.Count)
        {
            return $scoredFiles[$index].File.FullName
        }
        else
        {
            Write-Host "Invalid selection" -ForegroundColor Red
            return $null
        }
    }
    catch
    {
        Write-Host "Invalid input" -ForegroundColor Red
        return $null
    }
}

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
        Write-Host "Test file not found: $resolvedPath" -ForegroundColor Yellow
        
        # Try to find the file in the tests folder
        $testsPath = Join-Path $PSScriptRoot "tests"
        $foundPath = Find-TestFile -FileName $TestFile -TestsPath $testsPath
        
        if ($foundPath)
        {
            $resolvedPath = $foundPath
            Write-Host ""
            Write-Host "Using selected test file: $resolvedPath" -ForegroundColor Green
        }
        else
        {
            Write-Host ""
            Write-Host "ERROR: Could not resolve test file" -ForegroundColor Red
            exit 1
        }
    }
    
    $config.Run.Path = $resolvedPath
    Write-Host "`nRunning single test file: $(Split-Path -Leaf $resolvedPath)" -ForegroundColor Yellow
}

# Apply tag filter if specified
if ($Tags.Count -gt 0)
{
    $config.Filter.Tag = $Tags
}


# Display configuration
Write-Host "`nTest Configuration:" -ForegroundColor Cyan
Write-Host "  Test Type: $TestType" -ForegroundColor White
Write-Host "  Test Path: $($config.Run.Path.Value)" -ForegroundColor White
if ($EnableCodeCoverage -or $OutputVerbosity -eq 'Detailed')
{
    Write-Host "  Code Coverage: $($config.CodeCoverage.Enabled)" -ForegroundColor White
}
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
    
    # Clean up any leftover Pester TestDrive GUID folders
    # Pester 5 sometimes leaves these behind in the working directory
    Get-ChildItem -Directory | Where-Object { 
        $_.Name -match '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' 
    } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    
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
    
    # Display skipped test details if any
    if ($result.SkippedCount -gt 0)
    {
        Write-Host "`n  Skipped Tests:" -ForegroundColor Yellow
        
        # Group skipped tests by file
        $skippedByFile = $result.Skipped | Group-Object -Property { 
            if ($_.ScriptBlock.File)
            {
                Split-Path $_.ScriptBlock.File -Leaf
            }
            else
            {
                "Unknown File"
            }
        } | Sort-Object Name
        
        foreach ($fileGroup in $skippedByFile)
        {
            Write-Host "`n    $($fileGroup.Name) ($($fileGroup.Count) skipped):" -ForegroundColor DarkYellow
            foreach ($test in $fileGroup.Group)
            {
                Write-Host "      - $($test.ExpandedName)" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    
    # Display code coverage only if enabled
    if ($EnableCodeCoverage -and $result.CodeCoverage)
    {
        $coverage = $result.CodeCoverage
        Write-Host "`nCode Coverage:" -ForegroundColor Cyan
        Write-Host "  Commands Analyzed: $($coverage.CommandsAnalyzedCount)" -ForegroundColor White
        Write-Host "  Commands Executed: $($coverage.CommandsExecutedCount)" -ForegroundColor White
        Write-Host "Commands missed: $($coverage.CommandsMissedCount)" -ForegroundColor White
        Write-Host "Files analyzed: $($coverage.FilesAnalyzedCount)" -ForegroundColor White
        Write-Host "  Coverage: $($coverage.CoveragePercent)" -ForegroundColor $(if ($coverage.CoveragePercent -ge 80) { 'Green' } elseif ($coverage.CoveragePercent -ge 60) { 'Yellow' } else { 'Red' })
        Write-Host "Coverage target: $($coverage.CoveragePercentTarget)"
        
        # Show detailed list ONLY if requested
        if ($ShowCodeCoverageDetails)
        {
            if ($coverage.CommandsMissedCount -gt 0)
            {
                Write-Host "`n  Missed Commands:" -ForegroundColor Yellow    
                Write-Host $coverage.CommandsMissed
            }
            if ($coverage.CommandsExecutedCount -gt 0)
            {
                Write-Host "`n  Executed Commands:" -ForegroundColor Green
                Write-Host $coverage.CommandsExecuted
            }
            if ($coverage.FilesAnalyzedCount -gt 0)
            {
                Write-Host "`n Analyzed Files:" -ForegroundColor Green
                Write-Host $coverage.FilesAnalyzed
            }
        }
        
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
