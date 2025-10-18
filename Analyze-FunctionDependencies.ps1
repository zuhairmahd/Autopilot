<#
.SYNOPSIS
    Analyzes function dependencies in the Autopilot project and identifies unused functions.

.DESCRIPTION
    This script traverses main.ps1 and all function files to build a dependency graph.
    It identifies which functions are actually used (directly or indirectly) and which
    functions are defined but never called, helping to optimize memory usage.

.PARAMETER OutputPath
    Path where the CSV report will be saved. Default: ".\FunctionDependencyReport.csv"

.PARAMETER FunctionsFolder
    Path to the functions folder. Default: ".\functions"

.PARAMETER MainScript
    Path to the main entry point script. Default: ".\main.ps1"

.PARAMETER Verbose
    Show detailed progress information during analysis.

.EXAMPLE
    .\Analyze-FunctionDependencies.ps1
    Analyzes dependencies using default paths and generates report.

.EXAMPLE
    .\Analyze-FunctionDependencies.ps1 -OutputPath "C:\Reports\dependencies.csv" -Verbose
    Analyzes with custom output path and verbose logging.

.NOTES
    Author: Autopilot Memory Optimization
    Version: 1.0.0
    Requires: PowerShell 5.1 or later
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

function Write-Progress-Custom
{
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Get-FunctionDefinitions
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
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        foreach ($match in $matches)
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

function Get-FunctionCalls
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
            $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            
            foreach ($match in $matches)
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

function Find-AllDefinedFunctions
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

function Build-DependencyGraph
{
    <#
    .SYNOPSIS
        Builds a dependency graph by analyzing function calls in all files.
    #>
    param()
    
    Write-Host "`nBuilding dependency graph..." -ForegroundColor Cyan
    
    $allFiles = @()
    $allFiles += Get-ChildItem -Path $FunctionsFolder -Filter "*.ps1" -Recurse -File -ErrorAction SilentlyContinue
    if (Test-Path $MainScript)
    {
        $allFiles += Get-Item $MainScript
    }
    if (Test-Path $TestScript)
    {
        $allFiles += Get-Item $TestScript
    }
    
    $totalFiles = $allFiles.Count
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

function Mark-UsedFunctions
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
            Mark-UsedFunctions -FunctionName $calledFunc -Depth ($Depth + 1)
        }
    }
}

function Find-UsedFunctions
{
    <#
    .SYNOPSIS
        Identifies all functions that are actually used (directly or transitively).
    #>
    param()
    
    Write-Host "`nIdentifying used functions..." -ForegroundColor Cyan
    
    # Start from main.ps1 and test.ps1 script bodies
    $entryPoints = @(
        "__SCRIPT_BODY__main.ps1",
        "__SCRIPT_BODY__test.ps1"
    )
    
    foreach ($entryPoint in $entryPoints)
    {
        if ($script:FunctionCalls.ContainsKey($entryPoint))
        {
            Write-Verbose "Starting from entry point: $entryPoint"
            foreach ($func in $script:FunctionCalls[$entryPoint])
            {
                Mark-UsedFunctions -FunctionName $func
            }
        }
    }
    
    Write-Host "  Identified $($script:UsedFunctions.Count) used functions" -ForegroundColor Green
}

function Generate-Report
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
            FunctionName    = $func
            IsUsed          = $isUsed
            Status          = if ($isUsed) { "USED" } else { "UNUSED" }
            FilePath        = $relativePath
            CallCount       = $callCount
            CalledBy        = ($calledBy | Sort-Object) -join '; '
            CallsOthers     = if ($script:FunctionCalls.ContainsKey($func)) { ($script:FunctionCalls[$func] | Sort-Object) -join '; ' } else { '' }
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
    Write-Error "Functions folder not found: $FunctionsFolder"
    exit 1
}

if (-not (Test-Path $MainScript))
{
    Write-Error "Main script not found: $MainScript"
    exit 1
}

# Step 1: Discover all defined functions
Find-AllDefinedFunctions -FolderPath $FunctionsFolder

# Step 2: Build dependency graph
Build-DependencyGraph

# Step 3: Find used functions
Find-UsedFunctions

# Step 4: Generate report
Generate-Report -OutputPath $OutputPath

Write-Host "`nAnalysis complete!" -ForegroundColor Green

#endregion
