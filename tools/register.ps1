[CmdletBinding()]
param(
    [string]$Label,
    [string]$scriptsFolder = "scripts\helpdesk",
    [string]$log = "$env:windir\Logs\DriveLetterFindScript.log",
    [switch]$EmitFinalPath,
    [switch]$ignoreLabelIfOnlyOne
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

function Test-WindowsSetupDrive()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $score = 0
    
    # Check for common Windows setup files and folders
    $windowsSetupIndicators = @(
        @{ Path = "setup.exe"; Weight = 3; Description = "Windows Setup executable" }
        @{ Path = "sources"; Weight = 3; Description = "Sources folder" }
        @{ Path = "boot"; Weight = 2; Description = "Boot folder" }
        @{ Path = "efi"; Weight = 2; Description = "EFI folder" }
        @{ Path = "bootmgr"; Weight = 2; Description = "Boot manager" }
        @{ Path = "sources\install.wim"; Weight = 4; Description = "Windows install image" }
        @{ Path = "sources\install.esd"; Weight = 4; Description = "Windows install image (ESD)" }
        @{ Path = "sources\boot.wim"; Weight = 3; Description = "Windows boot image" }
        @{ Path = "autorun.inf"; Weight = 1; Description = "Autorun file" }
    )
    
    Write-Verbose "[$functionName] Checking drive $DriveLetter for Windows setup indicators"
    
    foreach ($indicator in $windowsSetupIndicators) {
        $fullPath = Join-Path "${DriveLetter}:" $indicator.Path
        if (Test-Path $fullPath) {
            $score += $indicator.Weight
            Write-Verbose "[$functionName] Found $($indicator.Description) at $fullPath (weight: $($indicator.Weight))"
        }
    }
    
    # Score >= 5 indicates likely Windows setup drive
    # Score >= 8 indicates very likely Windows setup drive
    $isWindowsSetup = $score -ge 5
    Write-Verbose "[$functionName] Drive $DriveLetter Windows setup score: $score (threshold: 5, result: $isWindowsSetup)"
    
    return @{
        IsWindowsSetup = $isWindowsSetup
        Score = $score
        Confidence = if ($score -ge 8) { "High" } elseif ($score -ge 5) { "Medium" } else { "Low" }
    }
}

function Get-WindowsUSBDriveLetter()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Label,
        [Parameter(Mandatory = $false)]
        [switch]$IgnoreLabelIfOnlyOne
    )

    $functionName = $MyInvocation.MyCommand.Name
    # Collect all USB volumes found
    $results = @()

    # Ensure $usbDrives is always an array so .Count is reliable (0 when none, 1 when single)
    $usbDrivesRaw = Get-CimInstance -ClassName Win32_DiskDrive -Filter 'InterfaceType = "USB"'
    $usbDrives = if ($usbDrivesRaw)
    {
        @($usbDrivesRaw) 
    }
    else
    {
        @() 
    }
    Write-Verbose "[$functionName] Found $($usbDrives.Count) USB drives."

    # If only one physical USB drive exists and caller wants to ignore label requirement, disable label filtering
    if ($Label -and $IgnoreLabelIfOnlyOne -and $usbDrives.Count -eq 1)
    {
        Write-Verbose "[$functionName] -Label specified ('$Label') but only one USB drive detected and -IgnoreLabelIfOnlyOne provided. Ignoring label filter."
        $Label = $null
    }
    foreach ($usbDrive in $usbDrives)
    {
        Write-Verbose "[$functionName] Processing USB drive: $($usbDrive.DeviceID) - Model: $($usbDrive.Model)"
        $partitions = Get-CimAssociatedInstance -InputObject $usbDrive -ResultClassName Win32_DiskPartition
        Write-Verbose "[$functionName] Found $($partitions.Count) partitions for USB drive $($usbDrive.DeviceID)"
        foreach ($partition in $partitions)
        {
            Write-Verbose "[$functionName] Processing partition: $($partition.DeviceID)"
            $logicalDisks = Get-CimAssociatedInstance -InputObject $partition -ResultClassName Win32_LogicalDisk
            Write-Verbose "[$functionName] Found $($logicalDisks.Count) logical disks for partition $($partition.DeviceID)"
            foreach ($logicalDisk in $logicalDisks)
            {
                Write-Verbose "[$functionName] Processing logical disk: $($logicalDisk.DeviceID)"
                if ($null -ne $logicalDisk.DeviceID -and $logicalDisk.DeviceID -match '^[A-Z]:$')
                {
                    # Get-Volume -DriveLetter expects the letter without ':'
                    $driveLetter = $logicalDisk.DeviceID.TrimEnd(':')
                    Write-Verbose "[$functionName] Retrieving volume information for drive letter: $driveLetter"
                    try
                    {
                        $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
                        Write-Verbose "[$functionName] Retrieved volume: $($volume.DriveLetter) - Label: $($volume.FileSystemLabel)"
                    }
                    catch
                    {
                        $volume = $null
                        Write-Warning "[$functionName] Failed to retrieve volume for drive letter $($driveLetter): $($_.Exception.Message)"
                    }
                    if ($volume)
                    {
                        Write-Verbose "[$functionName] Found volume for drive letter $($driveLetter): Label=$($volume.FileSystemLabel), FileSystem=$($volume.FileSystem), Size=$($volume.Size), FreeSpace=$($volume.SizeRemaining)"
                        $obj = [PSCustomObject]@{
                            DeviceID      = $usbDrive.DeviceID
                            Model         = $usbDrive.Model
                            DriveLetter   = $volume.DriveLetter
                            FileSystem    = $volume.FileSystem
                            VolumeName    = $volume.FileSystemLabel
                            Size          = $volume.Size
                            SizeRemaining = $volume.SizeRemaining
                        }
                        if ($Label)
                        {
                            Write-Verbose "[$functionName] Checking volume label for drive letter $driveLetter"
                            # Case-insensitive exact match on volume label
                            if ($volume.FileSystemLabel -and ($volume.FileSystemLabel -match $Label))
                            {
                                # Always return an array for consistent .Count behavior
                                Write-Verbose "[$functionName] Volume label matches filter '$Label'. Returning this volume."
                                return @($obj)
                            }
                        }
                        else
                        {
                            Write-Verbose "[$functionName] No label filter provided. Adding volume for drive letter $driveLetter to results."
                            $results += $obj
                        }
                    }
                }
            }
        }
    }

    if ($Label)
    {
        # When filtering by label and not found, return an empty array for consistent .Count behavior
        Write-Verbose "[$functionName] No USB volume found matching label '$Label'. Returning empty array."
        return @()
    }
    else
    {
        Write-Verbose "[$functionName] Returning all found USB volumes. Count: $($results.Count)"
        return @($results)
    }
}

$scriptName = $MyInvocation.MyCommand.Name
$script:logFile = $log
$scriptsFolder = "scripts\helpdesk"
# If the logfile is a string without a path, set the path to the script directory
if ($logFile -and -not ($logFile -match '[\\/]+'))
{
    $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $logFile = Join-Path -Path $scriptDir -ChildPath $logFile
}
elseif (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator') -eq $false)
{
    $tempDir = [System.IO.Path]::GetTempPath()
    $logFile = Join-Path -Path $tempDir -ChildPath (Split-Path -Path $logFile -Leaf)
}

Write-Log -logFile $logFile -StartLogging
Write-Log -LogFile $logFile -Message "Script started." -Module $scriptName -LogLevel "Information"
if ($label)
{
    if ($ignoreLabelIfOnlyOne)
    {
        $usbDriveLetter = @(Get-WindowsUSBDriveLetter -Label $Label -IgnoreLabelIfOnlyOne)
    }
    else
    {
        $usbDriveLetter = @(Get-WindowsUSBDriveLetter -Label $Label)
    }
    if ($usbDriveLetter.Count -eq 1)
    {
        Write-Host "Using USB drive with label $($usbDriveLetter[0].VolumeName) in Drive $($usbDriveLetter[0].DriveLetter):"
        $usbDriveLetter = $usbDriveLetter[0]
        Write-Log -LogFile $logFile -Message "Using USB drive with label $($usbDriveLetter.VolumeName) in Drive $($usbDriveLetter.DriveLetter):" -Module $scriptName -LogLevel "Information"
    }
    elseif ($usbDriveLetter.Count -gt 1)
    {
        Write-Warning "Multiple USB drives found matching label '$Label'. Using the first one: $($usbDriveLetter[0].DriveLetter)"
        $usbDriveLetter = $usbDriveLetter[0]
        Write-Log -LogFile $logFile -Message "Multiple USB drives found matching label '$Label'. Using the first one: $($usbDriveLetter.DriveLetter)" -Module $scriptName -LogLevel "Warning"
    }
}
else
{
    $usbDriveLetters = @(Get-WindowsUSBDriveLetter)
    Write-Host "No label specified. Found $($usbDriveLetters.Count) USB drives."
    Write-Log -LogFile $logFile -Message "No label specified. Found $($usbDriveLetters.Count) USB drives." -Module $scriptName -LogLevel "Information"
    
    if ($usbDriveLetters.Count -eq 0)
    {
        Write-Warning "No USB drives found."
        Write-Log -LogFile $logFile -Message "No USB drives found." -Module $scriptName -LogLevel "Warning"
        $usbDriveLetter = $null
    }
    elseif ($usbDriveLetters.Count -eq 1)
    {
        Write-Host "Using the only USB drive found: $($usbDriveLetters[0].DriveLetter)"
        Write-Log -LogFile $logFile -Message "Using the only USB drive found: $($usbDriveLetters[0].DriveLetter)" -Module $scriptName -LogLevel "Information"
        $usbDriveLetter = $usbDriveLetters[0]
    }
    else
    {
        # Multiple USB drives found - try to detect Windows setup drives
        Write-Host "Multiple USB drives found. Attempting to detect Windows setup drive..."
        Write-Log -LogFile $logFile -Message "Multiple USB drives found. Attempting to detect Windows setup drive..." -Module $scriptName -LogLevel "Information"
        
        $windowsSetupDrives = @()
        foreach ($drive in $usbDriveLetters)
        {
            $setupTest = Test-WindowsSetupDrive -DriveLetter $drive.DriveLetter
            if ($setupTest.IsWindowsSetup)
            {
                $windowsSetupDrives += @{
                    Drive = $drive
                    Score = $setupTest.Score
                    Confidence = $setupTest.Confidence
                }
                Write-Host "Found potential Windows setup drive: $($drive.DriveLetter) (confidence: $($setupTest.Confidence), score: $($setupTest.Score))"
                Write-Log -LogFile $logFile -Message "Found potential Windows setup drive: $($drive.DriveLetter) (confidence: $($setupTest.Confidence), score: $($setupTest.Score))" -Module $scriptName -LogLevel "Information"
            }
        }
        
        if ($windowsSetupDrives.Count -eq 1)
        {
            $bestDrive = $windowsSetupDrives[0].Drive
            Write-Host "Using detected Windows setup drive: $($bestDrive.DriveLetter)"
            Write-Log -LogFile $logFile -Message "Using detected Windows setup drive: $($bestDrive.DriveLetter)" -Module $scriptName -LogLevel "Information"
            $usbDriveLetter = $bestDrive
        }
        elseif ($windowsSetupDrives.Count -gt 1)
        {
            # Multiple Windows setup drives - use the one with highest score
            $bestDrive = ($windowsSetupDrives | Sort-Object Score -Descending)[0].Drive
            Write-Host "Multiple Windows setup drives detected. Using highest scored drive: $($bestDrive.DriveLetter)"
            Write-Log -LogFile $logFile -Message "Multiple Windows setup drives detected. Using highest scored drive: $($bestDrive.DriveLetter)" -Module $scriptName -LogLevel "Information"
            $usbDriveLetter = $bestDrive
        }
        else
        {
            # No Windows setup drives detected - fall back to first drive
            Write-Warning "No Windows setup drives detected. Using first USB drive: $($usbDriveLetters[0].DriveLetter)"
            Write-Log -LogFile $logFile -Message "No Windows setup drives detected. Using first USB drive: $($usbDriveLetters[0].DriveLetter)" -Module $scriptName -LogLevel "Warning"
            $usbDriveLetter = $usbDriveLetters[0]
        }
    }
}

if ($usbDriveLetter -and $usbDriveLetter.DriveLetter)
{
    # Validate that this appears to be a Windows setup drive
    $setupValidation = Test-WindowsSetupDrive -DriveLetter $usbDriveLetter.DriveLetter
    if ($setupValidation.IsWindowsSetup)
    {
        Write-Host "Confirmed: Drive $($usbDriveLetter.DriveLetter) appears to be a Windows setup drive (confidence: $($setupValidation.Confidence))"
        Write-Log -LogFile $logFile -Message "Confirmed: Drive $($usbDriveLetter.DriveLetter) appears to be a Windows setup drive (confidence: $($setupValidation.Confidence))" -Module $scriptName -LogLevel "Information"
    }
    else
    {
        Write-Warning "Drive $($usbDriveLetter.DriveLetter) does not appear to contain Windows setup files (score: $($setupValidation.Score)). Proceeding anyway..."
        Write-Log -LogFile $logFile -Message "Drive $($usbDriveLetter.DriveLetter) does not appear to contain Windows setup files (score: $($setupValidation.Score)). Proceeding anyway..." -Module $scriptName -LogLevel "Warning"
    }
    
    $scriptsFolder = "$($usbDriveLetter.DriveLetter):\$scriptsFolder"
    Write-Host "Checking whether scripts folder exists at $scriptsFolder"
    if (Test-Path $scriptsFolder)
    {
        Write-Host "Script folder found.  " -NoNewline
        Write-Host "Changing location to scripts folder: $scriptsFolder"
        try 
        {
            Push-Location -Path $scriptsFolder
            Write-Log -LogFile $logFile -Message "Changed location to scripts folder: $scriptsFolder" -Module $scriptName -LogLevel "Information"
            Write-Host "Current location is now: $(Get-Location)"
            if ($EmitFinalPath)
            {
                Write-Host "FINALPATH:$(Get-Location)" 
            }
            Start-Process -FilePath $env:ComSpec -ArgumentList "/c `"main.exe`"" -WorkingDirectory (Get-Location) -WindowStyle Maximized -Wait
            Pop-Location
        }
        catch
        {
            Write-Warning "Failed to change location to scripts folder at $($scriptsFolder): $_"
            Write-Log -LogFile $logFile -Message "Failed to change location to scripts folder at $($scriptsFolder): $_" -Module $scriptName -LogLevel "Error"
            exit 1
        }
    }
    else
    {
        Write-Warning "Scripts folder not found at $scriptsFolder"
        Write-Log -LogFile $logFile -Message "Scripts folder not found at $scriptsFolder" -Module $scriptName -LogLevel "Warning"
        
        # Provide helpful information about what was found on the drive
        $driveRoot = "$($usbDriveLetter.DriveLetter):\"
        if (Test-Path $driveRoot)
        {
            $rootContents = Get-ChildItem $driveRoot -ErrorAction SilentlyContinue | Select-Object -First 10 -ExpandProperty Name
            if ($rootContents)
            {
                Write-Host "Contents found in drive root: $($rootContents -join ', ')"
                Write-Log -LogFile $logFile -Message "Contents found in drive root: $($rootContents -join ', ')" -Module $scriptName -LogLevel "Information"
            }
        }
    }
}
else
{
    Write-Warning "No USB drive found."
}

Write-Log -LogFile $logFile -FinishLogging

exit 0