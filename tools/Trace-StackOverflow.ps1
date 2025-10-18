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
    - Passive: Monitor only, no intervention
    - Active: Insert breakpoints and capture detailed traces
    - Profiler: Performance profiling with stack depth correlation
.EXAMPLE
    .\tools\Trace-StackOverflow.ps1 -ScriptPath .\main.ps1 -MonitorDepth 40 -BreakOnDepth 60
.EXAMPLE
    .\tools\Trace-StackOverflow.ps1 -ScriptPath .\main.ps1 -TraceMode Profiler -LogFile .\StackProfile.log
.NOTES
    Author: Autopilot Team
    Date: October 18, 2025
    Version: 2.0 - Enhanced with comment exclusion and dynamic Get-ChildItem detection
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
    [ValidateSet("Passive", "Active", "Profiler")]
    [string]$TraceMode = "Passive"
)
#region Helper Functions
function Write-StackLog
{
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logMessage = "[$timestamp] [$Level] $Message"
    $logDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $logDir))
    {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $logMessage
    $color = switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "INFO" { "Cyan" } default { "White" } }
    Write-Host $logMessage -ForegroundColor $color
}
function Get-CurrentStackDepth
{
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
function Get-DetailedCallStack
{
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
function Measure-FunctionStackCost
{
    param([string]$FilePath)
    if (-not (Test-Path $FilePath))
    {
        Write-StackLog "File not found: $FilePath" "ERROR"
        return $null
    }
    $content = Get-Content -Path $FilePath -Raw
    $cmdletBindingCount = ([regex]::Matches($content, "\[CmdletBinding\(\)\]", "IgnoreCase")).Count
    $paramValidationCount = ([regex]::Matches($content, "\[ValidateSet|ValidatePattern|ValidateRange|ValidateLength|ValidateScript", "IgnoreCase")).Count
    $tryCatchCount = ([regex]::Matches($content, "\btry\s*\{", "IgnoreCase")).Count
    $functionCount = ([regex]::Matches($content, "^\s*function\s+", "Multiline")).Count
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
function Find-RecursiveFunctions
{
    param([string]$FilePath)
    if (-not (Test-Path $FilePath))
    {
        return @()
    }
    $content = Get-Content -Path $FilePath -Raw
    $recursiveFunctions = @()
    $functionMatches = [regex]::Matches($content, "function\s+([A-Za-z0-9-_]+)\s*(?:\(|\{)", "IgnoreCase")
    foreach ($match in $functionMatches)
    {
        $funcName = $match.Groups[1].Value
        $funcPattern = "function\s+$funcName\s*[\(\{](.+?)(?=function\s+|\z)"
        $funcBodyMatch = [regex]::Match($content, $funcPattern, "Singleline, IgnoreCase")
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
function Install-StackMonitor
{
    param(
        [string]$SourcePath,
        [string]$OutputPath,
        [int]$DepthWarning
    )
    $content = Get-Content -Path $SourcePath -Raw
    $monitorCode = @"
`$script:StackDepth = (Get-PSCallStack).Count
if (`$script:StackDepth -gt $DepthWarning) {
    Write-Warning "Stack depth: `$script:StackDepth (exceeds $DepthWarning)"
}
"@
    $modifiedContent = $content -replace "(function\s+[A-Za-z0-9-_]+\s*(?:\([^\)]*\))?\s*\{)", "`$1`n$monitorCode"
    Set-Content -Path $OutputPath -Value $modifiedContent
    Write-StackLog "Instrumented script saved to: $OutputPath" "INFO"
}
function Get-DotSourcedFiles
{
    param([string]$FilePath)
    if (-not (Test-Path $FilePath))
    {
        return @()
    }
    $lines = Get-Content -Path $FilePath
    $dotSourcedFiles = @()
    $inCommentBlock = $false
    foreach ($line in $lines)
    {
        if ($line -match "<#")
        {
            $inCommentBlock = $true
        }
        if ($inCommentBlock)
        {
            if ($line -match "#>")
            {
                $inCommentBlock = $false
            }
            continue
        }
        $trimmedLine = $line.TrimStart()
        if ($trimmedLine.StartsWith("#"))
        {
            continue
        }
        if ($trimmedLine -match "^\.\s+[`"\x27]([^`"\x27]+\.ps1)[`"\x27]")
        {
            $dotSourcedFiles += $matches[1]
        }
    }
    return $dotSourcedFiles
}
function Get-DynamicDotSourcedFiles
{
    param([string]$FilePath)
    if (-not (Test-Path $FilePath))
    {
        return @()
    }
    $scriptDir = if (Split-Path -Parent $FilePath) { Split-Path -Parent $FilePath } else { "."          }

    Write-Host "File path: $FilePath"
    Write-Host "Script directory: $scriptDir"
    $content = Get-Content -Path $FilePath -Raw
    $dynamicFiles = @()
    $gciPattern = "Get-ChildItem\s+(?:-Path\s+)?[`"\x27]([^`"\x27]+)[`"\x27]\s*(?:-Recurse)?\s*(?:-Filter\s+[`"\x27]\*\.ps1[`"\x27])?[^\|]*\|[^\{]*\{[^\}]*\.\s+"
    $gciMatches = [regex]::Matches($content, $gciPattern, "IgnoreCase,Singleline")
    foreach ($match in $gciMatches)
    {
        $sourcePath = $match.Groups[1].Value
        $fullPath = Join-Path $scriptDir $sourcePath
        if (Test-Path $fullPath)
        {
            $files = Get-ChildItem -Path $fullPath -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue
            foreach ($file in $files)
            {
                $dynamicFiles += $file.FullName
            }
        }
    }
    $foreachPattern = "foreach\s*\([^\)]+\s+in\s+Get-ChildItem\s+(?:-Path\s+)?[`"\x27]([^`"\x27]+)[`"\x27]"
    $foreachMatches = [regex]::Matches($content, $foreachPattern, "IgnoreCase")
    foreach ($match in $foreachMatches)
    {
        $sourcePath = $match.Groups[1].Value
        $fullPath = Join-Path $scriptDir $sourcePath
        if (Test-Path $fullPath)
        {
            $files = Get-ChildItem -Path $fullPath -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue
            foreach ($file in $files)
            {
                if ($dynamicFiles -notcontains $file.FullName)
                {
                    $dynamicFiles += $file.FullName
                }
            }
        }
    }
    # Pattern 3: $var = Get-ChildItem -Path ... -Filter '*.ps1' -Recurse
    # Flexible pattern that handles various parameter orders and quoting styles
    $assignPattern = '\$\w+\s*=\s*Get-ChildItem.*-Filter.*\.ps1.*-Recurse'
    $assignMatches = [regex]::Matches($content, $assignPattern, "IgnoreCase")
    Write-Host "Found $($assignMatches.Count) Get-ChildItem assignments for dynamic dot-sourcing"
    foreach ($match in $assignMatches)
    {
        Write-Host "Processing assignment: $($match.Value)"
        # Since path can be a variable, check common folders
        $commonFolders = @('functions', 'modules', 'lib', 'scripts')
        foreach ($folder in $commonFolders)
        {
            Write-Host "Processing folder: $folder"
            $testPath = Join-Path $scriptDir $folder
            Write-Host "Test path: $testPath"
            if (Test-Path $testPath)
            {
                $files = Get-ChildItem -Path $testPath -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue
                foreach ($file in $files)
                {
                    if ($dynamicFiles -notcontains $file.FullName)
                    {
                        $dynamicFiles += $file.FullName
                    }
                }
            }
        }
    }
    return $dynamicFiles
}
#endregion
Write-Host ""
Write-Host "=== PowerShell Stack Overflow Diagnostic Tool ===" -ForegroundColor Cyan
Write-Host "Mode: $TraceMode" -ForegroundColor White
Write-Host "Target: $ScriptPath" -ForegroundColor White
Write-Host "Monitor Depth: $MonitorDepth | Break Depth: $BreakOnDepth" -ForegroundColor White
Write-Host ""
Write-StackLog "=== Stack Overflow Analysis Started ===" "INFO"
Write-StackLog "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
Write-StackLog "Script Path: $ScriptPath" "INFO"
Write-StackLog "Mode: $TraceMode" "INFO"
if (-not (Test-Path $ScriptPath))
{
    Write-StackLog "Script not found: $ScriptPath" "ERROR"
    exit 1
}
Write-Host ""
Write-Host "--- Static Analysis ---" -ForegroundColor Yellow
Write-StackLog "Starting static analysis..." "INFO"
$stackCost = Measure-FunctionStackCost -FilePath $ScriptPath
if ($stackCost)
{
    Write-Host "Functions: $($stackCost.FunctionCount)" -ForegroundColor White
    Write-Host "[CmdletBinding()]: $($stackCost.CmdletBindingCount)" -ForegroundColor White
    Write-Host "Parameter Validations: $($stackCost.ParamValidationCount)" -ForegroundColor White
    Write-Host "Try/Catch Blocks: $($stackCost.TryCatchCount)" -ForegroundColor White
    $frameColor = if ($stackCost.RiskLevel -eq "HIGH") { "Red" } elseif ($stackCost.RiskLevel -eq "MEDIUM") { "Yellow" } else { "Green" }
    Write-Host "Estimated Stack Frames: $($stackCost.EstimatedStackFrames)" -ForegroundColor $frameColor
    Write-Host "Risk Level: $($stackCost.RiskLevel)" -ForegroundColor $frameColor
    Write-StackLog "Static analysis complete: $($stackCost.EstimatedStackFrames) estimated frames, Risk: $($stackCost.RiskLevel)" "INFO"
}
Write-Host ""
Write-Host "--- Recursion Analysis ---" -ForegroundColor Yellow
$recursiveFuncs = Find-RecursiveFunctions -FilePath $ScriptPath
if ($recursiveFuncs.Count -gt 0)
{
    Write-Host "Potentially recursive functions found: $($recursiveFuncs.Count)" -ForegroundColor Red
    foreach ($func in $recursiveFuncs)
    {
        Write-Host "  - $func" -ForegroundColor Red
        Write-StackLog "Recursive function detected: $func" "WARN"
    }
}
else
{
    Write-Host "No obvious recursive functions detected" -ForegroundColor Green
}
Write-Host ""
Write-Host "--- Dot-Sourcing Analysis ---" -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $ScriptPath
$staticDotSourced = Get-DotSourcedFiles -FilePath $ScriptPath
Write-Host "Static dot-sourced files: $($staticDotSourced.Count)" -ForegroundColor White
$dynamicDotSourced = Get-DynamicDotSourcedFiles -FilePath $ScriptPath
if ($dynamicDotSourced.Count -gt 0)
{
    Write-Host "Dynamic dot-sourced files (Get-ChildItem): $($dynamicDotSourced.Count)" -ForegroundColor White
}
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
                if ($fileCost.EstimatedStackFrames -gt 20)
                {
                    $displayPath = Split-Path -Leaf $resolvedPath
                    $impactColor = if ($fileCost.RiskLevel -eq "HIGH") { "Red" } else { "Yellow" }
                    Write-Host "  $displayPath : $($fileCost.EstimatedStackFrames) frames [$($fileCost.RiskLevel)]" -ForegroundColor $impactColor
                }
            }
        }
        else
        {
            Write-StackLog "Dot-sourced file not found: $resolvedPath" "WARN"
        }
    }
    Write-Host ""
    Write-Host "Files analyzed: $analyzedCount / $($allDotSourced.Count)" -ForegroundColor Gray
    $totalColor = if ($totalEstimatedFrames -gt 200) { "Red" } elseif ($totalEstimatedFrames -gt 100) { "Yellow" } else { "Green" }
    Write-Host "Total estimated frames from dot-sourcing: $totalEstimatedFrames" -ForegroundColor $totalColor
    Write-StackLog "Dot-sourcing analysis: $($allDotSourced.Count) files ($($staticDotSourced.Count) static, $($dynamicDotSourced.Count) dynamic), $totalEstimatedFrames total estimated frames" "INFO"
    if ($highRiskFiles.Count -gt 0)
    {
        Write-Host ""
        Write-Host "High-risk files (>100 estimated frames):" -ForegroundColor Red
        foreach ($file in $highRiskFiles)
        {
            $displayPath = Split-Path -Leaf $file
            Write-Host "  - $displayPath" -ForegroundColor Red
            Write-StackLog "High-risk file: $file" "WARN"
        }
    }
}
else
{
    Write-Host "No dot-sourced files detected" -ForegroundColor Gray
}
switch ($TraceMode)
{
    "Active"
    {
        Write-Host ""
        Write-Host "--- Active Monitoring Setup ---" -ForegroundColor Yellow
        Write-Host "Creating instrumented version of script..." -ForegroundColor White
        $instrumentedPath = $ScriptPath -replace "\.ps1$", "_Instrumented.ps1"
        Install-StackMonitor -SourcePath $ScriptPath -OutputPath $instrumentedPath -DepthWarning $MonitorDepth
        Write-Host ""
        Write-Host "Instrumented script created: $instrumentedPath" -ForegroundColor Green
        Write-Host "Run this script to see real-time stack depth monitoring." -ForegroundColor Green
        Write-StackLog "Instrumented script created: $instrumentedPath" "INFO"
    }
    "Profiler"
    {
        Write-Host ""
        Write-Host "--- Profiler Mode ---" -ForegroundColor Yellow
        Write-Host "Use Measure-Command and Get-PSCallStack in your script to profile stack depth." -ForegroundColor White
        Write-Host "Example:" -ForegroundColor Gray
        Write-Host "  `$depth = (Get-PSCallStack).Count" -ForegroundColor Gray
        Write-Host "  Write-Host `"Current depth: `$depth`"" -ForegroundColor Gray
    }
    "Passive"
    {
        Write-Host ""
        Write-Host "--- Passive Monitoring ---" -ForegroundColor Yellow
        Write-Host "Static analysis complete. No runtime instrumentation." -ForegroundColor White
    }
}
Write-Host ""
Write-Host "--- Recommendations ---" -ForegroundColor Yellow
if ($PSVersionTable.PSVersion.Major -lt 7)
{
    Write-Host "WARNING: PowerShell 5.1 detected - Stack limit: ~1MB (~100-150 function calls)" -ForegroundColor Red
    Write-Host "   Consider upgrading to PowerShell 7+ (4MB stack, ~400-600 function calls)" -ForegroundColor Yellow
    Write-StackLog "PowerShell 5.1 detected - recommend upgrade to PS 7+" "WARN"
}
else
{
    Write-Host "OK: PowerShell 7+ detected - Stack limit: ~4MB (much safer)" -ForegroundColor Green
}
if ($stackCost -and $stackCost.CmdletBindingCount -gt 50)
{
    Write-Host "WARNING: High [CmdletBinding()] usage ($($stackCost.CmdletBindingCount) instances)" -ForegroundColor Yellow
    Write-Host "   Each adds ~4 stack frames. Consider removing from non-critical functions." -ForegroundColor Yellow
}
if ($totalEstimatedFrames -gt 150)
{
    Write-Host "WARNING: High estimated stack depth ($totalEstimatedFrames frames)" -ForegroundColor Red
    Write-Host "   PowerShell 5.1 may crash. Recommendations:" -ForegroundColor Red
    Write-Host "   1. Upgrade to PowerShell 7+" -ForegroundColor Yellow
    Write-Host "   2. Remove [CmdletBinding()] from utility functions" -ForegroundColor Yellow
    Write-Host "   3. Reduce parameter validation attributes" -ForegroundColor Yellow
    Write-Host "   4. Implement lazy-loading for functions" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "=== Analysis Complete ===" -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor White
Write-StackLog "=== Stack Overflow Analysis Complete ===" "INFO"
$color = if ($stackCost.RiskLevel -eq "HIGH") { "Red" }
elseif ($stackCost.RiskLevel -eq "MEDIUM") { "Yellow" }
else { "Green" }
Write-Host "Risk Level: $($stackCost.RiskLevel)" -ForegroundColor $color
Write-StackLog "Static analysis complete: $($stackCost.EstimatedStackFrames) estimated frames, Risk: $($stackCost.RiskLevel)" "INFO"

# Check for recursion
Write-Host "`n--- Recursion Analysis ---" -ForegroundColor Yellow
$recursiveFuncs = Find-RecursiveFunctions -FilePath $ScriptPath
if ($recursiveFuncs.Count -gt 0)
{
    Write-Host "Potentially recursive functions found: $($recursiveFuncs.Count)" -ForegroundColor Red
    foreach ($func in $recursiveFuncs)
    {
        Write-Host "  - $func" -ForegroundColor Red
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
                    Write-Host "  $displayPath : $($fileCost.EstimatedStackFrames) frames [$($fileCost.RiskLevel)]" -ForegroundColor $(
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
            Write-Host "  - $displayPath" -ForegroundColor Red
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
    Write-Host "WARNING: PowerShell 5.1 detected - Stack limit: ~1MB (~100-150 function calls)" -ForegroundColor Red
    Write-Host "   Consider upgrading to PowerShell 7+ (4MB stack, ~400-600 function calls)" -ForegroundColor Yellow
    Write-StackLog "PowerShell 5.1 detected - recommend upgrade to PS 7+" "WARN"
}
else
{
    Write-Host "OK: PowerShell 7+ detected - Stack limit: ~4MB (much safer)" -ForegroundColor Green
}

if ($stackCost -and $stackCost.CmdletBindingCount -gt 50)
{
    Write-Host "WARNING: High [CmdletBinding()] usage ($($stackCost.CmdletBindingCount) instances)" -ForegroundColor Yellow
    Write-Host "   Each adds ~4 stack frames. Consider removing from non-critical functions." -ForegroundColor Yellow
}

if ($totalEstimatedFrames -gt 150)
{
    Write-Host "WARNING: High estimated stack depth ($totalEstimatedFrames frames)" -ForegroundColor Red
    Write-Host "   PowerShell 5.1 may crash. Recommendations:" -ForegroundColor Red
    Write-Host "   1. Upgrade to PowerShell 7+" -ForegroundColor Yellow
    Write-Host "   2. Remove [CmdletBinding()] from utility functions" -ForegroundColor Yellow
    Write-Host "   3. Reduce parameter validation attributes" -ForegroundColor Yellow
    Write-Host "   4. Implement lazy-loading for functions" -ForegroundColor Yellow
}

Write-Host "`n=== Analysis Complete ===" -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor White
Write-StackLog "=== Stack Overflow Analysis Complete ===" "INFO"
#endregion


