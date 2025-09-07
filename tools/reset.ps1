[CmdletBinding()]
param(
    [string]$Log = "$PSScriptRoot\logs\reset.log",
    [string]$ScriptArchive = "$pwd\script.zip",
    [switch]$fullReset
)

function Write-Log()
{
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
    try
    {
        # Use global minimum log level if not provided
        if (-not $MinimumLogLevel -and $Global:MinimumLogLevel)
        {
            $MinimumLogLevel = $Global:MinimumLogLevel
        }
        elseif (-not $MinimumLogLevel)
        {
            $MinimumLogLevel = 'Information'
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
            
            # Create separator line
            $separatorLine = "=" * 80
            
            # Ensure log directory exists
            $logDir = Split-Path $LogFile -Parent
            if (-not (Test-Path $logDir))
            {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            if ($OverwriteLog)
            {
                Remove-Item -Path $LogFile -Force -ErrorAction SilentlyContinue
            }   
            
            # Check for log rotation if file exists and is too large
            if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt ($MaxLogSizeMB * 1MB))
            {
                $archiveFile = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $LogFile -Destination $archiveFile -Force
                Write-Verbose "Log file rotated to: $archiveFile"
            }
            
            if ($CMTraceFormat)
            {
                # For CMTrace format, still use the separator but in CMTrace format
                $cmTime = Get-Date -Format "HH:mm:ss.fff+000"
                $cmDate = Get-Date -Format "MM-dd-yyyy"
                $thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                $logEntry = "<![LOG[$separatorLine]LOG]!><time=`"$cmTime`" date=`"$cmDate`" component=`"$Module`" context=`"`" type=`"1`" thread=`"$thread`" file=`"`">"
            }
            else
            {
                # For standard format, just use the separator line without timestamp
                $logEntry = $separatorLine
            }
            
            # Use mutex for thread safety
            $mutexName = "LogMutex_" + ($LogFile -replace '[\\/:*?"<>|]', '_')
            $mutex = New-Object System.Threading.Mutex($false, $mutexName)
            
            try
            {
                $mutex.WaitOne() | Out-Null
                Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -Force
            }
            finally
            {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
            
            # Write to console
            <<<<<<< HEAD
            if ($WriteToConsole)
            =======
            if ($OutputToConsole)
            >>>>>>> origin/dev
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
            
            if ($currentLogLevelValue -gt $minimumLogLevelValue)
            {
                # Current log level is more detailed than the minimum, skip logging to file
                # But still write to console streams
                switch ($LogLevel)
                {
                    "Error"
                    {
                        <<<<<<< HEAD
                        if ($WriteToConsole)
                        =======
                        if ($OutputToConsole)
                        >>>>>>> origin/dev
                        {
                            Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue 
                        }
                    }
                    "Warning"
                    {
                        <<<<<<< HEAD
                        if ($WriteToConsole)
                        =======
                        if ($OutputToConsole)
                        >>>>>>> origin/dev
                        {
                            Write-Warning "[$Module] $Message" 
                        }
                    }
                    "Verbose"
                    {
                        <<<<<<< HEAD
                        if ($WriteToConsole)
                        =======
                        if ($OutputToConsole)
                        >>>>>>> origin/dev
                        {
                            Write-Verbose "[$Module] $Message" 
                        }
                    }
                    "Debug"
                    {
                        <<<<<<< HEAD
                        if ($WriteToConsole)
                        =======
                        if ($OutputToConsole)
                        >>>>>>> origin/dev
                        {
                            Write-Debug "[$Module] $Message" 
                        }
                    }
                    default
                    {
                        # For Information level, we don't output to console in this case
                    }
                }
                return
            }
        }
        
        # Ensure log directory exists
        $logDir = Split-Path $LogFile -Parent
        if (-not (Test-Path $logDir))
        {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        # Check for log rotation if file exists and is too large
        if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt ($MaxLogSizeMB * 1MB))
        {
            $archiveFile = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Move-Item -Path $LogFile -Destination $archiveFile -Force
            Write-Verbose "Log file rotated to: $archiveFile"
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        
        # Get context in a cross-platform way
        try 
        {
            if ($IsWindows -or ($null -eq $IsWindows -and $env:OS -eq "Windows_NT"))
            {
                $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
            }
            else
            {
                $Context = $env:USER
            }
        }
        catch 
        {
            $Context = "Unknown"
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
        }
        else
        {
            # Enhanced standard format with thread ID
            $logEntry = "$timestamp [$LogLevel] [$Module] [Thread:$thread] [Context:$Context] $Message"
        }
        
        # Use mutex for thread safety in concurrent scenarios
        $mutexName = "LogMutex_" + ($LogFile -replace '[\\/:*?"<>|]', '_')
        $mutex = New-Object System.Threading.Mutex($false, $mutexName)
        
        try
        {
            $mutex.WaitOne() | Out-Null
            Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -Force
        }
        finally
        {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
        
        # Write to appropriate PowerShell stream based on log level
        switch ($LogLevel)
        {
            "Error"
            {
                if ($OutputToConsole)
                {
                    Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue 
                }
            }
            "Warning"
            {
                if ($OutputToConsole)
                {
                    Write-Warning "[$Module] $Message" 
                }
            }
            "Verbose"
            {
                if ($OutputToConsole)
                {
                    Write-Verbose "[$Module] $Message" 
                }
            }
            "Debug"
            {
                if ($OutputToConsole)
                {
                    Write-Debug "[$Module] $Message" 
                }
            }
            default
            {
                if ($OutputToConsole)
                {
                    Write-Verbose "Logged: $logEntry" 
                }
            }
        }
        
        # Return log entry if PassThru is specified
        if ($PassThru)
        {
            return [PSCustomObject]@{
                Timestamp = $timestamp
                LogLevel  = $LogLevel
                Module    = $Module
                Message   = $Message
                Thread    = $thread
                LogFile   = $LogFile
                Entry     = $logEntry
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
    }
}

$scriptName = $MyInvocation.MyCommand.Name
$script:logFile = $Log
$secretsFolderName = '.secrets'
Write-Log -logFile $logFile -StartLogging
Write-Host "Resetting the script configuration..."
Write-Log -LogFile $logFile -Message "Starting reset process..." -Module $scriptName -LogLevel "Information"
if (-not (Test-Path -LiteralPath $ScriptArchive)) 
{ 
    Write-Error "[$scriptName] Archive not found: $ScriptArchive" 
    Write-Log -LogFile $logFile -Message "Archive not found: $ScriptArchive" -Module $scriptName -LogLevel "Error"
    Write-Log -logFile $logFile -FinishLogging
    exit 1 
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ("reset-secrets-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp -Force | Out-Null
Write-Verbose "[$scriptName] Extracting to $temp" 
Write-Log -LogFile $logFile -Message "Extracting archive to temp directory: $temp" -Module $scriptName -LogLevel "Information"

try
{
    Write-Host "Extracting archive..."
    Expand-Archive -LiteralPath $ScriptArchive -DestinationPath $temp -Force -ErrorAction Stop
    Write-Log -LogFile $logFile -Message "Archive extracted successfully." -Module $scriptName -LogLevel "Information"
    # Find $secretsFolderName inside extracted tree
    Write-Host "Searching for the $secretsFolderName folder..."
    Write-Log -LogFile $logFile -Message "Searching for the $secretsFolderName folder..." -Module $scriptName -LogLevel "Information"
    $candidate = Get-ChildItem -Path $temp -Recurse -Directory | Where-Object { $_.Name -eq $secretsFolderName } | Select-Object -First 1
    Write-Log -LogFile $logFile -Message "Candidate found: $($candidate.FullName)" -Module $scriptName -LogLevel "Debug"
    if (-not $candidate) 
    { 
        Write-Error "[$scriptName] No $secretsFolderName  folder found in archive." 
        Write-Log -LogFile $logFile -Message "No $secretsFolderName folder found in archive." -Module $scriptName -LogLevel "Error"
        Write-Log -LogFile $logFile -FinishLogging
        exit 1 
    }
    $dest = Join-Path $PSScriptRoot $secretsFolderName
    Write-Verbose "[$scriptName] Secrets destination folder: $dest"
    $candidateParent = Split-Path -Path $candidate.FullName -Parent
    Write-Verbose "[$scriptName] Script files folder: $candidateParent"
    if (Test-Path -LiteralPath $dest) 
    { 
        Write-Verbose "[$scriptName] Removing existing $dest folder before move."
        Write-Log -LogFile $logFile -Message "Removing existing $dest folder before move." -Module $scriptName -LogLevel "Information"
        Remove-Item -LiteralPath $dest -Recurse -Force 
    }
    try
    {
        Write-Host "Resetting password..."
        Move-Item -Path $candidate.FullName -Destination $dest -Force
        Write-Verbose "[$scriptName] Moved $secretsFolderName folder to $dest"
        Write-Log -LogFile $logFile -Message "Moved $secretsFolderName folder to $dest" -Module $scriptName -LogLevel "Information"
        if ($fullReset)
        {
            Write-Host "Resetting menus and other settings..."
            $allPSDFiles = Get-ChildItem -Path $candidateParent -Filter *.psd1 -Force
            Write-Verbose "[$scriptName] Performing full reset of all $($allPSDFiles.count) PSD files."
            Write-Log -LogFile $logFile -Message "Performing full reset of all $($allPSDFiles.count) PSD files." -Module $scriptName -LogLevel "Information"
            foreach ($file in $allPSDFiles)
            {
                $destinationPath = Join-Path $PSScriptRoot $file.Name
                Move-Item -Path $file.FullName -Destination $destinationPath -Force
                Write-Verbose "[$scriptName] Moved $($file.Name) to $PSScriptRoot"
            }
        }
        
    }
    catch
    {
        Write-Error "[$scriptName] Error moving items: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error moving items: $($_.Exception.Message)" -Module $scriptName -LogLevel "Error"
        Write-Log -LogFile $logFile -FinishLogging
        exit 1
    }
}
catch
{
    Write-Error "[$scriptName] Failure: $($_.Exception.Message)"
    Write-Log -LogFile $logFile -Message "Failure: $($_.Exception.Message)" -Module $scriptName -LogLevel "Error"
    Write-Log -LogFile $logFile -FinishLogging
    exit 1
}
finally
{
    Write-Verbose "[$scriptName] Cleaning up temporary files..."
    Write-Log -LogFile $logFile -Message "Cleaning up temporary files..." -Module $scriptName -LogLevel "Information"
    if (Test-Path -LiteralPath $temp) 
    { 
        try 
        {
            Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue 
            Write-Log -LogFile $logFile -Message "Temporary directory $temp removed." -Module $scriptName -LogLevel "Information"
            Write-Verbose "[$scriptName] Temporary directory $temp removed."
        }
        catch
        {
            Write-Verbose "[$scriptName] Warning: Failed to remove temp directory $temp. Exception: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Warning: Failed to remove temp directory $temp. Exception: $($_.Exception.Message)" -Module $scriptName -LogLevel "Warning"
        }
    }
}

Write-Host "Your script configuration has been reset to the original state."
Write-Host "You may now use the default password to reset your credentials."
Write-Log -LogFile $logFile -Message "Reset process completed successfully." -Module $scriptName -LogLevel "Information"
Write-Log -LogFile $logFile -FinishLogging