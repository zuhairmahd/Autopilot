<#
.SYNOPSIS
Writes log messages using the C# LogCore engine with automatic fallback to PowerShell logging.

.DESCRIPTION
This function provides a unified interface to the Autopilot.LogCore C# logging engine.
If the LogCore DLL is loaded, it uses the high-performance C# logger with async capabilities.
If the DLL is not available, it falls back to the PowerShell Write-Log function.

The LogCore engine provides:
- 5-15x performance improvement over PowerShell logging
- Thread-safe synchronous and asynchronous logging
- CMTrace format support
- Automatic log rotation
- Batch writing for improved I/O performance

.PARAMETER Message
The message to write to the log file.

.PARAMETER Level
The log level: Error (1), Warning (2), Information (3), Verbose (4), Debug (5).
Default is Information (3).

.PARAMETER Component
The component or function name generating the log entry.
Default is extracted from the calling function.

.PARAMETER LogFilePath
Full path to the log file.
Default is retrieved from global $settings.LogFilePath.

.PARAMETER UseCMTraceFormat
Whether to use CMTrace format for log entries.
Default is $true.

.PARAMETER Async
Whether to use asynchronous logging (non-blocking).
Default is $false (synchronous logging).

.PARAMETER MaxLogSizeMB
Maximum log file size in MB before rotation.
Default is 10 MB.

.EXAMPLE
Write-LogCore -Message "Device registration completed successfully" -Level Information

.EXAMPLE
Write-LogCore -Message "Failed to connect to Graph API" -Level Error -Component "Get-GraphAccessToken"

.EXAMPLE
Write-LogCore -Message "Starting batch processing" -Level Verbose -Async

.NOTES
Author: Autopilot Team
Requires: Autopilot.LogCore.dll (optional - falls back to PowerShell if unavailable)
#>

function Write-LogCore
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug', 1, 2, 3, 4, 5)]
        $Level = 'Information',
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = "",
        
        [Parameter(Mandatory = $false)]
        [bool]$UseCMTraceFormat = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$Async,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxLogSizeMB = 10
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Convert string level to numeric if needed
    $numericLevel = switch ($Level)
    {
        'Error' { 1 }
        'Warning' { 2 }
        'Information' { 3 }
        'Verbose' { 4 }
        'Debug' { 5 }
        1 { 1 }
        2 { 2 }
        3 { 3 }
        4 { 4 }
        5 { 5 }
        default { 3 }
    }
    
    # If component not specified, try to get calling function name
    if ([string]::IsNullOrEmpty($Component))
    {
        $caller = (Get-PSCallStack)[1]
        $Component = if ($caller.Command)
        {
            $caller.Command
        }
        else
        {
            $caller.FunctionName
        }
    }
    
    # If log file path not specified, try to get from global settings
    if ([string]::IsNullOrEmpty($LogFilePath))
    {
        if ($global:settings -and $global:settings.LogFilePath)
        {
            $LogFilePath = $global:settings.LogFilePath
        }
        else
        {
            # Default fallback
            $LogFilePath = Join-Path $PSScriptRoot "..\..\Logs\Autopilot.log"
        }
    }
    
    # Check if LogCore DLL is loaded
    $logCoreLoaded = $false
    if ($global:AutopilotDllStatus -and $global:AutopilotDllStatus.LogCoreLoaded)
    {
        $logCoreLoaded = $true
    }
    
    if ($logCoreLoaded)
    {
        try
        {
            # Initialize global logger if not already done
            if (-not $global:AutopilotLogger)
            {
                Write-Verbose "[$functionName] Initializing LogCore logger"
                $global:AutopilotLogger = New-Object Autopilot.LogCore.Logger(
                    $LogFilePath,
                    $UseCMTraceFormat,
                    $MaxLogSizeMB
                )
            }
            
            # Use async or sync logging based on parameter
            if ($Async)
            {
                $global:AutopilotLogger.WriteLogAsync($Message, $numericLevel, $Component)
            }
            else
            {
                $global:AutopilotLogger.WriteLog($Message, $numericLevel, $Component)
            }
        }
        catch
        {
            Write-Verbose "[$functionName] LogCore failed, falling back to PowerShell: $_"
            $logCoreLoaded = $false
        }
    }
    
    # Fallback to PowerShell Write-Log if LogCore not available
    if (-not $logCoreLoaded)
    {
        # Check if Write-Log function exists
        if (Get-Command Write-Log -ErrorAction SilentlyContinue)
        {
            # Map numeric level to Write-Log level parameter
            $psLevel = switch ($numericLevel)
            {
                1 { 'ERROR' }
                2 { 'WARNING' }
                3 { 'INFO' }
                4 { 'VERBOSE' }
                5 { 'DEBUG' }
                default { 'INFO' }
            }
            
            Write-Log -Message $Message -Level $psLevel -Component $Component
        }
        else
        {
            # Last resort: Write to console
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $levelText = switch ($numericLevel)
            {
                1 { "ERROR" }
                2 { "WARNING" }
                3 { "INFO" }
                4 { "VERBOSE" }
                5 { "DEBUG" }
                default { "INFO" }
            }
            Write-Host "[$timestamp] [$levelText] [$Component] $Message"
        }
    }
}

<#
.SYNOPSIS
Writes a separator line to the log file.

.DESCRIPTION
Writes a visual separator to the log file for better readability.

.PARAMETER Text
Optional text to include in the separator line.

.PARAMETER Async
Whether to use asynchronous logging.

.EXAMPLE
Write-LogCoreSeparator -Text "Starting New Session"

.EXAMPLE
Write-LogCoreSeparator
#>

function Write-LogCoreSeparator
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Text = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$Async
    )
    
    # Check if LogCore is loaded
    if ($global:AutopilotLogger)
    {
        if ($Async)
        {
            $global:AutopilotLogger.WriteSeparatorAsync($Text)
        }
        else
        {
            $global:AutopilotLogger.WriteSeparator($Text)
        }
    }
    else
    {
        # Fallback to simple separator
        $separator = if ([string]::IsNullOrEmpty($Text))
        {
            "=" * 80
        }
        else
        {
            "=" * 35 + " $Text " + "=" * 35
        }
        
        Write-LogCore -Message $separator -Level Information
    }
}

<#
.SYNOPSIS
Gracefully shuts down the LogCore logger.

.DESCRIPTION
Flushes any pending async log entries and shuts down the background logging thread.
Should be called before application exit when using async logging.

.PARAMETER TimeoutSeconds
Maximum time to wait for pending entries to flush.
Default is 5 seconds.

.EXAMPLE
Stop-LogCore

.EXAMPLE
Stop-LogCore -TimeoutSeconds 10
#>

function Stop-LogCore
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 5
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    if ($global:AutopilotLogger)
    {
        try
        {
            Write-Verbose "[$functionName] Shutting down LogCore logger"
            $global:AutopilotLogger.Shutdown($TimeoutSeconds)
            
            # Get final statistics
            $stats = $global:AutopilotLogger.GetStatistics()
            Write-Verbose "[$functionName] Log Statistics:"
            Write-Verbose "  Total Entries: $($stats.TotalEntriesWritten)"
            Write-Verbose "  Async Entries: $($stats.AsyncEntriesWritten)"
            Write-Verbose "  Sync Entries: $($stats.SyncEntriesWritten)"
            Write-Verbose "  Errors: $($stats.ErrorCount)"
            Write-Verbose "  Current Size: $([math]::Round($stats.CurrentLogSizeBytes / 1MB, 2)) MB"
            Write-Verbose "  Rotations: $($stats.RotationCount)"
            
            $global:AutopilotLogger = $null
        }
        catch
        {
            Write-Warning "[$functionName] Error shutting down LogCore: $_"
        }
    }
}

<#
.SYNOPSIS
Gets logging statistics from the LogCore logger.

.DESCRIPTION
Retrieves performance metrics and statistics from the C# logger.

.EXAMPLE
Get-LogCoreStatistics

.OUTPUTS
PSCustomObject with logging statistics
#>

function Get-LogCoreStatistics
{
    [CmdletBinding()]
    param()
    
    if ($global:AutopilotLogger)
    {
        try
        {
            $stats = $global:AutopilotLogger.GetStatistics()
            
            return [PSCustomObject]@{
                TotalEntriesWritten = $stats.TotalEntriesWritten
                AsyncEntriesWritten = $stats.AsyncEntriesWritten
                SyncEntriesWritten  = $stats.SyncEntriesWritten
                ErrorCount          = $stats.ErrorCount
                CurrentLogSizeMB    = [math]::Round($stats.CurrentLogSizeBytes / 1MB, 2)
                RotationCount       = $stats.RotationCount
                FirstEntryTime      = $stats.FirstEntryTime
                LastEntryTime       = $stats.LastEntryTime
                AverageWriteTimeMs  = $stats.AverageWriteTimeMs
            }
        }
        catch
        {
            Write-Warning "Error getting LogCore statistics: $_"
            return $null
        }
    }
    else
    {
        Write-Warning "LogCore logger not initialized"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Write-LogCore, Write-LogCoreSeparator, Stop-LogCore, Get-LogCoreStatistics
