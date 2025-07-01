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
    [string]$Repo = 'github',
    [string]$Release = 'main',
    [ValidateSet('full', 'helpDesk', 'registration')]
    [string]$appMode,
    [string]$LogFile = "$pwd\Logs\Autopilot.log",
    [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug')]
    [string]$LogLevel = 'Information'
)

#region Initialize script
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

$scriptName = $MyInvocation.MyCommand.Name
# Set global log level for all Write-Log calls
$Global:MinimumLogLevel = $LogLevel
# Initialize logging
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
#endregion Initialize script

#region Load parameters from the configuration file if it exists
Write-Verbose "[$scriptName] Checking configuration file: $configFile"
if (Test-Path $configFile)
{
    $domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
    $authConfiguration = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty auth
    $auth = @{}
    Write-Verbose "[$scriptName] Domain: $domain"
    Write-Verbose "[$scriptName] Loading Auth configuration from $configFile"
    foreach ($key in $authConfiguration.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $authConfiguration.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($authConfiguration.$key)"
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
}
if (Test-Path -Path $InitFile)
{
    Write-Verbose "[$scriptName] Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
    $global:globalSettings = @{}
    $global:localSettings = @{}
    $globalConfigData = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty 'globalSettings'
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
                # Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($globalConfigData.$key))."
                # Set-Variable -Name $key -Value $globalConfigData.$key
                $globalSettings.add($key, $globalConfigData.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Got parameter $key from the commandline as $($PSBoundParameters[$key])"
            #add it to the global settings hashtable.
            $globalSettings.add($key, $PSBoundParameters[$key])
        }
    }
    $localConfigData = (Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty "domains").$domain
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
    
}
else
{
    Write-Host "Configuration file $initFile not found. Using default values."
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

#region variables
$auth = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty auth
$global:settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
$global:requiredScopes = $settings.requiredScopes
# $scope = $auth.scope
# $logfile = "mylog.log"
# $serialNumber = '0F3CFP724223KV'
# $serialNumber = 'BTSB25000BCR'
# $serialNumber = '5R3SBZ3'
# $userUri = "users"
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $importedAutopilotDeviceExtraParameters = "select=serialNumber,importId,groupTag,state"
# $unmanagedDeviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $autopilotExtraParameters = "select=serialNumber,groupTag,manufacturer,model,systemFamily,enrollmentState,deploymentProfileAssignmentStatus&top=9999&skip=0&count=true"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $managedDeviceFilter = "startswith(deviceName,'w11-')"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $deviceConfigurationUri = "deviceManagement/deviceConfigurations"
# $autopilotCsv = [System.Collections.ArrayList]@()
# $importedCsv = [System.Collections.ArrayList]@()
# $accessToken = GetGraphAccessToken -configFile $configFile -deligated -scope $scope -AuthType 'PublicAuthFlow'
$accessToken = GetGraphAccessToken -configFile $configFile
# $autopilotDevices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken -extraParameters $autopilotExtraParameters -consistencyLevel -verbose
# $importedDevices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -consistencyLevel -extraParameters $importedAutopilotDeviceExtraParameters -verbose
# $unmanagedDevices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken
# $global:enrollments = [ordered] @{
# "autopilot" = $autopilotDevices
# "managed" = $managedDevices
# "imported"  = $importedDevices
# "unmanaged" = $unmanagedDevices
# }
#endregion variables

function HasScope()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ResourcePath,
        $requiredScopes = $settings.requiredScopes,
        $accessToken
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting scope validation for $($ResourcePath.Count) resource paths"
    
    # Get authorized scopes from the access token
    $global:authorizedScopes = (DecodeJwtToken -Token $accessToken).roles
    Write-Verbose "[$functionName] Total authorized scopes/roles: $($authorizedScopes.Count)"
    $returnObjects = @()
    $allScopesAuthorized = $true
    Write-Verbose "[$functionName] Checking $($ResourcePath.Count) resource paths for required scopes."
    foreach ($uri in $ResourcePath)
    {
        Write-Verbose "[$functionName] Checking resource path: $uri"
        Write-Host "Checking resource path: $uri"
        
        # Normalize $uri to relative path for endpoint comparison
        if ($uri -match 'https?://[^/]+/(v1\.0|beta)/(.+)')
        {
            $relativeUri = $Matches[2]
            Write-Verbose "[$functionName] Normalized URI for endpoint comparison: $relativeUri"
        }
        else
        {
            $relativeUri = $uri
            Write-Verbose "[$functionName] Using URI as-is for endpoint comparison: $relativeUri"
        }
        Write-Host "Normalized URI for endpoint comparison: $relativeUri"
        
        # Find required scopes for this endpoint
        [array]$global:matchingScopes = $requiredScopes | Where-Object { 
            $_.endpoints -contains $relativeUri -or 
            ($_.endpoints | Where-Object { $relativeUri -like $_.Replace('{id}', '*') })
        }
        Write-Host "Number of matching scopes: $($global:matchingScopes.Count)"
        Write-Host "Matching required scopes: $($matchingScopes | Out-String) scopes."
        $uriAuthorized = $false
        foreach ($scopeInfo in $matchingScopes)
        {
            # Handle both "Scope" and "scope" property names
            $global:requiredScope = if ($scopeInfo.Scope) { $scopeInfo.Scope } else { $scopeInfo.scope }
            Write-Verbose "[$functionName] Checking if scope '$requiredScope' is authorized"
            Write-Host "Required scope: $requiredScope"
            
            if ($authorizedScopes -contains $requiredScope)
            {
                Write-Host "Scope '$requiredScope' is authorized" -ForegroundColor Green
                $uriAuthorized = $true
            }
            else
            {
                Write-Host "Scope '$requiredScope' is NOT authorized" -ForegroundColor Red
                $allScopesAuthorized = $false
            }
        }
        
        # Create return object for this URI
        $returnObject = [PSCustomObject]@{
            Uri              = $uri
            RelativeUri      = $relativeUri
            RequiredScopes   = $matchingScopes
            IsAuthorized     = $uriAuthorized
            AuthorizedScopes = $authorizedScopes
        }
        
        $returnObjects += $returnObject
        Write-Verbose "[$functionName] URI '$uri' authorization status: $uriAuthorized"
    }
    
    Write-Verbose "[$functionName] Overall authorization status: $allScopesAuthorized"
    Write-Host "Overall authorization status: $allScopesAuthorized" 
    
    # Return both the detailed objects and the overall status
    return @{
        IsAuthorized     = $allScopesAuthorized
        Details          = $returnObjects
        AuthorizedScopes = $authorizedScopes
    }
}


$global:authorizationResult = HasScope -ResourcePath @('devices', 'users') -accessToken $accessToken -requiredScopes $global:requiredScopes
$global:isAuthorized = $global:authorizationResult.IsAuthorized

# Debug the required scopes structure
Write-Host "`n=== Debug: Required Scopes Structure ===" -ForegroundColor Cyan
Write-Host "Global required scopes type: $($global:requiredScopes.GetType().Name)" -ForegroundColor Yellow
Write-Host "Global required scopes count: $($global:requiredScopes.Count)" -ForegroundColor Yellow
if ($global:requiredScopes -is [array] -and $global:requiredScopes.Count -gt 0)
{
    Write-Host "First scope object type: $($global:requiredScopes[0].GetType().Name)" -ForegroundColor Yellow
    Write-Host "First scope properties: $($global:requiredScopes[0].PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
    if ($global:requiredScopes[0].Scope)
    {
        Write-Host "First scope value: $($global:requiredScopes[0].Scope)" -ForegroundColor Yellow
    }
    if ($global:requiredScopes[0].endpoints)
    {
        Write-Host "First scope endpoints: $($global:requiredScopes[0].endpoints -join ', ')" -ForegroundColor Yellow
    }
}
else
{
    Write-Host "Required scopes is not an array or is empty" -ForegroundColor Red
}

Write-Host "==========================================`n" -ForegroundColor Cyan

$global:authorizationResult = HasScope -ResourcePath @('devices', 'users') -accessToken $accessToken -requiredScopes $global:requiredScopes
$global:isAuthorized = $global:authorizationResult.IsAuthorized

Write-Host "`n=== Authorization Summary ===" -ForegroundColor Cyan
Write-Host "Is Authorized: $($global:isAuthorized)" -ForegroundColor $(if ($global:isAuthorized) { 'Green' } else { 'Red' })
Write-Host "Authorized Scopes Count: $($global:authorizationResult.AuthorizedScopes.Count)" -ForegroundColor Yellow
Write-Host "Authorized Scopes: $($global:authorizationResult.AuthorizedScopes -join ', ')" -ForegroundColor Yellow
Write-Host "Required Scopes Structure Count: $($global:requiredScopes.Count)" -ForegroundColor Magenta
if ($global:requiredScopes.Count -gt 0)
{
    Write-Host "First Required Scope Properties: $($global:requiredScopes[0] | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)" -ForegroundColor Magenta
}
Write-Host "================================`n" -ForegroundColor Cyan




exit 0


for ($i = 0; $i -lt $global:requiredScopes.count; $i++)
{
    $requiredScope = $global:requiredScopes[$i]
    Write-Host "Required scope: $($requiredScope.scope)"
    Write-Host "Checking if the scope $($requiredScope.scope) is granted."
    Write-Host "Scope reason: $($requiredScope.reason)"
    Write-Host "Covered endpoints:"
    $requiredScope.endpoints | ForEach-Object {
        Write-Host " - $_"
    }
    if ($requiredScope.scope -in $authorizedScopes)
    {
        Write-Host "The scope $($requiredScope.scope) is not granted. Exiting script." -ForegroundColor Red
    }
    else
    {
        Write-Host "The scope $($requiredScope.scope) is granted."
    }
}



# Define required permissions with reasons
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profile information and check group memberships"
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Needed to perform privileged operations on managed devices, such as wiping or retiring devices and reading LAPS passwords"
    },
    @{
        Permission = "DeviceManagementManagedDevices.ReadWrite.All"
        Reason     = "Required to read and write managed device information, including compliance policies and device configurations"
    },
    @{
        Permission = "DeviceManagementConfiguration.ReadWrite.All"
        Reason     = "Needed to read and write Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Needed to read and write Intune service configuration settings"
    },
    @{
        Permission = "offline_access"
        Reason     = "Needed to maintain access to resources when the user is not actively using the application"
    },
    @{ 
        Permission = "openid"
        Reason     = "Needed for OpenID Connect authentication to verify user identity"
    },
    @{
        Permission = "Device.ReadWrite.All"
        Reason     = "Needed to import devices into Autopilot"
    },    
    @{
        Permission = "Group.Read.All"
        Reason     = "Needed to read group information and memberships"
    },
    @{
        Permission = "DeviceManagementConfiguration.Read.All"
        Reason     = "Allows reading Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementApps.Read.All"
        Reason     = "Necessary to read mobile app management policies and app configurations"
    },
    @{
        Permission = "DeviceManagementManagedDevices.Read.All"
        Reason     = "Required to read managed device information and compliance policies"
    },
    @{
        Permission = "Device.Read.All"
        Reason     = "Needed to read device information from Entra ID"
    }
)

# Required permissions based on specific API endpoint access, following the principle of least privilege.
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profiles, group memberships, and registered devices."
        endpoints  = @("users", "users/{id}", "users/{id}/memberOf", "users/{id}/registeredDevices")
    },
    @{
        Permission = "Device.Read.All"
        Reason     = "Required to read Microsoft Entra ID device objects."
        endpoints  = @("devices")
    },
    @{
        Permission = "DeviceManagementApps.ReadWrite.All"
        Reason     = "Required to read application information and manage app assignments."
        endpoints  = @("deviceAppManagement/mobileApps", "deviceAppManagement/mobileApps/{id}/assignments")
    },
    @{
        Permission = "DeviceManagementConfiguration.Read.All"
        Reason     = "Required to read Intune device configuration policies."
        endpoints  = @("deviceManagement/deviceConfigurations", "deviceManagement/deviceConfigurations/{id}")
    },
    @{
        Permission = "DeviceManagementManagedDevices.Read.All"
        Reason     = "Required to read Intune managed device properties."
        endpoints  = @("deviceManagement/managedDevices", "deviceManagement/managedDevices/{id}")
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords."
        endpoints  = @("directory/deviceLocalCredentials")
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Required to read Autopilot events and to read and manage Autopilot device identities."
        endpoints  = @("deviceManagement/autopilotEvents", "importedWindowsAutopilotDeviceIdentities", "/windowsAutopilotDeviceIdentities")
    },
    @{
        Permission = "BitlockerKey.Read.All"
        Reason     = "Required to read BitLocker recovery keys for all devices."
        endpoints  = @("informationProtection/bitlocker/recoveryKeys")
    },
    @{
        Permission = "openid"
        Reason     = "Standard scope required for user sign-in with OpenID Connect."
        endpoints  = @("openid")
    },
    @{
        Permission = "profile"
        Reason     = "Standard scope to get basic user profile information during sign-in."
        endpoints  = @("profile")
    },
    @{
        Permission = "offline_access"
        Reason     = "Standard scope that provides refresh tokens to maintain access when the user is not active."
        endpoints  = @("offline_access")
    }
)

# Define revised required permissions with reasons
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profile information and check group memberships"
    },
    @{
        Permission = "Group.Read.All"
        Reason     = "Needed to read group information and memberships"
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Needed to perform privileged operations on managed devices, such as wiping or retiring devices and reading LAPS passwords"
    },
    @{
        Permission = "DeviceManagementManagedDevices.ReadWrite.All"
        Reason     = "Required to read and write managed device information and compliance policies"
    },
    @{
        Permission = "DeviceManagementConfiguration.ReadWrite.All"
        Reason     = "Needed to read and write Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementApps.Read.All"
        Reason     = "Necessary to read mobile app management policies and app configurations"
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Needed to read/write Intune service configuration settings and to import devices into Autopilot"
    },
    @{
        Permission = "openid"
        Reason     = "Needed for OpenID Connect authentication to verify user identity"
    },
    @{
        Permission = "offline_access"
        Reason     = "Needed to maintain access to resources when the user is not actively using the application"
    }
)
$uris = @()
# Regex pattern to find variables ending with 'uri' (case-insensitive) whose assignment doesn't start with $ or http
$queryPattern = '\$\w*uri\s*=\s*(?!\$|(?i:http))'
$filesToSearch = Get-ChildItem "$pwd\*.ps1" -Recurse 
Write-Host "Found $($filesToSearch.count) files."
#Search each file for variables ending with 'uri' and extract their assigned values
foreach ($file in $filesToSearch)
{
    Write-Host "Searching in $($file.Name)"
    $lines = Select-String -Path $file.FullName -Pattern $queryPattern -AllMatches
    if ($lines)
    {
        Write-Host "Found $($lines.count) lines in $($file.Name)" 
        foreach ($line in $lines)
        {
            # Extract the value after the = sign, handling quoted and unquoted strings
            $match = $line.Line -match '\$\w*uri\s*=\s*([\x27\x22]?)([^\x27\x22#\r\n]+)\1'
            if ($match)
            {
                $extractedUri = $matches[2].Trim()
                if ($extractedUri -and $extractedUri -notmatch '^(\$|(?i:http))')
                {
                    $uris += $extractedUri
                    Write-Verbose "Found URI: $extractedUri in $($file.Name) at line $($line.LineNumber)"
                }
            }
        }
    }
    else
    {
        Write-Host "No matches found in $($file.Name)"
    }
}
#sort uris and remove dupicates
Write-Host "Found $($uris.count) URIs."
if ($uris.count -eq 0)
{
    Write-Host "No URIs found. Exiting script." -ForegroundColor Red
    exit 1
}
else
{
    Write-Host "Found $($uris.count) unique URIs."
}
# Remove duplicates and sort the URIs
Write-Host "Sorting and removing duplicates from URIs..."
$uris = $uris | Sort-Object -Unique
Write-Host "Found $($uris.count) unique URIs after sorting."
Set-Content -Path 'uris.txt' -Value $uris -Force


exit 0

Write-Host "Required scopes: $($global:requiredScopes.count) scopes."
for ($i = 0; $i -lt $global:requiredScopes.count; $i++)
{
    $requiredScope = $global:requiredScopes[$i]
    Write-Host "Required scope: $($requiredScope.scope)"
    Write-Host "Checking if the scope $($requiredScope.scope) is granted."
    Write-Host "Scope reason: $($requiredScope.reason)"
    Write-Host "Covered endpoints:"
    $requiredScope.endpoints | ForEach-Object {
        Write-Host " - $_"
    }
    if ($requiredScope.scope -in $authorizedScopes)
    {
        Write-Host "The scope $($requiredScope.scope) is not granted. Exiting script." -ForegroundColor Red
    }
    else
    {
        Write-Host "The scope $($requiredScope.scope) is granted."
    }
}



# Define required permissions with reasons
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profile information and check group memberships"
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Needed to perform privileged operations on managed devices, such as wiping or retiring devices and reading LAPS passwords"
    },
    @{
        Permission = "DeviceManagementManagedDevices.ReadWrite.All"
        Reason     = "Required to read and write managed device information, including compliance policies and device configurations"
    },
    @{
        Permission = "DeviceManagementConfiguration.ReadWrite.All"
        Reason     = "Needed to read and write Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Needed to read and write Intune service configuration settings"
    },
    @{
        Permission = "offline_access"
        Reason     = "Needed to maintain access to resources when the user is not actively using the application"
    },
    @{ 
        Permission = "openid"
        Reason     = "Needed for OpenID Connect authentication to verify user identity"
    },
    @{
        Permission = "Device.ReadWrite.All"
        Reason     = "Needed to import devices into Autopilot"
    },    
    @{
        Permission = "Group.Read.All"
        Reason     = "Needed to read group information and memberships"
    },
    @{
        Permission = "DeviceManagementConfiguration.Read.All"
        Reason     = "Allows reading Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementApps.Read.All"
        Reason     = "Necessary to read mobile app management policies and app configurations"
    },
    @{
        Permission = "DeviceManagementManagedDevices.Read.All"
        Reason     = "Required to read managed device information and compliance policies"
    },
    @{
        Permission = "Device.Read.All"
        Reason     = "Needed to read device information from Entra ID"
    }
)

# Required permissions based on specific API endpoint access, following the principle of least privilege.
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profiles, group memberships, and registered devices."
        endpoints  = @("users", "users/{id}", "users/{id}/memberOf", "users/{id}/registeredDevices")
    },
    @{
        Permission = "Device.Read.All"
        Reason     = "Required to read Microsoft Entra ID device objects."
        endpoints  = @("devices")
    },
    @{
        Permission = "DeviceManagementApps.ReadWrite.All"
        Reason     = "Required to read application information and manage app assignments."
        endpoints  = @("deviceAppManagement/mobileApps", "deviceAppManagement/mobileApps/{id}/assignments")
    },
    @{
        Permission = "DeviceManagementConfiguration.Read.All"
        Reason     = "Required to read Intune device configuration policies."
        endpoints  = @("deviceManagement/deviceConfigurations", "deviceManagement/deviceConfigurations/{id}")
    },
    @{
        Permission = "DeviceManagementManagedDevices.Read.All"
        Reason     = "Required to read Intune managed device properties."
        endpoints  = @("deviceManagement/managedDevices", "deviceManagement/managedDevices/{id}")
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords."
        endpoints  = @("directory/deviceLocalCredentials")
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Required to read Autopilot events and to read and manage Autopilot device identities."
        endpoints  = @("deviceManagement/autopilotEvents", "importedWindowsAutopilotDeviceIdentities", "/windowsAutopilotDeviceIdentities")
    },
    @{
        Permission = "BitlockerKey.Read.All"
        Reason     = "Required to read BitLocker recovery keys for all devices."
        endpoints  = @("informationProtection/bitlocker/recoveryKeys")
    },
    @{
        Permission = "openid"
        Reason     = "Standard scope required for user sign-in with OpenID Connect."
        endpoints  = @("openid")
    },
    @{
        Permission = "profile"
        Reason     = "Standard scope to get basic user profile information during sign-in."
        endpoints  = @("profile")
    },
    @{
        Permission = "offline_access"
        Reason     = "Standard scope that provides refresh tokens to maintain access when the user is not active."
        endpoints  = @("offline_access")
    }
)

# Define revised required permissions with reasons
$requiredPermissions = @(
    @{
        Permission = "User.Read.All"
        Reason     = "Required to read user profile information and check group memberships"
    },
    @{
        Permission = "Group.Read.All"
        Reason     = "Needed to read group information and memberships"
    },
    @{
        Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Reason     = "Needed to perform privileged operations on managed devices, such as wiping or retiring devices and reading LAPS passwords"
    },
    @{
        Permission = "DeviceManagementManagedDevices.ReadWrite.All"
        Reason     = "Required to read and write managed device information and compliance policies"
    },
    @{
        Permission = "DeviceManagementConfiguration.ReadWrite.All"
        Reason     = "Needed to read and write Intune device configuration policies and their assignments"
    },
    @{
        Permission = "DeviceManagementApps.Read.All"
        Reason     = "Necessary to read mobile app management policies and app configurations"
    },
    @{
        Permission = "DeviceManagementServiceConfig.ReadWrite.All"
        Reason     = "Needed to read/write Intune service configuration settings and to import devices into Autopilot"
    },
    @{
        Permission = "openid"
        Reason     = "Needed for OpenID Connect authentication to verify user identity"
    },
    @{
        Permission = "offline_access"
        Reason     = "Needed to maintain access to resources when the user is not actively using the application"
    }
)
$uris = @()
# Regex pattern to find variables ending with 'uri' (case-insensitive) whose assignment doesn't start with $ or http
$queryPattern = '\$\w*uri\s*=\s*(?!\$|(?i:http))'
$filesToSearch = Get-ChildItem "$pwd\*.ps1" -Recurse 
Write-Host "Found $($filesToSearch.count) files."
#Search each file for variables ending with 'uri' and extract their assigned values
foreach ($file in $filesToSearch)
{
    Write-Host "Searching in $($file.Name)"
    $lines = Select-String -Path $file.FullName -Pattern $queryPattern -AllMatches
    if ($lines)
    {
        Write-Host "Found $($lines.count) lines in $($file.Name)" 
        foreach ($line in $lines)
        {
            # Extract the value after the = sign, handling quoted and unquoted strings
            $match = $line.Line -match '\$\w*uri\s*=\s*([\x27\x22]?)([^\x27\x22#\r\n]+)\1'
            if ($match)
            {
                $extractedUri = $matches[2].Trim()
                if ($extractedUri -and $extractedUri -notmatch '^(\$|(?i:http))')
                {
                    $uris += $extractedUri
                    Write-Verbose "Found URI: $extractedUri in $($file.Name) at line $($line.LineNumber)"
                }
            }
        }
    }
    else
    {
        Write-Host "No matches found in $($file.Name)"
    }
}
#sort uris and remove dupicates
Write-Host "Found $($uris.count) URIs."
if ($uris.count -eq 0)
{
    Write-Host "No URIs found. Exiting script." -ForegroundColor Red
    exit 1
}
else
{
    Write-Host "Found $($uris.count) unique URIs."
}
# Remove duplicates and sort the URIs
Write-Host "Sorting and removing duplicates from URIs..."
$uris = $uris | Sort-Object -Unique
Write-Host "Found $($uris.count) unique URIs after sorting."
Set-Content -Path 'uris.txt' -Value $uris -Force



