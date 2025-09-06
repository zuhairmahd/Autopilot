[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\settings.psd1",
    [string]$stringsFile = "$pwd\strings.psd1",
    [int]$maxWaitTime,
    [int]$timeInSeconds,
    [String] $GroupTag,
    [switch]$showLicenseBanner,
    [switch]$showAuth,
    [switch]$showVersion,
    [switch]$showSettings,
    [switch]$OverwriteLogs,
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
    [ValidateSet('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')]
    [string]$appMode,
    [string]$LogFilePath = "$pwd\Logs\Autopilot.log",
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
# A sample object to export
$myObject = [PSCustomObject]@{
    ComputerName    = 'Server01'
    OperatingSystem = 'Windows Server 2025'
    LastReboot      = (Get-Date).ToString()
    InstalledApps   = @('AppA', 'AppB', 'AppC')
}

# Convert the object to a hashtable for writing to the file
$exportData = @{
    ComputerName    = $myObject.ComputerName
    OperatingSystem = $myObject.OperatingSystem
    LastReboot      = $myObject.LastReboot
    InstalledApps   = $myObject.InstalledApps
}

# Write the hashtable to a .psd1 file
Export-PowerShellDataFile -InputObject $exportData -Path 'mydata.psd1'
exit 0
#region Initialize script
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
#If the scriptname is a Powershell, change the extension to an exe.
if ($scriptName -match '\.ps1$' -and $MyInvocation.MyCommand.CommandType -eq "ExternalScript")
{
    Write-Log -logFile $LogFile -module $scriptName -Message "Script name ends with .ps1, changing to .exe for version check." -logLevel "Verbose"
    $scriptNameExe = $scriptName -replace '\.ps1$', '.exe'
    if (Test-Path "$pwd\$scriptNameExe")
    {
        Write-Log -logFile $LogFile -module $scriptName -Message "Found executable file: $scriptNameExe" -logLevel "Verbose"
        $version = GetFileVersion -executableFileName "$scriptPath\$scriptNameExe"
    }
    else 
    {
        Write-Log -logFile $LogFile -module $scriptName -Message "Executable file '$scriptNameExe' not found." -LogLevel "Warning"
    }
}
else 
{
    Write-Log -logFile $LogFile -module $scriptName -Message "Script file '$scriptName' found." -LogLevel "Verbose"
    $version = GetFileVersion -executableFileName "$scriptPath\$scriptName"        
}
Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Version: $($version | Out-String)" -LogLevel "Information"
$appMetaData = Get-ApplicationMetaDataFromDomain
Write-Log -LogFile $LogFile -Module $scriptName -Message "Application metadata retrieved successfully." -LogLevel "Information"
if (-not $version.version)
{
    Write-Verbose "[$scriptName] Unable to get file version."
    #see if you can find it in the metadata.
    if ($appMetaData -and $appMetaData.version)
    {
        $version = $appMetaData.version
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Found version in metadata: $($version | Out-String)" -LogLevel "Verbose"
    }
    else 
    {
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Unable to find version information. Defaulting to 1.0.0.0." -LogLevel "Warning"
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
if (-not ([string]::IsNullOrWhiteSpace($appMetaData.companyName)) -and $appMetaData.companyName -ne $version.companyName)
{
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Company name mismatch: $($appMetaData.companyName) vs $($version.companyName)" -LogLevel "Warning"
    $version.companyName = $appMetaData.companyName
    Write-Verbose "[$scriptName] Updated company name: $($version.companyName)"
}
if ($ShowVersion)
{
    Write-Verbose "[$scriptName] Version: $version"
    Write-Host "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))" -ForegroundColor Green
    Write-Host "Copyright (c) $((Get-Date).Year) $($version.companyName)" -ForegroundColor Cyan
    Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))" -LogLevel "Information"
    Write-Log -LogFile $LogFile -finishLogging
    exit 0  
}
$oldExecutableFileName = 'main.exe.old'
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
$script:maxRetries = 6

if (Test-Path $configFile)
{
    # Initialize configuration session
    $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -PasswordPrompt "Enter your password"
    
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
    
    # Check if password change is required
    if (Test-Path $InitFile)
    {
        try 
        {
            $initFileContent = Import-PowerShellDataFile -Path $InitFile -ErrorAction Stop
            if ($initFileContent.auth -and $initFileContent.auth.changePWOnNextStart -eq $true)
            {
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change required (changePWOnNextStart=true)" -LogLevel "Information"
                
                # Invoke password change process
                $passwordChangeResult = Invoke-PasswordChangeProcess -ConfigFile $configFile -ConfigContent $configContent -SettingsFile $InitFile
                
                if ($passwordChangeResult)
                {
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change completed successfully" -LogLevel "Information"
                    
                    # Reload the configuration with new password
                    Write-Host "Reloading configuration with new password..." -ForegroundColor Cyan
                    $reloadResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -UseStoredPassword
                    
                    if ($reloadResult.Success)
                    {
                        # Update configContent for this session
                        $configContent = $reloadResult.ConfigContent
                    }
                    else
                    {
                        Write-Host "Failed to reload configuration after password change: $($reloadResult.ErrorMessage)" -ForegroundColor Red
                        Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to reload configuration after password change: $($reloadResult.ErrorMessage)" -LogLevel "Error"
                        exit 1
                    }
                }
                else
                {
                    Write-Host "Password change failed. Continuing with current password." -ForegroundColor Yellow
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change failed. Continuing with current password." -LogLevel "Warning"
                }
            }
        }
        catch
        {
            Write-Warning "Failed to check password change requirement: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to check password change requirement: $($_.Exception.Message)" -LogLevel "Warning"
        }
    }
    
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
    # Configuration file not found - launch first run wizard
    Write-Host "Configuration file $configFile not found." -ForegroundColor Yellow
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file not found. Starting first run wizard" -LogLevel "Verbose"
    
    Write-Host "Starting first run wizard to set up your configuration..." -ForegroundColor Green
    
    # Launch the first run wizard
    $wizardResult = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $InitFile -StringsFile "$PWD\strings.psd1"
    
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
            # Initialize configuration session after wizard
            $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -UseStoredPassword -PasswordPrompt "Enter your password"
            
            if (-not $sessionResult.Success)
            {
                Write-Host "Configuration file exists but cannot be read: $($sessionResult.ErrorMessage)" -ForegroundColor Red
                Write-Host "Please check file permissions and try again." -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file cannot be read: $($sessionResult.ErrorMessage)" -LogLevel "Warning"
                exit 1
            }
            
            $configContent = $sessionResult.ConfigContent
            $domain = $sessionResult.Domain
            Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration loaded successfully for domain: $domain" -LogLevel "Information"
            
            # Check if password change is required (wizard path)
            if (Test-Path $InitFile)
            {
                try 
                {
                    $initFileContent = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
                    if ($initFileContent.auth -and $initFileContent.auth.changePWOnNextStart -eq $true)
                    {
                        Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change required after wizard (changePWOnNextStart=true)" -LogLevel "Information"
                        
                        # Invoke password change process
                        $passwordChangeResult = Invoke-PasswordChangeProcess -ConfigFile $configFile -ConfigContent $configContent -SettingsFile $InitFile
                        
                        if ($passwordChangeResult)
                        {
                            Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change completed successfully after wizard" -LogLevel "Information"
                            
                            # Reload the configuration with new password
                            Write-Host "Reloading configuration with new password..." -ForegroundColor Cyan
                            $reloadResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -UseStoredPassword
                            
                            if ($reloadResult.Success)
                            {
                                # Update configContent for this session
                                $configContent = $reloadResult.ConfigContent
                            }
                            else
                            {
                                Write-Host "Failed to reload configuration after password change: $($reloadResult.ErrorMessage)" -ForegroundColor Red
                                Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to reload configuration after password change: $($reloadResult.ErrorMessage)" -LogLevel "Error"
                                exit 1
                            }
                        }
                        else
                        {
                            Write-Host "Password change failed. Continuing with current password." -ForegroundColor Yellow
                            Write-Log -LogFile $LogFile -Module $scriptName -Message "Password change failed after wizard. Continuing with current password." -LogLevel "Warning"
                        }
                    }
                }
                catch
                {
                    Write-Warning "Failed to check password change requirement after wizard: $($_.Exception.Message)"
                    Write-Log -LogFile $LogFile -Module $scriptName -Message "Failed to check password change requirement after wizard: $($_.Exception.Message)" -LogLevel "Warning"
                }
            }
            
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
# Initialize application configuration using centralized helper functions
Write-Verbose "[$scriptName] Initializing application configuration"

# Use domain if available, otherwise default to contoso.com
$domainForDefaults = if ($domain)
{
    $domain 
}
else
{
    "contoso.com" 
}
# Initialize configuration with helper function
$configResult = Initialize-ApplicationConfiguration -InitFile $InitFile -StringsFile $stringsFile -Domain $domainForDefaults -PSBoundParameters $PSBoundParameters

if (-not $configResult.Success)
{
    Write-Host "Error initializing configuration: $($configResult.ErrorMessage)" -ForegroundColor Red
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration initialization failed: $($configResult.ErrorMessage)" -LogLevel "Error"
    exit 1
}

# Extract configuration results
$auth = $configResult.Auth
$globalSettings = $configResult.GlobalSettings  
$localSettings = $configResult.LocalSettings
$requiredScopes = $configResult.RequiredScopes

# Set auth as a script variable so it can be accessed by functions
$script:Auth = $auth

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
#endregion Load parameters from the configuration file if it exists

#region Define variables
$global:settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
$scope = $auth.scope
# $DellDeviceHardwareDetailsURI = "deviceManagement/hardwarePasswordDetails. "
# $logfile = "mylog.log"
# $serialNumber = '0F3CFP724223KV'
# $serialNumber = 'BTSB25000BCR'
# $serialNumber = '5R3SBZ3'
# $userUri = "users"
$groupUri = "groups"
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

$objectName = GetUserInput -Message "Enter the name of the object" -Prompt "Name?" -InputType 'groupName'
$global:groupName = GetEntraUser -accessToken $accessToken -objectType 'Group' -Name $objectName -verbose 
ShowGroupAssignments -accessToken $accessToken -GroupName $groupName -AssignmentType 'All'


exit 0

foreach ($appAssignment in $assignments.appAssignments)
{
    Write-Host "Assignment Type: $($appAssignment.Type)"
    Write-Host "Name: $($appAssignment.Name)"
    Write-Host "Intent: $($appAssignment.Intent)"
}

foreach ($complianceAssignment in $assignments.ComplianceAssignments)
{
    Write-Host "Assignment Type: $($complianceAssignment.Type)"
    Write-Host "Name: $($complianceAssignment.Name)"
}

foreach ($configurationAssignment in $assignments.ConfigurationAssignments)
{
    Write-Host "Assignment Type: $($configurationAssignment.Type)"
    Write-Host "Name: $($configurationAssignment.Name)"
    Write-Host "Intent: $($configurationAssignment.Intent)"
}
foreach ($assignment in $assignments.AllAssignments)
{
    Write-Host "Assignment Type: $($assignment.Type)"
    Write-Host "Name: $($assignment.Name)"
    Write-Host "Intent: $($assignment.Intent)"
}   

$global:assignments = GetGroupDirectAssignments -accessToken $accessToken -GroupName 'autopilot' -IncludeBeta
$serialNumber = '5R3SBZ3'
$global:pw = GetBIOSPassword -accessToken $accessToken -serialNumber $serialNumber
$userPrincipalName = 'mahmoudz@gao.gov'
$userRegisteredDeviceURI = "users/$($userPrincipalName)/registeredDevices"
$global:myDevices = CallGraphAPI -ResourcePath $userRegisteredDeviceURI -AccessToken $accessToken

$global:pw = CallGraphAPI -ResourcePath $DellDeviceHardwareDetailsURI -AccessToken $accessToken
$inputFile = Read-Host "Enter the path to the input file"
if (-not (Test-Path $inputFile))
{
    Write-Host "Input file not found. Exiting script." -ForegroundColor Red
    exit 1
}
else
{
    Write-Host "Input file found: $inputFile"
}
Write-Host "Enter the password you want to use for encryption:"
$password = Read-Host -AsSecureString "Password"
#decode the $password to a plain text string
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($password))
Write-Host "Using $password for encryption/decryption."
Write-Host "What would you like to do with the file?"
$choice = Read-Host "Press d to decrypt, e to encrypt"
while ($choice -notin @('d', 'e'))
{
    Write-Host "Invalid choice. Please enter 'd' to decrypt or 'e' to encrypt."
    #beep
    [console]::beep(1000, 500)
    $choice = Read-Host "Press d to decrypt, e to encrypt"
}
if ($choice -eq 'd')
{
    Invoke-JsonFileEncryption -filePath $inputFile -Key $password -Decrypt 
}
elseif ($choice -eq 'e')
{
    Invoke-JsonFileEncryption -filePath $inputFile -Key $password
}
Write-Host "Script completed successfully." -ForegroundColor Green

exit 0

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
