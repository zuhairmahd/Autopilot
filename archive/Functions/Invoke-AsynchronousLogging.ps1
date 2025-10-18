function Initialize-AsynchronousLogging()
{
    <#
    .SYNOPSIS
        Phase 4B Optimization: Initializes asynchronous logging framework for improved performance.
    
    .DESCRIPTION
        Sets up a background logging queue that processes log entries asynchronously,
        reducing I/O blocking during application operations. Maintains thread-safe
        operations and ensures all log entries are eventually written.
    
    .PARAMETER LogFile
        Path to the log file
    
    .PARAMETER MaxQueueSize
        Maximum number of log entries to queue (default: 1000)
    
    .PARAMETER FlushIntervalMs
        Interval between queue flushes in milliseconds (default: 500)
    
    .OUTPUTS
        Returns logging session information
    
    .NOTES
        Phase 4B optimization for logging performance
        Uses background runspace for PowerShell 5.1 compatibility
        Provides graceful shutdown and emergency flushing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        [int]$MaxQueueSize = 1000,
        [int]$FlushIntervalMs = 500
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Initializing asynchronous logging framework"
    
    # Create global logging state if not exists
    if (-not $global:AsyncLoggingState)
    {
        $global:AsyncLoggingState = @{
            IsInitialized = $false
            LogQueue = [System.Collections.Concurrent.ConcurrentQueue[PSObject]]::new()
            Runspace = $null
            PowerShell = $null
            IsShuttingDown = $false
            LogFile = $LogFile
            MaxQueueSize = $MaxQueueSize
            FlushIntervalMs = $FlushIntervalMs
            Statistics = @{
                TotalEnqueued = 0
                TotalProcessed = 0
                QueueOverflows = 0
                FlushCount = 0
            }
        }
    }
    
    # Update configuration
    $global:AsyncLoggingState.LogFile = $LogFile
    $global:AsyncLoggingState.MaxQueueSize = $MaxQueueSize
    $global:AsyncLoggingState.FlushIntervalMs = $FlushIntervalMs
    
    try
    {
        # Create background runspace for logging
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        
        # Add variables to runspace
        $runspace.SessionStateProxy.SetVariable('LogQueue', $global:AsyncLoggingState.LogQueue)
        $runspace.SessionStateProxy.SetVariable('LogFile', $LogFile)
        $runspace.SessionStateProxy.SetVariable('FlushIntervalMs', $FlushIntervalMs)
        $runspace.SessionStateProxy.SetVariable('MaxQueueSize', $MaxQueueSize)
        
        # Create logging script
        $loggingScript = {
            $logEntries = @()
            $lastFlush = Get-Date
            $statistics = @{
                TotalProcessed = 0
                FlushCount = 0
            }
            
            while (-not $global:AsyncLoggingState.IsShuttingDown)
            {
                $hasEntries = $false
                $processedCount = 0
                
                # Process available log entries
                while ($LogQueue.TryDequeue([ref]$logEntry) -and $processedCount -lt 100)
                {
                    $logEntries += $logEntry
                    $hasEntries = $true
                    $processedCount++
                    $statistics.TotalProcessed++
                }
                
                # Flush if we have entries and interval has passed
                $now = Get-Date
                $timeSinceFlush = ($now - $lastFlush).TotalMilliseconds
                
                if ($hasEntries -and ($timeSinceFlush -ge $FlushIntervalMs -or $logEntries.Count -ge 50))
                {
                    try
                    {
                        # Batch write log entries
                        if ($logEntries.Count -gt 0)
                        {
                            $logContent = $logEntries | ForEach-Object { $_.FormattedMessage }
                            $logContent | Out-File -FilePath $LogFile -Append -Encoding UTF8
                            
                            $logEntries = @()
                            $lastFlush = $now
                            $statistics.FlushCount++
                        }
                    }
                    catch
                    {
                        # Emergency fallback - write to console if file write fails
                        Write-Warning "Async logging failed: $($_.Exception.Message)"
                    }
                }
                
                # Brief sleep to prevent CPU spinning
                if (-not $hasEntries)
                {
                    Start-Sleep -Milliseconds 50
                }
            }
            
            # Final flush on shutdown
            while ($LogQueue.TryDequeue([ref]$logEntry))
            {
                $logEntries += $logEntry
            }
            
            if ($logEntries.Count -gt 0)
            {
                try
                {
                    $logContent = $logEntries | ForEach-Object { $_.FormattedMessage }
                    $logContent | Out-File -FilePath $LogFile -Append -Encoding UTF8
                    $statistics.FlushCount++
                }
                catch
                {
                    Write-Warning "Final async logging flush failed: $($_.Exception.Message)"
                }
            }
        }
        
        # Start background logging
        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $runspace
        $powerShell.AddScript($loggingScript) | Out-Null
        $asyncResult = $powerShell.BeginInvoke()
        
        # Update global state
        $global:AsyncLoggingState.Runspace = $runspace
        $global:AsyncLoggingState.PowerShell = $powerShell
        $global:AsyncLoggingState.AsyncResult = $asyncResult
        $global:AsyncLoggingState.IsInitialized = $true
        
        Write-Verbose "[$functionName] Asynchronous logging initialized successfully"
        return @{
            Success = $true
            LogFile = $LogFile
            QueueSize = $MaxQueueSize
            FlushInterval = $FlushIntervalMs
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Failed to initialize asynchronous logging: $($_.Exception.Message)"
        
        # Cleanup on failure
        if ($powerShell) { $powerShell.Dispose() }
        if ($runspace) { $runspace.Dispose() }
        
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Write-AsyncLog()
{
    <#
    .SYNOPSIS
        Phase 4B Optimization: Writes log entries asynchronously for improved performance.
    
    .DESCRIPTION
        Enqueues log entries for background processing, eliminating I/O blocking
        during application operations. Provides graceful fallback to synchronous
        logging if async logging is not available.
    
    .PARAMETER LogFile
        Path to the log file (used for fallback)
    
    .PARAMETER Module
        Module name for the log entry
    
    .PARAMETER Message
        Log message content
    
    .PARAMETER LogLevel
        Log level (Error, Warning, Information, Verbose, Debug)
    
    .NOTES
        Phase 4B optimization for logging performance
        Falls back to synchronous logging if async not initialized
        Thread-safe queue operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        [string]$Module = "Unknown",
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$LogLevel = "Information"
    )
    
    # Check if async logging is initialized and available
    if ($global:AsyncLoggingState -and $global:AsyncLoggingState.IsInitialized -and -not $global:AsyncLoggingState.IsShuttingDown)
    {
        try
        {
            # Check queue size limit
            if ($global:AsyncLoggingState.LogQueue.Count -lt $global:AsyncLoggingState.MaxQueueSize)
            {
                # Create log entry
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                $logEntry = [PSCustomObject]@{
                    Timestamp = $timestamp
                    Module = $Module
                    Level = $LogLevel
                    Message = $Message
                    FormattedMessage = "[$timestamp] [$LogLevel] [$Module] $Message"
                }
                
                # Enqueue for background processing
                $global:AsyncLoggingState.LogQueue.Enqueue($logEntry)
                $global:AsyncLoggingState.Statistics.TotalEnqueued++
                
                return $true
            }
            else
            {
                # Queue overflow - increment counter and fall back to sync
                $global:AsyncLoggingState.Statistics.QueueOverflows++
            }
        }
        catch
        {
            Write-Verbose "Async logging failed, falling back to synchronous: $($_.Exception.Message)"
        }
    }
    
    # Fallback to synchronous logging
    try
    {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logMessage = "[$timestamp] [$LogLevel] [$Module] $Message"
        $logMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
        return $true
    }
    catch
    {
        Write-Warning "Synchronous logging also failed: $($_.Exception.Message)"
        return $false
    }
}

function Stop-AsynchronousLogging()
{
    <#
    .SYNOPSIS
        Phase 4B Optimization: Gracefully shuts down asynchronous logging.
    
    .DESCRIPTION
        Signals the background logging process to shutdown, waits for final
        flush, and cleans up resources. Ensures all queued log entries are
        written before termination.
    
    .PARAMETER TimeoutSeconds
        Maximum time to wait for shutdown (default: 10)
    
    .NOTES
        Phase 4B optimization cleanup
        Ensures data integrity during shutdown
    #>
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 10
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Stopping asynchronous logging"
    
    if (-not $global:AsyncLoggingState -or -not $global:AsyncLoggingState.IsInitialized)
    {
        Write-Verbose "[$functionName] Async logging not initialized"
        return @{ Success = $true; Message = "Not initialized" }
    }
    
    try
    {
        # Signal shutdown
        $global:AsyncLoggingState.IsShuttingDown = $true
        
        # Wait for background process to complete
        $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
        while ($global:AsyncLoggingState.PowerShell.InvocationStateInfo.State -eq 'Running' -and (Get-Date) -lt $timeout)
        {
            Start-Sleep -Milliseconds 100
        }
        
        # Force stop if still running
        if ($global:AsyncLoggingState.PowerShell.InvocationStateInfo.State -eq 'Running')
        {
            Write-Verbose "[$functionName] Forcing stop of background logging process"
            $global:AsyncLoggingState.PowerShell.Stop()
        }
        
        # Get final statistics
        $stats = $global:AsyncLoggingState.Statistics
        
        # Cleanup resources
        if ($global:AsyncLoggingState.PowerShell)
        {
            $global:AsyncLoggingState.PowerShell.Dispose()
        }
        if ($global:AsyncLoggingState.Runspace)
        {
            $global:AsyncLoggingState.Runspace.Dispose()
        }
        
        # Reset state
        $global:AsyncLoggingState = $null
        
        Write-Verbose "[$functionName] Async logging stopped. Final stats: Enqueued=$($stats.TotalEnqueued), Processed=$($stats.TotalProcessed), Overflows=$($stats.QueueOverflows)"
        
        return @{
            Success = $true
            Statistics = $stats
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error stopping async logging: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}