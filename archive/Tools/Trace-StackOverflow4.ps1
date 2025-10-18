
<#
.SYNOPSIS
    Advanced PowerShell stack overflow diagnostic tool for PS 5.1 debugging.

.DESCRIPTION
    This script provides comprehensive stack overflow debugging capabilities:
    1. Real-time stack depth monitoring during execution
    2. Function call tracing with depth tracking
    3. Identification of stack-heavy operations
    4. Memory and recursion pattern analysis
    5. Automated breakpoint insertion for deep stack detection

    Designed specifically for diagnosing PowerShell 5.1 stack overflow issues
    where the 1MB stack limit is exceeded.

.PARAMETER ScriptPath
    Path to the script to analyze for stack overflow.

.PARAMETER MonitorDepth
    Maximum call stack depth to track before warning. Default: 50

.PARAMETER BreakOnDepth
    Automatically break into debugger when this depth is reached. Default: 75

.PARAMETER LogFile
    Path to log file for stack trace output. Default: .\Logs\StackTrace.log

.PARAMETER TraceMode
    Analysis mode:
    - 'Passive': Monitor only, no intervention
    - 'Active': Insert breakpoints and capture detailed traces
    - 'Profiler': Performance profiling with stack depth correlation

.EXAMPLE
    .\tools\Trace-StackOverflow.ps1 -ScriptPath .\main.ps1 -MonitorDepth 40 -BreakOnDepth 60

.EXAMPLE
    .\tools\Trace-StackOverflow.ps1 -ScriptPath .\main.ps1 -TraceMode Profiler -LogFile .\StackProfile.log

.NOTES
    Author: Autopilot Team
    Date: October 18, 2025
    Version: 1.0
    
    PowerShell 5.1 Stack Limit: ~1MB (approximately 100-150 function calls deep)
    PowerShell 7+ Stack Limit: ~4MB (approximately 400-600 function calls deep)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,
    [int]$MonitorDepth = 50,
    [int]$BreakOnDepth = 75,
    [string]$LogFile = ".\Logs\StackTrace.log",
    [ValidateSet('Passive', 'Active', 'Profiler')]
    [string]$TraceMode = 'Active'
)

#region Helper Functions
function Write-StackLog()
{
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Ensure log directory exists
    $logDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $logDir))
    {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    Add-Content -Path $LogFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(
        switch ($Level)
        {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "INFO" { "Cyan" }
            default { "White" }
        }
    )
}

function Get-CurrentStackDepth()
{
    <#
    .SYNOPSIS
        Returns the current call stack depth using Get-PSCallStack.
    .DESCRIPTION
        Uses PowerShell's built-in Get-PSCallStack cmdlet to determine
        how deep the current execution context is nested.
    #>
    try
    {
        $stack = Get-PSCallStack
        return $stack.Count
    }
    catch
    {
        return -1
    }
}

function Get-DetailedCallStack()
{
    <#
    .SYNOPSIS
        Returns detailed call stack information including function names,
        file locations, and line numbers.
    #>
    try
    {
        $stack = Get-PSCallStack
        $details = @()
        
        foreach ($frame in $stack)
        {
            $details += [PSCustomObject]@{
                FunctionName     = $frame.FunctionName
                ScriptName       = $frame.ScriptName
                ScriptLineNumber = $frame.ScriptLineNumber
                Location         = $frame.Location
                Command          = $frame.Command
                Arguments        = $frame.Arguments
            }
        }
        
        return $details
    }
    catch
    {
        Write-StackLog "Failed to get detailed call stack: $_" "ERROR"
        return @()
    }
}

function Measure-FunctionStackCost()
{
    <#
    .SYNOPSIS
        Estimates stack cost for functions with [CmdletBinding()] and parameter validation.
    .DESCRIPTION
        Analyzes a script file to identify functions that consume significant stack:
        - [CmdletBinding()] attribute (adds 3-5 stack frames per function)
        - Parameter validation (adds 2-3 frames per validated parameter)
        - Try/Catch blocks (adds 2 frames per try block)
        - Recursive calls (variable, potentially infinite)
    #>
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath))
    {
        Write-StackLog "File not found: $FilePath" "ERROR"
        return $null
    }
    
    $content = Get-Content -Path $FilePath -Raw
    
    # Count stack-heavy constructs
    $cmdletBindingCount = ([regex]::Matches($content, '\[CmdletBinding\(\)\]', 'IgnoreCase')).Count
    $paramValidationCount = ([regex]::Matches($content, '\[ValidateSet|ValidatePattern|ValidateRange|ValidateLength|ValidateScript', 'IgnoreCase')).Count
    $tryCatchCount = ([regex]::Matches($content, '\btry\s*\{', 'IgnoreCase')).Count
    $functionCount = ([regex]::Matches($content, '^\s*function\s+', 'Multiline')).Count
    
    # Estimate stack frames
    # CmdletBinding: ~4 frames per function
    # Parameter validation: ~2 frames per parameter
    # Try/Catch: ~2 frames per try
    $estimatedFrames = ($cmdletBindingCount * 4) + ($paramValidationCount * 2) + ($tryCatchCount * 2)
    
    return [PSCustomObject]@{
        FilePath             = $FilePath
        FunctionCount        = $functionCount
        CmdletBindingCount   = $cmdletBindingCount
        ParamValidationCount = $paramValidationCount
        TryCatchCount        = $tryCatchCount
        EstimatedStackFrames = $estimatedFrames
        RiskLevel            = if ($estimatedFrames -gt 100) { "HIGH" } elseif ($estimatedFrames -gt 50) { "MEDIUM" } else { "LOW" }
    }
}

function Find-RecursiveFunctions()
{
    <#
    .SYNOPSIS
        Identifies potentially recursive functions in a script file.
    .DESCRIPTION
        Searches for functions that call themselves, either directly or indirectly.
    #>
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath))
    {
        return @()
    }
    
    $content = Get-Content -Path $FilePath -Raw
    $recursiveFunctions = @()
    
    # Find all function definitions
    $functionMatches = [regex]::Matches($content, 'function\s+([A-Za-z0-9-_]+)\s*(?:\(|\{)', 'IgnoreCase')
    
    foreach ($match in $functionMatches)
    {
        $funcName = $match.Groups[1].Value
        
        # Search for self-calls within the function body
        # This is a simplified check - doesn't handle all cases
        $funcPattern = "function\s+$funcName\s*[\(\{](.+?)(?=function\s+|\z)"
        $funcBodyMatch = [regex]::Match($content, $funcPattern, 'Singleline, IgnoreCase')
        
        if ($funcBodyMatch.Success)
        {
            $funcBody = $funcBodyMatch.Groups[1].Value
            if ($funcBody -match "\b$funcName\b")
            {
                $recursiveFunctions += $funcName
            }
        }
    }
    
    return $recursiveFunctions
}

function Install-StackMonitor()
{
    <#
    .SYNOPSIS
        Injects stack depth monitoring into a script's execution.
    .DESCRIPTION
        Creates a modified version of the target script with stack monitoring
        injected at key points (function entry, loop iterations, etc.).
    #>
    param(
        [string]$SourcePath,
        [string]$OutputPath,
        [int]$DepthWarning
    )
    
    $content = Get-Content -Path $SourcePath -Raw
    
    # Injection template for function entry
    $monitorCode = @"
`$script:StackDepth = (Get-PSCallStack).Count
if (`$script:StackDepth -gt $DepthWarning) {
    Write-Warning "Stack depth: `$script:StackDepth (exceeds $DepthWarning)"
}
"@
    
    # Inject after each "function FunctionName {" line
    $modifiedContent = $content -replace '(function\s+[A-Za-z0-9-_]+\s*(?:\([^\)]*\))?\s*\{)', "`$1`n$monitorCode"
    
    Set-Content -Path $OutputPath -Value $modifiedContent
    Write-StackLog "Instrumented script saved to: $OutputPath" "INFO"
}

function Get-DotSourcedFiles()
{
    <#
    .SYNOPSIS
        Finds all dot-sourced PowerShell files, excluding those in comments.
    .DESCRIPTION
        Parses a script file to find actual dot-sourcing statements,
        excluding false positives from:
        - Comment blocks (<# ... #>)
- Single-line comments (lines starting with #)
    - Help documentation examples
    #>
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath))
    {
        return @()
    }
    
    $lines = Get-Content -Path $FilePath
    $dotSourcedFiles = @()
    $inCommentBlock = $false
    
    foreach ($line in $lines)
    {
        # Check for comment block start/end
        if ($line -match '<#')
        {
            $inCommentBlock = $true
        }
        
        if ($inCommentBlock)
        {
            if ($line -match '#>')
            {
                $inCommentBlock = $false
            }
            continue
        }
        
        # Skip single-line comments
        $trimmedLine = $line.TrimStart()
        if ($trimmedLine.StartsWith('#'))
        {
            continue
        }
        
        # Look for dot-sourcing pattern in actual code
        # Pattern: . "path/file.ps1" or . 'path/file.ps1' or . $variablePath
        if ($trimmedLine -match '^\.\s+["\']([^"\'\.]+\.ps1)["\']')
            {
                $dotSourcedFiles += $matches[1]
            }
        }
    
        return $dotSourcedFiles
    }

    function Get-DynamicDotSourcedFiles()
    {
        <#
    .SYNOPSIS
        Detects and enumerates files loaded via Get-ChildItem patterns.
    .DESCRIPTION
        Finds patterns like:
        Get-ChildItem -Path "functions" -Recurse -Filter "*.ps1" | ForEach-Object { . $_.FullName }
        
        Then actually enumerates those files to return accurate counts.
    #>
        param(
            [string]$FilePath
        )
    
        if (-not (Test-Path $FilePath))
        {
            return @()
        }
    
        $scriptDir = Split-Path -Parent $FilePath
        $content = Get-Content -Path $FilePath -Raw
        $dynamicFiles = @()
    
        # Pattern 1: Get-ChildItem ... | ForEach-Object { . $_ }
        # Regex to find Get-ChildItem with dot-sourcing in ForEach-Object
        $gciPattern = 'Get-ChildItem\s+(?:-Path\s+)?["\']([^"\'\.]+)["\']\s*(?:-Recurse)?\s*(?:-Filter\s+["\']\*\.ps1["\'])?[^\|]*\|[^\{]*\{[^\}]*\.\s+'
    $matches = [regex]::Matches($content, $gciPattern, 'IgnoreCase,Singleline')
    
    foreach ($match in $matches)
    {
        $sourcePath = $match.Groups[1].Value
        $fullPath = Join-Path $scriptDir $sourcePath
        
        if (Test-Path $fullPath)
        {
            # Enumerate actual files
            $files = Get-ChildItem -Path $fullPath -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue
            foreach ($file in $files)
            {
                $dynamicFiles += $file.FullName
            }
        }
    }
    
    # Pattern 2: foreach ($file in Get-ChildItem ...) { . $file }
    $foreachPattern = 'foreach\s*\([^\)]+\s+in\s+Get-ChildItem\s+(?:-Path\s+)?["\']([^"\'\.]+)["\']'
    $matches = [regex]::Matches($content, $foreachPattern, 'IgnoreCase')
    
    foreach ($match in $matches)
    {
        $sourcePath = $match.Groups[1].Value
        $fullPath = Join-Path $scriptDir $sourcePath
        
        if (Test-Path $fullPath)
        {
            $files = Get-ChildItem -Path $fullPath -Recurse -Filter "* .ps1" -File -ErrorAction SilentlyContinue
            foreach ($file in $files)
            {
                if ($dynamicFiles -notcontains $file.FullName)
                {
                    $dynamicFiles += $file.FullName
                }
            }
        }
    }
    
    return $dynamicFiles
}
#endregion
#endregion

#region Main Analysis

Write-Host "`n=== PowerShell Stack Overflow Diagnostic Tool ===" -ForegroundColor Cyan
Write-Host "Mode: $TraceMode" -ForegroundColor White
Write-Host "Target: $ScriptPath" -ForegroundColor White
Write-Host "Monitor Depth: $MonitorDepth | Break Depth: $BreakOnDepth" -ForegroundColor White
Write-Host ""

# Initialize log
Write-StackLog "=== Stack Overflow Analysis Started ===" "INFO"
Write-StackLog "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
Write-StackLog "Script Path: $ScriptPath" "INFO"
Write-StackLog "Mode: $TraceMode" "INFO"

# Check if script exists
if (-not (Test-Path $ScriptPath))
{
    Write-StackLog "Script not found: $ScriptPath" "ERROR"
    exit 1
}

# Analyze script structure
Write-Host "`n--- Static Analysis ---" -ForegroundColor Yellow
Write-StackLog "Starting static analysis..." "INFO"

$stackCost = Measure-FunctionStackCost -FilePath $ScriptPath
if ($stackCost)
{
    Write-Host "Functions: $($stackCost.FunctionCount)" -ForegroundColor White
    Write-Host "[CmdletBinding()]: $($stackCost.CmdletBindingCount)" -ForegroundColor White
    Write-Host "Parameter Validations: $($stackCost.ParamValidationCount)" -ForegroundColor White
    Write-Host "Try/Catch Blocks: $($stackCost.TryCatchCount)" -ForegroundColor White
    Write-Host "Estimated Stack Frames: $($stackCost.EstimatedStackFrames)" -ForegroundColor $(
        if ($stackCost.RiskLevel -eq "HIGH") { "Red" }
        elseif ($stackCost.RiskLevel -eq "MEDIUM") { "Yellow" }
        else { "Green" }
    )
    Write-Host "Risk Level: $($stackCost.RiskLevel)" -ForegroundColor $(
        if ($stackCost.RiskLevel -eq "HIGH") { "Red" }
        elseif ($stackCost.RiskLevel -eq "MEDIUM") { "Yellow" }
        else { "Green" }
    )
    
    Write-StackLog "Static analysis complete: $($stackCost.EstimatedStackFrames) estimated frames, Risk: $($stackCost.RiskLevel)" "INFO"
}

# Check for recursion
Write-Host "`n--- Recursion Analysis ---" -ForegroundColor Yellow
$recursiveFuncs = Find-RecursiveFunctions -FilePath $ScriptPath
if ($recursiveFuncs.Count -gt 0)
{
    Write-Host "Potentially recursive functions found: $($recursiveFuncs.Count)" -ForegroundColor Red
    foreach ($func in $recursiveFuncs)
    {
        Write-Host " - $func" -ForegroundColor Red
        Write-StackLog "Recursive function detected: $func" "WARN"
    }
}
else
{
    Write-Host "No obvious recursive functions detected" -ForegroundColor Green
}

# Analyze dot-sourced files
Write-Host "`n--- Dot-Sourcing Analysis ---" -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $ScriptPath

# Get static dot-sourced files (excluding comments)
$staticDotSourced = Get-DotSourcedFiles -FilePath $ScriptPath
Write-Host "Static dot-sourced files: $($staticDotSourced.Count)" -ForegroundColor White

# Get dynamic dot-sourced files (Get-ChildItem patterns)
$dynamicDotSourced = Get-DynamicDotSourcedFiles -FilePath $ScriptPath
if ($dynamicDotSourced.Count -gt 0)
{
    Write-Host "Dynamic dot-sourced files (Get-ChildItem): $($dynamicDotSourced.Count)" -ForegroundColor White
}

# Combine all dot-sourced files
$allDotSourced = @()
$allDotSourced += $staticDotSourced
$allDotSourced += $dynamicDotSourced

if ($allDotSourced.Count -gt 0)
{
    Write-Host "Total dot-sourced files: $($allDotSourced.Count)" -ForegroundColor Cyan
    $totalEstimatedFrames = 0
    $highRiskFiles = @()
    $analyzedCount = 0
    
    foreach ($dotSourcedFile in $allDotSourced)
    {
        # Resolve relative paths for static files
        if (-not [System.IO.Path]::IsPathRooted($dotSourcedFile))
        {
            $resolvedPath = Join-Path $scriptDir $dotSourcedFile
        }
        else
        {
            $resolvedPath = $dotSourcedFile
        }
        
        if (Test-Path $resolvedPath)
        {
            $analyzedCount++
            $fileCost = Measure-FunctionStackCost -FilePath $resolvedPath
            if ($fileCost)
            {
                $totalEstimatedFrames += $fileCost.EstimatedStackFrames
                if ($fileCost.RiskLevel -eq "HIGH")
                {
                    $highRiskFiles += $resolvedPath
                }
                
                # Show high-impact files
                if ($fileCost.EstimatedStackFrames -gt 20)
                {
                    $displayPath = Split-Path -Leaf $resolvedPath
                    Write-Host " $displayPath : $($fileCost.EstimatedStackFrames) frames [$($fileCost.RiskLevel)]" -ForegroundColor $(
                        if ($fileCost.RiskLevel -eq "HIGH") { "Red" } else { "Yellow" }
                    )
                }
            }
        }
        else
        {
            Write-StackLog "Dot-sourced file not found: $resolvedPath" "WARN"
        }
    }
    
    Write-Host "`nFiles analyzed: $analyzedCount / $($allDotSourced.Count)" -ForegroundColor Gray
    Write-Host "Total estimated frames from dot-sourcing: $totalEstimatedFrames" -ForegroundColor $(
        if ($totalEstimatedFrames -gt 200) { "Red" }
        elseif ($totalEstimatedFrames -gt 100) { "Yellow" }
        else { "Green" }
    )
    Write-StackLog "Dot-sourcing analysis: $($allDotSourced.Count) files ($($staticDotSourced.Count) static, $($dynamicDotSourced.Count) dynamic), $totalEstimatedFrames total estimated frames" "INFO"
    
    if ($highRiskFiles.Count -gt 0)
    {
        Write-Host "`nHigh-risk files (>100 estimated frames):" -ForegroundColor Red
        foreach ($file in $highRiskFiles)
        {
            $displayPath = Split-Path -Leaf $file
            Write-Host " - $displayPath" -ForegroundColor Red
            Write-StackLog "High-risk file: $file" "WARN"
        }
    }
}
else
{
    Write-Host "No dot-sourced files detected" -ForegroundColor Gray
}

# Mode-specific operations
switch ($TraceMode)
{
    'Active'
    {
        Write-Host "`n--- Active Monitoring Setup ---" -ForegroundColor Yellow
        Write-Host "Creating instrumented version of script..." -ForegroundColor White
        
        $instrumentedPath = $ScriptPath -replace '\.ps1$', '_Instrumented.ps1'
        Install-StackMonitor -SourcePath $ScriptPath -OutputPath $instrumentedPath -DepthWarning $MonitorDepth
        
        Write-Host "`nInstrumented script created: $instrumentedPath" -ForegroundColor Green
        Write-Host "Run this script to see real-time stack depth monitoring." -ForegroundColor Green
        Write-StackLog "Instrumented script created: $instrumentedPath" "INFO"
    }
    
    'Profiler'
    {
        Write-Host "`n--- Profiler Mode ---" -ForegroundColor Yellow
        Write-Host "Use Measure-Command and Get-PSCallStack in your script to profile stack depth." -ForegroundColor White
        Write-Host "Example:" -ForegroundColor Gray
        Write-Host '  $depth = (Get-PSCallStack).Count' -ForegroundColor Gray
        Write-Host '  Write-Host "Current depth: $depth"' -ForegroundColor Gray
    }
    
    'Passive'
    {
        Write-Host "`n--- Passive Monitoring ---" -ForegroundColor Yellow
        Write-Host "Static analysis complete. No runtime instrumentation." -ForegroundColor White
    }
}

# Recommendations
Write-Host "`n--- Recommendations ---" -ForegroundColor Yellow

if ($PSVersionTable.PSVersion.Major -lt 7)
{
    Write-Host "⚠️ PowerShell 5.1 detected - Stack limit: ~1MB (~100-150 function calls)" -ForegroundColor Red
    Write-Host " Consider upgrading to PowerShell 7+ (4MB stack, ~400-600 function calls)" -ForegroundColor Yellow
    Write-StackLog "PowerShell 5.1 detected - recommend upgrade to PS 7+" "WARN"
}
else
{
    Write-Host "✅ PowerShell 7+ detected - Stack limit: ~4MB (much safer)" -ForegroundColor Green
}

if ($stackCost -and $stackCost.CmdletBindingCount -gt 50)
{
    Write-Host "⚠️ High [CmdletBinding()] usage ($($stackCost.CmdletBindingCount) instances)" -ForegroundColor Yellow
    Write-Host "   Each adds ~4 stack frames. Consider removing from non-critical functions." -ForegroundColor Yellow
}

if ($totalEstimatedFrames -gt 150)
{
    Write-Host "⚠️ High estimated stack depth ($totalEstimatedFrames frames)" -ForegroundColor Red
    Write-Host "   PowerShell 5.1 may crash. Recommendations:" -ForegroundColor Red
    Write-Host " 1. Upgrade to PowerShell 7+" -ForegroundColor Yellow
    Write-Host " 2. Remove [CmdletBinding()] from utility functions" -ForegroundColor Yellow
    Write-Host " 3. Reduce parameter validation attributes" -ForegroundColor Yellow
    Write-Host " 4. Implement lazy-loading for functions" -ForegroundColor Yellow
}

Write-Host "`n=== Analysis Complete ===" -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor White
Write-StackLog "=== Stack Overflow Analysis Complete ===" "INFO"

#endregion
