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
    - "Interactive" for interactive file browser: -TestFile "Interactive"
    
    If the file is not found, a fuzzy search will offer similar files for selection.
    Use "Interactive" to browse and select multiple test files interactively.
.PARAMETER EnableCodeCoverage
    Enable code coverage analysis
.PARAMETER ShowMissedCommands
    Show detailed list of commands without coverage (requires -EnableCodeCoverage)
.PARAMETER CI
    Run in CI/CD mode with NUnit XML output
.PARAMETER Tags
    Filter tests by tags. Can be:
    - Specific tags: -Tags "Unit", "Integration"
    - "Interactive" for interactive selection: -Tags "Interactive"
    - Omit parameter to run all tests
    
    When -Tags "Interactive" is used, an interactive menu will display all available tags
    from test files, allowing multiple selection.
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestType Unit
    Runs all unit tests
.EXAMPLE
    .\Invoke-PesterTests.ps1 -Tags "Unit", "Fast"
    Runs only tests tagged with 'Unit' and 'Fast'
.EXAMPLE
    .\Invoke-PesterTests.ps1 -Tags "Interactive"
    Shows interactive tag selection menu for choosing multiple tags
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
    .\Invoke-PesterTests.ps1 -TestFile "Interactive"
    Shows interactive menu to browse and select multiple test files to run
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
    [string]$OutputVerbosity = 'Detailed',
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
$strings = @('User canceled', 'No files found')
# Import configuration
. "$PSScriptRoot\PesterConfiguration.ps1"

Write-Host "=" * 63 -ForegroundColor Cyan
Write-Host "  Autopilot Pester Test Suite" -ForegroundColor Cyan
Write-Host "=" * 63 -ForegroundColor Cyan

# Get Pester configuration
$config = Get-AutopilotPesterConfiguration -TestType $TestType -EnableCodeCoverage:$EnableCodeCoverage -CI:$CI -OutputVerbosity $OutputVerbosity

#region Helper functions
function Find-FileWithFuzzySearch()
{
    [CmdletBinding()]
    param(
        [string]$FileName,
        [string]$Path,
        [int]$matchesToReturn = 10,
        [int]$minimScore = 100,
        [switch]$AllowMultiple
    )

    # Helper function for fuzzy string matching
    function Get-FuzzyMatchScore()
    {
        [CmdletBinding()]
        param(
            [string]$SearchTerm,
            [string]$Candidate
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Calculating fuzzy match score between '$SearchTerm' and '$Candidate'."
        $searchLower = $SearchTerm.ToLower()
        $candidateLower = $Candidate.ToLower()
        Write-Verbose "[$functionName] Lowercase SearchTerm: '$searchLower', Candidate: '$candidateLower'."
        # Exact match gets highest score
        if ($candidateLower -eq $searchLower)
        {
            Write-Verbose "[$functionName] Exact match found."
            return 1000
        }
    
        # Contains exact search term
        if ($candidateLower.Contains($searchLower))
        {
            Write-Verbose "[$functionName] Candidate contains search term."
            return 500 + (100 - $candidateLower.IndexOf($searchLower))
        }
    
        # Calculate sequential character matching score
        Write-Verbose "[$functionName] Calculating sequential character matching score."
        $score = 0
        $searchChars = $searchLower.ToCharArray()
        Write-Verbose "[$functionName] Search characters: $($searchChars -join ', ')."
        # Sequential character matching
        $lastIndex = -1
        foreach ($char in $searchChars)
        {
            $index = $candidateLower.IndexOf($char, $lastIndex + 1)
            Write-Verbose "[$functionName] Searching for character '$char' starting at index $($lastIndex + 1): found at index $index." 
            if ($index -ge 0)
            {
                $score += 10
                Write-Verbose "[$functionName] Found character '$char' at index $index."
                if ($index -eq $lastIndex + 1)
                {
                    $score += 5  # Bonus for consecutive characters
                    Write-Verbose "[$functionName] Found consecutive character '$char' at index $index."
                }
                $lastIndex = $index
            }
        }
    
        # Penalize length difference
        $lengthDiff = [Math]::Abs($searchLower.Length - $candidateLower.Length)
        $score -= $lengthDiff
        Write-Verbose "[$functionName] Length difference: $lengthDiff, final score: $score."    
        return $score
    }
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Searching for test file '$FileName' in path '$Path'.  If not found, up to $matchesToReturn similar files with a minimum score of $minimScore will be presented."
    Write-Host ""
    Write-Host "Searching for test file in tests folder..." -ForegroundColor Yellow
    
    # Get all test files recursively
    $allTestFiles = Get-ChildItem -Path $TestsPath -Filter "*.Tests.ps1" -Recurse -File
    Write-Verbose "[$functionName] Found $($allTestFiles.Count) test files in path '$Path'."
    # Extract just the filename from the search term for exact matching
    $searchFileName = Split-Path -Leaf $FileName
    
    # Try exact filename match first
    $exactMatch = $allTestFiles | Where-Object { $_.Name -eq $searchFileName }
    Write-Verbose "[$functionName] Found $($exactMatch.Count) exact matches for '$searchFileName'."
    if ($exactMatch)
    {
        if ($exactMatch.Count -eq 1 -and -not $AllowMultiple)
        {
            Write-Host "Found exact match: $($exactMatch.FullName)" -ForegroundColor Green
            return $exactMatch.FullName
        }
        else
        {
            Write-Host "Found $($exactMatch.Count) exact match$(if ($exactMatch.Count -ne 1) {'es'}):" -ForegroundColor Yellow
            
            $selectedFiles = Select-TestFiles -Files $exactMatch -TestsPath $TestsPath -AllowMultiple:$AllowMultiple
            
            if ($selectedFiles.Count -eq 0)
            {
                Write-Verbose "[$functionName] User chose to quit."
                return 'User canceled'
            }
            
            if ($AllowMultiple)
            {
                return $selectedFiles
            }
            else
            {
                return $selectedFiles[0]
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
    } | Where-Object { $_.Score -gt $minimScore } | Sort-Object -Property Score -Descending | Select-Object -First $matchesToReturn
    Write-Verbose "[$functionName] Found $($scoredFiles.Count) similar files for '$searchFileName' after fuzzy matching."
    
    if ($scoredFiles.Count -eq 0)
    {
        Write-Host "No similar test files found" -ForegroundColor Red
        return 'No files found'
    }
    
    Write-Host ""
    Write-Host "Found $($scoredFiles.Count) similar test file(s):" -ForegroundColor Cyan
    
    $files = $scoredFiles | ForEach-Object { $_.File }
    $selectedFiles = Select-TestFiles -Files $files -TestsPath $Path -AllowMultiple:$AllowMultiple
    
    if ($selectedFiles.Count -eq 0)
    {
        Write-Verbose "[$functionName] User chose to quit."
        return 'User canceled'
    }
    
    if ($AllowMultiple)
    {
        return $selectedFiles
    }
    else
    {
        return $selectedFiles[0]
    }
}

# Generic helper function for interactive selection from a list
function Select-ItemsFromList()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [scriptblock]$DisplayFormat,
        [switch]$AllowMultiple,
        [string]$PromptText = "Enter selection"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting interactive selection. Title: '$Title', AllowMultiple: $AllowMultiple."
    if ($Items.Count -eq 0)
    {
        Write-Host "No items available for selection" -ForegroundColor Yellow
        return @()
    }
    
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $Items.Count; $i++)
    {
        $displayText = & $DisplayFormat $Items[$i]
        Write-Host " [$($i + 1)] $displayText" -ForegroundColor White
    }
    
    Write-Host ""
    if ($AllowMultiple)
    {
        Write-Host "[a] Select All" -ForegroundColor Green
    }
    Write-Host "[q] or [0] to Quit" -ForegroundColor Gray
    Write-Host ""
    
    if ($AllowMultiple)
    {
        Write-Host "$PromptText (comma-separated, e.g., 1, 3, 5) or 'a' for all:" -ForegroundColor Cyan
    }
    else
    {
        Write-Host "${PromptText}:" -ForegroundColor Cyan
    }
    
    $validSelection = $false
    $selectedItems = @()
    
    while (-not $validSelection)
    {
        $choice = Read-Host "Selection"
        
        # Handle quit
        if ($choice -eq 'q' -or $choice -eq 'Q' -or $choice -eq '0')
        {
            Write-Host "Selection canceled" -ForegroundColor Yellow
            return @()
        }
        
        # Handle select all (only if allowed)
        if ($AllowMultiple -and ($choice -eq 'a' -or $choice -eq 'A'))
        {
            Write-Host ""
            Write-Host "Selected all $($Items.Count) items" -ForegroundColor Green
            return $Items
        }
        
        # Check for empty input
        if ([string]::IsNullOrWhiteSpace($choice))
        {
            Write-Host "No selection entered. Please enter a number or 'q' to quit. (Invalid attempts: $invalidAttemptCount/$maxInvalidAttempts)" -ForegroundColor Yellow
            continue
        }
        
        # Parse selection(s)
        $selectedItems = @()
        $hasErrors = $false
        
        $numbers = if ($AllowMultiple)
        {
            $choice -split ',' | ForEach-Object { $_.Trim() }
        }
        else
        {
            @($choice.Trim())
        }
        
        foreach ($num in $numbers)
        {
            try
            {
                $index = [int]$num - 1
                if ($index -ge 0 -and $index -lt $Items.Count)
                {
                    $selectedItems += $Items[$index]
                }
                else
                {
                    Write-Host "Invalid selection: $num (out of range 1-$($Items.Count))" -ForegroundColor Red
                    $hasErrors = $true
                }
            }
            catch
            {
                Write-Host "Invalid input: '$num' (not a number)" -ForegroundColor Red
                $hasErrors = $true
            }
        }
        
        # Check if we got valid selections
        if ($selectedItems.Count -gt 0)
        {
            Write-Host ""
            Write-Host "Selected $($selectedItems.Count) item(s)" -ForegroundColor Green
            $validSelection = $true
        }
    }
    
    return $selectedItems
}

# Helper function to extract all tags from test files
function Get-AvailableTags()
{
    param(
        [string]$TestsPath
    )
    
    Write-Host "Scanning test files for available tags..." -ForegroundColor Yellow
    
    $allTags = @{}
    $testFiles = Get-ChildItem -Path $TestsPath -Filter "*.Tests.ps1" -Recurse -File
    
    foreach ($file in $testFiles)
    {
        $content = Get-Content -Path $file.FullName -Raw
        # Match Describe blocks with -Tags parameter
        $tagMatches = [regex]::Matches($content, "Describe\s+[^-]+-Tags\s+([^ {]+)")
        
        foreach ($match in $tagMatches)
        {
            $tagsString = $match.Groups[1].Value
            # Extract individual tags (handle both 'tag' and "tag" format)
            $individualTags = [regex]::Matches($tagsString, "['`"]([^'`"]+)['`"]")
            
            foreach ($tagMatch in $individualTags)
            {
                $tag = $tagMatch.Groups[1].Value.Trim()
                if (-not [string]::IsNullOrWhiteSpace($tag))
                {
                    if ($allTags.ContainsKey($tag))
                    {
                        $allTags[$tag]++
                    }
                    else
                    {
                        $allTags[$tag] = 1
                    }
                }
            }
        }
    }
    
    # Return sorted tags with their counts
    return $allTags.GetEnumerator() | Sort-Object -Property Name
}

# Helper function for tag selection menu
function Select-Tags()
{
    param(
        [string]$TestsPath
    )
    
    $availableTags = Get-AvailableTags -TestsPath $TestsPath
    
    if ($availableTags.Count -eq 0)
    {
        Write-Host "No tags found in test files" -ForegroundColor Yellow
        return @()
    }
    
    $tagList = @($availableTags)
    
    $selectedTags = Select-ItemsFromList `
        -Items $tagList `
        -Title "Available Test Tags" `
        -DisplayFormat { param($tag) "$($tag.Name) ($($tag.Value) test(s))" } `
        -AllowMultiple `
        -PromptText "Enter tag numbers"
    
    if ($selectedTags.Count -gt 0)
    {
        $tagNames = $selectedTags | ForEach-Object { $_.Name }
        Write-Host "Selected tags: $($tagNames -join ', ')" -ForegroundColor Green
        return $tagNames
    }
    
    return @()
}

# Helper function for test file selection menu
function Select-TestFiles()
{
    param(
        [Parameter(Mandatory)]
        [array]$Files,
        [string]$TestsPath,
        [switch]$AllowMultiple
    )
    if ($Files.Count -eq 0)
    {
        Write-Host "No test files available for selection" -ForegroundColor Yellow
        return @()
    }
    
    $selectedFiles = Select-ItemsFromList `
        -Items $Files `
        -Title "Available Test Files" `
        -DisplayFormat { 
        param($file) 
        if ($TestsPath)
        {
            $file.FullName.Replace($TestsPath, "tests").TrimStart('\')
        }
        else
        {
            $file.FullName
        }
    } `
        -AllowMultiple:$AllowMultiple `
        -PromptText "Enter file number$(if ($AllowMultiple) {'s'})"
    
    if ($selectedFiles.Count -gt 0)
    {
        return $selectedFiles | ForEach-Object { $_.FullName }
    }
    
    return @()
}
#endregion

# Check if -Tags was passed with "Interactive" value (interactive mode)
if ($PSBoundParameters.ContainsKey('Tags') -and $Tags.Count -eq 1 -and $Tags[0] -eq "Interactive")
{
    # User passed -Tags "Interactive", show interactive selection
    $testsPath = Join-Path $PSScriptRoot "tests"
    $Tags = Select-Tags -TestsPath $testsPath
    
    if ($Tags.Count -eq 0)
    {
        Write-Host ""
        Write-Host "No tags selected. Running all tests." -ForegroundColor Yellow
        $Tags = @()
    }
}

# Check if -TestFile was passed with "Interactive" value (interactive file selection mode)
if ($PSBoundParameters.ContainsKey('TestFile') -and $TestFile -eq "Interactive")
{
    # User passed -TestFile "Interactive", show interactive file selection
    Write-Host ""
    Write-Host "Loading test files..." -ForegroundColor Yellow
    $testsPath = Join-Path $PSScriptRoot "tests"
    $allTestFiles = Get-ChildItem -Path $testsPath -Filter "*.Tests.ps1" -Recurse -File
    
    if ($allTestFiles.Count -eq 0)
    {
        Write-Host "No test files found in tests folder" -ForegroundColor Red
        exit 1
    }
    
    $selectedFiles = Select-TestFiles -Files $allTestFiles -TestsPath $testsPath -AllowMultiple
    
    if ($selectedFiles.Count -eq 0)
    {
        Write-Host ""
        Write-Host "No files selected. Exiting." -ForegroundColor Yellow
        exit 0
    }
    
    # Update config to run selected files
    $config.Run.Path = $selectedFiles
    Write-Host ""
    Write-Host "Selected $($selectedFiles.Count) test file(s) to run" -ForegroundColor Green
}
elseif ($PSBoundParameters.ContainsKey('TestFile') -and -not [string]::IsNullOrWhiteSpace($TestFile))
{
    # User specified a test file path or search term
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
        $foundPath = Find-FileWithFuzzySearch -FileName $TestFile -Path $testsPath -AllowMultiple
        
        if ($foundPath -notin $strings)
        {
            # Check if multiple files were returned
            if ($foundPath -is [array])
            {
                Write-Host ""
                Write-Host "Using $($foundPath.Count) selected test file(s)" -ForegroundColor Green
                $config.Run.Path = $foundPath
            }
            else
            {
                $resolvedPath = $foundPath
                Write-Host ""
                Write-Host "Using selected test file: $resolvedPath" -ForegroundColor Green
                $config.Run.Path = $resolvedPath
            }
        }
        elseif ($foundPath -in $strings)
        {
            if ($foundPath -eq 'User canceled')
            {
                Write-Host ""
                Write-Host "Operation canceled by user." -ForegroundColor Red
                exit 1
            }
            elseif ($foundPath -eq 'No files found')
            {
                Write-Host ""
                Write-Host "ERROR: No matching test files found." -ForegroundColor Red
                exit 1
            }
        }   
        else
        {
            Write-Host ""
            Write-Host "ERROR: Could not resolve test file" -ForegroundColor Red
            exit 1
        }
    }
    else
    {
        $config.Run.Path = $resolvedPath
        Write-Host "`nRunning single test file: $(Split-Path -Leaf $resolvedPath)" -ForegroundColor Yellow
    }
}

# Apply tag filter if specified
if ($Tags.Count -gt 0)
{
    $config.Filter.Tag = $Tags
}

# Display configuration
Write-Host "`nTest Configuration:" -ForegroundColor Cyan
Write-Host "  Test Type: $TestType" -ForegroundColor White

# Handle display of test paths (single or multiple)
$testPaths = $config.Run.Path.Value
if ($testPaths -is [array] -and $testPaths.Count -gt 1)
{
    Write-Host "  Test Files: $($testPaths.Count) files selected" -ForegroundColor White
    foreach ($path in $testPaths)
    {
        Write-Host "    - $(Split-Path -Leaf $path)" -ForegroundColor Gray
    }
}
else
{
    Write-Host "  Test Path: $testPaths" -ForegroundColor White
}

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
        $_.Name -match '^[a-f0-9] {8}-[a-f0-9] {4}-[a-f0-9] {4}-[a-f0-9] {4}-[a-f0-9] {12}$' 
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
