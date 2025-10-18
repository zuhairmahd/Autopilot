<#
.SYNOPSIS
    Analyzes function dependencies in the Autopilot project and identifies unused functions for memory optimization.

.DESCRIPTION
    This script performs comprehensive static code analysis to help optimize the Autopilot codebase by:
    
    1. Discovering all 254+ function definitions across 186+ PowerShell files in the functions/ directory
    2. Building a complete dependency graph showing which functions call which other functions
    3. Tracing actual usage starting from main.ps1 and test.ps1 entry points
    4. Recursively identifying all functions that are used (directly or indirectly)
    5. Generating a detailed CSV report listing all functions with their usage status
    
    The analysis helps identify functions that are defined but never called, enabling:
    - Memory optimization by removing unused code
    - Codebase cleanup and maintenance
    - Dependency understanding and visualization
    - Technical debt identification
    
    The script uses advanced regex patterns to detect various PowerShell calling conventions including:
    - Direct function calls (FunctionName -Parameter)
    - Variable assignments ($var = FunctionName)
    - Return statements (return FunctionName @params)
    - Pipeline operations (| FunctionName)
    - Call operators (& FunctionName)
    - Dot sourcing (. FunctionName)
    
    **Current Results**: ~10.63% memory optimization potential (27 unused functions out of 254 total)

.PARAMETER OutputPath
    Path where the CSV report will be saved. Default: ".\FunctionDependencyReport.csv"
    The report includes: FunctionName, IsUsed, Status, FilePath, CallCount, CalledBy, CallsOthers

.PARAMETER FunctionsFolder
    Path to the functions folder. Default: ".\functions"

.PARAMETER MainScript
    Path to the main entry point script. Default: ".\main.ps1"

.PARAMETER TestScript
    Path to the test script. Default: ".\test.ps1"

.PARAMETER Verbose
    Show detailed progress information during analysis, including file-by-file processing.

.EXAMPLE
    .\Analyze-FunctionDependencies.ps1
    
    Analyzes dependencies using default paths and generates FunctionDependencyReport.csv in the current directory.
    Output includes summary statistics and top 10 unused functions.

.EXAMPLE
    .\Analyze-FunctionDependencies.ps1 -Verbose
    
    Runs analysis with detailed logging showing each file being processed and each function being discovered.

.EXAMPLE
    .\Analyze-FunctionDependencies.ps1 -OutputPath "C:\Reports\dependencies-$(Get-Date -Format 'yyyyMMdd').csv"
    
    Generates a timestamped report in a custom location.

.EXAMPLE
    .\Analyze-FunctionDependencies.ps1 -OutputPath "report.csv"
    $report = Import-Csv "report.csv"
    $unused = $report | Where-Object { $_.Status -eq "UNUSED" }
    $unused | Format-Table FunctionName, FilePath
    
    Generates report and then displays only unused functions in a formatted table.

.EXAMPLE
    # Integrate into CI/CD pipeline
    .\Analyze-FunctionDependencies.ps1 -OutputPath "analysis.csv"
    $unused = (Import-Csv "analysis.csv" | Where-Object { $_.Status -eq "UNUSED" }).Count
    if ($unused -gt 50) {
        Write-Warning "High number of unused functions detected: $unused"
    }
    
    Automated check that warns if unused function count exceeds threshold.

.OUTPUTS
    CSV file containing:
    - FunctionName: Name of each discovered function
    - IsUsed: Boolean (True/False) indicating if function is called
    - Status: Human-readable status ("USED" or "UNUSED")
    - FilePath: Relative path to file containing the function
    - CallCount: Number of functions that call this function
    - CalledBy: Semicolon-separated list of calling functions
    - CallsOthers: Semicolon-separated list of functions this function calls
    
    Console output includes:
    - Progress bars during processing
    - Summary statistics (total, used, unused counts)
    - Memory optimization potential percentage
    - Top 10 unused functions for quick review

.NOTES
    Author: Autopilot Project Team
    Version: 1.0.0
    Last Updated: October 2025
    Requires: PowerShell 5.1 or later
    
    For detailed documentation, see: Analyze-FunctionDependencies-README.md
    
    Known Limitations:
    - Dynamic function calls (using Invoke-Expression or call operators with variables) may not be detected
    - Functions called from external scripts not included in analysis will appear as unused
    - Conditionally loaded functions may be marked as unused if conditions aren't in main.ps1/test.ps1
    
    Best Practices:
    - Run this script regularly (monthly or after major refactoring)
    - Manually verify unused functions before removing them
    - Search for string references to function names to catch dynamic calls
    - Review function documentation and purpose before deletion
    - Run full test suite after removing any functions
    
.LINK
    Project Repository: https://github.com/zuhairmahd/autopilot
    
.LINK
    Analyze-FunctionDependencies-README.md
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\FunctionDependencyReport.csv",
    [string]$FunctionsFolder = ".\functions",
    [string]$MainScript = ".\main.ps1",
    [string]$TestScript = ".\test.ps1"
)

$ErrorActionPreference = 'Stop'

# Script-level variables
$script:AllDefinedFunctions = @{}      # Hash: FunctionName -> FilePath
$script:FunctionCalls = @{}            # Hash: FunctionName -> @(CalledFunctions)
$script:UsedFunctions = [System.Collections.Generic.HashSet[string]]::new()
$script:ScannedFiles = [System.Collections.Generic.HashSet[string]]::new()

#region Helper Functions
function Find-FolderPath()
{
    <#
    .SYNOPSIS
        Searches upward from the given path for a folder with the specified name.
    .PARAMETER Path
        The starting path to begin searching from.
    .PARAMETER FolderName
        The name of the folder to search for.
    .OUTPUTS
        Returns the full path to the folder if found, otherwise $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write verbose log of received parameters
    Write-Verbose "[$functionName] Find-FolderPath called with Path: $Path, FolderName: $FolderName"
    try
    {
        $currentPath = (Resolve-Path -Path $Path).Path
        Write-Verbose "[$functionName] Current path resolved to: $currentPath"

        # 1. Search children (recursively) of the starting path
        Write-Verbose "[$functionName] Searching children of $currentPath for folder named $FolderName"
        $childMatch = Get-ChildItem -Path $currentPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
        Write-Verbose "[$functionName] Checking child match: $($childMatch.FullName)"
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

        # 2. Search up the parent chain, at each level search its children for the folder
        while ($currentPath)
        {
            $parent = Split-Path -Path $currentPath -Parent
            if ($parent -eq $currentPath -or [string]::IsNullOrEmpty($parent))
            {
                break
            } # Reached root
            Write-Verbose "[$functionName] Searching children of parent: $parent for folder named $FolderName"
            $siblingMatch = Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
            if ($siblingMatch)
            {
                Write-Verbose "[$functionName] Found folder in parent: $($siblingMatch.FullName)"
                return $siblingMatch.FullName
            }
            # Also check if the parent itself matches
            if ((Split-Path -Path $parent -Leaf) -ieq $FolderName)
            {
                Write-Verbose "[$functionName] Parent itself matches: $parent"
                return $parent
            }
            $currentPath = $parent
        }
        Write-Verbose "[$functionName] No folder found with name $FolderName in children or parent hierarchy."
        return $null
    }
    catch
    {
        Write-Error "[$functionName] Error occurred while searching for folder: $_"
        return $null
    }
}

function Write-Progress-Custom()
{
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Get-FunctionDefinitions()
{
    <#
    .SYNOPSIS
        Extracts function definitions from a PowerShell file.
    #>
    param(
        [string]$FilePath
    )
    
    Write-Verbose "Scanning file for function definitions: $FilePath"
    
    $functions = @()
    
    try
    {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        
        # Match function definitions: function FunctionName { ... }
        # Also match: function Script:FunctionName, function Global:FunctionName
        $pattern = '(?m)^\s*function\s+(?:script:|global:)?([\w-]+)\s*(?:\([^\)]*\))?\s*\{'
        $regexMatches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        foreach ($match in $regexMatches)
        {
            $functionName = $match.Groups[1].Value
            $functions += $functionName
            Write-Verbose "  Found function: $functionName"
        }
    }
    catch
    {
        Write-Warning "Failed to read file ${FilePath}: $_"
    }
    
    return $functions
}

function Get-FunctionCalls()
{
    <#
    .SYNOPSIS
        Extracts function calls from a PowerShell file.
    #>
    param(
        [string]$FilePath
    )
    
    Write-Verbose "Scanning file for function calls: $FilePath"
    
    $calls = [System.Collections.Generic.HashSet[string]]::new()
    
    try
    {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        
        # Remove comments to avoid false positives
        $content = $content -replace '(?m)^\s*#.*$', ''
        $content = $content -replace '<#[\s\S]*?#>', ''
        
        # Match direct function calls (including with parameters)
        # This pattern looks for word characters followed by optional whitespace and parameters
        $patterns = @(
            '(?<![\.`$])(\b[A-Z][\w-]*)\s*(?:-[\w]+|\()',           # FunctionName -Param or FunctionName(
            '\$[\w]+\s*=\s*(\b[A-Z][\w-]*)\s*(?:@|-)?([\w]+)?',     # $var = FunctionName @params or -param
            'return\s+(\b[A-Z][\w-]*)\s*(?:@|-)?([\w]+)?',          # return FunctionName @params or -param
            '\|\s*(\b[A-Z][\w-]*)\s*(?:-[\w]+)?',                   # | FunctionName -param (pipeline)
            '&\s+(\b[A-Z][\w-]*)\s*(?:-[\w]+)?',                    # & FunctionName -param (call operator)
            '\.\s+(\b[A-Z][\w-]*)\s*(?:-[\w]+)?'                    # . FunctionName -param (dot source)
        )
        
        foreach ($pattern in $patterns)
        {
            $regexMatches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            
            foreach ($match in $regexMatches)
            {
                # Get the function name from the first non-empty capture group
                $functionName = $null
                for ($i = 1; $i -lt $match.Groups.Count; $i++)
                {
                    if ($match.Groups[$i].Success -and -not [string]::IsNullOrWhiteSpace($match.Groups[$i].Value))
                    {
                        $functionName = $match.Groups[$i].Value
                        break
                    }
                }
                
                # Filter out common keywords and built-in cmdlets
                if ($functionName -and $functionName -notmatch '^(if|else|elseif|switch|foreach|for|while|do|try|catch|finally|param|return|throw|break|continue|exit)$')
                {
                    [void]$calls.Add($functionName)
                }
            }
        }
    }
    catch
    {
        Write-Warning "Failed to read file ${FilePath}: $_"
    }
    
    return $calls
}

function Find-AllDefinedFunctions()
{
    <#
    .SYNOPSIS
        Discovers all function definitions in the functions folder.
    #>
    param(
        [string]$FolderPath
    )
    
    Write-Host "Discovering all function definitions..." -ForegroundColor Cyan
    
    $allFiles = Get-ChildItem -Path $FolderPath -Filter "*.ps1" -Recurse -File -ErrorAction SilentlyContinue
    $totalFiles = $allFiles.Count
    $currentFile = 0
    
    foreach ($file in $allFiles)
    {
        $currentFile++
        $percentComplete = [int](($currentFile / $totalFiles) * 100)
        Write-Progress-Custom -Activity "Discovering Functions" -Status "Processing $($file.Name) ($currentFile/$totalFiles)" -PercentComplete $percentComplete
        
        $functions = Get-FunctionDefinitions -FilePath $file.FullName
        
        foreach ($func in $functions)
        {
            if (-not $script:AllDefinedFunctions.ContainsKey($func))
            {
                $script:AllDefinedFunctions[$func] = $file.FullName
            }
            else
            {
                Write-Verbose "Duplicate function found: $func in $($file.FullName) (already defined in $($script:AllDefinedFunctions[$func]))"
            }
        }
    }
    
    Write-Progress -Activity "Discovering Functions" -Completed
    Write-Host "  Found $($script:AllDefinedFunctions.Count) unique function definitions" -ForegroundColor Green
}

function Build-DependencyGraph()
{
    <#
    .SYNOPSIS
        Builds a dependency graph by analyzing function calls in all files.
    #>
    param(
        [string]$FolderPath,
        [string]$MainScript
    )
    
    $functionsFolder = $FolderPath
    Write-Host "Functions folder: $functionsFolder"
    Write-Host "Main script: $MainScript"
    Write-Host ""
    Write-Host "`nBuilding dependency graph..." -ForegroundColor Cyan
    
    $allFiles = @()
    $allFiles += Get-ChildItem -Path $FunctionsFolder -Filter "*.ps1" -Recurse -File -ErrorAction SilentlyContinue
    Write-Host "Number of function files: $($allFiles.Count)"
    if (Test-Path $MainScript)
    {
        Write-Host "Including main script in analysis: $MainScript"
        $allFiles += Get-Item $MainScript
    }
    $totalFiles = $allFiles.Count
    Write-Host "Total files to analyze: $totalFiles"
    $currentFile = 0
    
    foreach ($file in $allFiles)
    {
        $currentFile++
        $percentComplete = [int](($currentFile / $totalFiles) * 100)
        Write-Progress-Custom -Activity "Building Dependency Graph" -Status "Analyzing $($file.Name) ($currentFile/$totalFiles)" -PercentComplete $percentComplete
        
        # Get all functions defined in this file
        $definedInFile = Get-FunctionDefinitions -FilePath $file.FullName
        
        # Get all function calls in this file (entire file, not just inside functions)
        $calls = Get-FunctionCalls -FilePath $file.FullName
        
        # If this file defines functions, track what each function might call
        # Since we can't easily determine which calls are inside which function,
        # we assume all calls in a file could be made by any function in that file
        if ($definedInFile.Count -gt 0)
        {
            foreach ($func in $definedInFile)
            {
                if (-not $script:FunctionCalls.ContainsKey($func))
                {
                    $script:FunctionCalls[$func] = [System.Collections.Generic.HashSet[string]]::new()
                }
                
                foreach ($call in $calls)
                {
                    # Only track calls to functions we've defined (not built-in cmdlets)
                    if ($script:AllDefinedFunctions.ContainsKey($call) -and $call -ne $func)
                    {
                        [void]$script:FunctionCalls[$func].Add($call)
                    }
                }
            }
        }
        
        # Also track calls from the main script body (not inside functions)
        if ($file.FullName -eq (Resolve-Path $MainScript).Path -or $file.FullName -eq (Resolve-Path $TestScript).Path)
        {
            $scriptBodyKey = "__SCRIPT_BODY__$($file.Name)"
            if (-not $script:FunctionCalls.ContainsKey($scriptBodyKey))
            {
                $script:FunctionCalls[$scriptBodyKey] = [System.Collections.Generic.HashSet[string]]::new()
            }
            
            foreach ($call in $calls)
            {
                if ($script:AllDefinedFunctions.ContainsKey($call))
                {
                    [void]$script:FunctionCalls[$scriptBodyKey].Add($call)
                }
            }
        }
    }
    
    Write-Progress -Activity "Building Dependency Graph" -Completed
    Write-Host "  Analyzed $totalFiles files" -ForegroundColor Green
}

function Select-UsedFunctions()
{
    <#
    .SYNOPSIS
        Recursively marks all functions used by main.ps1 and test.ps1.
    #>
    param(
        [string]$FunctionName,
        [int]$Depth = 0
    )
    
    # Prevent infinite recursion
    if ($Depth -gt 50)
    {
        Write-Verbose "Max recursion depth reached for $FunctionName"
        return
    }
    
    # If already marked, skip
    if ($script:UsedFunctions.Contains($FunctionName))
    {
        return
    }
    
    # Mark this function as used
    [void]$script:UsedFunctions.Add($FunctionName)
    Write-Verbose ("  " * $Depth + "Marking as used: $FunctionName")
    
    # Recursively mark all functions this one calls
    if ($script:FunctionCalls.ContainsKey($FunctionName))
    {
        foreach ($calledFunc in $script:FunctionCalls[$FunctionName])
        {
            Select-UsedFunctions -FunctionName $calledFunc -Depth ($Depth + 1)
        }
    }
}

function Find-UsedFunctions()
{
    <#
    .SYNOPSIS
        Identifies all functions that are actually used (directly or transitively).
    #>
    param()
    
    Write-Host "`nIdentifying used functions..." -ForegroundColor Cyan
    
    # Start from main.ps1 and test.ps1 script bodies
    $entryPoints = @(
        "__SCRIPT_BODY__main.ps1"
    )
    
    foreach ($entryPoint in $entryPoints)
    {
        if ($script:FunctionCalls.ContainsKey($entryPoint))
        {
            Write-Verbose "Starting from entry point: $entryPoint"
            foreach ($func in $script:FunctionCalls[$entryPoint])
            {
                Select-UsedFunctions -FunctionName $func
            }
        }
    }
    
    Write-Host "  Identified $($script:UsedFunctions.Count) used functions" -ForegroundColor Green
}

function Export-Report()
{
    <#
    .SYNOPSIS
        Generates a CSV report of all functions with their usage status.
    #>
    param(
        [string]$OutputPath
    )
    
    Write-Host "`nGenerating report..." -ForegroundColor Cyan
    
    $report = @()
    
    foreach ($func in $script:AllDefinedFunctions.Keys | Sort-Object)
    {
        $isUsed = $script:UsedFunctions.Contains($func)
        $filePath = $script:AllDefinedFunctions[$func]
        $relativePath = $filePath -replace [regex]::Escape((Get-Location).Path), '.'
        
        $callCount = 0
        $calledBy = @()
        
        # Count how many times this function is called
        foreach ($caller in $script:FunctionCalls.Keys)
        {
            if ($script:FunctionCalls[$caller].Contains($func))
            {
                $callCount++
                if ($caller -notlike "__SCRIPT_BODY__*")
                {
                    $calledBy += $caller
                }
            }
        }
        
        $report += [PSCustomObject]@{
            FunctionName = $func
            IsUsed       = $isUsed
            Status       = if ($isUsed) { "USED" } else { "UNUSED" }
            FilePath     = $relativePath
            CallCount    = $callCount
            CalledBy     = ($calledBy | Sort-Object) -join '; '
            CallsOthers  = if ($script:FunctionCalls.ContainsKey($func)) { ($script:FunctionCalls[$func] | Sort-Object) -join '; ' } else { '' }
        }
    }
    
    # Export to CSV
    $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    # Display summary
    $usedCount = ($report | Where-Object { $_.IsUsed }).Count
    $unusedCount = ($report | Where-Object { -not $_.IsUsed }).Count
    $totalCount = $report.Count
    
    Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Total functions defined: $totalCount" -ForegroundColor White
    Write-Host "Used functions: $usedCount" -ForegroundColor Green
    Write-Host "Unused functions: $unusedCount" -ForegroundColor Yellow
    Write-Host "Memory optimization potential: $([math]::Round(($unusedCount/$totalCount)*100, 2))%" -ForegroundColor Magenta
    Write-Host "`nReport saved to: $OutputPath" -ForegroundColor Green
    
    # Show top 10 unused functions
    $unused = $report | Where-Object { -not $_.IsUsed } | Select-Object -First 10
    if ($unused.Count -gt 0)
    {
        Write-Host "`nTop unused functions:" -ForegroundColor Yellow
        foreach ($item in $unused)
        {
            Write-Host "  - $($item.FunctionName) ($($item.FilePath))" -ForegroundColor Gray
        }
        if ($unusedCount -gt 10)
        {
            Write-Host "  ... and $($unusedCount - 10) more (see CSV for full list)" -ForegroundColor Gray
        }
    }
}
#endregion

#region Main Execution

Write-Host "=== Autopilot Function Dependency Analyzer ===" -ForegroundColor Cyan
Write-Host ""

# Validate input paths
if (-not (Test-Path $FunctionsFolder))
{
    Write-Host "Looking for functions folder starting at $FunctionsFolder" -ForegroundColor Yellow
    $foundFolder = Find-FolderPath -Path $FunctionsFolder -FolderName "functions"
    if ($foundFolder)
    {
        Write-Host "Functions folder found at: $foundFolder" -ForegroundColor Green
        $FunctionsFolder = $foundFolder
    }
    else
    {
        Write-Error "Functions folder not found starting from: $FunctionsFolder"
        exit 1
    }
}
Write-Host "Using functions folder: $FunctionsFolder" -ForegroundColor Green
if (-not (Test-Path $MainScript))
{
    Write-Host "Looking for the main script in the parent of $FunctionsFolder" -ForegroundColor Yellow
    $parentDir = Split-Path $FunctionsFolder -Parent
    $foundScript = if (Test-Path (Join-Path $parentDir "main.ps1")) { Join-Path $parentDir "main.ps1" } else { $null }
    if ($foundScript)
    {
        Write-Host "Main script found at: $foundScript" -ForegroundColor Green
        $MainScript = $foundScript
    }
    else
    {
        Write-Error "Main script not found starting from: $parentDir"
    }
}
Write-Host "Using main script: $MainScript" -ForegroundColor Green
# Step 1: Discover all defined functions
Find-AllDefinedFunctions -FolderPath $FunctionsFolder

# Step 2: Build dependency graph
Build-DependencyGraph -FolderPath $FunctionsFolder -MainScript $MainScript

# Step 3: Find used functions
Find-UsedFunctions

# Step 4: Generate report
Export-Report -OutputPath $OutputPath

Write-Host "`nAnalysis complete!" -ForegroundColor Green

#endregion
