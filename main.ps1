<#
.SYNOPSIS
    Main entry point for the Intune Helpdesk Menu application.

.DESCRIPTION
    This PowerShell script initializes configuration, authentication, and menu structures for managing Windows Autopilot devices and related Intune operations.
    It supports exporting device lists, managing Autopilot profiles, updating application settings, and handling authentication with Microsoft Graph API.
    The script loads supporting functions from the 'functions' folder and provides a menu-driven interface for helpdesk and administrative tasks.

.PARAMETER configFile
    Path to the configuration file containing authentication details. Default: "$pwd\.secrets\config.json"

.PARAMETER InitFile
    Path to the initialization file containing application settings. Default: "$pwd\settings.psd1"

.PARAMETER stringsFile
    Path to the strings file containing localized text. Default: "$pwd\strings.psd1"

.PARAMETER menuFile
    Path to the menu configuration file. Default: "$pwd\menu.psd1"

.PARAMETER maxWaitTime
    Maximum wait time in seconds for API operations.

.PARAMETER timeInSeconds
    Time limit in seconds for specific operations.

.PARAMETER GroupTag
    Autopilot group tag to assign to devices during import operations.

.PARAMETER showLicenseBanner
    Display the license banner on application startup.

.PARAMETER showAuth
    Display authentication configuration details during startup.

.PARAMETER showVersion
    Display the application version information and exit.

.PARAMETER showSettings
    Display all application settings during startup.

.PARAMETER OverwriteLogs
    Overwrite existing log files instead of appending to them.

.PARAMETER SecureString
    Use secure string encryption for sensitive data.

.PARAMETER ResetAuth
    Reset authentication credentials and launch the authentication wizard.

.PARAMETER ForceNewToken
    Force retrieval of a new access token, ignoring cached tokens.

.PARAMETER delegated
    Use delegated authentication flow (requires user interaction).

.PARAMETER ForceNewRefreshToken
    Force retrieval of a new refresh token (delegated auth only).

.PARAMETER NoSaveRefreshToken
    Do not save refresh tokens to disk (delegated auth only).

.PARAMETER Scope
    Microsoft Graph API scopes to request (delegated auth only).

.PARAMETER AuthType
    Authentication type for delegated flow. Valid values: 'PublicAuthFlow', 'Interactive', 'Private'

.PARAMETER CacheType
    Token cache storage type. Valid values: 'file', 'memory'

.PARAMETER Repo
    Repository source for updates. Valid values: 'github', 'gitlab'

.PARAMETER Release
    Specific release version to use for updates.

.PARAMETER appMode
    Application mode determining available features. Valid values: 'full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom'

.PARAMETER LogFilePath
    Path to the log file. Default: "$pwd\Logs\Autopilot.log"

.PARAMETER LogLevel
    Logging level for the application. Valid values: 'Error', 'Warning', 'Information', 'Verbose', 'Debug'

.PARAMETER testMode
    Enable test mode to skip interactive prompts and menu display. Used primarily for automated testing.

.PARAMETER testModeMetadata
    Test mode: Enable metadata initialization phase (default: true). Only effective with -testMode.

.PARAMETER testModeCleanup
    Test mode: Enable temporary file cleanup phase (default: true). Only effective with -testMode.

.PARAMETER testModeMigration
    Test mode: Enable settings migration check phase (default: true). Only effective with -testMode.

.PARAMETER testModeConfig
    Test mode: Enable configuration loading phase (default: true). Only effective with -testMode.

.PARAMETER testModeAuth
    Test mode: Enable authentication phase (default: false). Only effective with -testMode.

.PARAMETER testModeLegacyMigration
    Test mode: Enable legacy migration phase (default: false). Only effective with -testMode.

.PARAMETER testModeExitAfter
    Test mode: Exit after initialization phases complete (default: true). Only effective with -testMode.

.PARAMETER TestPassword
    Test password for encryption operations during test mode. Only works with -testMode.

.EXAMPLE
    .\main.ps1
    Run the application with default settings and display the main menu.

.EXAMPLE
    .\main.ps1 -showVersion
    Display version information and exit without launching the menu.

.EXAMPLE
    .\main.ps1 -appMode helpDesk -LogLevel Verbose
    Launch the application in help desk mode with verbose logging.

.EXAMPLE
    .\main.ps1 -delegated -AuthType Interactive -Scope "DeviceManagementManagedDevices.ReadWrite.All"
    Use delegated authentication with interactive login and specific Graph API scopes.

.EXAMPLE
    .\main.ps1 -ResetAuth
    Reset authentication credentials and launch the first-run wizard.

.EXAMPLE
    .\main.ps1 -GroupTag "IT-Devices" -OverwriteLogs -LogLevel Debug
    Run with a specific group tag for Autopilot imports, overwrite existing logs, and enable debug logging.

.EXAMPLE
    .\main.ps1 -configFile "C:\Config\custom-config.json" -InitFile "C:\Config\custom-settings.psd1"
    Use custom configuration and settings files instead of defaults.

.EXAMPLE
    .\main.ps1 -ForceNewToken -CacheType memory
    Force a new access token and store it in memory only (not on disk).

.EXAMPLE
    .\main.ps1 -testMode -testModeMetadata -testModeExitAfter
    Run in test mode, only testing metadata initialization phase then exit.

.LINK
    Project Repository: https://github.com/zuhairmahd/autopilot

.NOTES
    Author: Zuhair Mahmoud
    Copyright: (c) 2024 Zuhair Mahmoud
    License: MIT License

    Project URL: https://github.com/zuhairmahd/autopilot

    Prerequisites:
    - PowerShell 5.1 or later
    - Microsoft Graph PowerShell modules
    - Appropriate permissions in Microsoft Intune/Entra ID

    First Run:
    If no configuration file exists, the script will launch a first-run wizard to set up authentication and basic settings.

    Authentication:
    The script supports both application (client credentials) and delegated (user interactive) authentication flows.
    Configuration is stored securely with encryption.

    Logging:
    All operations are logged to the specified log file. Use -LogLevel to control verbosity.
    Use -OverwriteLogs to start with a fresh log file on each run.
#>

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
    [switch]$HideEmptyMenus,
    [switch]$showAuth,
    [switch]$clearCache,
    [switch]$showVersion,
    [switch]$showSettings,
    [switch]$OverwriteLogs,
    [switch]$SecureString,
    [bool]$autoUpdate,
    [switch]$testMode,
    [switch]$testModeMetadata,
    [switch]$testModeCleanup,
    [switch]$testModeMigration,
    [switch]$testModeConfig,
    [switch]$testModeAuth,
    [switch]$testModeLegacyMigration,
    [switch]$testModeExitAfter,
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

#region Initialize test mode
# Store test password in script scope if provided (only works with testMode for security)
if ($testMode -and $TestPassword)
{
    $script:UserEncryptionPassword = $TestPassword
    $global:UserEncryptionPassword = $TestPassword
}

# Initialize testModeOptions with defaults if testMode is enabled
function Get-TestModeOption()
{
    param(
        [string]$ParameterName,
        $DefaultValue
    )
    if ($PSBoundParameters.ContainsKey($ParameterName))
    {
        return (Get-Variable -Name $ParameterName -Scope 1).Value.IsPresent
    }
    else
    {
        return $DefaultValue
    }
}

if ($testMode)
{
    # Default test mode options - only execute essential phases unless specified
    $defaultTestModeOptions = @{
        metadata        = Get-TestModeOption -ParameterName 'testModeMetadata' -DefaultValue $true
        cleanup         = Get-TestModeOption -ParameterName 'testModeCleanup' -DefaultValue $true
        migration       = Get-TestModeOption -ParameterName 'testModeMigration' -DefaultValue $true
        config          = Get-TestModeOption -ParameterName 'testModeConfig' -DefaultValue $true
        auth            = Get-TestModeOption -ParameterName 'testModeAuth' -DefaultValue $false
        legacyMigration = Get-TestModeOption -ParameterName 'testModeLegacyMigration' -DefaultValue $false
        menu            = $false  # Never show menu in test mode
        exitAfter       = Get-TestModeOption -ParameterName 'testModeExitAfter' -DefaultValue $true
    }

    # Store in script scope
    $script:testModeOptions = $defaultTestModeOptions

    Write-Verbose "[$scriptName] Test mode options initialized: $($script:testModeOptions | ConvertTo-Json -Compress)"
}
#endregion Initialize test mode

#region Initialize script variables
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
#endregion Initialize script variables

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

    # Check if metadata phase should be executed
    if ($script:testModeOptions.metadata)
    {
        $appMetaData = Get-ApplicationMetaData -GlobalSettingsFile $InitFile -scriptName $scriptName -scriptPath $ScriptPath -Silent
    }
    else
    {
        Write-Verbose "[$scriptName] Test mode: Skipping metadata initialization (testModeOptions.metadata = false)"
        write-log -logFile $logFile -module $scriptName -message "Test mode: Skipping metadata initialization"
        # Set minimal metadata for scripts that need it
        $appMetaData = @{
            version     = New-Object System.Version 0, 0, 0, 0
            companyName = "Test"
            release     = "test"
        }
    }
}
else
{
    Write-Verbose "[$scriptName] Initializing application metadata"
    write-log -logFile $logFile -module $scriptName -message "Initializing application metadata"
    $appMetaData = Get-ApplicationMetaData -GlobalSettingsFile $InitFile -scriptName $scriptName -scriptPath $ScriptPath
}
if ($null -ne $appMetaData.corporateSettings -and $appMetaData.corporateSettings.useCorporateSettings -and $null -ne $appMetaData.corporateSettings.corporateSettingsFilePaths -and $appMetaData.corporateSettings.corporateSettingsFilePaths.count -gt 0)
{
    $fileCopied = $false
    $domain = if ($appMetaData.corporateSettings.corporateDomain)
    {
        $appMetaData.corporateSettings.corporateDomain
    }
    else
    {
        $appMetaData.domain
    }
    if ([string]::IsNullOrWhiteSpace($domain))
    {
        Write-Host "Error: Corporate domain is not specified. Skipping corporate settings file operations." -ForegroundColor Red
        write-log -logFile $logFile -module $scriptName -Message "Corporate domain is not specified. Skipping corporate settings file operations." -LogLevel "Error"
        return
    }
    $localDomainFileName = Join-Path -Path $scriptPath -ChildPath "$domain.psd1"
    Write-Verbose "[$scriptName] Checking $($appMetaData.corporateSettings.corporateSettingsFilePaths) paths for corporate settings for domain: $domain"
    write-log -logFile $logFile -module $scriptName -Message "Checking $($appMetaData.corporateSettings.corporateSettingsFilePaths) paths for corporate settings for domain: $domain"
    for ($i = 0; $i -lt $appMetaData.corporateSettings.corporateSettingsFilePaths.count; $i++)
    {
        $path = $appMetaData.corporateSettings.corporateSettingsFilePaths[$i]
        $domainFileName = Join-Path -Path $path -ChildPath "$domain.psd1"
        Write-Verbose "[$scriptName] Checking path: $path for corporate settings file."
        write-log -logFile $logFile -module $scriptName -Message "Checking path: $path for corporate settings file."
        if (-not (Test-Path $domainFileName -ErrorAction SilentlyContinue))
        {
            Write-Verbose "[$scriptName] Path does not exist: $path"
            write-log -logFile $logFile -module $scriptName -Message "Path does not exist: $path"
            continue
        }
        Write-Verbose "[$scriptName] Found corporate settings file: $domainFileName"
        write-log -logFile $logFile -module $scriptName -Message "Found corporate settings file: $domainFileName"
        try
        {
            Copy-Item -Path $domainFileName -Destination $localDomainFileName -Force -ErrorAction Stop
            $fileCopied = $true
            write-log -logFile $logFile -module $scriptName -Message "Successfully copied corporate settings from $domainFileName to $localDomainFileName"
            Write-Verbose "[$scriptName] Successfully copied corporate settings from $domainFileName to $localDomainFileName"
            $numberOfBeeps = 4
            for ($i = 0; $i -lt $numberOfBeeps; $i++)
            {
                [console]::beep(150, 80)
            }
            break
        }
        catch
        {
            Write-Error "[$scriptName] Error copying corporate settings file: $_"
            write-log -logFile $logFile -module $scriptName -Message "Error copying corporate settings file: $_" -LogLevel "Error"
            if ($i -lt ($appMetaData.corporateSettings.corporateSettingsFilePaths.count - 1))
            {
                Write-Host "Trying next path if available..." -ForegroundColor Yellow
                write-log -logFile $logFile -module $scriptName -Message "Trying next path if available..."
            }
            else
            {
                Write-Host "No more paths to try." -ForegroundColor Yellow
                write-log -logFile $logFile -module $scriptName -Message "No more paths to try."
            }
        }
    }
    if ($fileCopied)
    {
        Write-Host "Corporate settings file copied successfully." -ForegroundColor Green
        Write-Verbose "[$scriptName] Corporate settings file copied successfully."
        write-log -logFile $logFile -module $scriptName -Message "Corporate settings file copied successfully."
    }
    else
    {
        Write-Host "No files were copied from all specified paths." -ForegroundColor Red
        write-log -logFile $logFile -module $scriptName -Message "Failed to copy corporate settings file from all specified paths." -LogLevel "Error"
    }
}
else
{
    Write-Verbose "[$scriptName] Corporate settings not enabled or no paths specified."
    write-log -logFile $logFile -module $scriptName -Message "Corporate settings not enabled or no paths specified."
}
$version = if ($null -ne $appMetaData.version)
{
    $appMetaData.version
}
else
{
    New-Object System.Version 0, 0, 0, 0
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
if ($testMode -and -not $script:testModeOptions.cleanup)
{
    Write-Verbose "[$scriptName] Test mode: Skipping temporary file cleanup (testModeOptions.cleanup = false)"
    write-log -logFile $logFile -module $scriptName -message "Test mode: Skipping temporary file cleanup"
    # Create minimal cleanup result
    $filesCleaned = @{
        AllRemoved        = $true
        RemovedFilesCount = 0
        FailedFilesCount  = 0
    }
}
else
{
    $filesCleaned = cleanupTempFiles
    if ($filesCleaned.AllRemoved)
    {
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "All temporary files were cleaned." -LogLevel "Information"
    }
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files found: $($filesCleaned.RemovedFilesCount)" -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files removed: $($filesCleaned.RemovedFilesCount)" -LogLevel "Information"
}

#Check for settings migration
if ($testMode -and -not $script:testModeOptions.migration)
{
    Write-Verbose "[$scriptName] Test mode: Skipping settings migration check (testModeOptions.migration = false)"
    write-log -logFile $logFile -module $scriptName -message "Test mode: Skipping settings migration check"
    $migrationCheck = @{ MigrationNeeded = $false }
}
else
{
    write-log -logFile $logFile -module $scriptName -message "Checking for settings migration need." -LogLevel "Information"
    Write-Verbose "[$scriptName] Checking for settings migration need."
    $migrationCheck = Invoke-SettingsMigration -RemoveJsonFiles -Force
}
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

#clear cache if requested
if ($clearCache)
{
    $clearedCache = Invoke-CacheManagement -Action Clear -ShowDetails
    if ($clearedCache.Action -eq 'Clear' -and $clearedCache.CachesCleared -ge 0)
    {
        Write-Host "Cache cleared." -ForegroundColor Green
    }
    else
    {
        Write-Host "No cache files to clear." -ForegroundColor Yellow
    }
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
# Skip config loading entirely if testMode and config flag is false
if ($testMode -and -not $script:testModeOptions.config)
{
    Write-Verbose "[$scriptName] Test mode: Skipping configuration loading (testModeOptions.config = false)"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping configuration loading" -LogLevel "Information"
    # Set minimal test values
    $domain = "test.contoso.com"
    $appId = "00000000-0000-0000-0000-000000000000"
    $tenantId = "00000000-0000-0000-0000-000000000000"
    $name = "Test Application"
}
# In test mode without a test password and config file exists, skip config loading
elseif ($testMode -and -not $TestPassword -and (Test-Path $configFile))
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
        $repoInfo = $configResult.RepoInfo
        $global:cacheSettings = $configResult.CacheSettings
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

#region initialize script objects
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
$repoInfo = $configResult.RepoInfo
$global:cacheSettings = $configResult.CacheSettings
# Merge global and local settings into a single settings object
Write-Verbose "[$scriptName] Merging global and local settings"
$global:settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
# Make sure we are using the correct domain in settings
if ($settings.domain -ne $domain)
{
    Write-Verbose "[$scriptName] Updating settings domain from $($settings.domain) to $domain"
    write-log -logFile $logFile -module $scriptName -message "Updating settings domain from $($settings.domain) to $domain"
    Write-Warning "[$scriptName] Settings domain updated from $($settings.domain) to $domain"
    $settings.domain = $domain
}
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
#endregion Initialize script objects

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
#define repo parameters
$defaultBranch = 'master'
$baseSourceURL = if ($repoInfo.baseSourceURL)
{
    $repoInfo.baseSourceURL
}
else
{
    'https://raw.githubusercontent.com'
}
Write-Log -logFile $LogFile -Module $scriptName -Message "Base source URL: $baseSourceURL" -LogLevel "Information"
$baseURL = if ($repoInfo.baseURL)
{
    $repoInfo.baseURL
}
else
{
    "https://www.github.com"
}
Write-Log -logFile $LogFile -Module $scriptName -Message "Base URL: $baseURL" -LogLevel "Information"
$repoPath = if ($repoInfo.repoPath)
{
    $repoInfo.repoPath
}
else
{
    'zuhairmahd'
}
Write-Log -LogFile $LogFile -Module $scriptName -Message "Repository path: $repoPath" -LogLevel "Information"
$repoName = if ($repoInfo.repoName)
{
    $repoInfo.repoName
}
else
{
    'autopilot'
}
Write-Log -LogFile $LogFile -Module $scriptName -Message "Repository name: $repoName" -LogLevel "Information"
$latestRelease = if ($settings.Release)
{
    if ($settings.Release -eq 'auto')
    {
        Write-Log -logFile $LogFile -Module $scriptName -Message "Latest release is set to 'auto'. Fetching the latest release from GitHub." -LogLevel "Information"
        $tempRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
        Write-Log -logFile $LogFile -Module $scriptName -Message "Latest release fetched: $tempRelease" -LogLevel "Information"
    }
    else
    {
        $tempRelease = $settings.Release
    }
    $tempRelease
}
else
{
    $defaultBranch
}
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
$updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL -executableFileName "$scriptPath\$scriptName"
Write-Verbose "[$scriptName] Update available: $($updateAvailable.updateAvailable), Remote version: $($updateAvailable.version | Out-String)"
write-log -logFile $LogFile -Module $scriptName -Message "Update available: $($updateAvailable.updateAvailable), Remote version: $($updateAvailable.version | Out-String)" -LogLevel "Information"
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
        Write-Host "Setting $($key): $($settings[$key])" -ForegroundColor Cyan
    }
}
Write-Verbose "[$scriptName] Auth configuration loaded from $configFile"
$getTokenParams = BuildAuthSplatTable -auth $auth
foreach ($key in $getTokenParams.Keys)
{
    Write-Verbose "[$scriptName] $($key): $($getTokenParams[$key])"
}
if ($showAuth)
{
    Write-Host "$($key): $($getTokenParams[$key])" -ForegroundColor Cyan
    $global:previousMenu = New-Object System.Collections.Hashtable
    # Device enrollment state cache content has been migrated to the unified cache system.
}
Write-Verbose "[$scriptName] Using authentication parameters: $($getTokenParams | ConvertTo-Json -Depth $maxJSONDepth)"
Write-Verbose "[$scriptName] Loading strings from: $stringsFile"
$loadedStrings = $configResult.strings
$global:returnValues = $loadedStrings.returnValues
$deviceStates = $loadedStrings.deviceStates
$deviceActions = $loadedStrings.deviceActions
Write-Verbose "[$scriptName] Loaded $($returnValues.Count) return values, $($deviceStates.Count) device states, and $($deviceActions.Count) device actions"
# Initialize navigation context variables
$Global:History = [System.Collections.ArrayList]::new()
$Global:MenuHistory = [System.Collections.ArrayList]::new()
$global:previousMenu = New-Object System.Collections.Hashtable
#endregion Define variables

#region banner
Write-Host "Welcome to the Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))" -ForegroundColor Green
Write-Host "Copyright (c) $((Get-Date).Year) $($appMetaData.companyName)" -ForegroundColor Cyan
if ($settings.showLicenseBanner)
{
    Write-Host "==========================================================`n" -ForegroundColor White
    Write-Host "This script is licensed under the MIT License." -ForegroundColor White
    Write-Host "For more information and to read the license terms, visit: https://opensource.org/licenses/MIT" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "Report issues at $baseURL/$repoPath/$repoName/issues" -ForegroundColor White
    Write-Host "For the changeLog, go to $baseURL/$repoPath/$repoName/releases" -ForegroundColor White
    Write-Host "==========================================================`n" -ForegroundColor White
    Write-Host " DISCLAIMER: This script is provided AS IS without warranty of any kind." -ForegroundColor Red
    Write-Host "The author makes no guarantees about the script's functionality or suitability for any purpose." -ForegroundColor Red
    Write-Host "It is your responsibility to test and validate the script in your environment before using it." -ForegroundColor Red
    Write-Host "Use at your own risk. The author is not responsible for any damage or data loss." -ForegroundColor Red
    Write-Host "==========================================================`n" -ForegroundColor White
}
if ($updateAvailable.success -and $updateAvailable.updateAvailable)
{
    Write-Verbose "[$scriptName] An update is available: $($updateAvailable.version.major).$($updateAvailable.version.minor).$($updateAvailable.version.build) ($($updateAvailable.version.revision))"
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "An update is available: $($updateAvailable.version.major).$($updateAvailable.version.minor).$($updateAvailable.version.build) (revision $($updateAvailable.version.revision))"
    Write-Host "==========================================================`n" -ForegroundColor Yellow
    Write-Host "An update is available to version $($updateAvailable.version.major).$($updateAvailable.version.minor).$($updateAvailable.version.build) (revision $($updateAvailable.version.revision))" -ForegroundColor Yellow
    Write-Host "Release date: $($updateAvailable.ReleaseDate | FormatDateWithTimeZone)" -ForegroundColor Yellow
    Write-Host "Release notes: $($updateAvailable.releaseNotes)" -ForegroundColor Yellow
    if ($settings.autoUpdate)
    {
        Write-Host "Automatic updates are enabled." -ForegroundColor Green
        Write-Host "The script will now attempt to update itself." -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Automatic updates are enabled. The script will now attempt to update itself." -LogLevel "Information"
        $updateResult = Get-Updates -executableFileName "$scriptPath\$scriptName" -updateURL $updateURL -metaDataURL $remoteVersionURL -filesToUpdate @($stringsFile, $menuFile) -noConfirmation
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Update result: $updateResult" -LogLevel "Information"
        switch ($updateResult)
        {
            $returnValues.UpdateSuccessMessage
            {
                Write-Host 'The script has been updated.' -ForegroundColor Green
                Write-Host 'Please restart the script.' -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module "$scriptName" -Message "The script has been updated. Please restart the script." -LogLevel "Information"
                Write-Log -LogFile $LogFile -finishLogging
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
    else
    {
        Write-Host "Please run the update command to get the latest version." -ForegroundColor Yellow
        Write-Host "==========================================================`n" -ForegroundColor Yellow
    }
}
else
{
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "No updates available or current script is up to date." -LogLevel "Information"
}
#endregion banner

#region initialization block with access token
if ($ResetAuth)
{
    Write-Verbose "[$scriptName] Resetting authentication..."
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Resetting authentication as requested by user" -LogLevel "Information"
    if (Start-FirstRunWizard -authOnly)
    {
        Write-Host "The authentication information has been changed." -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $scriptName -Message "The authentication information has been changed." -LogLevel "Information"
    }
    else
    {
        Write-Host "Failed to change the authentication information." -ForegroundColor Red
        Write-Host "Please check the logs for more information." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to change the authentication information." -LogLevel "Error"
        Write-Log -logFile $LogFile -finishLogging
        exit 1
    }
}
Write-Host "Retrieving access token..."
Write-Verbose "[$scriptName] Initialization block started."
Write-Log -LogFile $LogFile -Module $scriptName -Message "Initialization block started" -LogLevel "Information"

if ($testMode -and -not $script:testModeOptions.auth)
{
    Write-Verbose "[$scriptName] Test mode: Skipping Graph API token retrieval (testModeOptions.auth = false)"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping Graph API authentication" -LogLevel "Information"
    $accessToken = "test-mode-fake-token"
}
elseif ($testMode)
{
    Write-Verbose "[$scriptName] Test mode: Skipping Graph API token retrieval but auth testing enabled"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping Graph API authentication" -LogLevel "Information"
    $accessToken = "test-mode-fake-token"
}
else
{
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Force new token: $($auth.ForceNewToken )" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Force new refresh token: $($auth.ForceNewRefreshToken )" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "No save refresh token: $($auth.NoSaveRefreshToken )" -LogLevel "Information"
    Write-Log -logFile $LogFile -Module $scriptName -Message "Getting access token..." -LogLevel "Information"

    $accessToken = GetGraphAccessToken @getTokenParams
}
# Clear the cached user password now that authentication is complete
if ($script:UserEncryptionPassword)
{
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Clearing cached user password after authentication" -LogLevel "Information"
    Clear-SecureMemory -Variables @("UserEncryptionPassword")
}

if ($accessToken)
{
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Access token retrieved successfully." -LogLevel "Information"

    # Validate scope availability for the retrieved access token
    if ($settings.validateScopes -and $auth.delegated)
    {
        Write-Verbose "[$scriptName] Validating Microsoft Graph API scope availability..."
        Write-Host "Validating Microsoft Graph API scope availability..."
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Starting scope validation for retrieved access token" -LogLevel "Verbose"
        try
        {
            # Get the current requested scopes for delegated authentication
            Write-Log -logFile $LogFile -Module $scriptName -Message "Getting current requested scopes for delegated authentication" -LogLevel "Information"
            # Perform scope validation
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Performing scope validation..." -LogLevel "Information"
            $scopeValidation = Test-ScopeAvailability -AccessToken $accessToken -RequiredScopes $requiredScopes -AuthConfiguration $auth
            if ($scopeValidation.HasAllRequiredScopes)
            {
                Write-Log -LogFile $LogFile -Module $scriptName -Message "All required Microsoft Graph scopes are available" -LogLevel "Information"
                Write-Verbose "[$scriptName] All required Microsoft Graph scopes are available."
                Write-Host "All required Microsoft Graph scopes are available." -ForegroundColor Green
            }
            else
            {
                Write-Host ""
                Write-Host "Microsoft Graph Scope Validation Results:" -ForegroundColor Yellow
                Write-Host "Some required permissions are missing. This may limit functionality." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Some required Microsoft Graph permissions are missing. This may limit functionality." -LogLevel "Warning"
                Write-Verbose "[$scriptName] Some required Microsoft Graph permissions are missing. This may limit functionality."
                # Show missing scopes in verbose mode or if user wants details
                if ($scopeValidation.MissingScopes.Count -gt 0)
                {
                    Write-Host "`nMissing permissions:" -ForegroundColor Cyan
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Missing permissions:" -LogLevel "Information"
                    foreach ($missingScope in $scopeValidation.MissingScopes)
                    {
                        Write-Host "  - $($missingScope.Scope)" -ForegroundColor White
                        Write-Host "    Impact: $($missingScope.Reason)" -ForegroundColor Gray
                        Write-Log -LogFile $LogFile -Module $scriptName -Message "  - $($missingScope.Scope)`n    Impact: $($missingScope.Reason)" -LogLevel "Information"
                    }
                }
                Write-Host "`nRecommended action:`n $($scopeValidation.RecommendedAction)" -ForegroundColor Cyan
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Recommended action: $($scopeValidation.RecommendedAction)" -LogLevel "Information"
                # For delegated authentication, offer to request additional scopes
                if ($auth.Delegated -eq $true -and -not ($auth.ForceNewToken -or $auth.ForceNewRefreshToken -or $auth.NoSaveRefreshToken))
                {
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Requesting additional scopes..." -LogLevel "Information"
                    Write-Host ""
                    $scopeRequest = Request-AdditionalScopes -MissingScopes $scopeValidation.MissingScopes -AuthConfiguration $auth -CurrentScopes $currentRequestedScopes -AuthParams $getTokenParams
                    if ($scopeRequest.Success)
                    {
                        Write-Host "Successfully obtained additional permissions!" -ForegroundColor Green
                        $accessToken = $scopeRequest.NewAccessToken
                        Write-Log -LogFile $LogFile -Module $scriptName -Message "Successfully updated access token with additional scopes" -LogLevel "Information"
                    }
                    elseif ($scopeRequest.UserCancelled)
                    {
                        Write-Host "Continuing with current permissions. Some features may be unavailable." -ForegroundColor Yellow
                        Write-Log -LogFile $LogFile -Module $scriptName -Message "User cancelled additional scope request" -LogLevel "Information"
                    }
                    else
                    {
                        Write-Host "Could not obtain additional permissions: $($scopeRequest.ErrorMessage)" -ForegroundColor Red
                        Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to obtain additional scopes: $($scopeRequest.ErrorMessage)" -LogLevel "Warning"
                    }
                }
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Write-Host ""
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Scope validation completed with $($scopeValidation.MissingScopes.Count) missing scopes" -LogLevel "Warning"
            }
        }
        catch
        {
            Write-Warning "[$scriptName] Scope validation failed: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Scope validation failed: $($_.Exception.Message)" -LogLevel "Error"
            Write-Host "Could not validate Microsoft Graph API permissions. Continuing..." -ForegroundColor Yellow
        }
    }
    if ($auth.ForceNewToken -or $auth.ForceNewRefreshToken -or $auth.NoSaveRefreshToken)
    {
        Write-Host "Forced new token retrieval due to parameters." -ForegroundColor Cyan
        Write-Host "The script will now exit."
        Write-Host "You can run the script again without these parameters to use the new token."
        Write-Verbose "[$scriptName] Exiting script due to forced new token retrieval."
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Exiting script due to forced new token retrieval." -LogLevel "Information"
        write-log -logFile $logFile -finishLogging
        exit 0
    }
    Write-Host "Access token retrieved successfully." -ForegroundColor Green
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
        write-log -logFile $logFile -module $scriptName -message "Exiting script due to authentication failure." -LogLevel "Error"
        write-log -logFile $logFile -finishLogging
        exit 1
    }
}
if ($testMode -and -not $script:testModeOptions.legacyMigration)
{
    Write-Verbose "[$scriptName] Test mode: Skipping legacy configuration migration (testModeOptions.legacyMigration = false)"
    write-log -logFile $logFile -module $scriptName -message "Test mode: Skipping legacy configuration migration" -LogLevel "Information"
}
elseif ($testMode)
{
    Write-Verbose "[$scriptName] Test mode enabled, skipping legacy configuration migration."
    write-log -logFile $logFile -module $scriptName -message "Test mode enabled, skipping legacy configuration migration." -LogLevel "Information"
}
else
{
    Write-Verbose "[$scriptName] Migrate legacy configuration: $($settings.migrateLegacyConfiguration)"
    write-log -logFile $logFile -module $scriptName -message "Migrate legacy configuration: $($settings.migrateLegacyConfiguration)" -LogLevel "Information"
    if ($settings.migrateLegacyConfiguration)
    {
        Write-Verbose "Starting migration of legacy configuration"
        write-log -logFile $logFile -module $scriptName -message "Starting migration of legacy configuration." -LogLevel "Information"
        $resolvedLegacyObjects = Resolve-MigratedLegacyObjects -accessToken $accessToken -settings $settings -domain $domain -SettingsFile $InitFile
        write-log -logFile $logFile -module $scriptName -message "Resolved migrated legacy objects: $($resolvedLegacyObjects | Out-String)" -LogLevel "Information"
        $newSetting = @{
            migrateLegacyConfiguration = $settings.migrateLegacyConfiguration
        }
        # Check if resolution was not needed (all objects already have IDs or no objects exist)
        if ($resolvedLegacyObjects.resolutionNeeded -eq $false)
        {
            Write-Verbose "[$scriptName] No legacy object resolution needed. All objects already resolved or no objects found."
            write-log -logFile $logFile -module $scriptName -message "No legacy object resolution needed. Setting migrateLegacyConfiguration to false." -LogLevel "Information"
            # Turn off the migration flag since no work is needed
            $newSetting = @{
                migrateLegacyConfiguration = $false
            }
        }
        # Check if user deferred the resolution
        elseif ($resolvedLegacyObjects.userDeferred)
        {
            Write-Host "Legacy object resolution has been deferred." -ForegroundColor Yellow
            Write-Host "You will be prompted again the next time the script starts." -ForegroundColor Yellow
            write-log -logFile $logFile -module $scriptName -message "User deferred legacy object resolution. Will prompt on next start." -LogLevel "Information"
            # Keep migrateLegacyConfiguration as true so user is prompted next time
            $newSetting = @{
                migrateLegacyConfiguration = $true
            }
        }
        elseif ($resolvedLegacyObjects.success)
        {
            Write-Host "Successfully resolved $($resolvedLegacyObjects.totalResolved) legacy objects"
            write-log -logFile $logFile -module $scriptName -message "Successfully resolved $($resolvedLegacyObjects.totalResolved) legacy objects." -LogLevel "Information"
            $newSetting = @{
                migrateLegacyConfiguration = $false
            }
        }
        else
        {
            Write-Host "Failed to resolve legacy objects." -ForegroundColor Red
            write-log -logFile $logFile -module $scriptName -message "Failed to resolve legacy objects." -LogLevel "Error"
            $retry = Read-Host "Would you like to be prompted to resolve them the next time the script starts? (yes/no)"
            write-log -logFile $logFile -module $scriptName -message "User chose to be prompted to resolve legacy objects on next start: $retry" -LogLevel "Information"
            Write-Verbose "User chose to be prompted to resolve legacy objects on next start: $retry"
            while ($retry -notin @('yes', 'no', 'y', 'n'))
            {
                Write-Host "Invalid choice. Please enter 'yes' or 'no'."
                [console]::beep()
                $retry = Read-Host "Would you like to be prompted to resolve them the next time the script starts? (yes/no)"
            }
            if ($retry -in @('no', 'n'))
            {
                Write-Verbose "User chose not to be prompted to resolve legacy objects on next start."
                write-log -logFile $logFile -module $scriptName -message "User chose not to be prompted to resolve legacy objects on next start." -LogLevel "Information"
                $newSetting = @{
                    migrateLegacyConfiguration = $false
                }
            }
            else
            {
                Write-Host "You will be prompted to resolve them the next time the script starts."
                write-log -logFile $logFile -module $scriptName -message "User chose to be prompted to resolve legacy objects on next start." -LogLevel "Information"
                $newSetting = @{
                    migrateLegacyConfiguration = $true
                }
            }
        }
        if ($newSetting.migrateLegacyConfiguration -ne $settings.migrateLegacyConfiguration)
        {
            $updatedSetting = Update-Setting -SettingType "Domain" -DomainName $domain -Settings $newSetting -SettingsFile $InitFile -MergeSettings
            write-log -logFile $logFile -module $scriptName -message "Settings updated: $($updatedSetting | Out-String)" -LogLevel "Information"
            if ($updatedSetting)
            {
                Write-Host "Settings updated successfully." -ForegroundColor Green
                write-log -logFile $logFile -module $scriptName -message "Settings updated successfully." -LogLevel "Information"
                Write-Host "`nPress any key to continue"
                $null = $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
            }
            else
            {
                Write-Host "Failed to update settings." -ForegroundColor Red
                write-log -logFile $logFile -module $scriptName -message "Failed to update settings." -LogLevel "Error"
                Write-Host "`nPress any key to continue"
                $null = $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
            }
        }
        else
        {
            Write-Verbose "No changes made to migrateLegacyConfiguration setting."
            write-log -logFile $logFile -module $scriptName -message "No changes made to migrateLegacyConfiguration setting." -LogLevel "Information"
        }
    }
}

# Early exit point for test mode when exitAfter is true
if ($testMode -and $script:testModeOptions.exitAfter)
{
    Write-Verbose "[$scriptName] Test mode: Exiting after initialization phases (testModeOptions.exitAfter = true)"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Exiting after initialization phases complete" -LogLevel "Information"
    Write-Host "Test mode: Initialization phases completed successfully" -ForegroundColor Green

    # Cleanup before exit
    Clear-SecureMemory -ClearScriptVariables
    Write-Log -LogFile $LogFile -FinishLogging
    exit 0
}
#endregion initialization block with access token

#region Create menus
# Clear menu configuration cache to ensure fresh menu loading
# Write-Verbose "[$scriptName] Clearing menu configuration cache"
# Invoke-CacheManagement -Action ClearSpecific -CacheType Menu
#Now load the menu configuration
$menuConfig = $configResult.menu
if ($menuConfig)
{
    # Convert the flat menu.psd1 structure to array format for Test-MenuItemIncluded
    foreach ($menuName in $menuConfig.keys)
    {
        Write-Verbose "[$scriptName] Loading menu: $menuName"
        $menu = $menuConfig.$menuName
        if ($menu.items)
        {
            $script:menus += $menu.items
        }
    }
    Write-Verbose "Loaded $($script:menus.Count) menu items for filtering"
}
$mainMenu = NewMenu -MenuName "mainMenu"
$CheckMenu = NewMenu -MenuName "checkMenu"
$serialNumberMenu = NewMenu -MenuName "serialNumberMenu"
$exportMenu = NewMenu -MenuName "exportMenu"
$settingsMenu = NewMenu -MenuName "settingsMenu"
$autopilotMenu = NewMenu -MenuName "autopilotMenu"
$environmentMenu = NewMenu -MenuName "environmentMenu"
$inclusionExclusionMenu = NewMenu -MenuName "inclusionExclusionMenu"
$deviceReportsMenu = NewMenu -MenuName "deviceReportsMenu"
$getGroupAssignmentsMenu = NewMenu -MenuName "getGroupAssignmentsMenu"
#endregion Create menus

#region export menu
$exportMenu = addMenuItem -menu $exportMenu -name 'Export Device Assignment Reports' -SubMenu $deviceReportsMenu
$exportMenu = AddMenuItem -menu $exportMenu -name "Export Autopilot Devices" -Action {
    $exported = Export-DeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'autopilot'
    if ($exported.success)
    {
        Write-Host $exported.message -ForegroundColor Green
    }
    else
    {
        Write-Host $exported.message -ForegroundColor Red
    }
}
$exportMenu = AddMenuItem -menu $exportMenu -name "Export Imported Autopilot Devices" -Action {
    $exported = Export-DeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'imported'
    if ($exported.success)
    {
        Write-Host $exported.message -ForegroundColor Green
    }
    else
    {
        Write-Host $exported.message -ForegroundColor Red
    }
}
$exportMenu = AddMenuItem -menu $exportMenu -name "Export Managed Windows Devices" -Action {
    $exported = Export-DeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'managed'
    if ($exported.success)
    {
        Write-Host $exported.message -ForegroundColor Green
    }
    else
    {
        Write-Host $exported.message -ForegroundColor Red
    }
}
$exportMenu = AddMenuItem -menu $exportMenu -name "Export Unmanaged Windows Devices" -Action {
    $exported = Export-DeviceList -AccessToken $AccessToken -outputPath $scriptPath -deviceType 'unmanaged'
    if ($exported.success)
    {
        Write-Host $exported.message -ForegroundColor Green
    }
    else
    {
        Write-Host $exported.message -ForegroundColor Red
    }
}
$exportMenu = AddMenuItem -menu $exportMenu -name "Export device storage report" -Action {
    $dateTime = Get-Date -Format "yyyyMMdd_HHmm"
    $storageOutputFileName = "DeviceStorageReport-$dateTime.csv"
    if (ExportDeviceStorage -AccessToken $accessToken -OutputFile $storageOutputFileName)
    {
        Write-Host "Exported device storage report to $($storageOutputFileName)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export device storage report." -ForegroundColor Red
    }
}
$exportMenu = AddMenuItem -menu $exportMenu -name "Export Application Assignments" -Action {
    $exported, $appsProcessed = GetAppAssignmentTypes -AccessToken $accessToken -Export -outputPath $ScriptPath -fileMode 'Overwrite'
    if ($exported)
    {
        Write-Host "App assignment types exported successfully."
    }
    else
    {
        if ($appsProcessed.AllApps.Count -eq 0)
        {
            Write-Host "No apps found to export." -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $scriptName -Message "No apps found to export." -LogLevel "Verbose"
        }
        else
        {
            Write-Host "Failed to export app assignment types." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to export app assignment types." -LogLevel "Error"
        }
    }
}
#endregion export menu

#region device reports menu
$deviceReportsMenu = AddMenuItem -menu $deviceReportsMenu -name "Assigned Windows Devices" -Action {
    Write-Host "Exporting assigned device report..."
    $lastContactDateTime = Get-DateInput
    $exportParams = @{
        accessToken = $accessToken
        outputPath  = $scriptPath
        reportType  = 'Assigned'
        fileMode    = 'Overwrite'
    }
    if ($lastContactDateTime)
    {
        $exportParams.lastContactDateTime = $lastContactDateTime
    }
    $exportedDeviceAssignment = Export-DeviceAssignmentReport @exportParams
    write-log -logFile $logFile -module $scriptName -message "Assigned device report export result: $($exportedDeviceAssignment | Out-String)" -LogLevel "Information"
    if ($exportedDeviceAssignment.success)
    {
        if ($exportedDeviceAssignment.deviceCount -gt 0)
        {
            write-log -logFile $logFile -module $scriptName -message "Assigned device report exported: File=$($exportedDeviceAssignment.outputFile), DeviceCount=$($exportedDeviceAssignment.deviceCount)" -LogLevel "Information"
            Write-Host " $($exportedDeviceAssignment.deviceCount) Assigned devices exported successfully to $($exportedDeviceAssignment.outputFile)             ." -ForegroundColor Green
        }
        else
        {
            if ($lastContactDateTime)
            {
                $formattedDate = FormatDateWithTimeZone -DateTime $lastContactDateTime
                write-log -logFile $logFile -module $scriptName -message "No assigned devices found that have connected to Intune since $formattedDate" -LogLevel "Warning"
                Write-Host "No assigned devices found that have connected to Intune since $formattedDate" -ForegroundColor Yellow
            }
            else
            {
                write-log -logFile $logFile -module $scriptName -message "No assigned devices found to export - no devices in scope" -LogLevel "Warning"
                Write-Host "No reports generated - no assigned devices found." -ForegroundColor Yellow
            }
        }
    }
    else
    {
        write-log -logFile $logFile -module $scriptName -message "Failed to export assigned device report: $($exportedDeviceAssignment.message)" -LogLevel "Error"
        Write-Host $exportedDeviceAssignment.message -ForegroundColor Red
    }
}
$deviceReportsMenu = AddMenuItem -menu $deviceReportsMenu -name "Unassigned Windows Devices" -Action {
    Write-Host "Exporting unassigned device report..."
    $exportParams = @{
        accessToken = $accessToken
        outputPath  = $scriptPath
        reportType  = 'Unassigned'
        fileMode    = 'Overwrite'
    }
    $exportedDeviceAssignment = Export-DeviceAssignmentReport @exportParams
    write-log -logFile $logFile -module $scriptName -message "Unassigned device report export result: $($exportedDeviceAssignment | Out-String)" -LogLevel "Information"
    if ($exportedDeviceAssignment.success)
    {
        if ($exportedDeviceAssignment.deviceCount -gt 0)
        {
            write-log -logFile $logFile -module $scriptName -message "Unassigned device report exported: File=$($exportedDeviceAssignment.outputFile), DeviceCount=$($exportedDeviceAssignment.deviceCount)" -LogLevel "Information"
            Write-Host " $($exportedDeviceAssignment.deviceCount) Unassigned devices exported successfully to $($exportedDeviceAssignment.outputFile)                           ." -ForegroundColor Green
        }
        else
        {
            write-log -logFile $logFile -module $scriptName -message "No unassigned devices found to export - no devices in scope" -LogLevel "Warning"
            Write-Host "No reports generated - no unassigned devices found." -ForegroundColor Yellow
        }
    }
    else
    {
        write-log -logFile $logFile -module $scriptName -message "Failed to export unassigned device report: $($exportedDeviceAssignment.message)" -LogLevel "Error"
        Write-Host $exportedDeviceAssignment.message -ForegroundColor Red
    }
}
$deviceReportsMenu = AddMenuItem -menu $deviceReportsMenu -name "Pre-provisioned Windows Devices" -Action {
    Write-Host "Exporting pre-provisioned device report..."
    $lastContactDateTime = Get-DateInput
    $exportParams = @{
        accessToken = $accessToken
        outputPath  = $scriptPath
        reportType  = 'PreProvisioned'
        fileMode    = 'Overwrite'
    }
    if ($lastContactDateTime)
    {
        $exportParams.lastContactDateTime = $lastContactDateTime
    }
    $exportedDeviceAssignment = Export-DeviceAssignmentReport @exportParams
    write-log -logFile $logFile -module $scriptName -message "Pre-provisioned device report export result: $($exportedDeviceAssignment | Out-String)" -LogLevel "Information"
    if ($exportedDeviceAssignment.success)
    {
        if ($exportedDeviceAssignment.deviceCount -gt 0)
        {
            write-log -logFile $logFile -module $scriptName -message "Pre-provisioned device report exported: File=$($exportedDeviceAssignment.outputFile), DeviceCount=$($exportedDeviceAssignment.deviceCount)" -LogLevel "Information"
            Write-Host "$($exportedDeviceAssignment.deviceCount) Pre-provisioned devices exported successfully to $($exportedDeviceAssignment.outputFile)." -ForegroundColor Green
        }
        else
        {
            if ($lastContactDateTime)
            {
                $formattedDate = FormatDateWithTimeZone -DateTime $lastContactDateTime
                write-log -logFile $logFile -module $scriptName -message "No pre-provisioned devices found that have connected to Intune since $formattedDate" -LogLevel "Warning"
                Write-Host "No pre-provisioned devices found that have connected to Intune since $formattedDate" -ForegroundColor Yellow
            }
            else
            {
                write-log -logFile $logFile -module $scriptName -message "No pre-provisioned devices found to export - no devices in scope" -LogLevel "Warning"
                Write-Host "No reports generated - no pre-provisioned devices found." -ForegroundColor Yellow
            }
        }
    }
    else
    {
        write-log -logFile $logFile -module $scriptName -message "Failed to export pre-provisioned device report: $($exportedDeviceAssignment.message)" -LogLevel "Error"
        Write-Host $exportedDeviceAssignment.message -ForegroundColor Red
    }
}
$deviceReportsMenu = AddMenuItem -menu $deviceReportsMenu -name "All Windows Devices" -Action {
    Write-Host "Exporting all devices with their assignment status..."
    $exportParams = @{
        accessToken = $accessToken
        outputPath  = $scriptPath
        reportType  = 'All'
        fileMode    = 'Overwrite'
    }
    $exportedDeviceAssignment = Export-DeviceAssignmentReport @exportParams
    write-log -logFile $logFile -module $scriptName -message "All device report export result: $($exportedDeviceAssignment | Out-String)" -LogLevel "Information"
    if ($exportedDeviceAssignment.success)
    {
        if ($exportedDeviceAssignment.deviceCount -gt 0)
        {
            write-log -logFile $logFile -module $scriptName -message "All device report exported: File=$($exportedDeviceAssignment.outputFile), DeviceCount=$($exportedDeviceAssignment.deviceCount)" -LogLevel "Information"
            Write-Host "All $($exportedDeviceAssignment.deviceCount) devices exported successfully to $($exportedDeviceAssignment.outputFile)." -ForegroundColor Green
        }
        else
        {
            write-log -logFile $logFile -module $scriptName -message "No devices found to export - no devices in scope" -LogLevel "Warning"
            Write-Host "No reports generated - no devices found." -ForegroundColor Yellow
        }
    }
    else
    {
        write-log -logFile $logFile -module $scriptName -message "Failed to export all device report: $($exportedDeviceAssignment.message)" -LogLevel "Error"
        Write-Host $exportedDeviceAssignment.message -ForegroundColor Red
    }
}
$deviceReportsMenu = AddMenuItem -menu $deviceReportsMenu -name "Assigned devices by user" -Action {
    $result = Get-AssignedDevicesByUserReport -accessToken $accessToken
    Write-Verbose "[$scriptName] Device user assignment report result: $($result | ConvertTo-Json -Depth 3)"
    write-log -logFile $logFile -module $scriptName -message "Device user assignment report result: Action=$($result.Action), Success=$($result.Success), DeviceCount=$($result.DeviceCount), UserCount=$($result.UserCount)" -LogLevel "Information"
    if ($result.Success)
    {
        switch ($result.Action)
        {
            'Displayed'
            {
                Write-Verbose "[$scriptName] $($result.Message)"
            }
            'Exported'
            {
                Write-Host "$($result.Message)" -ForegroundColor Green
            }
            'NoDevices'
            {
                Write-Verbose "[$scriptName] $($result.Message)"
            }
            'UserCancelled'
            {
                Write-Verbose "[$scriptName] $($result.Message)"
            }
            default
            {
                Write-Verbose "[$scriptName] Report completed: $($result.Message)"
            }
        }
    }
    else
    {
        Write-Host "Error generating report: $($result.Message)" -ForegroundColor Red
        if ($result.ErrorDetails)
        {
            Write-Verbose "[$scriptName] Error details: $($result.ErrorDetails)"
            write-log -logFile $logFile -module $scriptName -message "Error details: $($result.ErrorDetails)" -LogLevel "Error"
        }
    }
}
#endregion device reports menu

#region serial number menu
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number" -Action {
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
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number" -Action {
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
    $deviceIdentifier = GetDeviceInfo -nohash
    Write-Verbose "[$scriptName] Device identifier: $($deviceIdentifier | Out-String)"
    write-log -logFile $LogFile -Module $functionName -Message "Device identifier: $($deviceIdentifier | Out-String)" -LogLevel "Verbose"
    if ($deviceIdentifier.deviceAllowed -eq $false)
    {
        Write-Host "The device manufacturer $($deviceIdentifier.manufacturer) is not allowed." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Device manufacturer $($deviceIdentifier.manufacturer) is not allowed" -LogLevel "Error"
        return $returnValues.manufacturerNotAllowed
    }
    if ($deviceIdentifier -and $deviceIdentifier.SerialNumber)
    {
        # For manufacturerModelSerial type, format as comma-separated string
        $result = AddCorporateDeviceIdentifier -AccessToken $accessToken -DeviceInfo $deviceIdentifier -IdentifierType "manufacturerModelSerial" -OverwriteImportedDeviceIdentities
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
        Write-Host "This will delete the corporate device identifier for:"
        Write-Host " Manufacturer: $($deviceIdentifier.Manufacturer)"
        Write-Host " Model: $($deviceIdentifier.Model)"
        Write-Host " Serial Number: $($deviceIdentifier.SerialNumber)"
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
        $result = DeleteCorporateDeviceIdentifier -AccessToken $accessToken -deviceInfo $deviceIdentifier -IdentifierType "manufacturerModelSerial"
        if ($result -in $returnValues.deviceDeleteSuccessMessage)
        {
            Write-Host "Device successfully removed from corporate identifiers." -ForegroundColor Green
        }
        else
        {
            Write-Host $result
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
    $updateResult = Apply-WindowsUpdates
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

#region Environment menu
$environmentMenu = AddMenuItem -menu $environmentMenu -Name "View group inclusion/exclusion settings for all domains" -Action {
    Write-Host "Displaying group inclusion/exclusion settings..." -ForegroundColor Cyan
    Write-Host "These settings control which groups are included or excluded from operations." -ForegroundColor Gray
    $success = Show-GroupsViewer -SettingsFile $InitFile
    if ($success)
    {
        Write-Host "`nGroup settings displayed successfully." -ForegroundColor Green
    }
    else
    {
        Write-Host "`nFailed to display group settings. Please check the logs for details." -ForegroundColor Red
    }
}
$environmentMenu = AddMenuItem -menu $environmentMenu -Name "Change global environment settings" -Action {
    Write-Host "Launching global settings editor..." -ForegroundColor Cyan
    $success = Show-SettingsEditor -SettingsType "Global" -SettingsFile $InitFile
    if ($success)
    {
        Write-Host "`nGlobal settings updated successfully. Changes will take effect on next restart." -ForegroundColor Green
    }
    else
    {
        Write-Host "`nFailed to update global settings. Please check the logs for details." -ForegroundColor Red
    }
}
$environmentMenu = AddMenuItem -menu $environmentMenu -Name "Change domain specific settings" -action {
    Write-Host "Launching domain-specific settings editor..." -ForegroundColor Cyan
    # Get the current domain from settings
    $currentDomain = $domain
    if ([string]::IsNullOrWhiteSpace($currentDomain))
    {
        Write-Host "No domain specified. Cannot edit domain-specific settings." -ForegroundColor Red
        return $returnValues.backoutText
    }
    $success = Show-SettingsEditor -SettingsType "Domain" -DomainName $currentDomain -SettingsFile $InitFile
    if ($success)
    {
        Write-Host "`nDomain settings for '$currentDomain' updated successfully." -ForegroundColor Green
    }
    else
    {
        Write-Host "`nFailed to update domain settings. Please check the logs for details." -ForegroundColor Red
    }
}
$environmentMenu = AddMenuItem -menu $environmentMenu -Name "Change authentication settings" -Action {
    Write-Host "Launching authentication settings editor..." -ForegroundColor Cyan
    Write-Host "These settings control how the application authenticates with Microsoft Graph API." -ForegroundColor Gray
    $success = Show-SettingsEditor -SettingsType "Auth" -SettingsFile $InitFile
    if ($success)
    {
        Write-Host "`nAuthentication settings updated successfully. Changes may require application restart." -ForegroundColor Green
    }
    else
    {
        Write-Host "`nFailed to update authentication settings. Please check the logs for details." -ForegroundColor Red
    }
}
$environmentMenu = AddMenuItem -menu $environmentMenu -Name "Change inclusion/exclusion" -subMenu $inclusionExclusionMenu
$inclusionExclusionMenu = AddMenuItem -menu $inclusionExclusionMenu -Name "Change group inclusion/exclusion" -Action {
    Write-Host "Launching groups editor..." -ForegroundColor Cyan
    Write-Host "These settings control which groups are included or excluded from operations." -ForegroundColor Gray
    $result = Show-GroupsEditor -SettingsFile $InitFile -DomainName $domain -accessToken $accessToken
    if ($result -eq "Back" -or $result -eq "back")
    {
        Write-Verbose "[$scriptName] User selected Back from groups editor, returning to previous menu"
        return $returnValues.backoutText
    }
    elseif ($result -eq "Main Menu" -or $result -eq "main menu")
    {
        Write-Verbose "[$scriptName] User selected Main Menu from groups editor"
        return "EXIT_APPLICATION"
    }
    elseif ([string]::IsNullOrWhiteSpace($result) -or $null -eq $result)
    {
        Write-Verbose "[$scriptName] User requested application exit from groups editor."
        return "EXIT_APPLICATION"
    }
    else
    {
        return $result
    }
}
$inclusionExclusionMenu = AddMenuItem -menu $inclusionExclusionMenu -Name "Change Autopilot profile settings" -Action {
    Write-Host "Launching Autopilot profiles editor..." -ForegroundColor Cyan
    Write-Host "These settings control which Autopilot profiles are considered valid for device assignment." -ForegroundColor Gray
    $result = Show-AutopilotProfilesEditor -SettingsFile $InitFile -DomainName $domain -AccessToken $accessToken
    if ($result -eq "Back" -or $result -eq "back")
    {
        Write-Verbose "[$scriptName] User selected Back from Autopilot profiles editor, returning to previous menu"
        return $returnValues.backoutText
    }
    elseif ($result -eq "Main Menu" -or $result -eq "main menu")
    {
        Write-Verbose "[$scriptName] User selected Main Menu from Autopilot profiles editor"
        return "EXIT_APPLICATION"
    }
    elseif ([string]::IsNullOrWhiteSpace($result) -or $null -eq $result)
    {
        Write-Verbose "[$scriptName] User requested application exit from Autopilot profiles editor."
        return "EXIT_APPLICATION"
    }
    else
    {
        return $result
    }
}
#endregion Environment menu

#region Settings menu
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change environment settings" -subMenu $environmentMenu
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change Entra Credentials" -Action {
    Write-Host "This will change the authentication information used by the script and will allow you to set a new password."
    $choice = Read-Host "Are you sure you want to change the authentication information? (yes/no)"
    while ($choice -notin @('yes', 'no'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'."
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
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change Auto Update settings" -Action {
    Write-Verbose "[$scriptName] Auto Update: $($settings.autoUpdate)"
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Auto Update setting: $($settings.autoUpdate)" -LogLevel "Information"
    if ($settings.autoUpdate)
    {
        Write-Log -logFile $LogFile -Module "$scriptName" -Message "Auto Update is currently enabled." -LogLevel "Information"
        $messageString = "Auto Update is currently enabled. Would you like to disable it?"
    }
    else
    {
        Write-Log -logFile $LogFile -Module "$scriptName" -Message "Auto Update is currently disabled." -LogLevel "Information"
        $messageString = "Auto Update is currently disabled. Would you like to enable it?"
    }
    $choice = Read-Host "$messageString (yes/no)"
    while ($choice -notin @('yes', 'no', 'y', 'n'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'." -ForegroundColor Red
        [console]::beep(1000, 500)
        $choice = Read-Host "$messageString (yes/no)"
    }
    if ($choice -in @('no', 'n'))
    {
        Write-Log -logFile $LogFile -Module "$scriptName" -Message "User chose not to change Auto Update setting." -LogLevel "Information"
        return $returnValues.backoutText
    }
    $settings.autoUpdate = -not $settings.autoUpdate
    if (Update-Setting -SettingType "Global" -SettingsFile $initFile -SettingName "autoUpdate" -SettingValue $settings.autoUpdate)
    {
        Write-Host "Auto Update settings saved successfully." -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Auto Update settings saved successfully." -LogLevel "Information"
        $filesCleaned = cleanupTempFiles
        if ($filesCleaned.AllRemoved)
        {
            Write-Log -LogFile $LogFile -Module "$scriptName" -Message "All temporary files were cleaned." -LogLevel "Information"
        }
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files found: $($filesCleaned.RemovedFilesCount)" -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files removed: $($filesCleaned.RemovedFilesCount)" -LogLevel "Information"
    }
    else
    {
        Write-Host "Failed to update autoUpdate setting" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Failed to update autoUpdate setting" -LogLevel "Error"
    }
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change App Mode settings" -Action {
    Write-Verbose "[$scriptName] Current App Mode: $($settings.appMode)"
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Current App Mode setting: $($settings.appMode)" -LogLevel "Information"
    $result = Get-AppModeConfigurationFromUser -CurrentMode $settings.appMode -Context "settings"
    if ($result.cancelled)
    {
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "User chose to cancel app mode change." -LogLevel "Information"
        Write-Host "`nApp mode change cancelled." -ForegroundColor Yellow
        return $returnValues.backoutText
    }
    if ($result.currentModeUnchanged)
    {
        Write-Host "`nThe selected mode is already the current mode." -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "User selected the same app mode that is already set." -LogLevel "Information"
        return $returnValues.backoutText
    }
    # Use Update-AppModeSettings for specialized handling with storage preference
    try
    {
        if ($result.useGlobalStorage)
        {
            $storageType = "Global settings"
            $saveResult = Update-AppModeSettings -Configuration $result.appModes -SettingsFile $initFile -UseGlobalSettings
        }
        else
        {
            $storageType = "Domain settings"
            $saveResult = Update-AppModeSettings -Configuration $result.appModes -SettingsFile $initFile -Settings $settings
        }
        if ($saveResult)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully saved app mode configuration to $storageType" -LogLevel "Information"
            Write-Host "App mode configuration saved successfully to $storageType" -ForegroundColor Green
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to save app mode configuration" -LogLevel "Error"
            Write-Host "Failed to save app mode configuration" -ForegroundColor Red
        }
    }
    catch
    {
        $errorMessage = "Error saving app mode configuration: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $functionName -Message $errorMessage -LogLevel "Error"
        Write-Host $errorMessage -ForegroundColor Red
        return $null
    }
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change repository information" -Action {
    Write-Host "Launching repository information editor..." -ForegroundColor Cyan
    Write-Host "These settings control repository URLs and paths used for updates." -ForegroundColor Gray
    $result = Show-RepoInfoEditor -SettingsFile $InitFile
    if ($result -eq "Back" -or $result -eq "back")
    {
        Write-Verbose "[$scriptName] User selected Back from repository info editor"
        return $returnValues.backoutText
    }
    elseif ($result -eq "Main Menu" -or $result -eq "main menu")
    {
        Write-Verbose "[$scriptName] User selected Main Menu from repository info editor"
        return $returnValues.mainMenuText
    }
    else
    {
        return $result
    }
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change cache settings" -Action {
    Write-Host "Launching cache settings editor..." -ForegroundColor Cyan
    Write-Host "These settings control caching behavior, expiration times, and size limits." -ForegroundColor Gray
    $result = Show-CacheSettingsEditor -SettingsFile $InitFile
    if ($result -eq "Back" -or $result -eq "back")
    {
        Write-Verbose "[$scriptName] User selected Back from cache settings editor"
        return $returnValues.backoutText
    }
    elseif ($result -eq "Main Menu" -or $result -eq "main menu")
    {
        Write-Verbose "[$scriptName] User selected Main Menu from cache settings editor"
        return $returnValues.mainMenuText
    }
    else
    {
        return $result
    }
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Restore application defaults" -Action {
    Write-Host "Restoring application default settings..." -ForegroundColor Cyan
    $restoreResult = Show-RestoreApplicationDefaultsResults -FilesToDelete @($InitFile, $stringsFile, $menuFile) -Domain $domain -ScriptPath $scriptPath
    if ($restoreResult -in $returnValues.Values)
    {
        return $restoreResult
    }
    else
    {
        Write-Host $restoreResult
    }
}
#endregion Settings menu

#region Check menu
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by Serial Number" -Submenu $serialNumberMenu
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by User" -Action {
    $userName = GetUserInput -Message "Enter the username (Email address) of the user whose device you want to look up." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    if ($null -eq $userName)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.backoutText)."
        return $returnValues.backoutText
    }
    Write-Verbose "[$scriptName] Got user name: $userName"

    #region Resolve user with matching support
    $userName = Resolve-DirectoryObject -EntityName $userName -AccessToken $accessToken -Settings $settings -ReturnValues $returnValues -EntityType "User"
    # Check if user resolution returned a navigation command
    if ($userName -in $returnValues.Values -or $userName -in @("Main Menu", "EXIT_APPLICATION"))
    {
        Write-Verbose "[$scriptName] User resolution returned navigation command: $userName"
        return $userName
    }
    #endregion Resolve user with matching support

    # Call GetDeviceByUser to find devices for the specified user
    Write-Verbose "[$scriptName] Calling GetDeviceByUser for user: $userName"
    $serialNumber = GetDeviceByUser -UserName $userName -OperatingSystem 'Windows' -AccessToken $accessToken
    Write-Verbose "[$scriptName] GetDeviceByUser returned: $serialNumber"

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
    elseif ([string]::IsNullOrWhiteSpace($SerialNumber) -or $null -eq $serialNumber -or $serialNumber -eq 0 -or $serialNumber -eq "0")
    {
        Write-Verbose "[$scriptName] User requested application exit from device selection."
        return "EXIT_APPLICATION"
    }
    else
    {
        Write-Verbose "[$scriptName] Continuing script..."
    }
    #endregion Handle navigation responses from GetDeviceByUser

    Write-Host "Found device for user $userName with serial number: $serialNumber"
    do
    {
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        Write-Verbose "[$scriptName] Result: $result"
        Write-Verbose "[$scriptName] ProcessSerialNumber returned: $result"
        if ($null -ne $result)
        {
            Write-Verbose "[$scriptName] Result: $result"
            $serialNumber = $result
        }
        else
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            $result = "EXIT_APPLICATION"
        }
    } until ($result -in $returnValues.values -or $result -eq "EXIT_APPLICATION" -or $result -eq "Back" -or $result -eq "back" -or $result -eq "Main Menu" -or $result -eq "main menu" -or [string]::IsNullOrWhiteSpace($result))
    return $result
}
#endregion Check menu

#region show Group Assignments menu
# Helper scriptblock to avoid duplication between direct and indirect assignment menu items
$script:ShowGroupAssignmentsAction = {
    <#
    This script-scoped variable defines a reusable script block for showing group assignments in the Intune Helpdesk Menu.
    It is defined at script scope to allow sharing between multiple menu items (e.g., direct and indirect assignment views),
    avoiding code duplication and ensuring consistent behavior. The script block encapsulates the logic for prompting the user
    for a group name, resolving the group, and handling navigation commands, and is invoked by different menu actions as needed.
    #>
    param(
        [bool]$IncludeIndirectAssignments,
        [bool]$exportInstead
    )

    $assignmentScope = if ($IncludeIndirectAssignments)
    {
        "indirect (All Users/All Devices)"
    }
    else
    {
        "direct"
    }
    $specialGroups = @("*", "?")
    $messageText = if ($IncludeIndirectAssignments)
    {
        "Enter the name of the group whose indirect (All Users/All Devices) assignments you want to view. Enter any of $specialGroups for all assignments"
    }
    else
    {
        "Enter the name of the group whose direct assignments you want to view."
    }
    write-log -logFile $LogFile -Module $scriptName -Message "Prompting user for group name to view $assignmentScope assignments" -LogLevel "Information"
    $groupName = GetUserInput -Message $messageText -Prompt 'Please enter the group name' -InputType 'groupName' -settings $settings
    $needsResolution = if ($IncludeIndirectAssignments -and $groupName -in $specialGroups)
    {
        $false
    }
    else
    {
        $true
    }
    Write-Log -LogFile $LogFile -Module $scriptName -Message "GroupName: $groupName, IncludeIndirectAssignments: $IncludeIndirectAssignments, AssignmentScope: $assignmentScope, SpecialGroups: $specialGroups, NeedsResolution: $needsResolution"

    if ($null -eq $groupName)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.BackoutText)."
        write-log -logFile $LogFile -Module $scriptName -Message "User pressed Enter without providing a group name. Returning $($returnValues.BackoutText)." -LogLevel "Information"
        return $returnValues.backoutText
    }

    if ($groupName)
    {
        Write-Verbose "[$scriptName] Got group name: $groupName"
        write-log -logFile $LogFile -Module $scriptName -Message "Got group name: $groupName" -LogLevel "Information"
    }

    #region Resolve group using unified Resolve-DirectoryObject with entity return
    if ($needsResolution)
    {
        Write-Verbose "[$scriptName] Resolving group: $groupName"
        write-log -logFile $LogFile -Module $scriptName -Message "Resolving group: $groupName" -LogLevel "Information"
        $selectedGroup = Resolve-DirectoryObject -EntityName $groupName -AccessToken $accessToken -Settings $settings -ReturnValues $returnValues -EntityType "Group" -ReturnEntity
        write-log -logFile $LogFile -Module $scriptName -Message "Resolve-DirectoryObject returned: $($selectedGroup | Out-String)" -LogLevel "Verbose"
        # Handle navigation commands - check these FIRST before trying to use as group object
        if ($selectedGroup -eq "EXIT_APPLICATION")
        {
            Write-Verbose "[$scriptName] User requested application exit from group resolution"
            write-log -logFile $LogFile -Module $scriptName -Message "User requested application exit from group resolution" -LogLevel "Information"
            return "EXIT_APPLICATION"
        }
        elseif ($selectedGroup -eq "Main Menu")
        {
            Write-Verbose "[$scriptName] User selected Main Menu from group resolution"
            write-log -logFile $LogFile -Module $scriptName -Message "User selected Main Menu from group resolution" -LogLevel "Information"
            return "Main Menu"
        }
        elseif ($selectedGroup -in $returnValues.Values)
        {
            Write-Verbose "[$scriptName] Resolve-DirectoryObject returned navigation command: $selectedGroup"
            write-log -logFile $LogFile -Module $scriptName -Message "Resolve-DirectoryObject returned navigation command: $selectedGroup" -LogLevel "Information"
            return $selectedGroup
        }

        # Validate we got a valid group object
        if ($null -eq $selectedGroup -or -not $selectedGroup.id -or -not $selectedGroup.displayName)
        {
            write-log -logFile $LogFile -Module $scriptName -Message "Invalid group object returned from Resolve-DirectoryObject" -LogLevel "Error"
            Write-Host "No group found for the specified group name." -ForegroundColor Red
            return $returnValues.noGroupFoundMessage
        }
        Write-Verbose "[$scriptName] Group selected: $($selectedGroup.displayName) (ID: $($selectedGroup.id))"
        write-log -logFile $LogFile -Module $scriptName -Message "Group selected: $($selectedGroup.displayName) (ID: $($selectedGroup.id))" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$scriptName] Special group selected, skipping resolution: $groupName"
        write-log -logFile $LogFile -Module $scriptName -Message "Special group selected, skipping resolution: $groupName" -LogLevel "Information"
        $selectedGroup = $groupName
    }
    #endregion Resolve group using unified Resolve-DirectoryObject with entity return

    # Call ShowGroupAssignments to display the group's assignments
    Write-Verbose "[$scriptName] Calling ShowGroupAssignments for group: $($selectedGroup.displayName) with IncludeIndirect=$IncludeIndirectAssignments"
    write-log -logFile $LogFile -Module $scriptName -Message "Building splat for ShowGroupAssignments call" -LogLevel "Information"
    $showGroupAssignmentsSplat = @{
        AccessToken = $accessToken
        Settings    = $global:settings
        Group       = $selectedGroup
    }

    if ($IncludeIndirectAssignments)
    {
        $showGroupAssignmentsSplat['ShowIndirectAssignments'] = $true
        $showGroupAssignmentsSplat['SpecialGroups'] = $specialGroups
        write-log -logFile $LogFile -Module $scriptName -Message "Added ShowIndirectAssignments and SpecialGroups parameters to ShowGroupAssignments splat" -LogLevel "Information"
    }

    if ($exportInstead)
    {
        $showGroupAssignmentsSplat['exportInstead'] = $true
        write-log -logFile $LogFile -Module $scriptName -Message "Added exportInstead parameter to ShowGroupAssignments splat" -LogLevel "Information"
    }
    if ($settings.HideEmptyMenus)
    {
        $showGroupAssignmentsSplat['HideEmptyMenus'] = $true
        write-log -logFile $LogFile -Module $scriptName -Message "Added HideEmptyMenus parameter to ShowGroupAssignments splat" -LogLevel "Information"
    }
    $ShowGroupAssignmentsResponse = ShowGroupAssignments @showGroupAssignmentsSplat
    write-log -logFile $LogFile -Module $scriptName -Message "ShowGroupAssignments returned: $($ShowGroupAssignmentsResponse | Out-String)" -LogLevel "Verbose"
    #region Handle navigation responses from ShowGroupAssignments
    if ($ShowGroupAssignmentsResponse -eq "Back" -or $ShowGroupAssignmentsResponse -eq "back")
    {
        Write-Verbose "[$scriptName] User selected Back from group assignment selection, returning to previous menu"
        write-log -logFile $LogFile -Module $scriptName -Message "User selected Back from group assignment selection, returning to previous menu" -LogLevel "Information"
        return $returnValues.backoutText
    }
    elseif ($ShowGroupAssignmentsResponse -eq "Main Menu" -or $ShowGroupAssignmentsResponse -eq "main menu")
    {
        Write-Verbose "[$scriptName] User selected Main Menu from group assignment selection"
        write-log -logFile $LogFile -Module $scriptName -Message "User selected Main Menu from group assignment selection" -LogLevel "Information"
        return "EXIT_APPLICATION"
    }
    elseif ([string]::IsNullOrWhiteSpace($ShowGroupAssignmentsResponse) -or $null -eq $ShowGroupAssignmentsResponse)
    {
        Write-Verbose "[$scriptName] User requested application exit from group assignment selection."
        write-log -logFile $LogFile -Module $scriptName -Message "User requested application exit from group assignment selection" -LogLevel "Information"
        return "EXIT_APPLICATION"
    }
    else
    {
        Write-Verbose "[$scriptName] Continuing script..."
        write-log -logFile $LogFile -Module $scriptName -Message "Continuing script after group assignment selection" -LogLevel "Information"
        return $ShowGroupAssignmentsResponse
    }
    #endregion Handle navigation responses from ShowGroupAssignments
}

$script:ExportGroupAssignmentsAction = {
    param(
        [bool]$RespectOperatingSystem
    )
    $resourceScope = if ($RespectOperatingSystem)
    {
        "Windows"
    }
    else
    {
        "Tenant"
    }
    Write-Host "Exporting all $resourceScope configurations and their assignments..." -ForegroundColor Cyan
    Write-Host "This will export all $resourceScope resources with detailed assignment information to a CSV file." -ForegroundColor Gray
    Write-Host ""
    $exportParamSplat = @{
        AccessToken           = $accessToken
        OutputPath            = $ScriptPath
        IncludeBeta           = $true
        Settings              = $settings
        CreateErrorExportFile = $true
    }
    if ($RespectOperatingSystem)
    {
        $exportParamSplat['RespectOperatingSystem'] = $true
        write-log -logFile $LogFile -Module $scriptName -Message "Added RespectOperatingSystem parameter to Export-AllConfigurationsAndAssignments splat" -LogLevel "Information"
    }
    $exportResult = Export-ConfigurationAssignments @exportParamSplat
    write-log -logFile $LogFile -Module $scriptName -Message "Export-ConfigurationAssignments returned: $($exportResult | Out-String)" -LogLevel "Verbose"
    if ($exportResult.Success)
    {
        write-log -logFile $LogFile -Module $scriptName -Message "Export completed successfully. File: $($exportResult.OutputFile), Resources exported: $($exportResult.ResourceCount)" -LogLevel "Information"
        Write-Host ""
        Write-Host "Export completed successfully!" -ForegroundColor Green
        Write-Host "File: $($exportResult.OutputFile)" -ForegroundColor Cyan
        Write-Host "Resources exported: $($exportResult.ResourceCount)" -ForegroundColor Cyan
    }
    else
    {
        Write-Host ""
        Write-Host "Export failed: $($exportResult.Message)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Export failed: $($exportResult.Message)" -LogLevel "Error"
    }
}

$getGroupAssignmentsMenu = AddMenuItem -Menu $getGroupAssignmentsMenu -Name "View direct group assignments" -Action {
    & $script:ShowGroupAssignmentsAction -IncludeIndirectAssignments $false -exportInstead $false
}
$getGroupAssignmentsMenu = AddMenuItem -Menu $getGroupAssignmentsMenu -Name "View indirect group assignments (All Users/All Devices)" -Action {
    & $script:ShowGroupAssignmentsAction -IncludeIndirectAssignments $true -exportInstead $false
}
$getGroupAssignmentsMenu = AddMenuItem -Menu $getGroupAssignmentsMenu -Name "Export direct group assignments" -Action {
    & $script:ShowGroupAssignmentsAction -IncludeIndirectAssignments $false -exportInstead $true
}
$getGroupAssignmentsMenu = AddMenuItem -Menu $getGroupAssignmentsMenu -Name "Export indirect group assignments (All Users/All Devices)" -Action {
    & $script:ShowGroupAssignmentsAction -IncludeIndirectAssignments $true -exportInstead $true
}
$getGroupAssignmentsMenu = AddMenuItem -Menu $getGroupAssignmentsMenu -Name "Export all Windows configurations and their assignments" -Action {
    & $script:ExportGroupAssignmentsAction -RespectOperatingSystem $true
}
$getGroupAssignmentsMenu = AddMenuItem -Menu $getGroupAssignmentsMenu -Name "Export all tenant configurations and their assignments" -Action {
    & $script:ExportGroupAssignmentsAction -RespectOperatingSystem $false
}
#endregion Show Group Assignments menu

$mainMenu = AddMenuItem -Menu $mainMenu -Name "Give a device to a user" -Action {
    $username = GetUserInput -Message "Enter the username (Email address) of the user receiving the device." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    # Check if user entered 'back'
    if ($null -eq $username)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.backoutText)."
        return $returnValues.backoutText # Return to the previous menu
    }

    #region Resolve user with matching support
    $userName = Resolve-DirectoryObject -EntityName $userName -AccessToken $accessToken -Settings $settings -ReturnValues $returnValues -EntityType "User"

    # Check if user resolution returned a navigation command
    if ($userName -in $returnValues.Values -or $userName -in @("Main Menu", "EXIT_APPLICATION"))
    {
        Write-Verbose "[$scriptName] User resolution returned navigation command: $userName"
        return $userName
    }
    #endregion Resolve user with matching support

    # Perform comprehensive readiness checks
    Write-Verbose "[$scriptName] Starting comprehensive user readiness checks for: $userName"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Starting comprehensive user readiness checks for: $userName" -LogLevel Information
    $readinessResult = Test-UserReadiness -UserName $userName -AccessToken $accessToken -GroupsToInclude $groupsToInclude -GroupsToExclude $groupsToExclude -Settings $settings
    # Display the readiness report
    Show-UserReadinessReport -ReadinessResult $readinessResult
    # Proceed to device check if user is ready
    if ($readinessResult.IsReady)
    {
        Write-Host "Enter the device's serial number." -ForegroundColor Cyan
        Write-Host "This would be the device you plan to give to the user." -ForegroundColor Cyan
        $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
        # Check if user entered 'back'
        if ($null -eq $serialNumber)
        {
            Write-Verbose "[$scriptName] User pressed Enter. Returning $($returnValues.backoutText)."
            return $returnValues.backoutText # Return to the previous menu
        }
        else # Process only if a serial number was entered
        {
            $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -CheckUserReadiness -username $username
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
        Write-Verbose "[$scriptName] User $userName is not ready. Readiness check failed with $($readinessResult.IssueCount) issues."
        Write-Log -LogFile $LogFile -Module $scriptName -Message "User $userName is not ready. Issues: $($readinessResult.IssueCount), Warnings: $($readinessResult.WarningCount)" -LogLevel Warning
    }
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Check device status" -Submenu $CheckMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Autopilot menu" -Submenu $autopilotMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Change application settings" -Submenu $settingsMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Check for script updates" -Action {
    Write-Host "Checking for script updates..."
    # Intentionally omitting -noConfirmation here to allow user confirmation before updating
    $updateResult = Get-Updates -executableFileName "$scriptPath\$scriptName" -updateURL $updateURL -metaDataURL $remoteVersionURL -filesToUpdate @($stringsFile, $menuFile)
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
            Write-Host "An error has occurred:"
            Write-Host "Error message: $($updateResult.Content)"
            Write-Host "Status Code: $($updateResult.StatusCode)"
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
$mainMenu = AddMenuItem -menu $mainMenu -name "Shutdown the device" -action {
    Write-Host 'Shutting down the device...'
    if (-not (RestartDevice -Question 'Do you want to shut down the device now? (Y/N)' -action 'shutdown' -bootMessage 'Shutting down the device...'))
    {
        Write-Verbose "[$scriptName] RestartDevice function failed."
        return $returnValues.backoutText
    }
}
$mainMenu = AddMenuItem -menu $mainMenu -name "Group Assignments Menu" -Submenu $getGroupAssignmentsMenu
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Export Menu" -Submenu $exportMenu
$mainMenu = AddMenuItem -Menu $mainMenu -Name "About" -action {
    $aboutMenuResult = Show-AboutApplication -accessToken $accessToken -Release $latestRelease -name $name -updateAvailable $updateAvailable
    if ($aboutMenuResult -in $returnValues.Values)
    {
        return $aboutMenuResult
    }
}
#region show menus
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
if ($testMode)
{
    Write-Host "Test mode: $($testMode). No menu will be shown." -ForegroundColor Yellow
    Write-Host "You can run the script in test mode to validate functionality without showing the menu."
}
else
{
    Write-Verbose "Test mode: $($testMode)"
    if ($null -ne $mainMenu)
    {
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Showing main menu." -LogLevel "Information"
        $result = ShowMenu -Menu $mainMenu
        if ($null -eq $result)
        {
            Write-Host "`nThank you for using the Intune Helpdesk menu. Goodbye!" -ForegroundColor Green
        }
    }
}
#endregion show menus

#region Cleanup
# Clear sensitive data from memory before exiting
Clear-SecureMemory -ClearScriptVariables

# Cleanup temporary files
$filesCleaned = cleanupTempFiles
if ($filesCleaned.AllRemoved)
{
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "All temporary files were cleaned." -LogLevel "Information"
}
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files found: $($filesCleaned.RemovedFilesCount)" -LogLevel "Verbose"
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Total temporary files removed: $($filesCleaned.RemovedFilesCount)" -LogLevel "Information"
# Finish logging
Write-Log -LogFile $LogFile -FinishLogging
#endregion Cleanup
