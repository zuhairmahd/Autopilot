[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\settings.json",
    [int]$maxWaitTime,
    [int]$timeInSeconds,
    [String] $GroupTag,
    [switch]$Reconfigure,
    [switch]$ReInitialize,
    [switch]$Update,
    [switch]$showLicenseBanner,
    [switch]$showAuth,
    [switch]$showSettings,
    [switch]$SecureString,
    [switch]$ForceNewToken,
    [parameter(parameterSetName = 'Deligated')]
    [switch]$Deligated,
    [parameter(parameterSetName = 'Deligated')]
    [switch]$ForceNewRefreshToken,
    [parameter(parameterSetName = 'Deligated')]
    [switch]$NoSaveRefreshToken,
    [parameter(parameterSetName = 'Deligated')]
    [string]$Scope,
    [parameter(parameterSetName = 'Deligated')]
    [ValidateSet('PublicAuthFlow', 'Interactive', 'Private')]
    [string]$AuthType,
    [ValidateSet('file', 'memory')]
    [string]$CacheType,
    [ValidateSet('github', 'gitlab')]
    [string]$Repo,  
    [string]$Release,
    [ValidateSet('full', 'helpDesk', 'registration')]
    [string]$appMode,
    [string]$LogFile = "$pwd\Logs\Autopilot.log",
    [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug')]
    [string]$LogLevel = 'Information'
)



#region Initialize script
$scriptName = $MyInvocation.MyCommand.Name
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
            Write-Host $separatorLine
            
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
                        Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue 
                    }
                    "Warning"
                    {
                        Write-Warning "[$Module] $Message" 
                    }
                    "Verbose"
                    {
                        Write-Verbose "[$Module] $Message" 
                    }
                    "Debug"
                    {
                        Write-Debug "[$Module] $Message" 
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
            $logEntry = "$timestamp [$LogLevel] [$Module] [Thread:$thread] $Message"
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
                Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue 
            }
            "Warning"
            {
                Write-Warning "[$Module] $Message" 
            }
            "Verbose"
            {
                Write-Verbose "[$Module] $Message" 
            }
            "Debug"
            {
                Write-Debug "[$Module] $Message" 
            }
            default
            {
                Write-Verbose "Logged: $logEntry" 
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

# Set global log level for all Write-Log calls
$Global:MinimumLogLevel = $LogLevel
Write-Log -LogFile $LogFile -StartLogging
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
{
    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Write-Verbose "[$scriptName] Running as an external script."
    Write-Verbose "[$scriptName] Script path: $ScriptPath"
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Running as an external script." -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Script path: $ScriptPath" -LogLevel "Information"
}
else
{
    Write-Verbose "[$scriptName] Running as a script block."
    $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    Write-Verbose "[$scriptName] Script path: $ScriptPath"
    if (!$ScriptPath)
    {
        $scriptName = 'main.exe'
        Write-Verbose "[$scriptName] Script path is not set. Defaulting to current directory: $pwd"
        $ScriptPath = "$PWD"
        Write-Verbose "[$scriptName] Default script path: $ScriptPath"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Script path is not set. Defaulting to current directory: $pwd" -LogLevel "Information"
        $fullScriptPath = "$scriptPath\$scriptName"
        Write-Verbose "[$scriptName] Full script path: $fullScriptPath"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Full script path: $fullScriptPath" -LogLevel "Information"
    }
}

function Clear-SecureMemory
{
    <#
    .SYNOPSIS
    Clears sensitive data from memory and forces garbage collection.
    
    .DESCRIPTION
    This function helps ensure sensitive data like passwords and encryption keys
    are properly cleared from memory and garbage collected.
    
    .PARAMETER Variables
    Array of variable names to clear from memory.
    
    .PARAMETER ClearScriptVariables
    If specified, also clears script-level temporary encryption variables.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Variables = @(),
        [switch]$ClearScriptVariables
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting secure memory cleanup operation" -LogLevel "Debug"
    Write-Verbose "[$functionName] Clearing sensitive data from memory"
    
    $clearedVariables = @()
    
    # Clear specified variables
    foreach ($varName in $Variables)
    {
        if (Get-Variable -Name $varName -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name $varName -Force -ErrorAction SilentlyContinue
            $clearedVariables += $varName
            Write-Verbose "[$functionName] Cleared variable: $varName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared variable from memory" -LogLevel "Debug"
        }
    }
    
    # Clear script-level variables only if explicitly requested
    if ($ClearScriptVariables)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Clearing script-level encryption variables" -LogLevel "Debug"
        
        if (Get-Variable -Name "TempEncryptedConfig" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "TempEncryptedConfig" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Verbose "[$functionName] Cleared script variable: TempEncryptedConfig"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: TempEncryptedConfig" -LogLevel "Debug"
        }
        
        if (Get-Variable -Name "TempEncryptionKey" -Scope Script -ErrorAction SilentlyContinue)
        {
            Remove-Variable -Name "TempEncryptionKey" -Scope Script -Force -ErrorAction SilentlyContinue
            Write-Verbose "[$functionName] Cleared script variable: TempEncryptionKey"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared script variable: TempEncryptionKey" -LogLevel "Debug"
        }
    }
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    Write-Verbose "[$functionName] Memory cleanup completed"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Memory cleanup completed successfully. Variables cleared: $($clearedVariables.Count)" -LogLevel "Debug"
}

function Get-SecurePassword
{
    <#
    .SYNOPSIS
    Prompts the user for a secure password with confirmation.
    
    .DESCRIPTION
    This function prompts the user to enter a password securely, with an optional confirmation prompt.
    The password is returned as a SecureString for security.
    
    .PARAMETER Message
    The message to display to the user when prompting for the password.
    
    .PARAMETER RequireConfirmation
    If specified, the user will be prompted to confirm their password.
    
    .PARAMETER MinLength
    The minimum length required for the password (default: 8).
    
    .OUTPUTS
    Returns the password as a SecureString.
    
    .EXAMPLE
    $password = Get-SecurePassword -Message "Enter your encryption password" -RequireConfirmation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$RequireConfirmation,
        [int]$MinLength = 8
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting secure password prompt. RequireConfirmation: $RequireConfirmation, MinLength: $MinLength" -LogLevel "Debug"
    Write-Verbose "[$functionName] Prompting user for secure password"
    
    $attemptCount = 0
    do
    {
        $attemptCount++
        $validPassword = $true
        Write-Log -LogFile $LogFile -Module $functionName -Message "Password prompt attempt $attemptCount" -LogLevel "Debug"
        
        $password = Read-Host -Prompt $Message -AsSecureString
        
        # Convert to plain text temporarily for validation
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        
        # Validate password length
        if ($plainPassword.Length -lt $MinLength)
        {
            Write-Host "Password must be at least $MinLength characters long. Please try again." -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "Password validation failed: insufficient length" -LogLevel "Warning"
            $validPassword = $false
            continue
        }
        
        # Confirm password if required
        if ($RequireConfirmation)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting for password confirmation" -LogLevel "Debug"
            $confirmPassword = Read-Host -Prompt "Confirm password" -AsSecureString
            $plainConfirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
            
            if ($plainPassword -ne $plainConfirmPassword)
            {
                Write-Host "Passwords do not match. Please try again." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $functionName -Message "Password confirmation failed: passwords do not match" -LogLevel "Warning"
                $validPassword = $false
                continue
            }
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Password confirmation successful" -LogLevel "Debug"
        }
        
        # Clear plain text passwords from memory
        $plainPassword = $null
        if ($plainConfirmPassword)
        {
            $plainConfirmPassword = $null
        }
        
    } while (-not $validPassword)
    
    Write-Verbose "[$functionName] Password obtained successfully"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Secure password obtained successfully after $attemptCount attempts" -LogLevel "Information"
    return $password
}

function Get-DecryptedConfigValue
{
    <#
    .SYNOPSIS
    Retrieves a configuration value from the temporarily encrypted configuration.
    
    .DESCRIPTION
    This function decrypts the temporary configuration and retrieves a specific value.
    This is used during runtime to access configuration values without keeping them in plain text.
    
    .PARAMETER PropertyPath
    The path to the property to retrieve (e.g., "auth.AppId").
    
    .OUTPUTS
    Returns the decrypted configuration value.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving config value for path: $PropertyPath" -LogLevel "Debug"
    Write-Verbose "[$functionName] Retrieving config value for path: $PropertyPath"
    
    if (-not $script:TempEncryptedConfig -or -not $script:TempEncryptionKey)
    {
        Write-Error "No temporary encrypted configuration available"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No temporary encrypted configuration available" -LogLevel "Error"
        return $null
    }
    
    # Create a temporary file to decrypt
    $tempFile = [System.IO.Path]::GetTempFileName()
    Write-Log -LogFile $LogFile -Module $functionName -Message "Created temporary file for decryption" -LogLevel "Debug"
    
    try
    {
        Set-Content -Path $tempFile -Value $script:TempEncryptedConfig -Encoding UTF8
        
        # Decrypt the content
        $decryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $script:TempEncryptionKey -Decrypt -InMemoryOnly
        
        if ($decryptResult.Success)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully decrypted configuration for property access" -LogLevel "Debug"
            $config = ConvertFrom-Json $decryptResult.Content
            
            # Navigate the property path
            $pathParts = $PropertyPath.Split('.')
            $current = $config
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Navigating property path with $($pathParts.Length) segments" -LogLevel "Debug"
            
            foreach ($part in $pathParts)
            {
                if ($current.PSObject.Properties.Name -contains $part)
                {
                    $current = $current.$part
                }
                else
                {
                    Write-Verbose "[$functionName] Property path '$PropertyPath' not found in configuration"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Property path '$PropertyPath' not found in configuration" -LogLevel "debug"
                    return $null
                }
            }
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully retrieved configuration value for path: $PropertyPath" -LogLevel "Debug"
            return $current
        }
        else
        {
            Write-Error "Failed to decrypt temporary configuration: $($decryptResult.ErrorMessage)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decrypt temporary configuration: $($decryptResult.ErrorMessage)" -LogLevel "Error"
            return $null
        }
    }
    finally
    {
        # Clean up temporary file
        if (Test-Path $tempFile)
        {
            Remove-Item $tempFile -Force
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleaned up temporary file" -LogLevel "Debug"
        }
    }
}

function Get-AuthConfigValue
{
    <#
    .SYNOPSIS
    Retrieves an authentication configuration value from the init file.
    
    .DESCRIPTION
    This function retrieves authentication configuration values from the script-level $Auth variable
    which is loaded from the init file.
    
    .PARAMETER PropertyPath
    The path to the property to retrieve (e.g., "scope", "authType").
    
    .EXAMPLE
    Get-AuthConfigValue -PropertyPath "scope"
    
    .EXAMPLE
    Get-AuthConfigValue -PropertyPath "authType"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Retrieving auth config value for path: $PropertyPath"
    
    if (-not $script:Auth)
    {
        Write-Error "No auth configuration available"
        return $null
    }
    
    # Navigate the property path
    $pathParts = $PropertyPath.Split('.')
    $current = $script:Auth
    
    foreach ($part in $pathParts)
    {
        if ($current.ContainsKey($part))
        {
            $current = $current[$part]
        }
        else
        {
            Write-Verbose "[$functionName] Property path '$PropertyPath' not found in auth configuration"
            return $null
        }
    }
    
    return $current
}

function ConvertFrom-SecureString-ToPlainText
{
    <#
    .SYNOPSIS
    Converts a SecureString to plain text.
    
    .DESCRIPTION
    This function converts a SecureString to plain text for use in encryption operations.
    The plain text should be cleared from memory as soon as possible after use.
    
    .PARAMETER SecureString
    The SecureString to convert.
    
    .OUTPUTS
    Returns the plain text string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [SecureString]$SecureString
    )
    
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
}

function Test-FileEncryptionStatus
{
    <#
    .SYNOPSIS
    Tests whether a JSON file is encrypted or not.
    
    .DESCRIPTION
    This function examines a file to determine if it contains encrypted content.
    It checks if the file content is valid Base64 (indicating encryption) or valid JSON (indicating unencrypted).
    
    .PARAMETER FilePath
    The path to the file to check.
    
    .OUTPUTS
    Returns a hashtable with the following properties:
    - IsEncrypted: Boolean indicating if the file is encrypted
    - IsValidFile: Boolean indicating if the file exists and is readable
    - FileContent: The raw content of the file (for debugging)
    - ErrorMessage: Any error encountered during the check
    
    .EXAMPLE
    $status = Test-FileEncryptionStatus -FilePath "C:\config.json"
    if ($status.IsEncrypted) {
        Write-Host "File is encrypted"
    } else {
        Write-Host "File is not encrypted"
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting file encryption status check for: $FilePath" -LogLevel "Debug"
    Write-Verbose "[$functionName] Checking encryption status of file: $FilePath"
    
    # Initialize result object
    $result = @{
        IsEncrypted  = $false
        IsValidFile  = $false
        FileContent  = $null
        ErrorMessage = $null
    }
    
    try
    {
        # Check if file exists
        if (-not (Test-Path $FilePath))
        {
            $result.ErrorMessage = "File does not exist: $FilePath"
            Write-Verbose "[$functionName] File not found: $FilePath"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File not found: $FilePath" -LogLevel "Error"
            return $result
        }
        
        # Read file content
        $fileContent = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
        $result.FileContent = $fileContent
        $result.IsValidFile = $true
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully read file. Content length: $($fileContent.Length) characters" -LogLevel "Debug"
        
        if ([string]::IsNullOrWhiteSpace($fileContent))
        {
            $result.ErrorMessage = "File is empty or contains only whitespace"
            Write-Verbose "[$functionName] File is empty: $FilePath"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is empty or contains only whitespace" -LogLevel "Warning"
            return $result
        }
        
        Write-Verbose "[$functionName] File content length: $($fileContent.Length) characters"
        
        # First, try to parse as JSON (unencrypted)
        try
        {
            $null = ConvertFrom-Json $fileContent -ErrorAction Stop
            $result.IsEncrypted = $false
            Write-Verbose "[$functionName] File contains valid JSON - not encrypted"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File contains valid JSON - not encrypted" -LogLevel "Debug"
            return $result
        }
        catch
        {
            Write-Verbose "[$functionName] File is not valid JSON, checking if it's encrypted..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is not valid JSON, checking if it's encrypted" -LogLevel "Debug"
        }
        
        # If not JSON, check if it's Base64 encoded (encrypted)
        try
        {
            $decodedBytes = [Convert]::FromBase64String($fileContent.Trim())
            if ($decodedBytes.Length -ge 16)
            {
                # Minimum size for IV + some encrypted content
                $result.IsEncrypted = $true
                Write-Verbose "[$functionName] File contains valid Base64 with sufficient length - appears encrypted"
                Write-Log -LogFile $LogFile -Module $functionName -Message "File contains valid Base64 with sufficient length - appears encrypted" -LogLevel "Debug"
                return $result
            }
            else
            {
                $result.ErrorMessage = "File appears to be Base64 but is too short to be properly encrypted"
                Write-Verbose "[$functionName] Base64 data too short for encryption"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Base64 data too short for encryption" -LogLevel "Warning"
                return $result
            }
        }
        catch
        {
            $result.ErrorMessage = "File is neither valid JSON nor valid Base64 - unknown format"
            Write-Verbose "[$functionName] File is not valid Base64 either: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is neither valid JSON nor valid Base64 - unknown format" -LogLevel "Warning"
            return $result
        }
    }
    catch
    {
        $result.ErrorMessage = "Error reading file: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Error reading file: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error reading file: $($_.Exception.Message)" -LogLevel "Error"
        return $result
    }
}

function Invoke-JsonFileEncryption
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        [Parameter(Mandatory = $false)]
        [switch]$Decrypt,
        [Parameter(Mandatory = $false)]
        [switch]$BackupOriginal,
        [Parameter(Mandatory = $false)]
        [switch]$InMemoryOnly
    )

    $functionName = $MyInvocation.MyCommand.Name
    $operationMode = if ($Decrypt) { 'DECRYPT' } else { 'ENCRYPT' }
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting JSON file encryption/decryption operation" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: $operationMode" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "File path: $FilePath" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Backup original: $BackupOriginal" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module $functionName -Message "In-memory only: $InMemoryOnly" -LogLevel "Debug"
    
    Write-Verbose "[$functionName] =========================================="
    Write-Verbose "[$functionName] Starting JSON file encryption/decryption operation"
    Write-Verbose "[$functionName] =========================================="
    Write-Verbose "[$functionName] File path: $FilePath"
    Write-Verbose "[$functionName] Operation mode: $operationMode"
    Write-Verbose "[$functionName] Backup original: $BackupOriginal"
    Write-Verbose "[$functionName] In-memory only: $InMemoryOnly"
    Write-Verbose "[$functionName] PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Verbose "[$functionName] Current user: $env:USERNAME"
    Write-Verbose "[$functionName] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Initialize variables for error handling and cleanup
    $operationStartTime = $null
    $aes = $null
    $sha256 = $null
    $encryptor = $null
    $decryptor = $null
    
    try
    {
        # Validate file exists and is accessible
        Write-Log -LogFile $LogFile -Module $functionName -Message "Validating file existence and accessibility" -LogLevel "Debug"
        Write-Verbose "[$functionName] Validating file existence and accessibility..."
        if (-not (Test-Path $FilePath))
        {
            Write-Host "CRITICAL ERROR: File not found at path '$FilePath'. `n Please verify that The file path is correct `n - The file exists, `n and that You have read permissions to the file. `n `n"
            Write-Verbose "[$functionName] File validation failed: File does not exist"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File validation failed: File does not exist at path '$FilePath'" -LogLevel "Error"
        }
    
        # Check file accessibility
        try
        {
            $fileInfo = Get-Item $FilePath -ErrorAction Stop
            Write-Verbose "[$functionName] File found successfully:"
            Write-Verbose "[$functionName] Full name: $($fileInfo.FullName)"
            Write-Verbose "[$functionName] Size: $($fileInfo.Length) bytes"
            Write-Verbose "[$functionName] Last modified: $($fileInfo.LastWriteTime)"
            Write-Verbose "[$functionName] Is read-only: $($fileInfo.IsReadOnly)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File found successfully. Size: $($fileInfo.Length) bytes" -LogLevel "Debug"
        }
        catch
        {
            $errorMsg = "CRITICAL ERROR: Cannot access file '$FilePath'."
            $errorMsg += "`nError details: $($_.Exception.Message)"
            $errorMsg += "`nPlease verify you have the necessary permissions to access this file."
            Write-Host $errorMsg
            Write-Verbose "[$functionName] File accessibility check failed: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File accessibility check failed: $($_.Exception.Message)" -LogLevel "Error"
            return @{
                Success      = $false
                Content      = $null
                Operation    = $operationMode
                InMemoryOnly = $InMemoryOnly
                ErrorMessage = $errorMsg
            }
        }        

        # Get absolute path
        $FilePath = Resolve-Path $FilePath
        Write-Verbose "[$functionName] File path resolved to: $FilePath"
        Write-Verbose "[$functionName] File validation completed successfully"
        Write-Log -LogFile $LogFile -Module $functionName -Message "File validation completed successfully" -LogLevel "Debug"
        $operationStartTime = Get-Date
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Starting main processing at $($operationStartTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] =========================================="
        Write-Log -LogFile $LogFile -Module $functionName -Message "Starting main processing" -LogLevel "Debug"
    
        # Create backup if requested
        if ($BackupOriginal)
        {
            Write-Verbose "[$functionName] Backup requested... creating backup copy..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Creating backup copy" -LogLevel "Information"
            $backupPath = "$FilePath.bak"
            Write-Verbose "[$functionName] Backup destination: $backupPath"
            try
            {
                Copy-Item $FilePath $backupPath -Force -ErrorAction Stop
                $backupInfo = Get-Item $backupPath
                Write-Verbose "[$functionName] Backup created successfully:"
                Write-Verbose "[$functionName] - Backup path: $($backupInfo.FullName)"
                Write-Verbose "[$functionName] - Backup size: $($backupInfo.Length) bytes"
                Write-Verbose "[$functionName] - Backup timestamp: $($backupInfo.CreationTime)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Backup created successfully. Size: $($backupInfo.Length) bytes" -LogLevel "Information"
            }
            catch
            {
                Write-Verbose "[$functionName] Backup creation failed: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Backup creation failed: $($_.Exception.Message)" -LogLevel "Error"
            }
        }
        else
        {
            Write-Verbose "[$functionName] No backup requested - proceeding without backup. The original file will be overwritten if the operation succeeds."
            Write-Verbose "[$functionName] Consider using -BackupOriginal for safer operations, especially on sensitive or production files."
            Write-Log -LogFile $LogFile -Module $functionName -Message "No backup requested - proceeding without backup" -LogLevel "Debug"
        }
    
        # Read file content
        Write-Verbose "[$functionName] Reading source file content..."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Reading source file content" -LogLevel "Debug"
        try
        {
            $fileContent = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "[$functionName] File content read successfully:"
            Write-Verbose "[$functionName] Content length: $($fileContent.Length) characters"
            Write-Verbose "[$functionName] First 100 characters: $($fileContent.Substring(0, [Math]::Min(100, $fileContent.Length)))"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File content read successfully. Length: $($fileContent.Length) characters" -LogLevel "Debug"
        }
        catch
        {
            Write-Verbose "[$functionName] File read failed: $($_.Exception.Message)"
            $errorMsg = "CRITICAL ERROR: Failed to read file '$FilePath'."
            Write-Host $errorMsg
            Write-Log -LogFile $LogFile -Module $functionName -Message "File read failed: $($_.Exception.Message)" -LogLevel "Error"
            return @{
                Success      = $false
                Content      = $null
                Operation    = $operationMode
                InMemoryOnly = $InMemoryOnly
                ErrorMessage = $errorMsg
            }
        }
        if ([string]::IsNullOrEmpty($fileContent))
        {
            $warningMsg = "WARNING: File appears to be empty: $FilePath"
            Write-Verbose $warningMsg
            Write-Warning $warningMsg
            Write-Warning "No operation will be performed on empty file."
            Write-Log -LogFile $LogFile -Module $functionName -Message "File appears to be empty - no operation performed" -LogLevel "Warning"
            return @{
                Success      = $false
                Content      = $null
                Operation    = $operationMode
                InMemoryOnly = $InMemoryOnly
                ErrorMessage = $warningMsg
            }
        }
    
        # Initialize cryptographic components
        Write-Verbose "[$functionName] Initializing cryptographic components..."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Initializing cryptographic components (AES-256)" -LogLevel "Debug"
        Write-Verbose "[$functionName] Setting up AES encryption with the following parameters:"
        Write-Verbose "[$functionName] Algorithm: AES (Advanced Encryption Standard)"
        Write-Verbose "[$functionName] Key size: 256 bits"
        Write-Verbose "[$functionName] Mode: CBC (Cipher Block Chaining)"
        Write-Verbose "[$functionName] Padding: PKCS7"
        $aes = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        Write-Verbose "[$functionName] AES provider initialized successfully"
    
        # Create 256-bit key from the provided string using SHA256
        Write-Verbose "[$functionName] Generating 256-bit encryption key from user-provided string..."
        Write-Verbose "[$functionName] Input key length: $($Key.Length) characters"
        Write-Verbose "[$functionName] Using SHA256 hash algorithm for key derivation"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Generating 256-bit encryption key using SHA256" -LogLevel "Debug"
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $keyBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Key))
        $aes.Key = $keyBytes
        Write-Verbose "[$functionName] Encryption key generated successfully:"
        $first8 = $keyBytes[0..7] | ForEach-Object { '{0:X2}' -f $_ }
        Write-Verbose ("Key hash (first 8 bytes): {0}" -f ($first8 -join ''))
        Write-Verbose "[$functionName] Key length: $($keyBytes.Length) bytes"
    
        if ($Decrypt)
        {
            Write-Verbose "[$functionName] =========================================="
            Write-Verbose "[$functionName] STARTING DECRYPTION PROCESS"
            Write-Verbose "[$functionName] =========================================="
            # Pre-decryption validation
            Write-Verbose "[$functionName] Performing pre-decryption validation checks..."
        
            # Check if content looks like encrypted data (base64)
            Write-Verbose "[$functionName] Validating encrypted data format..."
            try
            {
                $encryptedData = [Convert]::FromBase64String($fileContent)
                Write-Verbose "[$functionName] File content is valid base64 format"
                Write-Verbose "[$functionName] Base64 string length: $($fileContent.Length) characters"
                Write-Verbose "[$functionName] Decoded data length: $($encryptedData.Length) bytes"
            }
            catch
            {
                Write-Verbose "[$functionName] Base64 validation failed: $($_.Exception.Message)"
                Write-Host "DECRYPTION ERROR: The file content is not valid base64 encoded data."
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "The file content is not valid base64 encoded data."
                }
            }
            # Validate encrypted data structure
            Write-Verbose "[$functionName] Validating encrypted data structure..."
            if ($encryptedData.Length -lt 16)
            {
                $errorMsg = "DECRYPTION ERROR: Encrypted data is corrupted or invalid."
                $errorMsg += "`n`nData structure analysis:"
                $errorMsg += "`n Minimum expected size: 16 bytes (IV) + encrypted content"
                $errorMsg += "`n Actual size: $($encryptedData.Length) bytes"
                $errorMsg += "`n`nThis indicates the encrypted file is corrupted or was not properly encrypted."
                Write-Verbose "[$functionName] Encrypted data structure validation failed: Data too short"
                Write-Host $errorMsg
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = $errorMsg
                }
            }
            # Extract IV and encrypted content
            Write-Verbose "[$functionName] Extracting initialization vector (IV) and encrypted content..."
            $iv = $encryptedData[0..15]
            $encryptedContent = $encryptedData[16..($encryptedData.Length - 1)]
            $aes.IV = $iv
            Write-Verbose "[$functionName] Data structure analysis:"
            $first16 = $iv | ForEach-Object { '{0:X2}' -f $_ }
            Write-Verbose "[$functionName] - IV (first 16 bytes): $($first16 -join '')"
            Write-Verbose "[$functionName] - IV length: $($iv.Length) bytes"
            Write-Verbose "[$functionName] - Encrypted content length: $($encryptedContent.Length) bytes"
            Write-Verbose "[$functionName] Total encrypted data: $($encryptedData.Length) bytes"
            Write-Verbose "[$functionName] Beginning AES decryption process..."
        
            # Attempt decryption
            try
            {
                $decryptor = $aes.CreateDecryptor()
                Write-Verbose "[$functionName] AES decryptor created successfully"
                Write-Verbose "[$functionName] Decrypting content block..."
                $decryptedBytes = $decryptor.TransformFinalBlock($encryptedContent, 0, $encryptedContent.Length)
                Write-Verbose "[$functionName] Decryption completed without cryptographic errors"
                Write-Verbose "[$functionName] Decrypted data length: $($decryptedBytes.Length) bytes"
                $decryptedText = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                Write-Verbose "[$functionName] Decrypted bytes converted to UTF-8 string successfully"
                Write-Verbose "[$functionName] Decrypted text length: $($decryptedText.Length) characters"
            }
            catch [System.Security.Cryptography.CryptographicException]
            {
                Write-Host "`n`nThe decryption key you provided does not match the key used to encrypt this file."
                Write-Verbose "[$functionName] Decryption failed with CryptographicException (likely wrong key): $($_.Exception.Message)"
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "The decryption key you provided does not match the key used to encrypt this file."
                }
            }
            catch
            {
                Write-Host "DECRYPTION ERROR: Unexpected error during decryption process."
                Write-Verbose "[$functionName] `n`nError type: $($_.Exception.GetType().Name)"
                Write-Verbose "[$functionName] `nError details: $($_.Exception.Message)"
                Write-Host "`n`nThis may indicate:"
                Write-Host "`n File corruption"
                Write-Host "`n Incompatible encryption method"
                Write-Host "`n - System cryptography issue"
                Write-Verbose "[$functionName] Decryption failed with unexpected error: $($_.Exception.Message)"
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "Unexpected error during decryption process: $($_.Exception.Message)"
                }
            }
        
            # Validate decrypted content is valid JSON
            Write-Verbose "[$functionName] Validating decrypted content format..."
            try
            {
                $null = ConvertFrom-Json $decryptedText -ErrorAction Stop
                Write-Verbose "[$functionName] Decrypted content is valid JSON"
                Write-Verbose "[$functionName] JSON validation successful"
                Write-Verbose "[$functionName] Content preview: $($decryptedText.Substring(0, [Math]::Min(200, $decryptedText.Length)))"
            }
            catch
            {
                Write-Host "DECRYPTION ERROR: Decrypted content is not valid JSON."
                Write-Host "⚠️ POSSIBLE INCORRECT DECRYPTION KEY"
                Write-Host "`nThe decryption process completed, but the result is not valid JSON."
                Write-Host "`nThis strongly suggests the wrong decryption key was used."
                if ($null -ne $decryptedText)
                {
                    Write-Verbose "[$functionName] Decrypted content preview:"
                    Write-Verbose "[$functionName] `n$($decryptedText.Substring(0, [Math]::Min(300, $decryptedText.Length)))"
                    if ($decryptedText.Length -gt 300)
                    {
                        Write-Verbose "[$functionName] `n... (truncated)" 
                    }
                }
                Write-Verbose "[$functionName] Expected: Valid JSON data"
                Write-Verbose "[$functionName] Actual: Garbled or corrupted text"
                Write-Verbose "[$functionName] JSON validation failed after decryption: $($_.Exception.Message)"
                return @{
                    Success      = $false
                    Content      = $decryptedText
                    Operation    = "Decrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = "Decrypted content is not valid JSON - possible incorrect decryption key"
                }
            }
        
            # Write decrypted content back to file or return it
            if ($InMemoryOnly)
            {
                Write-Verbose "[$functionName] In-memory mode: returning decrypted content without writing to disk"
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] DECRYPTION COMPLETED SUCCESSFULLY (IN-MEMORY)"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] Decrypted content length: $($decryptedText.Length) characters"
                
                # Return both success status and decrypted content
                return @{
                    Success      = $true
                    Content      = $decryptedText
                    Operation    = "Decrypt"
                    InMemoryOnly = $true
                }
            }
            else
            {
                Write-Verbose "[$functionName] Writing decrypted content back to original file..."
                try
                {
                    Set-Content $FilePath -Value $decryptedText -Encoding UTF8 -NoNewline -ErrorAction Stop
                    Write-Verbose "[$functionName] Decrypted content written successfully"
                    # Verify the write operation
                    $verifyContent = Get-Content $FilePath -Raw -Encoding UTF8
                    if ($verifyContent -eq $decryptedText)
                    {
                        Write-Verbose "[$functionName] File write verification successful"
                    }
                    else
                    {
                        Write-Warning "File write verification failed - content may not have been written correctly"
                    }
                }
                catch
                {
                    $errorMsg = "CRITICAL ERROR: Failed to write decrypted content to file."
                    $errorMsg += "`nFile path: $FilePath"
                    $errorMsg += "`nError details: $($_.Exception.Message)"
                    $errorMsg += "`n`nThe decryption was successful, but the file could not be updated."
                    Write-Host $errorMsg
                    Write-Verbose "[$functionName] File write failed: $($_.Exception.Message)"
                    return @{
                        Success      = $false
                        Content      = $decryptedText
                        Operation    = "Decrypt"
                        InMemoryOnly = $false
                        ErrorMessage = $errorMsg
                    }
                }
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] DECRYPTION COMPLETED SUCCESSFULLY"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] Decryption completed in $([Math]::Round($operationDuration.TotalMilliseconds, 2)) ms"
            }
        }
        else
        {
            Write-Verbose "[$functionName] =========================================="
            Write-Verbose "[$functionName] STARTING ENCRYPTION PROCESS"
            Write-Verbose "[$functionName] =========================================="
            # Pre-encryption validation
            Write-Verbose "[$functionName] Performing pre-encryption validation checks..."
            # Validate that content is valid JSON before encrypting
            Write-Verbose "[$functionName] Validating JSON format of source content..."
            try
            {
                $jsonObject = ConvertFrom-Json $fileContent -ErrorAction Stop
                Write-Verbose "[$functionName] Source content is valid JSON"
                Write-Verbose "[$functionName] JSON validation successful"
                Write-Verbose "[$functionName] JSON object type: $($jsonObject.GetType().Name)"
                if ($jsonObject -is [PSCustomObject])
                {
                    $propertyCount = ($jsonObject | Get-Member -MemberType NoteProperty).Count
                    Write-Verbose "[$functionName] - JSON properties count: $propertyCount"
                }
            }
            catch
            {
                $errorMsg = "ENCRYPTION ERROR: Source file does not contain valid JSON data."
                $errorMsg += "`n`nJSON validation failed:"
                $errorMsg += "`n Error: $($_.Exception.Message)"
                $errorMsg += "`n Line: $($_.Exception.ItemName)"
                $errorMsg += "`n`nFile content preview:"
                $errorMsg += "`n$($fileContent.Substring(0, [Math]::Min(300, $fileContent.Length)))"
                if ($fileContent.Length -gt 300)
                {
                    $errorMsg += "`n... (truncated)" 
                }
                $errorMsg += "`n`nPlease ensure the file contains valid JSON before encryption."
                Write-Verbose "[$functionName] JSON validation failed: $($_.Exception.Message)"
                Write-Host $errorMsg 
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Encrypt"
                    InMemoryOnly = $false
                    ErrorMessage = $errorMsg
                }
            }
            # Generate random IV for this encryption
            Write-Verbose "[$functionName] Generating cryptographically secure random initialization vector (IV)..."
            $aes.GenerateIV()
            Write-Verbose "[$functionName] Random IV generated successfully"
            Write-Verbose "[$functionName] IV length: $($aes.IV.Length) bytes"
            $ivValue = $aes.IV | ForEach-Object { '{0:X2}' -f $_ }   
            Write-Verbose "[$functionName] IV value: $($ivValue -join '')"
            Write-Verbose "[$functionName] IV provides unique encryption for this session"
            Write-Verbose "[$functionName] Beginning AES encryption process..."
        
            # Encrypt the content
            try
            {
                $encryptor = $aes.CreateEncryptor()
                Write-Verbose "[$functionName] AES encryptor created successfully"
                $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
                Write-Verbose "[$functionName] Source content converted to bytes:"
                Write-Verbose "[$functionName] Original text length: $($fileContent.Length) characters"
                Write-Verbose "[$functionName] UTF-8 bytes length: $($contentBytes.Length) bytes"
                Write-Verbose "[$functionName] Encrypting content block..."
                $encryptedBytes = $encryptor.TransformFinalBlock($contentBytes, 0, $contentBytes.Length)
                Write-Verbose "[$functionName] Encryption completed successfully"
                Write-Verbose "[$functionName] Encrypted data length: $($encryptedBytes.Length) bytes"
            }
            catch
            {
                $errorMsg = "ENCRYPTION ERROR: Failed during AES encryption process."
                $errorMsg += "`nError details: $($_.Exception.Message)"
                $errorMsg += "`nError type: $($_.Exception.GetType().Name)"
                Write-Verbose "[$functionName] Encryption process failed: $($_.Exception.Message)"
                Write-Host $errorMsg
                return @{
                    Success      = $false
                    Content      = $null
                    Operation    = "Encrypt"
                    InMemoryOnly = $InMemoryOnly
                    ErrorMessage = $errorMsg
                }
            }
            # Combine IV and encrypted content for storage
            Write-Verbose "[$functionName] Preparing encrypted data for storage..."
            $combinedBytes = $aes.IV + $encryptedBytes
            Write-Verbose "[$functionName] Data structure for storage:"
            Write-Verbose "[$functionName] IV length: $($aes.IV.Length) bytes"
            Write-Verbose "[$functionName] Encrypted content length: $($encryptedBytes.Length) bytes"
            Write-Verbose "[$functionName] Total combined length: $($combinedBytes.Length) bytes"
        
            # Convert to base64 for safe text storage
            Write-Verbose "[$functionName] Converting encrypted data to base64 format..."
            $base64String = [Convert]::ToBase64String($combinedBytes)
            Write-Verbose "[$functionName] Base64 conversion completed"
            Write-Verbose "[$functionName] Base64 string length: $($base64String.Length) characters"
            Write-Verbose "[$functionName] Compression ratio: $([Math]::Round(($base64String.Length / $fileContent.Length) * 100, 2))% of original size"
        
            # Write encrypted content back to file or return it
            if ($InMemoryOnly)
            {
                Write-Verbose "[$functionName] In-memory mode: returning encrypted content without writing to disk"
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] ENCRYPTION COMPLETED SUCCESSFULLY (IN-MEMORY)"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] Encrypted content length: $($base64String.Length) characters"
                
                # Return both success status and encrypted content
                return @{
                    Success      = $true
                    Content      = $base64String
                    Operation    = "Encrypt"
                    InMemoryOnly = $true
                }
            }
            else
            {
                Write-Verbose "[$functionName] Writing encrypted content to original file..."
                try
                {
                    Set-Content $FilePath -Value $base64String -Encoding UTF8 -NoNewline -ErrorAction Stop
                    Write-Verbose "[$functionName] Encrypted content written successfully"
                    # Verify the write operation
                    $verifyContent = Get-Content $FilePath -Raw -Encoding UTF8
                    if ($verifyContent -eq $base64String)
                    {
                        Write-Verbose "[$functionName] File write verification successful"
                    }
                    else
                    {
                        Write-Warning "File write verification failed - content may not have been written correctly"
                    }
                }
                catch
                {
                    $errorMsg = "CRITICAL ERROR: Failed to write encrypted content to file."
                    $errorMsg += "`nFile path: $FilePath"
                    $errorMsg += "`nError details: $($_.Exception.Message)"
                    $errorMsg += "`n`nThe encryption was successful, but the file could not be updated."
                    Write-Verbose "[$functionName] File write failed: $($_.Exception.Message)"
                    Write-Host $errorMsg
                    return @{
                        Success      = $false
                        Content      = $base64String
                        Operation    = "Encrypt"
                        InMemoryOnly = $false
                        ErrorMessage = $errorMsg
                    }
                }
        
                $operationEndTime = Get-Date
                $operationDuration = $operationEndTime - $operationStartTime
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] ENCRYPTION COMPLETED SUCCESSFULLY"
                Write-Verbose "[$functionName] =========================================="
                Write-Verbose "[$functionName] Operation completed at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
                Write-Verbose "[$functionName] Total operation time: $($operationDuration.TotalMilliseconds) milliseconds"
                Write-Verbose "[$functionName] File '$FilePath' has been encrypted successfully."
                Write-Verbose "[$functionName] Encryption completed in $([Math]::Round($operationDuration.TotalMilliseconds, 2)) ms"    
            }
        }
    
        # Return success for non-in-memory operations
        return @{
            Success      = $true
            Content      = $null
            Operation    = $(if ($Decrypt) { "Decrypt" } else { "Encrypt" })
            InMemoryOnly = $false
        }
    }
    catch
    {
        $operationEndTime = Get-Date
        $operationDuration = if ($operationStartTime)
        {
            $operationEndTime - $operationStartTime 
        }
        else
        {
            [TimeSpan]::Zero 
        }
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] OPERATION FAILED"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Error occurred at: $($operationEndTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        Write-Verbose "[$functionName] Operation duration before failure: $($operationDuration.TotalMilliseconds) milliseconds"
        Write-Verbose "[$functionName] Error type: $($_.Exception.GetType().Name)"
        Write-Verbose "[$functionName] Error message: $($_.Exception.Message)"
        if ($_.Exception.InnerException)
        {
            Write-Verbose "[$functionName] Inner exception: $($_.Exception.InnerException.Message)"
        }
        # Log the full call stack for debugging
        Write-Verbose "[$functionName] Call stack:"
        $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Verbose "[$functionName] $_" }
        Write-Error "Operation failed: $($_.Exception.Message)"
                
        # If backup exists and operation failed, provide restoration guidance
        if ($BackupOriginal -and (Test-Path "$FilePath.bak"))
        {
            Write-Warning "BACKUP AVAILABLE: A backup file exists at '$FilePath.bak'"
            Write-Warning " You can restore the original file if needed using:"
            Write-Warning " Copy-Item '$FilePath.bak' '$FilePath' -Force"
        }
        return @{
            Success      = $false
            Content      = $null
            Operation    = $(if ($Decrypt) { "Decrypt" } else { "Encrypt" })
            InMemoryOnly = $InMemoryOnly
            ErrorMessage = "Operation failed: $($_.Exception.Message)"
        }
    }
    finally
    {
        # Clean up cryptographic objects
        Write-Verbose "[$functionName] Performing cleanup of cryptographic resources..."
                
        if ($null -ne $aes)
        {
            try
            {
                $aes.Dispose()
                Write-Verbose "[$functionName] ✓ AES encryption object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing AES object: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $sha256)
        {
            try
            {
                $sha256.Dispose()
                Write-Verbose "[$functionName] ✓ SHA256 hash object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing SHA256 object: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $encryptor)
        {
            try
            {
                $encryptor.Dispose()
                Write-Verbose "[$functionName] ✓ Encryptor object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing encryptor: $($_.Exception.Message)"
            }
        }
                
        if ($null -ne $decryptor)
        {
            try
            {
                $decryptor.Dispose()
                Write-Verbose "[$functionName] ✓ Decryptor object disposed successfully"
            }
            catch
            {
                Write-Verbose "[$functionName] ⚠️ Warning: Error disposing decryptor: $($_.Exception.Message)"
            }
        }
                
        # Force garbage collection to clear sensitive data from memory
        Write-Verbose "[$functionName] Forcing garbage collection to clear sensitive data..."
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-Verbose "[$functionName] Garbage collection completed"
        Write-Verbose "[$functionName] Resource cleanup completed"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] FUNCTION EXECUTION COMPLETED"
        Write-Verbose "[$functionName] =========================================="
        Write-Verbose "[$functionName] Function: Invoke-JsonFileEncryption"
        Write-Verbose "[$functionName] Completion timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')"
        Write-Verbose "[$functionName] All resources cleaned up successfully"
        Write-Verbose "[$functionName] Function execution finished"
    }
}
#endregion Initialize script

#region Load parameters from the configuration file if it exists
Write-Verbose "[$scriptName] Checking configuration file: $configFile"

# Check if the .secrets directory exists, create it if it doesn't
$secretsDir = Split-Path $configFile -Parent
if (-not (Test-Path $secretsDir))
{
    Write-Verbose "[$scriptName] Creating secrets directory: $secretsDir"
    New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
}

# Initialize variables for encryption handling
$configContent = $null
$userPassword = $null
$tempEncryptionKey = $null

if (Test-Path $configFile)
{
    # Check if the config file is encrypted
    $encryptionStatus = Test-FileEncryptionStatus -FilePath $configFile
    
    if (-not $encryptionStatus.IsValidFile)
    {
        Write-Host "Configuration file exists but cannot be read: $($encryptionStatus.ErrorMessage)" -ForegroundColor Red
        Write-Host "Please check file permissions and try again." -ForegroundColor Red
        exit 1
    }
    
    if ($encryptionStatus.IsEncrypted)
    {
        Write-Host "Please enter your password to continue." -ForegroundColor Cyan

        $maxRetries = 3
        $retryCount = 0
        $decryptResult = $null
        
        do
        {
            $retryCount++
            Write-Verbose "[$scriptName] Password attempt $retryCount of $maxRetries"
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Password attempt $retryCount of $maxRetries" -LogLevel "Debug"
            
            # Get the password from user
            $userPasswordSecure = Get-SecurePassword -Message "Enter your encryption password (Attempt $retryCount of $maxRetries)"
            $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
            
            # Decrypt the file in memory
            $decryptResult = Invoke-JsonFileEncryption -FilePath $configFile -Key $userPassword -Decrypt -InMemoryOnly
            
            if ($decryptResult.Success)
            {
                Write-Verbose "[$scriptName] Configuration file decrypted successfully."
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file decrypted successfully" -LogLevel "Information"
                $configContent = $decryptResult.Content
                break
            }
            else
            {
                Write-Host "Decryption failed: $($decryptResult.ErrorMessage)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Decryption failed: $($decryptResult.ErrorMessage)" -LogLevel "Error"
                if ($retryCount -lt $maxRetries)
                {
                    Write-Host "Please try again." -ForegroundColor Yellow
                }
            }
            
            # Clear the password from memory
            Clear-SecureMemory -Variables @("userPassword")
            
        } while ($retryCount -lt $maxRetries -and -not $decryptResult.Success)
        
        if (-not $decryptResult.Success)
        {
            Write-Host "Failed to decrypt configuration file after $maxRetries attempts." -ForegroundColor Red
            Write-Host "Please verify your password and try again." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to decrypt configuration file after $maxRetries attempts" -LogLevel "Error"
            Clear-SecureMemory -ClearScriptVariables
            exit 1
        }
        
        # Generate a temporary encryption key for in-memory use
        $tempEncryptionKey = [System.Guid]::NewGuid().ToString()
        Write-Verbose "[$scriptName] Generated temporary encryption key for in-memory operations"
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Generated temporary encryption key for in-memory operations" -LogLevel "Debug"
        
        # Re-encrypt the content with the temporary key for in-memory use
        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            Set-Content -Path $tempFile -Value $configContent -Encoding UTF8
            $tempEncryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $tempEncryptionKey -InMemoryOnly
            
            if ($tempEncryptResult.Success)
            {
                Write-Verbose "[$scriptName] Content re-encrypted with temporary key for in-memory use"
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Content re-encrypted with temporary key for in-memory use" -LogLevel "Debug"
                # Store the encrypted content for later use during the session
                $script:TempEncryptedConfig = $tempEncryptResult.Content
                $script:TempEncryptionKey = $tempEncryptionKey
            }
            else
            {
                Write-Warning "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)" -LogLevel "Error"
                # Continue without temporary encryption but with a warning
            }
        }
        catch
        {
            Write-Warning "Error during temporary encryption setup: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Error during temporary encryption setup: $($_.Exception.Message)" -LogLevel "Error"
        }
        finally
        {
            # Clean up temporary file
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Clear the user password from memory
        Clear-SecureMemory -Variables @("userPassword", "tempEncryptionKey")
    }
    else
    {
        # File is not encrypted - this is a first run scenario
        Write-Host "Configuration file is not encrypted. Setting up encryption..." -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file is not encrypted. Setting up encryption for first run" -LogLevel "Information"
        
        # Get password from user for first-time setup
        $userPasswordSecure = Get-SecurePassword -Message "Enter a password to encrypt your configuration file" -RequireConfirmation
        $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
        
        # Read the current config content
        $configContent = Get-Content -Path $configFile -Raw -Encoding UTF8
        
        # Encrypt the file on disk
        $encryptResult = Invoke-JsonFileEncryption -FilePath $configFile -Key $userPassword
        
        if ($encryptResult.Success)
        {
            Write-Host "Configuration file encrypted successfully." -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file encrypted successfully" -LogLevel "Information"
            
            # Generate a temporary encryption key for in-memory use
            $tempEncryptionKey = [System.Guid]::NewGuid().ToString()
            Write-Verbose "[$scriptName] Generated temporary encryption key for in-memory operations"
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Generated temporary encryption key for in-memory operations" -LogLevel "Debug"
            
            # Re-encrypt the content with the temporary key for in-memory use
            $tempFile = [System.IO.Path]::GetTempFileName()
            try
            {
                Set-Content -Path $tempFile -Value $configContent -Encoding UTF8
                $tempEncryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $tempEncryptionKey -InMemoryOnly
                
                if ($tempEncryptResult.Success)
                {
                    Write-Verbose "[$scriptName] Content re-encrypted with temporary key for in-memory use"
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Content re-encrypted with temporary key for in-memory use" -LogLevel "Debug"
                    # Store the encrypted content for later use during the session
                    $script:TempEncryptedConfig = $tempEncryptResult.Content
                    $script:TempEncryptionKey = $tempEncryptionKey
                }
                else
                {
                    Write-Warning "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)"
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)" -LogLevel "Error"
                    # Continue without temporary encryption but with a warning
                }
            }
            catch
            {
                Write-Warning "Error during temporary encryption setup: $($_.Exception.Message)"
            }
            finally
            {
                # Clean up temporary file
                if (Test-Path $tempFile)
                {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else
        {
            Write-Host "Failed to encrypt configuration file: $($encryptResult.ErrorMessage)" -ForegroundColor Red
            Clear-SecureMemory -ClearScriptVariables
            exit 1
        }
        
        # Clear the user password from memory
        Clear-SecureMemory -Variables @("userPassword", "tempEncryptionKey")
    }
    
    # Parse the configuration content
    $configJson = ConvertFrom-Json $configContent
    $domain = $configJson.domain
    
    # Clear the config content from memory
    $configContent = $null
}
else
{
    Write-Host "Configuration file $configFile not found." -ForegroundColor Yellow
    Write-Host "Please create a configuration file or run the script with the -Reconfigure parameter." -ForegroundColor Yellow
}
if (Test-Path -Path $InitFile)
{
    Write-Verbose "[$scriptName] Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
    $global:globalSettings = @{}
    $global:localSettings = @{}
    
    # Load the init file content
    $initFileContent = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    
    # Load auth configuration from init file
    $authConfiguration = $initFileContent.auth
    $auth = @{}
    Write-Verbose "[$scriptName] Loading Auth configuration from init file"
    foreach ($key in $authConfiguration.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $authConfiguration.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the init file as $($authConfiguration.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($authConfiguration.$key)"
            if ($authConfiguration.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($authConfiguration.$key)
                $auth.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($authConfiguration.$key))."
                $auth.add($key, $authConfiguration.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Got parameter $key from the commandline as $($PSBoundParameters[$key])"
            $auth.add($key, $PSBoundParameters[$key])
        }
    }
    
    # Set auth as a script variable so it can be accessed by functions
    $script:Auth = $auth
    
    $globalConfigData = $initFileContent | Select-Object -ExpandProperty 'globalSettings'
    Write-Verbose "[$scriptName] Reading global settings..."
    Write-Verbose "[$scriptName] Found $($globalConfigData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $globalConfigData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $globalConfigData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($globalConfigData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($globalConfigData.$key)"
            if ($globalConfigData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($globalConfigData.$key)
                $globalSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($globalConfigData.$key))."
                $globalSettings.add($key, $globalConfigData.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Got parameter $key from the commandline as $($PSBoundParameters[$key])"
            $globalSettings.add($key, $PSBoundParameters[$key])
        }
    }
    $localConfigData = ($initFileContent | Select-Object -ExpandProperty "domains").$domain
    Write-Verbose "[$scriptName] Reading local settings for domain $domain..."
    Write-Verbose "[$scriptName] Found $($localConfigData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $localConfigData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $localConfigData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($localConfigData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($localConfigData.$key)"
            if ($localConfigData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($localConfigData.$key)
                $localSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
                # Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($localConfigData.$key))."
                # Set-Variable -Name $key -Value $localConfigData.$key
                $localSettings.add($key, $localConfigData.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Read parameter $key from the commandline as $($PSBoundParameters[$key])"
            #add it to the local settings hashtable.
            $localSettings.add($key, $PSBoundParameters[$key])
        }
    }   
    #region handle scopes
    $basicScopes = (Get-Content -Path $initFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty 'requiredScopes')     
    $additionalScopes = (Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty "domains").$domain.additionalScopes
    # Ensure arrays are properly handled and merge them, eliminating duplicates
    Write-Verbose "[$scriptName] Merging basicScopes and additionalScopes and removing duplicates."
    # Initialize as empty arrays if null
    if ($null -eq $basicScopes) 
    { 
        Write-Verbose "[$scriptName] No basic scopes found in the configuration file. Initializing as empty array."
        $basicScopes = @() 
    }
    if ($null -eq $additionalScopes) 
    { 
        Write-Verbose "[$scriptName] No additional scopes found in the configuration file. Initializing as empty array."
        $additionalScopes = @() 
    }
    # Ensure they are arrays
    Write-Verbose "[$scriptName] Ensuring basicScopes and additionalScopes are arrays."
    $basicScopes = @($basicScopes)
    Write-Verbose "[$scriptName] Basic scopes has $($basicScopes.Count) items."
    $additionalScopes = @($additionalScopes)
    Write-Verbose "[$scriptName] Additional scopes has $($additionalScopes.Count) items."
    # Merge arrays and remove duplicates based on Scope property
    Write-Verbose "[$scriptName] Merging scopes and removing duplicates."
    $allScopes = @($basicScopes) + @($additionalScopes)
    Write-Verbose "[$scriptName] Total scopes before deduplication: $($allScopes.Count)"
    $requiredScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
    Write-Verbose "[$scriptName] Merged scopes - Total unique scopes: $($requiredScopes.Count)"
    #endregion handle scopes
}
else
{
    Write-Host "Configuration file $initFile not found. Using default values."
    # Set empty auth array to prevent errors
    $auth = @{}
    # Set auth as a script variable so it can be accessed by functions
    $script:Auth = $auth
}
#endregion Load parameters from the configuration file if it exists

#region import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "[$scriptName] Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "[$scriptName] Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}
#endregion import functions.

#region Define variables
$settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
if ($settings.Repo -eq 'github')
{
    Write-Verbose "[$scriptName] Using GitHub repository."
    $baseSourceURL = 'https://raw.githubusercontent.com'
    Write-Verbose "[$scriptName] Base source URL: $baseSourceURL"
    $baseURL = "https://www.github.com"
    Write-Verbose "[$scriptName] Base URL: $baseURL"
    $repoPath = 'zuhairmahd'
    Write-Verbose "[$scriptName] Repository path: $repoPath"
    $repoName = 'autopilot'
    Write-Verbose "[$scriptName] Repository name: $repoName"
    $defaultBranch = 'master'
    Write-Verbose "[$scriptName] Default branch: $defaultBranch"
    if ($settings.release -eq 'auto')
    {
        Write-Verbose "[$scriptName] Release is set to 'auto'. Fetching the latest release from GitHub."
        $latestRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
        Write-Verbose "[$scriptName] Latest release fetched: $latestRelease"
        if ($latestRelease)
        {
            Write-Verbose "[$scriptName] Successfully retrieved the latest release information from GitHub."
            Write-Host "Latest release: $latestRelease"
        }
        else
        {
            Write-Host 'Failed to retrieve the latest release information from GitHub.' -ForegroundColor Red
            Write-Host "Defaulting to $defaultBranch branch."
            $latestRelease = $defaultBranch
        }
    }
    else
    {
        Write-Verbose "[$scriptName] Using specified release: $($settings.release)"
        $latestRelease = $settings.release
    }
}
elseif ($settings.Repo -eq 'gitlab')
{
    $baseSourceURL = 'https://git.gao.gov'
    Write-Verbose "[$scriptName] Base source URL: $baseSourceURL"
    $baseURL = "https://git.gao.gov"
    Write-Verbose "[$scriptName] Base URL: $baseURL"
    $repoPath = 'mahmoudz'
    $repoName = 'autopilot-deployment'
    $repoId = '1031'
    $latestRelease = GetLatestGitlabRelease -RepositoryId $repoId
}
else
{
    Write-Host 'Invalid repository specified.'
    Write-Host 'Defaulting to the main branch from GitHub.'
    $latestRelease = $defaultBranch
}
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
Write-Verbose "[$scriptName] Remote version URL: $remoteVersionURL"
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
Write-Verbose "[$scriptName] Update URL: $updateURL"
$updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
$version = GetFileVersion -executableFileName "$scriptPath\$scriptName"
Write-Verbose "[$scriptName] Version: $version"
if (-not $version)
{
    Write-Verbose "[$scriptName] Unable to get file version. Defaulting to 1.0.0"
    $version = [System.Version]::Parse('1.0.0.0')
}
$groupsToInclude = $settings.groupsToInclude
Write-Verbose "[$scriptName] Groups to include: $($groupsToInclude | Out-String)"
$groupsToExclude = $settings.groupsToExclude
Write-Verbose "[$scriptName] Groups to exclude: $($groupsToExclude | Out-String)"
Write-Verbose "[$scriptName] Settings are as follows:"
foreach ($key in $settings.Keys)
{
    Write-Verbose "[$scriptName] $($key): $($settings[$key])"
    if ($showSettings)
    {
        Write-Host "Setting $($key): $($settings[$key])"
    }
}
Write-Verbose "[$scriptName] Auth configuration loaded from $configFile"
$getTokenParams = BuildAuthSplatTable -auth $auth
foreach ($key in $getTokenParams.Keys)
{
    Write-Verbose "[$scriptName] $($key): $($getTokenParams[$key])"
    if ($showAuth)
    {
        Write-Host "$($key): $($getTokenParams[$key])"
    }
}
Write-Verbose "[$scriptName] Using authentication parameters: $($getTokenParams | ConvertTo-Json -Depth 5)"
Write-Verbose "[$scriptName] Update URL: $updateURL"
Write-Verbose "[$scriptName] Remote version URL: $remoteVersionURL"
$stringsFile = "$PWD\strings.json"
Write-Verbose "[$scriptName] Loading strings from: $stringsFile"
$loadedStrings = Get-StringsFromJson -StringsFile $stringsFile
$returnValues = $loadedStrings.returnValues
$deviceStates = $loadedStrings.deviceStates
$deviceActions = $loadedStrings.deviceActions
Write-Verbose "[$scriptName] Loaded $($returnValues.Count) return values, $($deviceStates.Count) device states, and $($deviceActions.Count) device actions"
# Initialize navigation context variables
$Global:History = [System.Collections.ArrayList]::new() 
$Global:MenuHistory = [System.Collections.ArrayList]::new() 
$global:previousMenu = New-Object System.Collections.Hashtable
# Device enrollment state cache content
$script:DeviceEnrollmentCache = @{}
#endregion Define variables

#region logging
Write-Verbose "[$scriptName] Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Received the following parameters: $($PSBoundParameters | ConvertTo-Json)" -LogLevel "Information"
Write-Verbose "[$scriptName] The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "The current parameter set is $($PSCmdlet.ParameterSetName)" -LogLevel "Information"
Write-Verbose "[$scriptName] Configuration file: $configFile"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Configuration file: $configFile" -LogLevel "Information"
Write-Verbose "[$scriptName] Initialization file: $InitFile"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Initialization file: $InitFile" -LogLevel "Information"
Write-Verbose "Log filename: $LogFile"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Log filename: $LogFile" -LogLevel "Information"
Write-Verbose "[$scriptName] Show settings: $showSettings"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Show settings: $showSettings" -LogLevel "Information"
Write-Verbose "[$scriptName] Show auth: $showAuth"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Show auth: $showAuth" -LogLevel "Information"
Write-Verbose "[$scriptName] Log level: $LogLevel"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Log level: $LogLevel" -LogLevel "Information"
Write-Verbose "[$scriptName] App mode is $($settings.appMode)."
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "App mode is $($settings.appMode)." -LogLevel "Information"
Write-Verbose "[$scriptName] Group tag: $settings.GroupTag"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Group tag: $settings.GroupTag" -LogLevel "Information"
Write-Verbose "[$scriptName] Assigned user: $AssignedUser"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Assigned user: $AssignedUser" -LogLevel "Information"
Write-Verbose "[$scriptName] Reconfigure: $Reconfigure"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Reconfigure: $Reconfigure" -LogLevel "Information"
Write-Verbose "[$scriptName] Repository: $settings.Repo"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Repository: $settings.Repo" -LogLevel "Information"
Write-Verbose "[$scriptName] Release: $settings.Release"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Release: $settings.Release" -LogLevel "Information"
Write-Verbose "[$scriptName] Domain: $domain"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Domain: $domain" -LogLevel "Information"
Write-Verbose "[$scriptName] Max wait time: $settings.maxWaitTime"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Max wait time: $settings.maxWaitTime" -LogLevel "Information"
Write-Verbose "[$scriptName] Time in seconds: $settings.timeInSeconds"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Time in seconds: $settings.timeInSeconds" -LogLevel "Information"
Write-Verbose "[$scriptName] Auth type: $auth.AuthType"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Auth type: $auth.AuthType" -LogLevel "Information"
Write-Verbose "[$scriptName] Cache type: $auth.CacheType"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Cache type: $auth.CacheType" -LogLevel "Information"
Write-Verbose "[$scriptName] Force new token: $auth.ForceNewToken"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Force new token: $auth.ForceNewToken" -LogLevel "Information"
Write-Verbose "[$scriptName] Force new refresh token: $auth.ForceNewRefreshToken"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Force new refresh token: $auth.ForceNewRefreshToken" -LogLevel "Information"
Write-Verbose "[$scriptName] No save refresh token: $auth.NoSaveRefreshToken"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "No save refresh token: $auth.NoSaveRefreshToken" -LogLevel "Information"
Write-Verbose "[$scriptName] Deligated: $auth.Deligated"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Deligated: $auth.Deligated" -LogLevel "Information"
Write-Verbose "[$scriptName] Scope: $auth.Scope"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Scope: $auth.Scope" -LogLevel "Information"
Write-Verbose "[$scriptName] Secure string: $auth.SecureString"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Secure string: $auth.SecureString" -LogLevel "Information"
Write-Verbose "[$scriptName] App mode: $settings.appMode"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "App mode: $settings.appMode" -LogLevel "Information"
Write-Verbose "[$scriptName] Functions folder: $functionsFolder"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Functions folder: $functionsFolder" -LogLevel "Information"
Write-Verbose "[$scriptName] Base source URL: $baseSourceURL"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Base source URL: $baseSourceURL" -LogLevel "Information"
Write-Verbose "[$scriptName] Remote version URL: $remoteVersionURL"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Remote version URL: $remoteVersionURL" -LogLevel "Information"
#endregion logging

#region helper functions
function ProcessDevice()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $DeviceObject,
        [Parameter(Mandatory = $true)]
        [ValidateSet('import', 'check', 'delete')]
        [string]$action,
        [switch]$CustomImport
    )
    
    #region check and initialize variables
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking access token..."
        
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking access token..." -LogLevel "Verbose"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token provided." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Access token not provided. Returning Null."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token not provided. Returning Null." -LogLevel "Information"
        return $null
    }
    Write-Verbose "[$functionName] Processing serial number: $($deviceObject.SerialNumber)."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing serial number: $($deviceObject.SerialNumber)." -LogLevel "Verbose"
    Write-Verbose "[$functionName] Action: $action"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action: $action" -LogLevel "Information"
    Write-Verbose "[$functionName] Custom import: $CustomImport"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Custom import: $CustomImport" -LogLevel "Information"
    $serialNumber = $deviceObject.serialNumber
    Write-Verbose "[$functionName] The serial number is $serialNumber."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The serial number is $serialNumber." -LogLevel "Information"
    $make = $deviceObject.manufacturer
    Write-Verbose "[$functionName] The manufacturer is $make"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The manufacturer is $make" -LogLevel "Information"
    $model = $deviceObject.model
    Write-Verbose "[$functionName] The model is $model"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The model is $model" -LogLevel "Information"
    #endregion check and initialize variables
    
    switch ($action)
    {
        'import'
        {
            Write-Verbose "[$functionName] Importing device with serial number $serialNumber."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Importing device with serial number $serialNumber." -LogLevel "Information"
            Write-Host "Checking to make sure the device hash is not already in Intune..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            Write-Verbose "[$functionName] Device assignment check returned: $deviceAssignment"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assignment check returned: $deviceAssignment" -LogLevel "Information"
            if ($null -ne $deviceAssignment -and $deviceAssignment -notin $returnValues.values)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment 
                Write-Verbose "[$functionName] Device assignment status: $isAssigned"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assignment status: $isAssigned" -LogLevel "Information"
                if ($isAssigned)
                {
                    return $returnValues.deviceAssignedMessage
                }
            }
            else
            {
                Write-Host "The device is not in Intune." 
            }
            
            #region Add the device to Intune
            Write-Host "This will import the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) into Autopilot."
            $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            while ($choice -notin @('yes', 'no'))
            {
                Write-Host "Invalid choice. Please enter 'yes' or 'no'."
                #beep
                $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            }
            if ($choice -eq 'no')
            {
                Write-Host "Exiting..."
                return $returnValues.backoutText
            }
            $importStart = Get-Date
            $device = ImportAutopilotDevice -DeviceObject $deviceObject -AccessToken $accessToken -GroupTag $GroupTag -AssignedUser $AssignedUser -TimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime -CustomImport $CustomImport
            if ($device -eq $returnValues.backoutText)
            {
                Write-Verbose "[$functionName] The import function returned $device."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The import function returned $device." -LogLevel "Information"
                return $returnValues.backoutText
            }
            $importResult = ProcessImportResult -device $device -returnValues $returnValues
            if ($importResult -ne $returnValues.deviceImportSuccessMessage)
            {
                return $importResult
            }
            Write-Host "Waiting for $timeInSeconds seconds to allow for profile assignment."
            Start-Sleep -Seconds $timeInSeconds
            $assignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -WaitForAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
            return ProcessAssignmentResult -assignment $assignment -importStart $importStart -returnValues $returnValues
            #endregion Add the device to Intune.
        }
        'check'
        {
            Write-Host "Checking device with serial number $serialNumber..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            if ($null -ne $deviceAssignment -and $deviceAssignment -notin $returnValues.values)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment 
                if ($isAssigned)
                {
                    # Handle enrollment state for assigned devices
                    return HandleDeviceEnrollmentState -deviceAssignment $deviceAssignment -serialNumber $serialNumber -accessToken $accessToken -returnValues $returnValues -domain $domain
                }
                else
                {
                    # Handle unassigned devices
                    switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                    {
                        'unassigned'
                        {
                            return $returnValues.deviceNotAssignedMessage
                        }
                        'pending'
                        {
                            return $returnValues.deviceAssignmentPendingMessage
                        }
                    }
                    # Show options for problem devices
                    Write-Host "What would you like to do?"
                    $deviceWaitMenu = NewMenu -Title "Options for Device With Serial Number $serialNumber" -Description "Choose what you would like to do with this device:"
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Restart the device" -Action {
                        Write-Host "Restarting the device..."
                        Write-Verbose "[$functionName] User chose to restart the device."

                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User chose to restart the device." -LogLevel "Information"
                        if (-not (RestartDevice))
                        {
                            Write-Verbose "[$functionName] RestartDevice function returned false."
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "RestartDevice function returned false." -LogLevel "Information"
                            return $returnValues.noRestartMessage 
                        }
                    }
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Continue to wait for profile assignment" -Action {
                        Write-Host "Continuing to wait for profile assignment..."
                        $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -waitforAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
                        return $deviceAssignment
                    }
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Delete the device from Autopilot" -Action {
                        Write-Host "Deleting the device from Autopilot..."
                        if (DeleteAutopilotDevice -DeviceIdentifyer $deviceAssignment.id -IdentifyerType 'DeviceId')
                        {
                            Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                            return $returnValues.deviceDeleteSuccessMessage
                        }
                        else
                        {
                            Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                            return $returnValues.deviceDeleteFailedMessage
                        }
                    }
                    $result = ShowMenu -Menu $deviceWaitMenu -CalledBy 'Action'
                    Write-Verbose "[$functionName] Result from device wait menu: $result"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Result from device wait menu: $result" -LogLevel "Information"
                    if ($result -eq $returnValues.backoutText)
                    {
                        Write-Verbose "[$functionName] User selected Back from device wait menu."
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected Back from device wait menu." -LogLevel "Information"
                        return $returnValues.backoutText
                    }
                    elseif ($result -eq "EXIT_APPLICATION")
                    {
                        Write-Verbose "[$functionName] User selected to exit the application."
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected to exit the application." -LogLevel "Information"
                        return "EXIT_APPLICATION"
                    }
                    else 
                    {
                        return $result
                    }
                }
            }
            else
            {
                Write-Host 'The device is not in Autopilot.'
                return $deviceAssignment
            }
        }
        'delete'
        {
            Write-Host "Checking whether the device is in Autopilot..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            if ($deviceAssignment)
            {
                Write-Host "Deleting device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) from Autopilot."
                if (DeleteAutopilotDevice -DeviceIdentifyer $serialNumber -IdentifyerType 'serialNumber')
                {
                    Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                    return $returnValues.deviceDeleteSuccessMessage
                }
                else
                {
                    Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                    return $returnValues.deviceDeleteFailedMessage
                }
            }
            else
            {
                Write-Host "The device with serial number $serialNumber is not in Autopilot." -ForegroundColor Yellow
                Write-Host "No action taken." -ForegroundColor Yellow
                return $returnValues.deviceNotInIntuneMessage 
            }
        }
        default
        {
            Write-Verbose "[$functionName] Invalid action: $action"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invalid action: $action" -LogLevel "Error"
            return $returnValues.unknownErrorMessage
        }
    }
}

function ProcessSerialNumber()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$SerialNumber,
        $AccessToken,
        $Settings = $settings,
        [switch]$CheckUserReadiness
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing device lookup for serial number: $SerialNumber"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing device lookup for serial number: $SerialNumber" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Validating serial number: $SerialNumber"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Validating serial number: $SerialNumber" -LogLevel "Information"
    if ([string]::IsNullOrWhiteSpace($SerialNumber))
    {
        Write-Host "Serial number cannot be empty or null." -ForegroundColor Red
        return $null # Return null to signal no valid serial number
    }
    $SerialNumber = $SerialNumber.Trim()
    Write-Host "`nLooking up device information for serial number: $SerialNumber" -ForegroundColor Cyan
    $enrollmentState = GetCachedDeviceEnrollmentState -SerialNumber $SerialNumber -AccessToken $AccessToken -Settings $Settings
    if ($enrollmentState)
    {
        $success = $true
        Write-Verbose "[$functionName] Device lookup successful"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device lookup successful" -LogLevel "Information"
        # Display basic device information
        Write-Host "`n=== Device Information ===" -ForegroundColor Green
        Write-Host "Serial Number: $SerialNumber"
        Write-Verbose "[$scriptName] Device is managed: $($enrollmentState.managed)"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Device is managed: $($enrollmentState.managed)" -LogLevel "Information"
        Write-Verbose "[$scriptName] Has device object: $($enrollmentState.hasDeviceObject)"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Has device object: $($enrollmentState.hasDeviceObject)" -LogLevel "Information"
        Write-Verbose "[$scriptName] In Autopilot: $($enrollmentState.inAutopilot)"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "In Autopilot: $($enrollmentState.inAutopilot)" -LogLevel "Information"
        Write-Verbose "[$scriptName] Device imported: $($enrollmentState.Imported)"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Device imported: $($enrollmentState.Imported)" -LogLevel "Information"
        if ($CheckUserReadiness)
        {
            return GetNextUserReadinessReport -enrollmentState $enrollmentState
        }
        if ($enrollmentState.inAutopilot)
        {
            Write-Host "This device is enrolled in Autopilot."
            #capture the device information since this is the first place we can get it.
            if (-not $enrollmentState.managed)
            {
                Write-Host "Model: $($enrollmentState.autopilot.device.model)"
                Write-Host "Manufacturer: $($enrollmentState.autopilot.device.manufacturer)"
                Write-Host "System Family: $($enrollmentState.autopilot.device.systemFamily)"
                Write-Host "=============================`n" -ForegroundColor Green
                $DeviceAssessmentState = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness'
                Write-Verbose "[$scriptName] Device assessment state: $DeviceAssessmentState"
                Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Device assessment state: $DeviceAssessmentState" -LogLevel "Information"
                Write-Host "Device Assessment State: $DeviceAssessmentState" -ForegroundColor Green
            }
            Write-Host "Deployment profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
            {
                Write-Host "Deployment profile: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host "Deployment Profile Assignment Date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone)"
            }
            else
            {
                Write-Host "This device is not assigned to a deployment profile." -ForegroundColor Yellow
            }
        }
        else
        {
            Write-Host "This device is not enrolled in Autopilot." -ForegroundColor Yellow
            Write-Host "=============================`n" -ForegroundColor Yellow
        }
        if ($enrollmentState.Imported)
        {
            Write-Verbose "[$scriptName] Imported in Autopilot: $($enrollmentState.inAutopilot)"
            Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Imported in Autopilot: $($enrollmentState.inAutopilot)" -LogLevel "Information"
            Write-Verbose "[$scriptName] Imported count: $($enrollmentState.Imported)"
            Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Imported count: $($enrollmentState.Imported)" -LogLevel "Information"
            if ($enrollmentState.Imported -gt 1)
            {
                Write-Host "This device was imported into Autopilot $($enrollmentState.Imported) times." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice[$enrollmentState.ImportedAutopilotDevice.Count - 1]
            }
            else
            {
                Write-Host "This device was recently imported into Autopilot." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice
            }
            if (-not $enrollmentState.managed)
            {
                Write-Host "However, this device is not currently managed in Intune."
            }
            Write-Host "Here is the latest known import information:"
            Write-Host "Imported Device ID: $($importedDeviceInfo.id)"
            Write-Host "Last import registration id: $($importedDeviceInfo.state.deviceRegistrationId)"
            Write-Host "Last import status: $($importedDeviceInfo.state.deviceImportStatus)"
            Write-Host "Last import error: $($importedDeviceInfo.state.deviceErrorName)"
            Write-Host "Last import error code: $($importedDeviceInfo.state.deviceErrorCode)"
        }
        else
        {
            Write-Verbose "This device was not recently imported into Autopilot."
            Write-Log -LogFile $LogFile -Module "$scriptName" -Message "This device was not recently imported into Autopilot." -LogLevel "Warning"
        }
        if ($enrollmentState.managed)
        {
            $deviceName = $enrollmentState.managedDevice.device.deviceName
            $model = $enrollmentState.managedDevice.device.model
            $manufacturer = $enrollmentState.managedDevice.device.manufacturer
            $managedDeviceId = $enrollmentState.managedDevice.device.id
            Write-Host "Device Name: $deviceName"
            Write-Host "Model: $model"
            Write-Host "Manufacturer: $manufacturer"
            Write-Host "Status: Managed by Intune" -ForegroundColor Green
            Write-Host "=============================`n" -ForegroundColor Green
            $pendingActions = getDevicePendingActions -enrollmentState $enrollmentState
            Write-Verbose "[$functionName] Pending actions: $($pendingActions | ConvertTo-Json -Depth 5)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Pending actions: $($pendingActions | ConvertTo-Json -Depth 5)" -LogLevel "Information"
            if ($pendingActions.isPendingAction)
            {
                Write-Host "This device has pending actions:"
                foreach ($action in $pendingActions.pendingActions)
                {
                    Write-Host "- Action name: $($action.actionName)" -ForegroundColor Yellow
                    Write-Host "- Action status: $($action.status)" -ForegroundColor Yellow
                }
                return $returnValues.deviceActionPendingMessage
            }
            else
            {
                Write-Verbose "[$functionName] No pending actions for this device."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "No pending actions for this device." -LogLevel "Information"
            }
            # Create and show device actions menu using main.ps1 menu structure
            Write-Verbose "[$functionName] Starting device actions menu loop"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting device actions menu loop" -LogLevel "Information"
            $deviceActionsMenu = NewMenu -Title "Device Actions for $deviceName" -Description "Select an action to perform on this device:"
            #region Process devices
            # Add menu items for each device action
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Wipe Device" -Action {
                Write-Host "`nInitiating device wipe for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'wipe' | Out-Null
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Clean Device" -Action {
                Write-Host "`nInitiating device clean for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'clean' -MonitorAction
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Sync Device" -Action {
                Write-Host "`nSyncing device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'sync'
            }
            Write-Verbose "[$functionName] Checking if device has LAPS credentials."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking if device has LAPS credentials." -LogLevel "Verbose"
            Write-Verbose "[$functionName] LAPS credentials count: $($enrollmentState.managedDevice.laps.credentials.count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "LAPS credentials count: $($enrollmentState.managedDevice.laps.credentials.count)" -LogLevel "Information"
            if ($enrollmentState.managedDevice.laps.credentials.count -gt 0)
            {
                $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Get LAPS Password" -Action {
                    GetDeviceLAPSCredentials -enrollmentState $enrollmentState
                    try
                    {
                        Set-Clipboard -Value ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($enrollmentState.managedDevice.LAPS.credentials[0].passwordBase64)))
                        Write-Host "`LAPS password copied to clipboard." -ForegroundColor Green
                    }
                    catch
                    {
                        Write-Host "`nFailed to copy LAPS password to clipboard. Please check your permissions." -ForegroundColor Red
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to copy LAPS password to clipboard. Error: $_" -LogLevel "Error"
                    }
                }
            }            
            Write-Verbose "Checking if we have bitlocker keys for this device."
            Write-Verbose "[$functionName] BitLocker recovery key count: $($enrollmentState.managedDevice.bitLocker.value.count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "BitLocker recovery key count: $($enrollmentState.managedDevice.bitLocker.value.count)" -LogLevel "Information"
            if ($null -ne $enrollmentState.managedDevice.latestBitlockerKey)
            {
                $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Get BitLocker Recovery Key" -Action {
                    Write-Verbose "[$scriptName] Sending value of $($enrollmentState.managedDevice.latestBitlockerKey) to GetBitLockerRecoveryKey function."
                    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Sending value of $($enrollmentState.managedDevice.latestBitlockerKey) to GetBitLockerRecoveryKey function." -LogLevel "Information"
                    $bitlockerKey = GetBitLockerRecoveryKey -key $enrollmentState.managedDevice.latestBitlockerKey -accessToken $AccessToken
                    if ($bitlockerKey -ne "`n")
                    {
                        try
                        {
                            Set-Clipboard -Value ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($enrollmentState.managedDevice.LAPS.credentials[0].passwordBase64)))
                            Write-Host "`nBitlocker key copied to clipboard." -ForegroundColor Green
                        }
                        catch
                        {
                            Write-Host "`nFailed to copy Bitlocker key to clipboard. Please check your permissions." -ForegroundColor Red
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to copy Bitlocker key to clipboard. Error: $_" -LogLevel "Error"
                        }
                
                    }
                }
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Restart Device" -Action {
                Write-Host "`nRestarting device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'restart' | Out-Null
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Show Device Health Status" -Action {
                $deviceReport = ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber
                Write-Verbose "[$functionName] Device report: $deviceReport"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device report: $deviceReport" -LogLevel "Information"
                # Handle navigation responses from ShowReport
                if ($deviceReport -eq "Back" -or $deviceReport -eq "back")
                {
                    Write-Verbose "[$scriptName] User selected Back from device selection, returning to previous menu"
                    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "User selected Back from device selection, returning to previous menu" -LogLevel "Information"
                    return $returnValues.backoutText
                }
                elseif ($deviceReport -eq "Main Menu" -or $deviceReport -eq "main menu")
                {
                    Write-Verbose "[$scriptName] User selected Main Menu from device selection"
                    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "User selected Main Menu from device selection" -LogLevel "Information"
                    return "EXIT_APPLICATION"
                }
                elseif ([string]::IsNullOrWhiteSpace($deviceReport) -or $null -eq $deviceReport)
                {
                    Write-Verbose "[$scriptName] User requested application exit from device selection."
                    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "User requested application exit from device selection." -LogLevel "Information"
                    return "EXIT_APPLICATION"
                }        
                elseif ($deviceReport -ne '0' -and $null -ne $deviceReport -and $deviceReport -ne "Back" -and $deviceReport -ne "Main Menu")
                {
                    if ($deviceReport -eq $true -or $deviceReport -in ("Export to HTML", "Export to CSV"))
                    {
                        Write-Host "`nDevice health status displayed successfully." -ForegroundColor Green
                    }
                    else
                    {
                        Write-Host "`nDevice health status could not be displayed." -ForegroundColor Red
                    }
                    Write-Verbose "[$scriptName] ShowDeviceReport returned: $deviceReport"
                    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "ShowDeviceReport returned: $deviceReport" -LogLevel "Information"
                }
                return $returnValues.backoutText
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Check next user readiness state" -Action {
                return (GetNextUserReadinessReport -enrollmentState $enrollmentState).ReadinessState
            }            # Show the device actions menu with navigation context
            Write-Verbose "[$functionName] Showing device actions menu with Depth: $depth, History count: $($History.Count), MenuHistory count: $($MenuHistory.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Showing device actions menu with Depth: $depth, History count: $($History.Count), MenuHistory count: $($MenuHistory.Count)" -LogLevel "Information"
            $result = ShowMenu -Menu $deviceActionsMenu -CalledBy 'Action'
            #endregion Process devices
            Write-Verbose "[$functionName] Device actions menu returned result: $result"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device actions menu returned result: $result" -LogLevel "Information"
            Write-Verbose "[$functionName] Returning from device actions menu with result: $result"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning from device actions menu with result: $result" -LogLevel "Information"
            return $result
        }
        else
        {
            Write-Host "This device is not managed in Intune." -ForegroundColor Yellow
        }
        if ($enrollmentState.hasDeviceObject)
        {
            Write-Host "`nDevice object found in Intune." -ForegroundColor Green
            Write-Host "Device ID: $($enrollmentState.managedDevice.device.id)"
            Write-Host "Device Name: $($enrollmentState.managedDevice.device.deviceName)"
            Write-Host "Model: $($enrollmentState.managedDevice.device.model)"
        }
        else
        {
            Write-Host "This device does not have an associated object in Intune." -ForegroundColor Red
        }
    }
    else
    {
        # Explicitly return $null if no enrollmentState
        Write-Verbose "[$functionName] Device lookup failed or no enrollment state found"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device lookup failed or no enrollment state found" -LogLevel "Error"
        return $null
    }
    
    # Return success status for calling functions
    return $success
}
#endregion helper functions

#region initialization block with access token
Write-Verbose "[$scriptName] Initialization block started."
Write-Verbose "[$scriptName] Force new token: $($auth.ForceNewToken )"
Write-Verbose "[$scriptName] Force new refresh token: $($auth.ForceNewRefreshToken )"
Write-Verbose "[$scriptName] No save refresh token: $($auth.NoSaveRefreshToken )"
Write-Verbose "[$scriptName] Getting access token..."
$accessToken = GetGraphAccessToken @getTokenParams
if ($accessToken)
{
    Write-Verbose "[$scriptName] Access token retrieved successfully."
    if ($auth.ForceNewToken -or $auth.ForceNewRefreshToken -or $auth.NoSaveRefreshToken)
    {
        Write-Host "Forced new token retrieval due to parameters." 
        Write-Host "The script will now exit."
        Write-Host "You can run the script again without these parameters to use the new token." 
        exit 0    
    }
}
else
{
    Write-Host "Failed to retrieve access token." -ForegroundColor Red
    Write-Host "Please check your authentication parameters and try again." 
    exit 1
}
#endregion initialization block with access token

#region banner
Write-Host "Welcome to the Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))"
Write-Host "Copyright (c) $((Get-Date).Year) Zuhair Mahmoud" -ForegroundColor Cyan

if ($settings.showLicenseBanner)
{
    Write-Host "==========================================================`n"     
    Write-Host "This script is licensed under the MIT License." 
    Write-Host "For more information and to read the license terms, visit: https://opensource.org/licenses/MIT"
    Write-Host ""
    Write-Host "Report issues at $baseURL/$repoPath/$repoName/issues"
    Write-Host "For the changeLog, go to $baseURL/$repoPath/$repoName/releases"
    Write-Host "==========================================================`n"
    Write-Host " DISCLAIMER: This script is provided AS IS without warranty of any kind." -ForegroundColor Red
    Write-Host "The author makes no guarantees about the script's functionality or suitability for any purpose." -ForegroundColor Red
    Write-Host "It is your responsibility to test and validate the script in your environment before using it." -ForegroundColor Red
    Write-Host "Use at your own risk. The author is not responsible for any damage or data loss." -ForegroundColor Red
    Write-Host "==========================================================`n"
}
if ($updateAvailable[1] -eq $true -and $updateAvailable[0] -gt $version)
{
    Write-Verbose "[$scriptName] An update is available: $($updateAvailable[0].major).$($updateAvailable[0].minor).$($updateAvailable[0].build) ($($updateAvailable[0].revision))"
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "An update is available: $($updateAvailable[0].major).$($updateAvailable[0].minor).$($updateAvailable[0].build) ($($updateAvailable[0].revision))"
    Write-Host "==========================================================`n"    
    Write-Host "An update is available to version $($updateAvailable[0].major).$($updateAvailable[0].minor).$($updateAvailable[0].build) ($($updateAvailable[0].revision))"
    Write-Host "Please run the update command to get the latest version." -ForegroundColor Yellow
    Write-Host "==========================================================`n"
}
else
{
    Write-Verbose "[$scriptName] No updates available or current script is up to date."
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "No updates available or current script is up to date." -LogLevel "Information"
}
#endregion banner

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Please choose from one of the following options"
$CheckMenu = NewMenu -Title "Check Device Status" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$deviceExportMenu = newMenu -Title "Export Devices" -Description "Choose which devices you want to export."
$settingsMenu = NewMenu -title "Settings menu" -Description "Make changes to the application settings"
$autopilotMenu = NewMenu -Title "Autopilot Menu" -Description "Import a device into Autopilot and perform related actions"

#region export menu
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Autopilot Devices" -Action {
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'autopilot'
    if ($exported)
    {
        Write-Host "Exported Autopilot devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Autopilot devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Imported Autopilot Devices" -Action {
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'imported'
    if ($exported)
    {
        Write-Host "Exported Imported Autopilot devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Imported Autopilot devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Managed Windows Devices" -Action {
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'managed'
    if ($exported)
    {
        Write-Host "Exported Managed devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Managed devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Unmanaged Windows Devices" -Action {
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'unmanaged'
    if ($exported)
    {
        Write-Host "Exported Unmanaged devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Unmanaged devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export device storage report" -Action {
    $dateTime = Get-Date -Format "yyyyMMdd_HHmm"
    $storageOutputFileName = "DeviceStorageReport-$dateTime.csv"
    if (ExportDeviceStorage -AccessToken $accessToken -OutputFile $storageOutputFileName -IncludeStorageInfo)
    {
        Write-Host "Exported device storage report to $($storageOutputFileName)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export device storage report." -ForegroundColor Red
    }
}
#endregion export menu

#region serial number menu
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
    if ($null -ne $serialNumber)
    {
        Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
        Write-Host "Looking up device with serial number: $serialNumber"
        $callingContext = Get-CallingContext -IncludeNavigationPath
        switch ($callingContext)
        {
            Action-ViaCheckMenu
            {
                Write-Verbose "[$scriptName] Action called via $callingContext"
                Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
                Write-Verbose "[$scriptName] Result returned: $result"
            }
            Action-ViaAutopilotMenu
            {
                Write-Verbose "[$scriptName] Action called via $callingContext"
                Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
                Write-Host "Checking device with serial number $($SerialNumber)..."
                $deviceObject = @{SerialNumber = $serialNumber}
                $result = ProcessDevice -accessToken $accessToken -deviceObject $deviceObject -action 'check'
                Write-Verbose "[$scriptName] Result returned: $result"
            }
        }
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
    }
    else
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.BackoutText)."
        return $returnValues.backoutText
    }
}
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number." -Action {
    Write-Verbose "[$scriptName] Getting the serial number for this device..."
    $deviceObject = GetDeviceInfo -NoHash
    Write-Verbose "[$scriptName] Device object: $($deviceObject)"
    if ($deviceObject)
    {
        $serialNumber = $deviceObject.serialNumber
        $make = $deviceObject.manufacturer
        $model = $deviceObject.model
        Write-Host "Looking up local device: $make $model (Serial: $serialNumber)"
        $context = Get-CallingContext -IncludeNavigationPath
        switch ($context)
        {
            Action-ViaCheckMenu
            {
                Write-Verbose "[$scriptName] Action called via $context"
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
                Write-Verbose "[$scriptName] Result returned: $result"
            }
            Action-ViaAutopilotMenu
            {
                Write-Verbose "[$scriptName] Action called via $context"
                Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
                $result = ProcessDevice -accessToken $accessToken -deviceObject $deviceObject -action 'check' 
                Write-Verbose "[$scriptName] Result returned: $result"
            }
        }
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
        elseif ($result -eq $true -or $result -in $returnValues.Values)
        {
            Write-Host $result
        }
        else
        {
            Write-Host "Failed to fetch information for device with serial number: $serialNumber" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
        Read-Host "Press Enter to continue"
    }
}
#endregion serial number menu

#region Autopilot menu   
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Quick Import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Quick import device into Autopilot."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    $result = PrepareImportDevice -accessToken $accessToken
    Write-Verbose "[$scriptName] Result of quick import: $result"
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Custom import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Custom import device into Autopilot."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Checking for Windows updates."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    $result = PrepareImportDevice -accessToken $accessToken -CustomImport
    if ($result -eq $returnValues.backoutText)
    {
        Write-Verbose "[$scriptName] Custom import aborted. Returning $($returnValues.backoutText)."
        return $returnValues.backoutText
    }
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -name "Get device hash for manual upload to Autopilot (requires admin rights)" -action {
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Getting device object."
        $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    if ($deviceObject)
    {
        Write-Host "Getting device hash for device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
        $outputFile = "\device_$($deviceObject.serialNumber).csv"
        if (GetDeviceHash -Device $deviceObject -OutputFile $outputFile)
        {
            Write-Host 'Device hash created successfully.' -ForegroundColor Green
            Write-Host "The device hash is saved to $outputFile." -ForegroundColor Green
            Write-Host 'You can now upload the device hash to Autopilot.' -ForegroundColor Green
            Write-Host 'Please check the Intune portal for more information.' -ForegroundColor Green
        }
        else
        {
            Write-Host 'Failed to create device hash.' -ForegroundColor Red
        }
    }
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Download and install latest Windows updates(requires admin rights)" -action {
    Write-Verbose "[$scriptName] Download and install latest Windows updates."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Checking for Windows updates."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    Write-Host 'Downloading and installing the latest Windows updates...'
    $updateResult = ApplyWindowsUpdates
    Write-Host $returnValues.$updateResult
}
$autopilotMenu = AddMenuItem -Menu $autopilotMenu -Name "Check device Autopilot status" -Submenu $SerialNumberMenu
$autopilotMenu = AddMenuItem -menu $autopilotMenu -name "Delete device from Autopilot" -action {
    Write-Host 'Deleting the device from Autopilot...'
    $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser -nohash
    if ($deviceObject)
    {
        Write-Host "This will delete the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) from Autopilot."
        $choice = Read-Host "Are you sure you want to delete this device? (yes/no)"
        while ($choice -notin @('yes', 'no'))
        {
            Write-Host "Invalid choice. Please enter 'yes' or 'no'."
            #beep
            [console]::beep(1000, 500)
            $choice = Read-Host "Are you sure you want to delete this device? (yes/no)"
        }
        if ($choice -eq 'no')
        {
            Write-Host "Exiting..."
            return $returnValues.backoutText
        }
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'delete'
        Write-Verbose "[$scriptName] Device deletion result: $result"
    }
}

#endregion Autopilot menu

#region Settings menu
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change application settings" -Action {
    Write-Host 'Reconfiguring the script...'
    if (CreateFullConfiguration -RootFolder $pwd)
    {
        Write-Host 'The script has been reconfigured.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to reconfigure the script.' -ForegroundColor Red
    }
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change application credentials" -Action {
    $AppId = Read-Host "Enter the application ID"
    $AppSecret = Read-Host "Enter the application secret"
    $TenantId = Read-Host "Enter the tenant ID"
    $appDomain = Read-Host "Enter the application domain"
    $appName = Read-Host "Enter the application name"
    $AppId = $AppId.Trim()
    $AppSecret = $AppSecret.Trim()
    $TenantId = $TenantId.Trim()
    $appDomain = $appDomain.Trim()
    $appName = $appName.Trim()
    $configObject = [PSCustomObject]@{
        AppId     = $AppId
        AppSecret = $AppSecret
        TenantId  = $TenantId
        domain    = $appDomain
        name      = $appName
    }
    # Get password for encryption
    $userPasswordSecure = Get-SecurePassword -Message "Enter a password to encrypt the configuration file" -Confirm
    $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
    
    # Create temporary file for encryption
    $tempFile = [System.IO.Path]::GetTempFileName()
    try
    {
        $json = $configObject | ConvertTo-Json -Depth 10
        Set-Content -Path $tempFile -Value $json -Force
        
        # Encrypt the configuration file
        $encryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $userPassword
        
        if ($encryptResult.Success)
        {
            Write-Host "Saving encrypted configuration to $configFile"
            Copy-Item -Path $tempFile -Destination $configFile -Force
            Write-Host 'The application credentials have been changed and encrypted.' -ForegroundColor Green
        }
        else
        {
            Write-Host "Failed to encrypt configuration: $($encryptResult.ErrorMessage)" -ForegroundColor Red
            return
        }
    }
    finally
    {
        if (Test-Path $tempFile)
        {
            Remove-Item $tempFile -Force
        }
        # Clear password from memory
        Clear-SecureMemory -Variables @("userPassword")
    }
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Restore defaults" -Action {
    Write-Host 'Restoring the script to its default settings...'
    if (InitializeConfiguration -RootFolder $pwd -overwrite)
    {
        Write-Host 'The script defaults have been restored.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to restore script defaults..' -ForegroundColor Red
    }
}
#endregion Settings menu

$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by Serial Number" -Submenu $serialNumberMenu
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by User" -Action {
    $userName = GetUserInput -Message "Enter the username (email address) of the user whose device you want to look up." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    if ($null -eq $userName)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.BackoutText)."
        return $returnValues.backoutText
    }
    Write-Verbose "[$scriptName] Got user name: $userName"
    
    #region Check if the user exists first.
    $userInfo = GetEntraUser -UserName $userName -AccessToken $accessToken -findSimilar
    Write-Verbose "[$scriptName] Substring search: $($userInfo)"
    Write-Verbose "[$scriptName] User info returned: $($userInfo[0].value.count) users."
    Write-Verbose "[$scriptName] User info: $($userInfo | ConvertTo-Json -Depth 10)"
    if ($null -ne $userInfo -and $userInfo[1] -eq $false)
    {
        Write-Host "Found user: $($userInfo[0].value.displayName) ($($userInfo[0].value.userPrincipalName))"
        $userName = $userInfo[0].value.userPrincipalName
        Write-Verbose "[$scriptName] User name set to: $userName"
    }
    elseif ($null -ne $userInfo -and $userInfo[1] -eq $true)
    {
        Write-Host "Could not find an exact match for user $($userName)."
        if ($userInfo[0].value.count -eq 1)
        {
            Write-Host "Found a user with a similar name."
        }
        else
        {
            Write-Host "Found $($($userInfo[0].value.count)) users with similar names:"
        }
        if ($($userInfo[0].value.count) -gt [int]$settings.maxUserMatchDisplay)
        {
            Write-Host "Displaying the first $($settings.maxUserMatchDisplay) matches:"
        }
        elseif ($($userInfo[0].value.count) -eq 1)
        {
            Write-Host "Is this the correct user?"
        }
        else
        {
            Write-Host "Displaying all $($userInfo[0].value.count) matches:"
        }
        $possibleUserName = DisplayUserList -UserList $userInfo[0].value -maxDisplay $settings.maxUserMatchDisplay
        Write-Verbose "[$scriptName] User name selected: $possibleUserName"
        # Handle navigation options returned from DisplayUserList
        if ($null -eq $possibleUserName)
        {
            Write-Verbose "[$scriptName] DisplayUserList returned null (exit signal)."
            return "EXIT_APPLICATION"
        }
        elseif ($possibleUserName -eq "Back" -or $possibleUserName -eq "back")
        {
            Write-Verbose "[$scriptName] User selected 'Back'. Returning $($returnValues.backoutText)."
            return $returnValues.backoutText
        }
        elseif ($possibleUserName -eq "Main Menu" -or $possibleUserName -eq "main menu")
        {
            Write-Verbose "[$scriptName] User selected 'Main Menu'. Returning to main menu."
            return "Main Menu"
        }
        elseif ($possibleUserName -eq 0 -or $possibleUserName -eq "0")
        {
            Write-Verbose "[$scriptName] User selected exit (0). Exiting application."
            return "EXIT_APPLICATION"
        }
        else
        {
            Write-Verbose "[$scriptName] User selected: $possibleUserName"
            $userName = $possibleUserName
        }
    }
    elseif ($userInfo -eq $returnValues.noUserFoundInDirectoryMessage)
    {
        return $userInfo
    }
    else
    {
        return $returnValues.noUserFoundInDirectoryMessage
    }
    #endregion Check if the user exists first.
    
    # Call GetDeviceByUser to find devices for the specified user
    Write-Verbose "[$scriptName] Calling GetDeviceByUser for user: $userName"
    $serialNumber = GetDeviceByUser -UserName $userName -OperatingSystem 'Windows' -AccessToken $accessToken
    Write-Verbose "[$scriptName] GetDeviceByUser returned: $serialNumber"
    Write-Host "Found device for user $userName with serial number: $serialNumber"
    
    do
    {
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        Write-Verbose "[$scriptName] Result: $result"
        Write-Verbose "[$scriptName] ProcessSerialNumber returned: $result"
        $serialNumber = $result        
    } until ($result -in $returnValues.values -or $result -eq "EXIT_APPLICATION" -or $result -eq "Back" -or $result -eq "back" -or $result -eq "Main Menu" -or $result -eq "main menu" -or [string]::IsNullOrWhiteSpace($result))    

    #region Handle navigation responses from GetDeviceByUser
    if ($serialNumber -eq "Back" -or $serialNumber -eq "back")
    {
        Write-Verbose "[$scriptName] User selected Back from device selection, returning to previous menu"
        return $returnValues.backoutText
    }
    elseif ($serialNumber -eq "Main Menu" -or $serialNumber -eq "main menu")
    {
        Write-Verbose "[$scriptName] User selected Main Menu from device selection"
        return "EXIT_APPLICATION"
    }
    elseif ([string]::IsNullOrWhiteSpace($SerialNumber) -or $null -eq $serialNumber)
    {
        Write-Verbose "[$scriptName] User requested application exit from device selection."
        return "EXIT_APPLICATION"
    }        
    else 
    {
        return $result
    }
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Give a device to a user" -Action {
    $username = GetUserInput -Message "Enter the username (email address) of the user receiving the device." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    # Check if user entered 'back'
    if ($null -eq $username)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.backoutText)."
        return $returnValues.backoutText # Return to the previous menu
    } 
    else # Continue only if a username was entered
    {
        $hasCorrectGroups = $false
        $hasCorrectNumberOfDevices = $false
        
        #region Check if the user exists first.
        $userInfo = GetEntraUser -UserName $userName -AccessToken $accessToken -findSimilar
        Write-Verbose "[$scriptName] Substring search: $($userInfo)"
        Write-Verbose "[$scriptName] User info returned: $($userInfo[0].value.count) users."
        Write-Verbose "[$scriptName] User info: $($userInfo | ConvertTo-Json -Depth 10)"
        if ($null -ne $userInfo -and $userInfo[1] -eq $false)
        {
            Write-Host "Found user: $($userInfo[0].value.displayName) ($($userInfo[0].value.userPrincipalName))"
            $userName = $userInfo[0].value.userPrincipalName
            Write-Verbose "[$scriptName] User name set to: $userName"
        }
        elseif ($null -ne $userInfo -and $userInfo[1] -eq $true)
        {
            Write-Host "Could not find an exact match for user $($userName)."
            if ($userInfo[0].value.count -eq 1)
            {
                Write-Host "Found a user with a similar name."
            }
            else
            {
                Write-Host "Found $($($userInfo[0].value.count)) users with similar names:"
            }
            if ($($userInfo[0].value.count) -gt [int]$settings.maxUserMatchDisplay)
            {
                Write-Host "Displaying the first $($settings.maxUserMatchDisplay) matches:"
            }
            elseif ($($userInfo[0].value.count) -eq 1)
            {
                Write-Host "Is this the correct user?"
            }
            else
            {
                Write-Host "Displaying all $($userInfo[0].value.count) matches:"
            }
            $possibleUserName = DisplayUserList -UserList $userInfo[0].value -maxDisplay $settings.maxUserMatchDisplay
            Write-Verbose "[$scriptName] User name selected: $possibleUserName"
            # Handle navigation options returned from DisplayUserList
            if ($null -eq $possibleUserName)
            {
                Write-Verbose "[$scriptName] DisplayUserList returned null (exit signal)."
                return "EXIT_APPLICATION"
            }
            elseif ($possibleUserName -eq "Back" -or $possibleUserName -eq "back")
            {
                Write-Verbose "[$scriptName] User selected 'Back'. Returning $($returnValues.backoutText)."
                return $returnValues.backoutText
            }
            elseif ($possibleUserName -eq "Main Menu" -or $possibleUserName -eq "main menu")
            {
                Write-Verbose "[$scriptName] User selected 'Main Menu'. Returning to main menu."
                return "Main Menu"
            }
            elseif ($possibleUserName -eq 0 -or $possibleUserName -eq "0")
            {
                Write-Verbose "[$scriptName] User selected exit (0). Exiting application."
                return "EXIT_APPLICATION"
            }
            else
            {
                Write-Verbose "[$scriptName] User selected: $possibleUserName"
                $userName = $possibleUserName
            }
        }
        elseif ($userInfo -eq $returnValues.noUserFoundInDirectoryMessage)
        {
            return $userInfo
        }
        else
        {
            return $returnValues.noUserFoundInDirectoryMessage
        }
        #endregion Check if the user exists first.
        Write-Host "Checking group membership for user $userName."
        $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
        if ($groups.success -eq $true)
        {
            Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
            Write-Host "The user is a member of all $($groupsToInclude.Count) required groups and is not a member of any of the $($groupsToExclude.Count) forbidden groups."
            $hasCorrectGroups = $true
        }
        elseif ($selectedItem.Submenu)
        {
            Write-Verbose "[$scriptName] The function returned $($groups.MissingGroups.Count) missing group membershipss and $($groups.ForbiddenGroups.Count) forbidden group membershipss."
            Write-Verbose "[$scriptName] Missing group memberships: $($groups.missingGroups | Out-String)"
            Write-Verbose "[$scriptName] Forbidden groups: $($groups.ForbiddenGroups | Out-String)"
            if ($groups.missingGroups.Count -gt 0)
            {
                Write-Host 'The user needs to be added to the following groups:' -ForegroundColor Red
                foreach ($group in $groups.missingGroups)
                {
                    Write-Host $group -ForegroundColor Red
                }
            }
            if ($groups.ForbiddenGroups.Count -gt 0)
            {
                Write-Host 'The user needs to be removed from the following groups:' -ForegroundColor Red
                foreach ($group in $groups.invalidExcludeGroups)
                {
                    Write-Host $group -ForegroundColor Red
                }
            }
            Write-Host 'Please contact an Intune administrator.' -ForegroundColor Red
        }
        Write-Host "`nChecking if the user $userName has exceeded the number of allowed devices." -ForegroundColor Cyan
        $totalDevices = GetTotalRegisteredDevicesByUser -Username $userName -AccessToken $accessToken 
        if ($totalDevices -lt $settings.maxNumberOfDevicesAllowed)
        {
            Write-Host "User $userName has $totalDevices devices, which is below the $($settings.maxNumberOfDevicesAllowed) allowed device limit." -ForegroundColor Green
            $hasCorrectNumberOfDevices = $true
        }
        else
        {
            Write-Host "User $userName has $totalDevices devices, which is equal to or above the $($settings.maxNumberOfDevicesAllowed) allowed device limit."
            Write-Host "No additional devices can be assigned to this user."
        }        
        if ($hasCorrectGroups -and $hasCorrectNumberOfDevices)
        {
            Write-Host "The user $userName is ready to receive a device." -ForegroundColor Green
            Write-Host "We will now check the device state." -ForegroundColor Green
            Write-Host "Enter the device's serial number."
            Write-Host "This would be the device you plan to give to the user."
            $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
            # Check if user entered 'back'
            if ($null -eq $serialNumber)
            {
                Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.backoutText)."
                return $returnValues.backoutText # Return to the previous menu
            }
            else # Process only if a serial number was entered
            {
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -CheckUserReadiness
                # Check if ProcessSerialNumber returned an exit signal
                if ($null -eq $result)
                {
                    Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
                    return "EXIT_APPLICATION"
                }
            }
        }
        else
        {
            Write-Host "The user $userName is not ready to receive a Windows 11 device." -ForegroundColor Red
        }
    }
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Check device status " -Submenu $CheckMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Autopilot menu" -Submenu $autopilotMenu
if ($settings.appMode -ne 'test')
{
    Write-Verbose "[$scriptName] App mode is not test. Adding settings menu to main menu."
    # Add the settings menu to the main menu
    $mainMenu = AddMenuItem -menu $mainMenu -Name "Change application settings" -Submenu $settingsMenu
}
else
{
    Write-Verbose "[$scriptName] App mode is test. Skipping Settings menu."
}
$mainMenu = AddMenuItem -menu $mainMenu -Name "Check for script updates" -Action {
    Write-Host "Checking for script updates..."
    $updateResult = GetUpdates -executableFileName "$scriptPath\$scriptName" -updateURL $updateURL
    Write-Verbose "[$scriptName] Update result: $updateResult"
    switch ($updateResult)
    {
        $returnValues.UpdateSuccessMessage
        {
            Write-Host 'The script has been updated.' -ForegroundColor Green
            Write-Host 'Please restart the script.' -ForegroundColor Green
            exit 0
        }
        $returnValues.UpdateFailedMessage
        {
            Write-Host 'The script update failed.' -ForegroundColor Red
        }
        $returnValues.UpdateNotNeededMessage
        {
            Write-Host 'The script is up to date.' -ForegroundColor Green
        }
        default
        {
            $updateResult
        }
    }
}
$mainMenu = AddMenuItem -menu $mainMenu -name "Restart the device" -action {
    Write-Host 'Restarting the device...'
    if (-not (RestartDevice))
    {
        Write-Verbose "[$scriptName] RestartDevice function failed."
        return $returnValues.backoutText
    }
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Export devices" -Submenu $deviceExportMenu
#endregion Menu Definitions

#region Show Menu
# Add the main menu to both history arrays for proper stack synchronization
try
{
    Write-Verbose "[$scriptName] Adding main menu to both history arrays using newer powershell functions."
    [void]$global:History.Add("Main Menu")
    [void]$global:MenuHistory.Add($mainMenu)
}
catch
{
    # Fallback for older PowerShell versions
    Write-Verbose "[$scriptName] Adding main menu to both history arrays using older powershell functions."
    $global:MainMenuHistory += "Main Menu"
    $global:MainMenuHistory_Menu += $mainMenu
}

# Only show menu if not in test mode
if ($settings.testMode -eq $false)
{
    Write-Verbose "Test mode: $($settings.testMode)" 
    $result = ShowMenu -Menu $mainMenu
    if ($null -eq $result)
    {
        Write-Host "`nThank you for using the Intune Helpdesk menu. Goodbye!" -ForegroundColor Green
    }
}
else
{
    Write-Host "Test mode: $($settings.testMode). No menu will be shown." -ForegroundColor Yellow
    Write-Host "You can run the script in test mode to validate functionality without showing the menu."
}
#endregion Show Menu

# Finish logging
Write-Log -LogFile $LogFile -FinishLogging

# Clear sensitive data from memory before exiting
Clear-SecureMemory -ClearScriptVariables


