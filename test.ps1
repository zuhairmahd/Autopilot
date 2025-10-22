[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\settings.psd1",
    [string]$stringsFile = "$pwd\strings.psd1",
    [string]$menuFile = "$pwd\menu.psd1",
    [int]$maxWaitTime,
    [int]$timeInSeconds,
    [String] $GroupTag,
    [switch]$showLicenseBanner,
    [switch]$showAuth,
    [switch]$showVersion,
    [switch]$showSettings,
    [switch]$OverwriteLogs,
    [switch]$SecureString,
    [bool]$autoUpdate,
    [switch]$testMode,
    [string]$TestPassword,
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
    [ValidateSet('github')]
    [string]$Repo,
    [string]$Release,
    [ValidateSet('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')]
    [string]$appMode,
    [string]$LogFilePath = "$pwd\Logs\Autopilot.log",
    [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug')]
    [string]$LogLevel = 'Information'
)

# Store test password in script scope if provided (only works with testMode for security)
if ($testMode -and $TestPassword)
{
    $script:UserEncryptionPassword = $TestPassword
    $global:UserEncryptionPassword = $TestPassword
}

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
function Find-FolderPath()
{
    <#
    .SYNOPSIS
        Searches upward from the given path for a folder with the specified name.
    .PARAMETER Path
        The starting path to begin searching from.
    .PARAMETER FolderName
        The name of the folder to search for.
    .OUTPUTS
        Returns the full path to the folder if found, otherwise $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write verbose log of received parameters
    Write-Verbose "[$functionName] Find-FolderPath called with Path: $Path, FolderName: $FolderName"
    try
    {
        $currentPath = (Resolve-Path -Path $Path).Path
        Write-Verbose "[$functionName] Current path resolved to: $currentPath"

        # 1. Search children (recursively) of the starting path
        Write-Verbose "[$functionName] Searching children of $currentPath for folder named $FolderName"
        $childMatch = Get-ChildItem -Path $currentPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
        Write-Verbose "[$functionName] Checking child match: $($childMatch.FullName)"
        if ($childMatch)
        {
            Write-Verbose "[$functionName] Found folder in children: $($childMatch.FullName)"
            return $childMatch.FullName
        }
        # Also check if the starting path itself matches
        if ((Split-Path -Path $currentPath -Leaf) -ieq $FolderName)
        {
            Write-Verbose "[$functionName] Starting path itself matches: $currentPath"
            return $currentPath
        }

        # 2. Search up the parent chain, at each level search its children for the folder
        while ($currentPath)
        {
            $parent = Split-Path -Path $currentPath -Parent
            if ($parent -eq $currentPath -or [string]::IsNullOrEmpty($parent))
            {
                break
            } # Reached root
            Write-Verbose "[$functionName] Searching children of parent: $parent for folder named $FolderName"
            $siblingMatch = Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
            if ($siblingMatch)
            {
                Write-Verbose "[$functionName] Found folder in parent: $($siblingMatch.FullName)"
                return $siblingMatch.FullName
            }
            # Also check if the parent itself matches
            if ((Split-Path -Path $parent -Leaf) -ieq $FolderName)
            {
                Write-Verbose "[$functionName] Parent itself matches: $parent"
                return $parent
            }
            $currentPath = $parent
        }
        Write-Verbose "[$functionName] No folder found with name $FolderName in children or parent hierarchy."
        return $null
    }
    catch
    {
        Write-Error "[$functionName] Error occurred while searching for folder: $_"
        return $null
    }
}

$functionsFolder = find-folderPath -Path $scriptPath -FolderName 'functions'
if (Test-Path $functionsFolder)
{
    Write-Verbose "[$scriptName] Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
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

#region Initialize script parameters
Write-Host "Starting script..."
$global:maxJSONDepth = 20
# Set global log level for all Write-Log calls
$global:LogFile = $logFilePath
$Global:MinimumLogLevel = $LogLevel
if ($OverwriteLogs)
{
    Write-Verbose "[$scriptName] Overwriting log file: $LogFile"
    Write-Log -LogFile $LogFile -StartLogging -OverwriteLog
}
else
{
    Write-Verbose "[$scriptName] Starting logging to file: $LogFile"
    Write-Log -LogFile $LogFile -StartLogging
}

if ($testMode)
{
    Write-Verbose "[$scriptName] Test mode enabled: Initializing application metadata in silent mode"   
    write-log -logFile $logFile -module $scriptName -message "Test mode enabled: Initializing application metadata in silent mode"
    $appMetaData = Get-ApplicationMetaData -GlobalSettingsFile $InitFile -scriptName $scriptName -scriptPath $ScriptPath -Silent
}
else
{
    Write-Verbose "[$scriptName] Initializing application metadata"
    write-log -logFile $logFile -module $scriptName -message "Initializing application metadata"
    $appMetaData = Get-ApplicationMetaData -GlobalSettingsFile $InitFile -scriptName $scriptName -scriptPath $ScriptPath
}
$version = if ($null -ne $appMetaData.version)
{
    $appMetaData.version
}
else
{
    [System.Version]::new(0, 0, 0, 0)
}
if ($ShowVersion)
{
    Write-Verbose "[$scriptName] Version: $version"
    Write-Host "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))" -ForegroundColor Green
    Write-Host "Copyright (c) $((Get-Date).Year) $($appMetaData.companyName)" -ForegroundColor Cyan
    Write-Host "Update branch: $($appMetaData.release)" -ForegroundColor Cyan
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))" -LogLevel "Information"
    Write-Log -LogFile $LogFile -finishLogging
    exit 0
}

#run cleanup of temp files from previous runs
$filesCleaned = cleanupTempFiles
if ($filesCleaned.AllRemoved)
{
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "All temporary files were cleaned." -LogLevel "Information"
}
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files found: $($filesCleaned.RemovedFilesCount)" -LogLevel "Verbose"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files removed: $($filesCleaned.RemovedFilesCount)" -LogLevel "Information"

#Check for settings migration
write-log -logFile $logFile -module $scriptName -message "Checking for settings migration need." -LogLevel "Information"
Write-Verbose "[$scriptName] Checking for settings migration need."
$migrationCheck = Invoke-SettingsMigration -RemoveJsonFiles -Force
# $migrationCheck = Invoke-SettingsMigration -Force
write-log -logFile $logFile -module $scriptName -message "Migration needed: $($migrationCheck.migrationNeeded), Success: $($migrationCheck.success)" -LogLevel "Information"
if ($migrationCheck.success -and $migrationCheck.migrationNeeded)
{
    Write-Host "Migration completed successfully." -ForegroundColor Green
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Migration completed successfully." -LogLevel "Information"
    Write-Verbose "[$scriptName] Legacy Autopilot profiles present: $legacyAutopilotProfilesPresent"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Migration completed successfully." -LogLevel "Information"
}
elseif ($migrationCheck.migrationNeeded -and -not $migrationCheck.success)
{
    $migrationCheck.errorMessages | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host "Please rerun the script or contact support." -ForegroundColor Yellow
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Migration failed with errors: $($migrationCheck.errorMessages -join '; ')" -LogLevel "Error"
    Write-Log -LogFile $LogFile -FinishLogging
    exit 1
}
else
{
    Write-Verbose "[$scriptName] No migration needed."
    Write-Log -LogFile $LogFile -Module $scriptName -Message "No migration needed." -LogLevel "Information" 
}
#endregion  Initialize script parameters

#region Process login
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
$script:maxRetries = 6

# In test mode without a test password and config file exists, skip config loading
if ($testMode -and -not $TestPassword -and (Test-Path $configFile))
{
    Write-Verbose "[$scriptName] Test mode enabled without test password, skipping encrypted config file loading"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode enabled without test password, skipping encrypted config file loading" -LogLevel "Information"
    # Set dummy values for required variables
    $domain = "test.local"
    $appId = "test-app-id"
    $tenantId = "test-tenant-id"
    $name = "Test Configuration"
}
elseif (Test-Path $configFile)
{
    # Initialize configuration session (use Silent mode if testMode is active)
    $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -PasswordPrompt "Enter your password" -Silent:$testMode
    
    if (-not $sessionResult.Success)
    {
        Write-Host "Error: $($sessionResult.ErrorMessage)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to initialize configuration session: $($sessionResult.ErrorMessage)" -LogLevel "Error"
        Write-Host "Exitting script due to configuration session failure." -ForegroundColor Red
        Write-Log -LogFile $LogFile -FinishLogging
        exit 1
    }
    
    $configContent = $sessionResult.ConfigContent
    $domain = $sessionResult.Domain
    $appId = $sessionResult.AppId
    $tenantId = $sessionResult.TenantId
    $name = $sessionResult.Name
    
    if (-not ($sessionResult.encrypted))
    {
        Write-Host "You need to set a new password to use this application."
        if (Invoke-PasswordChangeProcess -ConfigFile $configFile -ConfigContent $configContent -SettingsFile $initFile -setInitialPassword)
        {
            Write-Host "You can now use the application." -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Password set successfully after initialization" -LogLevel "Information"
        }
        else
        {
            Write-Host "Failed to set password. Exiting script." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to set password after initialization" -LogLevel "Error"
            write-log -logFile $logFile -finishLogging
            exit 1
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully for domain: $domain" -LogLevel "Information"
        Write-Host "Configuration loaded successfully for domain: $domain" -ForegroundColor Green
    }
    # Clear the config content from memory
    $configContent = $null
}
else
{
    # Configuration file not found
    if ($testMode)
    {
        # In test mode, skip first run wizard and create minimal configuration
        Write-Verbose "[$scriptName] Test mode enabled: Skipping first run wizard and using default test configuration"
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping first run wizard" -LogLevel "Information"
        
        # Set default test values
        $domain = "test.contoso.com"
        $appId = "00000000-0000-0000-0000-000000000000"
        $tenantId = "00000000-0000-0000-0000-000000000000"
        $name = "Test Application"
        
        # Skip config file loading in test mode
        Write-Verbose "[$scriptName] Test mode: Using default test configuration without config file"
        $wizardResult = $true
    }
    else
    {
        # Configuration file not found - launch first run wizard
        Write-Host "Configuration file $configFile not found." -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file not found. Starting first run wizard" -LogLevel "Verbose"
        
        Write-Host "Starting first run wizard to set up your configuration..." -ForegroundColor Green
        
        # Launch the first run wizard (pass Silent switch if testMode is active)
        $wizardResult = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $InitFile -StringsFile "$PWD\strings.psd1" -Silent:$testMode
    }
    
    if ($wizardResult)
    {
        if (-not $testMode)
        {
            Write-Host "First run wizard completed successfully." -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $scriptName -Message "First run wizard completed successfully" -LogLevel "Information"
            
            # Now try to load the newly created configuration
            Write-Host "Loading the newly created configuration..." -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Loading newly created configuration file" -LogLevel "Information"
            
            # Re-run the configuration loading logic
            if (Test-Path $configFile)
            {
                # Initialize configuration session after wizard (use Silent mode if testMode is active)
                $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -UseStoredPassword -PasswordPrompt "Enter your password" -Silent:$testMode
                
                if (-not $sessionResult.Success)
                {
                    Write-Host "Configuration file exists but cannot be read: $($sessionResult.ErrorMessage)" -ForegroundColor Red
                    Write-Host "Please check file permissions and try again." -ForegroundColor Red
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file cannot be read: $($sessionResult.ErrorMessage)" -LogLevel "Warning"
                    write-log -logFile $logFile -finishLogging
                    exit 1
                }
                
                $configContent = $sessionResult.ConfigContent
                $domain = $sessionResult.Domain
                $appId = $sessionResult.AppId
                $tenantId = $sessionResult.TenantId
                $name = $sessionResult.Name
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully for domain: $domain" -LogLevel "Information"
                # Clear the config content from memory
                $configContent = $null
            }
            else
            {
                Write-Host "Configuration file was not created successfully." -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file was not created by wizard" -LogLevel "Error"
                write-log -logFile $logFile -finishLogging
                exit 1
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Test mode: Skipping configuration file loading"
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Using default test configuration" -LogLevel "Information"
        }
        
        #reload settings since they likely have changed.
        Write-Verbose "[$scriptName] Initializing application configuration since the earlier initialization attempt failed or did not take place."
        write-log -logFile $logFile -module $scriptName -message "Initializing application configuration since earlier attempt failed or did not take place."
        $configResult = Initialize-ApplicationConfiguration -InitFile $InitFile -StringsFile $stringsFile -menuFile $menuFile -Domain $domain -BoundParameters $PSBoundParameters
        if (-not $configResult.Success)
        {
            Write-Host "Error initializing configuration: $($configResult.ErrorMessage)" -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration initialization failed: $($configResult.ErrorMessage)" -LogLevel "Error"
            write-log -logFile $logFile -finishLogging
            exit 1
        }
        # Extract configuration results
        $auth = $configResult.Auth
        $globalSettings = $configResult.GlobalSettings
        $localSettings = $configResult.LocalSettings
        $requiredScopes = $configResult.RequiredScopes
        # Merge global and local settings into a single settings object
        Write-Verbose "[$scriptName] Merging global and local settings"
        $global:settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
        Write-Verbose "[$scriptName] Settings merged successfully. Final settings count: $($settings.Count)"
        Write-Verbose "[$scriptName] Configuration initialization completed successfully"
        Write-Verbose "[$scriptName] Auth settings count: $($auth.Count)"
        Write-Verbose "[$scriptName] Global settings count: $($globalSettings.Count)"
        Write-Verbose "[$scriptName] Local settings count: $($localSettings.Count)"
        Write-Verbose "[$scriptName] Merged settings count: $($settings.Count)"
        Write-Verbose "[$scriptName] Menus count: $($menus.Count)"
        Write-Verbose "[$scriptName] Required scopes count: $($requiredScopes.Count)"
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully. Menus: $($menus.Count), Scopes: $($requiredScopes.Count), Settings: $($settings.Count)" -LogLevel "Information"


    }
    else
    {
        Write-Host "First run wizard failed or was cancelled." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $scriptName -Message "First run wizard failed or was cancelled" -LogLevel "Error"
        Write-Host "Please create a configuration file manually." -ForegroundColor Yellow
        write-log -logFile $logFile -finishLogging
        exit 1
    }
}
#endregion Process login

#region initialize script
Write-Host "Loading configuration..."
# Use domain if available, otherwise default to contoso.com
$domainForDefaults = if ($domain)
{
    $domain
}
else
{
    "contoso.com"
}
$configResult = Initialize-ApplicationConfiguration -InitFile $InitFile -StringsFile $stringsFile -menuFile $menuFile -Domain $domainForDefaults -BoundParameters $PSBoundParameters
if (-not $configResult.Success)
{
    Write-Host "Error initializing configuration: $($configResult.ErrorMessage)" -ForegroundColor Red
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration initialization failed: $($configResult.ErrorMessage)" -LogLevel "Error"
    write-log -logFile $logFile -finishLogging
    exit 1
}
# Extract configuration results
$auth = $configResult.Auth
$globalSettings = $configResult.GlobalSettings
$localSettings = $configResult.LocalSettings
$requiredScopes = $configResult.RequiredScopes
# Merge global and local settings into a single settings object
Write-Verbose "[$scriptName] Merging global and local settings"
$global:settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
Write-Verbose "[$scriptName] Settings merged successfully. Final settings count: $($settings.Count)"
Write-Verbose "[$scriptName] Configuration initialization completed successfully"
Write-Verbose "[$scriptName] Auth settings count: $($auth.Count)"
Write-Verbose "[$scriptName] Global settings count: $($globalSettings.Count)"
Write-Verbose "[$scriptName] Local settings count: $($localSettings.Count)"
Write-Verbose "[$scriptName] Merged settings count: $($settings.Count)"
Write-Verbose "[$scriptName] Menus count: $($configResult.menu.Count)"
Write-Verbose "[$scriptName] Required scopes count: $($requiredScopes.Count)"
Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully. Menus: $($menus.Count), Scopes: $($requiredScopes.Count), Settings: $($settings.Count)" -LogLevel "Information"
if (-not $version.version)
{
    Write-Verbose "[$scriptName] Unable to get file version."
    #see if you can find it in the metadata.
    if ($appMetaData -and $appMetaData.version)
    {
        $version = $appMetaData.version
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Found version in metadata: $($version | Out-String)" -LogLevel "Verbose"
        Write-Verbose "[$scriptName] Found version in metadata: $($version | Out-String)"
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Unable to find version information. Defaulting to 1.0.0.0." -LogLevel "Warning"
        Write-Verbose "[$scriptName] Defaulting version to 1.0.0.0"
        $version = @{
            version     = [System.Version]::Parse('1.0.0.0')
            companyName = 'Zuhair Mahmoud'
            major       = 1
            minor       = 0
            build       = 0
            revision    = 0
        }
    }
}
#endregion Initialize script

#region Check for password change requirement
if ($testMode)
{
    Write-Verbose "[$scriptName] Test mode enabled, skipping password change check."
    write-log -logFile $logFile -Module $scriptName -Message "Test mode enabled, skipping password change check." -LogLevel "Information"
}
else 
{
    if ((Test-Path $configFile) -and $auth.changePWOnNextStart -eq $true)
    {
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change required (changePWOnNextStart=true)" -LogLevel "Information"
    
        # Need to reload configContent for password change process
        $tempSessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -UseStoredPassword -PasswordPrompt "Enter your password" -Silent:$testMode
        if ($tempSessionResult.Success)
        {
            $configContent = $tempSessionResult.ConfigContent
        
            # Invoke password change process
            $passwordChangeResult = Invoke-PasswordChangeProcess -ConfigFile $configFile -ConfigContent $configContent -SettingsFile $InitFile
            if ($passwordChangeResult)
            {
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change completed successfully" -LogLevel "Information"
                Write-Host "Password changed successfully. Please restart the application and log in with your new password." -ForegroundColor Green
                Write-Host "To do so, type 'main' and press enter when you see the command prompt." -ForegroundColor Green
                Write-Log -LogFile $LogFile -FinishLogging
                exit 0
            }
            else
            {
                Write-Host "Password change failed. Continuing with current password." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change failed. Continuing with current password." -LogLevel "Warning"
            }
        
            # Clear the config content from memory
            $configContent = $null
        }
        else
        {
            Write-Host "Failed to reload configuration for password change: $($tempSessionResult.ErrorMessage)" -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to reload configuration for password change: $($tempSessionResult.ErrorMessage)" -LogLevel "Error"
        }
    }
}
#endregion Check for password change requirement

#region Define variables
$scope = $auth.scope
# $DellDeviceHardwareDetailsURI = "deviceManagement/hardwarePasswordDetails. "
# $logfile = "mylog.log"
# $serialNumber = '0F3CFP724223KV'
# $serialNumber = 'BTSB25000BCR'
# $serialNumber = '5R3SBZ3'
# $userUri = "users"
# $groupUri = "groups"
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
# $accessToken = GetGraphAccessToken -configFile $configFile -deligated -scope $scope -AuthType 'MGGraph' -verbose 
$accessToken = GetGraphAccessToken -configFile $configFile -delegated -scope $scope -AuthType 'PublicAuthFlow'
# $accessToken = GetGraphAccessToken -configFile $configFile
# $autopilotDevices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken -extraParameters $autopilotExtraParameters -consistencyLevel -verbose
# $importedDevices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -consistencyLevel -extraParameters $importedAutopilotDeviceExtraParameters -verbose
# $unmanagedDevices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken
# $global:enrollments = [ordered] @{
# "autopilot" = $autopilotDevices
# "managed" = $managedDevices
# "imported"  = $importedDevices
# "unmanaged" = $unmanagedDevices
# }
#endregion Define variables

exit 0
#region Usage examples for GetGraphObjectMetadata
# Example 1: Get metadata for users collection
$usersResponse = CallGraphAPI -accessToken $accessToken -ResourcePath "users"
$usersMetadata = GetGraphObjectMetadata -ApiResponse $usersResponse -AccessToken $accessToken
Write-Host "Users Entity Metadata:"
$usersMetadata | Format-List

# Example 2: Get metadata for groups with sample queries
$groupsResponse = CallGraphAPI -accessToken $accessToken -ResourcePath "groups"
$groupsMetadata = GetGraphObjectMetadata -ApiResponse $groupsResponse -AccessToken $accessToken -IncludeSampleQueries $true
Write-Host "Groups Entity Metadata with Sample Queries:"
$groupsMetadata | Format-List

# Example 3: Get metadata for a single user entity
# Replace {userId} with a valid user ID
$userId = 'zuhair@arabictutor.com'
$singleUserResponse = CallGraphAPI -accessToken $accessToken -ResourcePath "users/$userId"
$userMetadata = GetGraphObjectMetadata -ApiResponse $singleUserResponse -AccessToken $accessToken
Write-Host "Single User Metadata:"
$userMetadata | Format-List
#endregion Usage examples for GetGraphObjectMetadata


