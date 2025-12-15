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

#region Define upstream variables
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
#endregion Define upstream variables

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


#region show Group Assignments menu
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

    # Call Show-GroupAssignments to display the group's assignments
    Write-Verbose "[$scriptName] Calling Show-GroupAssignments for group: $($selectedGroup.displayName) with IncludeIndirect=$IncludeIndirectAssignments"
    write-log -logFile $LogFile -Module $scriptName -Message "Building splat for Show-GroupAssignments call" -LogLevel "Information"
    $ShowGroupAssignmentsSplat = @{
        AccessToken = $accessToken
        Settings    = $global:settings
        Group       = $selectedGroup
    }

    if ($IncludeIndirectAssignments)
    {
        $ShowGroupAssignmentsSplat['ShowIndirectAssignments'] = $true
        $ShowGroupAssignmentsSplat['SpecialGroups'] = $specialGroups
        write-log -logFile $LogFile -Module $scriptName -Message "Added ShowIndirectAssignments and SpecialGroups parameters to Show-GroupAssignments splat" -LogLevel "Information"
    }

    if ($exportInstead)
    {
        $ShowGroupAssignmentsSplat['exportInstead'] = $true
        write-log -logFile $LogFile -Module $scriptName -Message "Added exportInstead parameter to Show-GroupAssignments splat" -LogLevel "Information"
    }
    if ($settings.HideEmptyMenus)
    {
        $ShowGroupAssignmentsSplat['HideEmptyMenus'] = $true
        write-log -logFile $LogFile -Module $scriptName -Message "Added HideEmptyMenus parameter to Show-GroupAssignments splat" -LogLevel "Information"
    }
    $ShowGroupAssignmentsResponse = Show-GroupAssignments @ShowGroupAssignmentsSplat
    write-log -logFile $LogFile -Module $scriptName -Message "Show-GroupAssignments returned: $($ShowGroupAssignmentsResponse | Out-String)" -LogLevel "Verbose"
    #region Handle navigation responses from Show-GroupAssignments
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
    #endregion Handle navigation responses from Show-GroupAssignments
}

#"View direct group assignments"
& $script:ShowGroupAssignmentsAction -IncludeIndirectAssignments $false -exportInstead $false

#View indirect group assignments (All Users/All Devices)
& $script:ShowGroupAssignmentsAction -IncludeIndirectAssignments $true -exportInstead $false
#endregion Show Group Assignments menu




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


