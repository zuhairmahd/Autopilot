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
    [switch]$ResetAuth,
    [switch]$ForceNewToken,
    [parameter(parameterSetName = 'delegated')]
    [switch]$delegated,
    [parameter(parameterSetName = 'delegated')]
    [switch]$ForceNewRefreshToken,
    [parameter(parameterSetName = 'delegated')]
    [switch]$NoSaveRefreshToken,
    [parameter(parameterSetName = 'delegated')]
    [string]$Scope,
    [parameter(parameterSetName = 'delegated')]
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

$scriptName = $MyInvocation.MyCommand.Name
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
{
    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Write-Verbose "[$scriptName] Running as an external script."
    Write-Verbose "[$scriptName] Script path: $ScriptPath"
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
        $fullScriptPath = "$scriptPath\$scriptName"
        Write-Verbose "[$scriptName] Full script path: $fullScriptPath"
    }
}

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

#region Initialize script
$oldExecutableFileName = 'main.exe.old'
# Set global log level for all Write-Log calls
$Global:MinimumLogLevel = $LogLevel
Write-Log -LogFile $LogFile -StartLogging
if (Test-Path $oldExecutableFileName)
{
    Write-Verbose "[$scriptName] Old backup executable file found: $oldExecutableFileName"
    Write-Verbose "[$scriptName] removing old executable file: $oldExecutableFileName."
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Removing old executable file: $oldExecutableFileName" -LogLevel "Information"
    Remove-Item -Path $oldExecutableFileName -Force -ErrorAction SilentlyContinue
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

if (Test-Path $configFile)
{
    # Load the encrypted configuration file
    $loadResult = Load-EncryptedConfigFile -ConfigFile $configFile -MaxRetries 3 -PasswordPrompt "Enter your encryption password"
    
    if (-not $loadResult.Success)
    {
        Write-Host "Configuration file exists but cannot be read: $($loadResult.ErrorMessage)" -ForegroundColor Red
        Write-Host "Please check file permissions and try again." -ForegroundColor Red
        exit 1
    }
    
    $configContent = $loadResult.Content
    
    # Setup temporary encryption for in-memory access
    $tempEncryptionResult = Setup-TemporaryEncryption -ConfigContent $configContent
    if (-not $tempEncryptionResult)
    {
        Write-Warning "Temporary encryption setup failed, some features may not work properly"
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Temporary encryption setup failed" -LogLevel "Warning"
    }
    
    # Parse the configuration content
    $configJson = ConvertFrom-Json $configContent
    $domain = $configJson.domain
    $appId = $configJson.appId
    $tenantId = $configJson.tenantId
    $name = $configJson.name
    
    # Clear the config content from memory
    $configContent = $null
}
else
{
    # Configuration file not found - launch first run wizard
    Write-Host "Configuration file $configFile not found." -ForegroundColor Yellow
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file not found. Starting first run wizard" -LogLevel "Information"
    
    Write-Host "Starting first run wizard to set up your configuration..." -ForegroundColor Green
    
    # Launch the first run wizard
    $wizardResult = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $InitFile -StringsFile "$PWD\strings.json"
    
    if ($wizardResult)
    {
        Write-Host "First run wizard completed successfully." -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $scriptName -Message "First run wizard completed successfully" -LogLevel "Information"
        
        # Now try to load the newly created configuration
        Write-Host "Loading the newly created configuration..." -ForegroundColor Cyan
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Loading newly created configuration file" -LogLevel "Information"
        
        # Re-run the configuration loading logic
        if (Test-Path $configFile)
        {
            # Load the encrypted configuration file
            $loadResult = Load-EncryptedConfigFile -ConfigFile $configFile -MaxRetries 3 -UseStoredPassword -PasswordPrompt "Enter your encryption password"
            
            if (-not $loadResult.Success)
            {
                Write-Host "Configuration file exists but cannot be read: $($loadResult.ErrorMessage)" -ForegroundColor Red
                Write-Host "Please check file permissions and try again." -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file cannot be read: $($loadResult.ErrorMessage)" -LogLevel "Error"
                exit 1
            }
            
            $configContent = $loadResult.Content
            
            # Setup temporary encryption for in-memory access
            $tempEncryptionResult = Setup-TemporaryEncryption -ConfigContent $configContent
            if (-not $tempEncryptionResult)
            {
                Write-Warning "Temporary encryption setup failed, some features may not work properly"
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Temporary encryption setup failed" -LogLevel "Warning"
            }
            
            # Parse the configuration content
            $configJson = ConvertFrom-Json $configContent
            $domain = $configJson.domain
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully for domain: $domain" -LogLevel "Information"
            
            # Clear the config content from memory
            $configContent = $null
        }
        else
        {
            Write-Host "Configuration file was not created successfully." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file was not created by wizard" -LogLevel "Error"
            exit 1
        }
    }
    else
    {
        Write-Host "First run wizard failed or was cancelled." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $scriptName -Message "First run wizard failed or was cancelled" -LogLevel "Error"
        Write-Host "Please create a configuration file manually or run the script with the -Reconfigure parameter." -ForegroundColor Yellow
        exit 1
    }
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
    
    $settingsCreated = Test-SettingsJsonExists -SettingsFile $initFile -Silent -AuthType $authConfig.AuthType -IsDelegated $authConfig.IsDelegated -DomainName $domain
    if (-not $settingsCreated)
    {
            
    }
        

    # Set auth as a script variable so it can be accessed by functions
    $script:Auth = $auth
}
#endregion Load parameters from the configuration file if it exists

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
Write-Verbose "[$scriptName] delegated: $auth.delegated"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "delegated: $auth.delegated" -LogLevel "Information"
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
if ($ResetAuth)
{
    if (Start-FirstRunWizard -authOnly)
    {
        Write-Host "The authentication information has been changed." -ForegroundColor Green
    }
    else 
    {
        Write-Host "Failed to change the authentication information." -ForegroundColor Red
        Write-Host "Please check the logs for more information." -ForegroundColor Red
        exit 1
    }
}
Write-Verbose "[$scriptName] Initialization block started."
Write-Verbose "[$scriptName] Force new token: $($auth.ForceNewToken )"
Write-Verbose "[$scriptName] Force new refresh token: $($auth.ForceNewRefreshToken )"
Write-Verbose "[$scriptName] No save refresh token: $($auth.NoSaveRefreshToken )"
Write-Verbose "[$scriptName] Getting access token..."
$accessToken = GetGraphAccessToken @getTokenParams

# Clear the cached user password now that authentication is complete
if ($script:UserEncryptionPassword)
{
    Write-Verbose "[$scriptName] Clearing cached user password after authentication"
    Clear-SecureMemory -Variables @("UserEncryptionPassword")
}

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
    Write-Host "Would you like to re-enter your authentication information?"
    Write-Host "note that this will reset your password and require you to re-enter your application authentication information."
    $retry = Read-Host "Enter 'yes' to re-enter authentication, or 'no' to exit"
    while ($retry -notin @('yes', 'no'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'."
        [console]::beep()
        $retry = Read-Host "Enter 'yes' to re-enter authentication, or 'no' to exit"
    }   
    if ($retry -eq 'yes')
    {
        # Reset the authentication information
        if (Start-FirstRunWizard -authOnly)
        {
            Write-Host "The authentication information has been changed." -ForegroundColor Green
            Write-Host "Getting access token with new authentication information..."
            $accessToken = GetGraphAccessToken @getTokenParams
        }
        else 
        {
            Write-Host "Failed to change the authentication information." -ForegroundColor Red
            Write-Host "Please check the logs for more information." -ForegroundColor Red
            exit 1
        }
    }
    else
    {
        Write-Host "Exiting script due to authentication failure." -ForegroundColor Red
        exit 1
    }
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
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Import Corporate Device Identifier for Device Preparation (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Importing Corporate Device Identifier for Device Preparation."
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
    $deviceIdentifier = GetCorpDeviceIdentifier
    if ($deviceIdentifier -and $deviceIdentifier.SerialNumber)
    {
        # For manufacturerModelSerial type, format as comma-separated string
        $identifier = "$($deviceIdentifier.Manufacturer),$($deviceIdentifier.Model),$($deviceIdentifier.SerialNumber)"
        $result = AddCorporateDeviceIdentifier -AccessToken $accessToken -DeviceIdentifier $identifier -IdentifierType "manufacturerModelSerial" -OverwriteImportedDeviceIdentities
        if ($result)
        {
            Write-Host "Device successfully added to corporate identifiers." -ForegroundColor Green
        }
        else
        {
            Write-Host "Failed to add device to corporate identifiers." -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Failed to retrieve Corporate Device Identifier." -ForegroundColor Red
    }
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Delete Corporate Device Identifier from Device Preparation (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Deleting Corporate Device Identifier from Device Preparation."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Preparing to delete Corporate Device Identifier from Device Preparation."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    $deviceIdentifier = GetCorpDeviceIdentifier
    if ($deviceIdentifier -and $deviceIdentifier.SerialNumber)
    {
        # For manufacturerModelSerial type, format as comma-separated string
        $identifier = "$($deviceIdentifier.Manufacturer),$($deviceIdentifier.Model),$($deviceIdentifier.SerialNumber)"
        Write-Host "This will delete the corporate device identifier for:"
        Write-Host "  Manufacturer: $($deviceIdentifier.Manufacturer)"
        Write-Host "  Model: $($deviceIdentifier.Model)"
        Write-Host "  Serial Number: $($deviceIdentifier.SerialNumber)"
        $choice = Read-Host "Are you sure you want to delete this corporate device identifier? (yes/no)"
        while ($choice -notin @('yes', 'no'))
        {
            Write-Host "Invalid choice. Please enter 'yes' or 'no'." -ForegroundColor Red
            [console]::beep(1000, 500)
            $choice = Read-Host "Are you sure you want to delete this corporate device identifier? (yes/no)"
        }
        if ($choice -eq 'no')
        {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return $null
        }
        $result = DeleteCorporateDeviceIdentifier -AccessToken $accessToken -DeviceIdentifier $identifier -IdentifierType "manufacturerModelSerial"
        if ($result)
        {
            Write-Host "Device successfully removed from corporate identifiers." -ForegroundColor Green
        }
        else
        {
            Write-Host "Failed to remove device from corporate identifiers." -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Failed to retrieve Corporate Device Identifier." -ForegroundColor Red
    }
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -name "Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)" -action {
    Write-Verbose "[$scriptName] Exporting Corporate Device Identifier for manual upload to Device Preparation."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Preparing to export Corporate Device Identifier for manual upload to Device Preparation."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    $deviceIdentifier = GetCorpDeviceIdentifier
    if ($null -ne $deviceIdentifier)
    {
        $outputFile = "$pwd\CorporateDeviceIdentifier_$($deviceIdentifier.SerialNumber).csv"
        #if we are running under PowerShell 7 or later, we can use Export-Csv with -NoTypeInformation and -NoHeader
        if ($PSVersionTable.PSVersion.Major -ge 7)
        {
            $deviceIdentifier | Export-Csv -Path $outputFile -NoTypeInformation -NoHeader -Force
            Write-Host "Device information exported to $outputFile"
        }
        else
        {
            $deviceIdentifier | Export-Csv -Path $outputFile -NoTypeInformation -Force
            Write-Host "Device information exported to $outputFile"
            Write-Host "Since you are running under Powershell 5 or earlier, the CSV file will contain a header row."
            Write-Host "Be sure to remove the header row if you want to use this file for upload to Autopilot device preparation."
            Write-Host "You can use a text editor or a CSV editing tool to remove the header row."
            Write-Host "If you do not remove the header row, the upload to Autopilot device preparation will fail."
        }
    }
    else
    {
        Write-Host 'Failed to export Corporate Device Identifier.' -ForegroundColor Red
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
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change password and authentication information" -Action {
    Write-Host "This will change the authentication information used by the script and will allow you to set a new password."
    $choice = Read-Host "Are you sure you want to change the authentication information? (yes/no)"
    while ($choice -notin @('yes', 'no'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'."
        #beep
        [console]::beep(1000, 500)
        $choice = Read-Host "Are you sure you want to change the authentication information? (yes/no)"
    }
    if ($choice -eq 'no')
    {
        Write-Host "Exiting..."
        return $returnValues.backoutText
    }
    if (Start-FirstRunWizard -authOnly)
    {
        Write-Host "The authentication information has been changed." -ForegroundColor Green
    }
    else 
    {
        Write-Host "Failed to change the authentication information." -ForegroundColor Red
        Write-Host "Please check the logs for more information." -ForegroundColor Red
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
$mainMenu = AddMenuItem -Menu $mainMenu -Name "About" -Action {
    $uri = "applications(appId='$appId')"
    $extraParameters = "select=displayName"
    $registeredAppName = (CallGraphApi -ResourcePath $uri -accessToken $accessToken -extraParameters $extraParameters).displayName
    Write-Host "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))"
    Write-Host "Copyright (c) $((Get-Date).Year) Zuhair Mahmoud" -ForegroundColor Cyan
    Write-Host "==========================================================`n"    
    Write-Host "Domain: $domain"
    Write-Host "Application name from config: $name"
    Write-Host "Registered application name: $registeredAppName"
    Write-Host "Application id: $appId"
    Write-Host "Tenant id: $tenantId"
    Write-Host "Delegated authentication: $($auth.delegated)."
    Write-Host "Authentication type: $($auth.AuthType)"
}
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


