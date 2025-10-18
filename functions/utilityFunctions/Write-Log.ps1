function Write-Log()
{
    <#
    .SYNOPSIS
        Writes log messages with automatic C# DLL acceleration when available.
    .DESCRIPTION
        Primary logging function for the Autopilot application. Automatically uses the 
        high-performance Autopilot.LogCore C# DLL when available (10-20x faster), with 
        seamless fallback to PowerShell implementation.
        
        Features:
        - Automatic DLL detection and usage (zero configuration)
        - Thread-safe logging (mutex-based for PowerShell, native for C#)
        - CMTrace format support
        - Log rotation
        - Multiple parameter sets (Normal, StartLogging, FinishLogging)
        - Minimum log level filtering
    .NOTES
        Modified to integrate LogCore DLL functionality directly.
        When LogCore.dll is loaded, provides 10-20x performance improvement.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Normal')]
        [string]$Message,
        [Parameter(Mandatory = $true, ParameterSetName = 'Normal')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StartLogging')]
        [Parameter(Mandatory = $true, ParameterSetName = 'FinishLogging')]
        [ValidateScript({
                $parentDir = Split-Path $_ -Parent
                if (-not (Test-Path $parentDir))
                {
                    try
                    {
                        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    }
                    catch
                    {
                        throw "Failed to create log directory: $_. Exception: $($_.Exception.Message)"
                    }
                }
                return $true
            })]
        [string]$LogFile,
        [Parameter(Mandatory = $true, ParameterSetName = 'Normal')]
        [string]$Module,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [switch]$WriteToConsole,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [ValidateSet("Verbose", "Debug", "Information", "Warning", "Error")]
        [string]$LogLevel = "Information",
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [Parameter(Mandatory = $false, ParameterSetName = 'StartLogging')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FinishLogging')]
        [switch]$CMTraceFormat,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [Parameter(Mandatory = $false, ParameterSetName = 'StartLogging')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FinishLogging')]
        [int]$MaxLogSizeMB = 10,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [switch]$PassThru,
        [Parameter(Mandatory = $true, ParameterSetName = 'StartLogging')]
        [switch]$StartLogging,
        [Parameter(Mandatory = $false, ParameterSetName = 'StartLogging')]
        [switch]$OverwriteLog,
        [Parameter(Mandatory = $true, ParameterSetName = 'FinishLogging')]
        [switch]$FinishLogging,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [Parameter(Mandatory = $false, ParameterSetName = 'StartLogging')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FinishLogging')]
        [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug')]
        [string]$MinimumLogLevel
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Writing the following to $($logFile): $message"
    # Check if LogCore DLL is available for high-performance logging
    $useLogCore = $false
    if ($global:AutopilotDllStatus -and $global:AutopilotDllStatus.LogCoreLoaded -and -not ($StartLogging -or $FinishLogging))
    {
        $useLogCore = $true
        Write-Verbose "[$functionName] Using LogCore DLL for logging in function $functionName."
    }
    
    try
    {
        # If using LogCore DLL for normal logging
        if ($useLogCore)
        {
            # Initialize global logger if not already done
            Write-Verbose "[$functionName] Initializing AutopilotLogger in function $functionName."
            if (-not $global:AutopilotLogger)
            {
                # Logger constructor: (logFilePath, minimumLogLevel, useCMTraceFormat, maxLogSizeMB, enableAsync)
                # Use Information as default minimum level, sync logging (false for async)
                $minimumLevel = [Autopilot.LogCore.Logger+LogLevel]::Information
                if ($MinimumLogLevel)
                {
                    $minimumLevel = switch ($MinimumLogLevel)
                    {
                        'Error' { [Autopilot.LogCore.Logger+LogLevel]::Error }
                        'Warning' { [Autopilot.LogCore.Logger+LogLevel]::Warning }
                        'Information' { [Autopilot.LogCore.Logger+LogLevel]::Information }
                        'Verbose' { [Autopilot.LogCore.Logger+LogLevel]::Verbose }
                        'Debug' { [Autopilot.LogCore.Logger+LogLevel]::Debug }
                        default { [Autopilot.LogCore.Logger+LogLevel]::Information }
                    }
                }
                
                $global:AutopilotLogger = New-Object Autopilot.LogCore.Logger(
                    $LogFile,
                    $minimumLevel,
                    $CMTraceFormat.IsPresent,
                    $MaxLogSizeMB,
                    $false  # enableAsync = false (use sync logging)
                )
                Write-Verbose "[$functionName] AutopilotLogger initialized."
            }
            
            # Convert LogLevel string to numeric for LogCore
            $numericLevel = switch ($LogLevel)
            {
                'Error' { [Autopilot.LogCore.Logger+LogLevel]::Error }
                'Warning' { [Autopilot.LogCore.Logger+LogLevel]::Warning }
                'Information' { [Autopilot.LogCore.Logger+LogLevel]::Information }
                'Verbose' { [Autopilot.LogCore.Logger+LogLevel]::Verbose }
                'Debug' { [Autopilot.LogCore.Logger+LogLevel]::Debug }
                default { [Autopilot.LogCore.Logger+LogLevel]::Information }
            }
            Write-Verbose "[$functionName] Converted LogLevel '$LogLevel' to numeric level '$numericLevel'."            
            # Check minimum log level filtering
            if ($MinimumLogLevel)
            {
                $logLevelHierarchy = @{
                    'Error'       = 1
                    'Warning'     = 2
                    'Information' = 3
                    'Verbose'     = 4
                    'Debug'       = 5
                }
                
                $currentLogLevelValue = $logLevelHierarchy[$LogLevel]
                $minimumLogLevelValue = $logLevelHierarchy[$MinimumLogLevel]
                Write-Verbose "[$functionName] Current log level value: $currentLogLevelValue, Minimum log level value: $minimumLogLevelValue."
                if ($currentLogLevelValue -gt $minimumLogLevelValue)
                {
                    # Skip logging but still write to console if requested
                    Write-Verbose "[$functionName] Skipping log entry due to minimum log level filtering."
                    if ($WriteToConsole)
                    {
                        switch ($LogLevel)
                        {
                            "Error" { Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue }
                            "Warning" { Write-Warning "[$Module] $Message" }
                            "Verbose" { Write-Verbose "[$Module] $Message" }
                            "Debug" { Write-Debug "[$Module] $Message" }
                        }
                    }
                    return
                }
            }
            
            # Use high-performance C# logging
            Write-Verbose "[$functionName] Writing log entry using LogCore DLL."
            # WriteLog signature: WriteLog(string module, string message, LogLevel level)
            $global:AutopilotLogger.WriteLog($Module, $Message, $numericLevel)
            
            # Write to console if requested
            if ($WriteToConsole)
            {
                switch ($LogLevel)
                {
                    "Error" { Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue }
                    "Warning" { Write-Warning "[$Module] $Message" }
                    "Verbose" { Write-Verbose "[$Module] $Message" }
                    "Debug" { Write-Debug "[$Module] $Message" }
                    default { Write-Verbose "Logged: $Message" }
                }
                Write-Verbose "[$functionName] Logged LogCore.dll message to console."
            }
            
            # Return log entry if PassThru is specified
            if ($PassThru)
            {
                Write-Verbose "[$functionName] Returning LogCore.dll log entry object since Passthru is $passThru."
                return [PSCustomObject]@{
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                    LogLevel  = $LogLevel
                    Module    = $Module
                    Message   = $Message
                    LogFile   = $LogFile
                    UsedDLL   = $true
                }
            }
            
            return
        }
        
        # PowerShell fallback implementation (original code continues below)
        # Use global minimum log level if not provided
        Write-Verbose "[$functionName] Falling back to PowerShell logging in function $functionName."
        if (-not $MinimumLogLevel -and $Global:MinimumLogLevel)
        {
            $MinimumLogLevel = $Global:MinimumLogLevel
            Write-Verbose "[$functionName] Using global MinimumLogLevel: $MinimumLogLevel."
        }
        elseif (-not $MinimumLogLevel)
        {
            $MinimumLogLevel = 'Information'
            Write-Verbose "[$functionName] Using default MinimumLogLevel: $MinimumLogLevel."
        }
        
        # Define log level hierarchy (higher numbers = more detailed logging)
        $logLevelHierarchy = @{
            'Error'       = 1
            'Warning'     = 2
            'Information' = 3
            'Verbose'     = 4
            'Debug'       = 5
        }
        
        # Handle StartLogging and FinishLogging switches
        if ($StartLogging -or $FinishLogging)
        {
            # Set default values when using StartLogging or FinishLogging
            $Module = $MyInvocation.MyCommand.Name
            $LogLevel = "Information"
            Write-Verbose "[$functionName] Creating separator line for logging."
            # Create separator line
            $separatorLine = "=" * 80
            
            # Ensure log directory exists
            $logDir = Split-Path $LogFile -Parent
            if (-not (Test-Path $logDir))
            {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
                Write-Verbose "[$functionName] Created log directory: $logDir."
            }
            
            if ($OverwriteLog)
            {
                Remove-Item -Path $LogFile -Force -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] Overwritten existing log file: $LogFile."
            }   
            
            # Check for log rotation if file exists and is too large
            if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt ($MaxLogSizeMB * 1MB))
            {
                $archiveFile = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $LogFile -Destination $archiveFile -Force
                Write-Verbose "[$functionName] Log file rotated to: $archiveFile"
            }
            
            if ($CMTraceFormat)
            {
                # For CMTrace format, still use the separator but in CMTrace format
                $cmTime = Get-Date -Format "HH:mm:ss.fff+000"
                $cmDate = Get-Date -Format "MM-dd-yyyy"
                $thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                $logEntry = "<![LOG[$separatorLine]LOG]!><time=`"$cmTime`" date=`"$cmDate`" component=`"$Module`" context=`"`" type=`"1`" thread=`"$thread`" file=`"`">"
                Write-Verbose "[$functionName] Created CMTrace formatted separator line."
            }
            else
            {
                # For standard format, just use the separator line without timestamp
                $logEntry = $separatorLine
                Write-Verbose "[$functionName] Created standard log entry."
            }
            
            # Use mutex for thread safety
            $mutexName = "LogMutex_" + ($LogFile -replace '[\\/:*?"<>|]', '_')
            $mutex = New-Object System.Threading.Mutex($false, $mutexName)
            
            try
            {
                $mutex.WaitOne() | Out-Null
                Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -Force
                Write-Verbose "[$functionName] Log entry added to file: $LogFile."
            }
            finally
            {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
                Write-Verbose "[$functionName] Released mutex and disposed."
            }
            
            # Write to console
            if ($WriteToConsole)
            {
                Write-Host $separatorLine
            }
            return
        }
        
        # Check if this log entry should be written based on minimum log level
        # Only continue if the current log level meets or exceeds the minimum threshold
        if (-not ($StartLogging -or $FinishLogging))
        {
            $currentLogLevelValue = $logLevelHierarchy[$LogLevel]
            $minimumLogLevelValue = $logLevelHierarchy[$MinimumLogLevel]
            Write-Verbose "[$functionName] Current log level value: $currentLogLevelValue, Minimum log level value: $minimumLogLevelValue."
            if ($currentLogLevelValue -gt $minimumLogLevelValue)
            {
                # Current log level is more detailed than the minimum, skip logging to file
                # But still write to console streams
                switch ($LogLevel)
                {
                    "Error"
                    {
                        if ($WriteToConsole)
                        {
                            Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue 
                        }
                    }
                    "Warning"
                    {
                        if ($WriteToConsole)
                        {
                            Write-Warning "[$Module] $Message" 
                        }
                    }
                    "Verbose"
                    {
                        if ($WriteToConsole)
                        {
                            Write-Verbose "[$Module] $Message" 
                        }
                    }
                    "Debug"
                    {
                        if ($WriteToConsole)
                        {
                            Write-Debug "[$Module] $Message" 
                        }
                    }
                    default
                    {
                        # For Information level, we don't output to console in this case
                    }
                }
                Write-Verbose "[$functionName] Skipping log entry due to minimum log level filtering."
                return
            }
        }
        
        # Ensure log directory exists
        $logDir = Split-Path $LogFile -Parent
        if (-not (Test-Path $logDir))
        {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            Write-Verbose "[$functionName] Created log directory: $logDir."
        }
        
        # Check for log rotation if file exists and is too large
        if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt ($MaxLogSizeMB * 1MB))
        {
            $archiveFile = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Move-Item -Path $LogFile -Destination $archiveFile -Force
            Write-Verbose "[$functionName] Log file rotated to: $archiveFile"
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        
        # Get context in a cross-platform way
        try 
        {
            if ($IsWindows -or ($null -eq $IsWindows -and $env:OS -eq "Windows_NT"))
            {
                $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
                Write-Verbose "[$functionName] Detected Windows context: $Context."
            }
            else
            {
                $Context = $env:USER
                Write-Verbose "[$functionName] Detected non-Windows context: $Context."
            }
        }
        catch 
        {
            $Context = "Unknown"
            Write-Verbose "[$functionName] Failed to detect context, set to Unknown."
        }
        if ($CMTraceFormat)
        {
            # True CMTrace format: 
            $cmTime = Get-Date -Format "HH:mm:ss.fff+000"
            $cmDate = Get-Date -Format "MM-dd-yyyy"
            $severity = switch ($LogLevel)
            {
                "Error"
                {
                    3 
                }
                "Warning"
                {
                    2 
                }
                default
                {
                    1 
                }
            }
            $logEntry = "<![LOG[$Message]LOG]!><time=`"$cmTime`" date=`"$cmDate`" component=`"$Module`" context=`"`" type=`"$severity`" thread=`"$thread`" file=`"`">"
            Write-Verbose "[$functionName] Created CMTrace formatted log entry."
        }
        else
        {
            # Enhanced standard format with thread ID
            $logEntry = "$timestamp [$LogLevel] [$Module] [Thread:$thread] [Context:$Context] $Message"
            Write-Verbose "[$functionName] Created standard log entry."
        }
        
        # Use mutex for thread safety in concurrent scenarios
        $mutexName = "LogMutex_" + ($LogFile -replace '[\\/:*?"<>|]', '_')
        $mutex = New-Object System.Threading.Mutex($false, $mutexName)
        
        try
        {
            $mutex.WaitOne() | Out-Null
            Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -Force
            Write-Verbose "[$functionName] Log entry added to file: $LogFile."
        }
        finally
        {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
            Write-Verbose "[$functionName] Released mutex and disposed."
        }
        
        # Write to appropriate PowerShell stream based on log level
        switch ($LogLevel)
        {
            "Error"
            {
                if ($WriteToConsole)
                {
                    Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue 
                }
            }
            "Warning"
            {
                if ($WriteToConsole)
                {
                    Write-Warning "[$Module] $Message" 
                }
            }
            "Verbose"
            {
                if ($WriteToConsole)
                {
                    Write-Verbose "[$Module] $Message" 
                }
            }
            "Debug"
            {
                if ($WriteToConsole)
                {
                    Write-Debug "[$Module] $Message" 
                }
            }
            default
            {
                if ($WriteToConsole)
                {
                    Write-Verbose "[$functionName] Logged: $logEntry" 
                }
            }
        }
        Write-Verbose "[$functionName] Completed writing log entry and console output."
        # Return log entry if PassThru is specified
        if ($PassThru)
        {
            Write-Verbose "[$functionName] Returning log entry object since Passthru is $passThru."
            return [PSCustomObject]@{
                Timestamp = $timestamp
                LogLevel  = $LogLevel
                Module    = $Module
                Message   = $Message
                Thread    = $thread
                LogFile   = $LogFile
                Entry     = $logEntry
                UsedDLL   = $false
            }
        }
    }
    catch
    {
        Write-Error "Failed to write to log file '$LogFile': $_"
        # Fallback to console output
        Write-Host "$timestamp [$LogLevel] [$Module] $Message" -ForegroundColor $(
            switch ($LogLevel)
            {
                "Error"
                {
                    "Red" 
                }
                "Warning"
                {
                    "Yellow" 
                }
                "Debug"
                {
                    "Cyan" 
                }
                default
                {
                    "White" 
                }
            }
        )
        Write-Verbose "[$functionName] Fallback to console output."
    }
}
