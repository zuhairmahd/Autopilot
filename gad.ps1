[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\settings.psd1",
    [string]$stringsFile = "$pwd\strings.psd1",
    [string]$menuFile = "$pwd\menu.psd1",
    [int]$maxWaitTime,
    [int]$timeInSeconds,
    [switch]$clearCache,
    [switch]$showSettings,
    [switch]$OverwriteLogs,
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
    [string]$LogFilePath = "$pwd\Logs\Autopilot.log",
    [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug')]
    [string]$LogLevel = 'Information'
)

$scriptName = $MyInvocation.MyCommand.Name
#region import functions.
$functionsFolder = Join-Path $PSScriptRoot 'functions'
if (Test-Path $functionsFolder) {
    Write-Verbose "[$scriptName] Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions) {
        Write-Verbose "[$scriptName] Importing function $function"
        . $function.FullName
    }
}
else {
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
$menuCacheFile = Join-Path -Path $PSScriptRoot -ChildPath "menu-cache.json"
if ($OverwriteLogs) {
    Write-Verbose "[$scriptName] Overwriting log file: $LogFile"
    Write-Log -LogFile $LogFile -StartLogging -OverwriteLog
}
else {
    Write-Verbose "[$scriptName] Starting logging to file: $LogFile"
    Write-Log -LogFile $LogFile -StartLogging
}

#region Process login
Write-Verbose "[$scriptName] Checking configuration file: $configFile"
# Check if the .secrets directory exists, create it if it doesn't
$secretsDir = Split-Path $configFile -Parent
if (-not (Test-Path $secretsDir)) {
    Write-Verbose "[$scriptName] Creating secrets directory: $secretsDir"
    New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
}
# Initialize variables for encryption handling
$configContent = $null
$script:maxRetries = 6
if (Test-Path $configFile) {
    # Initialize configuration session (use Silent mode if testMode is active)
    $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -PasswordPrompt "Enter your password" -Silent:$testMode

    if (-not $sessionResult.Success) {
        Write-Host "Error: $($sessionResult.ErrorMessage)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to initialize configuration session: $($sessionResult.ErrorMessage)" -LogLevel "Error"
        Write-Host "Exitting script due to configuration session failure." -ForegroundColor Red
        Write-Log -LogFile $LogFile -FinishLogging
        exit 1
    }
    $configContent = $sessionResult.ConfigContent
    $domain = $sessionResult.Domain

    if (-not ($sessionResult.encrypted)) {
        Write-Host "You need to set a new password to use this application."
        if (Invoke-PasswordChangeProcess -ConfigFile $configFile -ConfigContent $configContent -SettingsFile $initFile -setInitialPassword) {
            Write-Host "You can now use the application." -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Password set successfully after initialization" -LogLevel "Information"
        }
        else {
            Write-Host "Failed to set password. Exiting script." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to set password after initialization" -LogLevel "Error"
            Write-Log -logFile $logFile -finishLogging
            exit 1
        }
    }
    else {
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully for domain: $domain" -LogLevel "Information"
        Write-Host "Configuration loaded successfully for domain: $domain" -ForegroundColor Green
    }
    # Clear the config content from memory
    $configContent = $null
}
#endregion Process login

#region initialize script objects
Write-Host "Loading configuration..."


$configResult = Initialize-FastStart -initFile $InitFile -stringsFile $stringsFile -menuFile $menuFile -menuCacheFile $menuCacheFile -domain $domain -ScriptPath $PSScriptRoot
if ($configResult.success) {
    Write-Log -logFile $logFile -module $scriptName -message "Fast start configuration load succeeded."
    Write-Verbose "[$scriptName] Fast start configuration load succeeded."
    Write-Host "Fast start configuration load succeeded."
}
else {
    Write-Log -logFile $logFile -module $scriptName -message "Fast start configuration load failed, falling back to full initialization."
    Write-Verbose "[$scriptName] Fast start configuration load failed, falling back to full initialization."
    Write-Host "Performing full configuration initialization..."
    $configResult = Initialize-ApplicationConfiguration -InitFile $InitFile -StringsFile $stringsFile -menuFile $menuFile -Domain $domain -BoundParameters $PSBoundParameters
}

if (-not $configResult.Success) {
    Write-Host "Error initializing configuration: $($configResult.ErrorMessage)" -ForegroundColor Red
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration initialization failed: $($configResult.ErrorMessage)" -LogLevel "Error"
    Write-Log -logFile $logFile -finishLogging
    exit 1
}
# Extract configuration results
$auth = $configResult.Auth
$globalSettings = $configResult.GlobalSettings
$localSettings = $configResult.LocalSettings
$requiredScopes = $configResult.RequiredScopes
$global:cacheSettings = $configResult.CacheSettings
# Merge global and local settings into a single settings object
Write-Verbose "[$scriptName] Merging global and local settings"
$global:settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
# Make sure we are using the correct domain in settings
if ($settings.domain -ne $domain) {
    Write-Verbose "[$scriptName] Updating settings domain from $($settings.domain) to $domain"
    Write-Log -logFile $logFile -module $scriptName -message "Updating settings domain from $($settings.domain) to $domain"
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
Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully. Scopes: $($requiredScopes.Count), Settings: $($settings.Count)" -LogLevel "Information"
#endregion Initialize script objects


#region Define variables
Write-Verbose "[$scriptName] Settings are as follows:"
foreach ($key in $settings.Keys) {
    Write-Verbose "[$scriptName] $($key): $($settings[$key])"
    if ($showSettings) {
        Write-Host "Setting $($key): $($settings[$key])" -ForegroundColor Cyan
    }
}
Write-Verbose "[$scriptName] Auth configuration loaded from $configFile"
$getTokenParams = BuildAuthSplatTable -auth $auth
foreach ($key in $getTokenParams.Keys) {
    Write-Verbose "[$scriptName] $($key): $($getTokenParams[$key])"
}
$scope = $auth.scope
$accessToken = GetGraphAccessToken -configFile $configFile -delegated -scope $scope -AuthType 'PublicAuthFlow'
#endregion Define variables


Add-Type -AssemblyName System.Windows.Forms
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.Filter = "Zip and Cab Files (*.zip;*.cab)|*.zip;*.cab|All Files (*.*)|*.*"
$openFileDialog.Title = "Select a .zip or .cab file"
if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $fileName = $openFileDialog.FileName
}
else {
    Write-Host "No file selected." -ForegroundColor Yellow
    exit 1
}

Invoke-AutopilotDiagnostics -RootPath $PSScriptRoot -accessToken $accessToken -fileName $fileName

