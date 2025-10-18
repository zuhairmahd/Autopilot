<#
.SYNOPSIS
    PowerShell Stack Monitor Module - Real-time stack depth tracking and management.

.DESCRIPTION
    This module provides real-time stack monitoring capabilities that can be
    imported into any PowerShell session to track stack depth, detect potential
    overflows, and provide stack management utilities.
    
    Features:
    - Real-time stack depth tracking
    - Automatic warnings when approaching stack limits
    - Stack trace capture and logging
    - Performance impact measurement
    - Stack clearing/optimization utilities

.EXAMPLE
    Import-Module .\tools\StackMonitor.psm1
    Enable-StackMonitoring -WarnThreshold 80 -ErrorThreshold 120
    
.EXAMPLE
    Import-Module .\tools\StackMonitor.psm1
    Get-StackDepth
    Get-StackReport

.NOTES
    Author: Autopilot Team
    Date: October 18, 2025
    Version: 1.0
    
    PowerShell Stack Limits:
    - PS 5.1: ~1MB stack (~100-150 function calls)
    - PS 7+:  ~4MB stack (~400-600 function calls)
#>

# Module-level variables
$script:StackMonitorEnabled = $false
$script:WarnThreshold = 80
$script:ErrorThreshold = 120
$script:StackHistory = @()
$script:MaxHistorySize = 1000
$script:MonitoringStartTime = $null
$script:StackPeakDepth = 0

#region Core Monitoring Functions
function Enable-StackMonitoring
{
    <#
    .SYNOPSIS
        Enables real-time stack depth monitoring.
    
    .PARAMETER WarnThreshold
        Stack depth at which to issue warnings. Default: 80
    
    .PARAMETER ErrorThreshold
        Stack depth at which to issue errors. Default: 120
    
    .PARAMETER CaptureHistory
        Whether to capture stack depth history for analysis. Default: $true
    #>
    [CmdletBinding()]
    param(
        [int]$WarnThreshold = 80,
        [int]$ErrorThreshold = 120,
        [bool]$CaptureHistory = $true
    )
    
    $script:StackMonitorEnabled = $true
    $script:WarnThreshold = $WarnThreshold
    $script:ErrorThreshold = $ErrorThreshold
    $script:MonitoringStartTime = Get-Date
    $script:StackHistory = @()
    $script:StackPeakDepth = 0
    
    Write-Host "[StackMonitor] Monitoring enabled" -ForegroundColor Green
    Write-Host "  Warn Threshold: $WarnThreshold" -ForegroundColor Gray
    Write-Host "  Error Threshold: $ErrorThreshold" -ForegroundColor Gray
    Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "  Estimated Safe Depth: $(Get-SafeStackDepth)" -ForegroundColor Gray
}

function Disable-StackMonitoring
{
    <#
    .SYNOPSIS
        Disables real-time stack depth monitoring.
    #>
    [CmdletBinding()]
    param()
    
    $script:StackMonitorEnabled = $false
    
    Write-Host "[StackMonitor] Monitoring disabled" -ForegroundColor Yellow
    if ($script:StackPeakDepth -gt 0)
    {
        Write-Host "  Peak depth reached: $script:StackPeakDepth" -ForegroundColor Gray
    }
}

function Get-StackDepth
{
    <#
    .SYNOPSIS
        Gets the current call stack depth.
    
    .DESCRIPTION
        Returns the number of frames in the current PowerShell call stack.
        This is a fast operation suitable for frequent polling.
    
    .OUTPUTS
        System.Int32 - The current stack depth
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()
    
    try
    {
        $callStack = Get-PSCallStack
        $depth = $callStack.Count
        
        # Update peak
        if ($depth -gt $script:StackPeakDepth)
        {
            $script:StackPeakDepth = $depth
        }
        
        # Capture history if monitoring enabled
        if ($script:StackMonitorEnabled -and $script:StackHistory.Count -lt $script:MaxHistorySize)
        {
            $script:StackHistory += [PSCustomObject]@{
                Timestamp   = Get-Date
                Depth       = $depth
                TopFunction = $callStack[0].FunctionName
            }
        }
        
        # Check thresholds
        if ($script:StackMonitorEnabled)
        {
            if ($depth -ge $script:ErrorThreshold)
            {
                Write-Host "[StackMonitor] ERROR: Stack depth $depth >= $script:ErrorThreshold" -ForegroundColor Red
                Write-Host "  Top function: $($callStack[0].FunctionName)" -ForegroundColor Red
            }
            elseif ($depth -ge $script:WarnThreshold)
            {
                Write-Host "[StackMonitor] WARNING: Stack depth $depth >= $script:WarnThreshold" -ForegroundColor Yellow
            }
        }
        
        return $depth
    }
    catch
    {
        Write-Warning "[StackMonitor] Failed to get stack depth: $_"
        return -1
    }
}

function Get-DetailedStack
{
    <#
    .SYNOPSIS
        Gets detailed information about the current call stack.
    
    .DESCRIPTION
        Returns comprehensive information about each frame in the call stack
        including function names, file locations, line numbers, and arguments.
    
    .OUTPUTS
        System.Object[] - Array of stack frame details
    #>
    [CmdletBinding()]
    param()
    
    try
    {
        $callStack = Get-PSCallStack
        $frames = @()
        
        for ($i = 0; $i -lt $callStack.Count; $i++)
        {
            $frame = $callStack[$i]
            $frames += [PSCustomObject]@{
                Index        = $i
                FunctionName = $frame.FunctionName
                ScriptName   = $frame.ScriptName
                LineNumber   = $frame.ScriptLineNumber
                Location     = $frame.Location
                Command      = $frame.Command
                Arguments    = $frame.Arguments -join ', '
            }
        }
        
        return $frames
    }
    catch
    {
        Write-Warning "[StackMonitor] Failed to get detailed stack: $_"
        return @()
    }
}

function Get-StackReport
{
    <#
    .SYNOPSIS
        Generates a comprehensive report of stack usage.
    
    .DESCRIPTION
        Provides statistics about stack usage including current depth,
        peak depth, history, and recommendations.
    #>
    [CmdletBinding()]
    param()
    
    $currentDepth = Get-StackDepth
    $safeDepth = Get-SafeStackDepth
    $psVersion = $PSVersionTable.PSVersion.Major
    
    Write-Host "`n=== Stack Usage Report ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $psVersion" -ForegroundColor White
    Write-Host "Estimated Safe Depth: $safeDepth" -ForegroundColor White
    Write-Host "Current Stack Depth: $currentDepth" -ForegroundColor $(
        if ($currentDepth -gt $safeDepth * 0.8) { "Red" }
        elseif ($currentDepth -gt $safeDepth * 0.6) { "Yellow" }
        else { "Green" }
    )
    Write-Host "Peak Stack Depth: $script:StackPeakDepth" -ForegroundColor White
    Write-Host "Monitoring Enabled: $script:StackMonitorEnabled" -ForegroundColor White
    
    if ($script:StackMonitorEnabled -and $script:MonitoringStartTime)
    {
        $duration = (Get-Date) - $script:MonitoringStartTime
        Write-Host "Monitoring Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
        Write-Host "History Entries: $($script:StackHistory.Count)" -ForegroundColor White
        
        if ($script:StackHistory.Count -gt 0)
        {
            $avgDepth = ($script:StackHistory | Measure-Object -Property Depth -Average).Average
            Write-Host "Average Depth: $([math]::Round($avgDepth, 2))" -ForegroundColor White
        }
    }
    
    # Usage percentage
    $usagePercent = [math]::Round(($currentDepth / $safeDepth) * 100, 2)
    Write-Host "Stack Usage: $usagePercent%" -ForegroundColor $(
        if ($usagePercent -gt 80) { "Red" }
        elseif ($usagePercent -gt 60) { "Yellow" }
        else { "Green" }
    )
    
    # Recommendations
    Write-Host "`n--- Recommendations ---" -ForegroundColor Yellow
    if ($psVersion -lt 7)
    {
        Write-Host "⚠️  PowerShell 5.1 detected - Consider upgrading to PS 7+ for 4x larger stack" -ForegroundColor Yellow
    }
    
    if ($usagePercent -gt 70)
    {
        Write-Host "⚠️  High stack usage detected!" -ForegroundColor Red
        Write-Host "  - Reduce recursion depth" -ForegroundColor Yellow
        Write-Host "  - Remove [CmdletBinding()] from non-critical functions" -ForegroundColor Yellow
        Write-Host "  - Simplify call chains" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Export-StackHistory
{
    <#
    .SYNOPSIS
        Exports stack depth history to a CSV file for analysis.
    
    .PARAMETER Path
        Output file path. Default: .\StackHistory.csv
    #>
    [CmdletBinding()]
    param(
        [string]$Path = ".\StackHistory.csv"
    )
    
    if ($script:StackHistory.Count -eq 0)
    {
        Write-Warning "[StackMonitor] No history to export. Enable monitoring first."
        return
    }
    
    try
    {
        $script:StackHistory | Export-Csv -Path $Path -NoTypeInformation
        Write-Host "[StackMonitor] History exported to: $Path" -ForegroundColor Green
        Write-Host "  Entries: $($script:StackHistory.Count)" -ForegroundColor Gray
    }
    catch
    {
        Write-Warning "[StackMonitor] Failed to export history: $_"
    }
}

function Get-SafeStackDepth
{
    <#
    .SYNOPSIS
        Returns the estimated safe stack depth for the current PowerShell version.
    
    .DESCRIPTION
        PowerShell 5.1 has ~1MB stack (~100-150 calls)
        PowerShell 7+ has ~4MB stack (~400-600 calls)
        
        Returns conservative estimates with safety margin.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()
    
    $psVersion = $PSVersionTable.PSVersion.Major
    
    if ($psVersion -ge 7)
    {
        return 400  # Conservative for PS 7+
    }
    else
    {
        return 100  # Conservative for PS 5.1
    }
}
#endregion

#region Stack Management Utilities
function Invoke-WithStackGuard
{
    <#
    .SYNOPSIS
        Executes a script block with stack overflow protection.
    
    .PARAMETER ScriptBlock
        The script block to execute.
    
    .PARAMETER MaxDepth
        Maximum allowed stack depth. Default: Safe depth for current PS version.
    
    .PARAMETER OnOverflow
        Action to take on stack overflow: 'Warn', 'Error', 'Break'
    
    .EXAMPLE
        Invoke-WithStackGuard -ScriptBlock { MyFunction } -MaxDepth 80
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [int]$MaxDepth = -1,
        [ValidateSet('Warn', 'Error', 'Break')]
        [string]$OnOverflow = 'Error'
    )
    
    if ($MaxDepth -lt 0)
    {
        $MaxDepth = Get-SafeStackDepth
    }
    
    $currentDepth = Get-StackDepth
    
    if ($currentDepth -ge $MaxDepth)
    {
        $message = "Stack depth ($currentDepth) exceeds maximum ($MaxDepth)"
        
        switch ($OnOverflow)
        {
            'Warn' { Write-Warning $message }
            'Error' { throw $message }
            'Break'
            { 
                Write-Host $message -ForegroundColor Red
                Wait-Debugger
            }
        }
        
        return
    }
    
    & $ScriptBlock
}

function Clear-CallStack
{
    <#
    .SYNOPSIS
        Attempts to optimize the call stack by clearing unnecessary variables.
    
    .DESCRIPTION
        NOTE: PowerShell doesn't provide direct stack manipulation.
        This function clears variables and forces garbage collection,
        which may help reduce memory pressure but won't reduce stack depth.
        
        The only way to reduce stack depth is to return from functions.
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "[StackMonitor] Attempting stack optimization..." -ForegroundColor Yellow
    Write-Host "  Note: Stack depth can only be reduced by returning from functions" -ForegroundColor Gray
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    Write-Host "  Garbage collection completed" -ForegroundColor Green
}

function Test-StackSafety
{
    <#
    .SYNOPSIS
        Tests if current stack depth is safe for the PowerShell version.
    
    .OUTPUTS
        System.Boolean - $true if stack is safe, $false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    $currentDepth = Get-StackDepth
    $safeDepth = Get-SafeStackDepth
    $isSafe = $currentDepth -lt ($safeDepth * 0.8)  # 80% threshold
    
    if (-not $isSafe)
    {
        Write-Warning "[StackMonitor] Stack depth $currentDepth approaching limit (safe: $safeDepth)"
    }
    
    return $isSafe
}
#endregion

#region Export Module Members
Export-ModuleMember -Function @(
    'Enable-StackMonitoring',
    'Disable-StackMonitoring',
    'Get-StackDepth',
    'Get-DetailedStack',
    'Get-StackReport',
    'Export-StackHistory',
    'Get-SafeStackDepth',
    'Invoke-WithStackGuard',
    'Clear-CallStack',
    'Test-StackSafety'
)
#endregion

# Auto-display help on import
Write-Host "`n[StackMonitor] Module loaded successfully" -ForegroundColor Green
Write-Host "  Commands available:" -ForegroundColor Gray
Write-Host "    Enable-StackMonitoring  - Start real-time monitoring" -ForegroundColor Gray
Write-Host "    Get-StackDepth          - Check current stack depth" -ForegroundColor Gray
Write-Host "    Get-StackReport         - View comprehensive report" -ForegroundColor Gray
Write-Host "    Invoke-WithStackGuard   - Execute code with stack protection" -ForegroundColor Gray
Write-Host "  Type 'Get-Command -Module StackMonitor' for all commands`n" -ForegroundColor Gray
