[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\settings.json",
    [string]$stringsFile = "$pwd\menus.json",
    [string]$menusFile = "$pwd\menus.json",
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
    [ValidateSet('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')]
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
$script:maxRetries = 6

if (Test-Path $configFile)
{
    # Initialize configuration session
    $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -PasswordPrompt "Enter your password"
    
    if (-not $sessionResult.Success)
    {
        Write-Host "Error: $($sessionResult.ErrorMessage)" -ForegroundColor Red
        Write-Verbose "[$scriptName] Failed to initialize configuration session: $($sessionResult.ErrorMessage)"
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
            $initFileContent = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
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
            # Initialize configuration session after wizard
            $sessionResult = Initialize-ConfigurationSession -ConfigFile $configFile -MaxRetries $maxRetries -UseStoredPassword -PasswordPrompt "Enter your password"
            
            if (-not $sessionResult.Success)
            {
                Write-Host "Configuration file exists but cannot be read: $($sessionResult.ErrorMessage)" -ForegroundColor Red
                Write-Host "Please check file permissions and try again." -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $scriptName -Message "Configuration file cannot be read: $($sessionResult.ErrorMessage)" -LogLevel "Error"
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
if (Test-Path -Path $InitFile)
{
    Write-Verbose "[$scriptName] Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
    
    # Ensure settings.json file has all required default values
    Write-Verbose "[$scriptName] Checking settings.json for missing default values"
    # Use domain if available, otherwise default to example.com
    $domainForDefaults = if ($domain)
    {
        $domain 
    }
    else
    {
        "contoso.com" 
    }
    $settingsUpdated = Test-SettingsJsonExists -SettingsFile $InitFile -Silent -DomainName $domainForDefaults
    if ($settingsUpdated)
    {
        Write-Verbose "[$scriptName] Settings file checked/updated successfully"
    }
    
    # Ensure strings.json file has all required default values  
    Write-Verbose "[$scriptName] Checking strings.json for missing default values"
    $stringsUpdated = Test-StringsJsonExists -StringsFile $stringsFile -Silent
    if ($stringsUpdated)
    {
        Write-Verbose "[$scriptName] Strings file checked/updated successfully"
    }
    
    $globalSettings = @{}
    $localSettings = @{}
    
    # Load the init file content (potentially updated with new defaults)
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
    #merge the local and global settings.
    $script:settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
    #if the appMode is not set, default to 'full', otherwise make sure it is avalid appMode.
    if (-not $script:settings.appMode)
    {
        Write-Verbose "[$scriptName] App mode is not set. Defaulting to 'full'."
        $script:settings.appMode = 'full'
    }
    elseif ($script:settings.appMode -notin @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom'))
    {
        Write-Host "Invalid app mode specified: $($script:settings.appMode). Valid options are: full, helpDesk, advanced, advancedRegistration, registration, admin, custom." -ForegroundColor Red
        Write-Host "Please specify a valid mode or remove the appMode parameter." -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $scriptName -Message "Invalid app mode specified: $($script:settings.appMode). Valid options are: full, helpDesk, advanced, advancedRegistration, registration, admin, custom." -LogLevel "Error"
        exit 1
    }
    #load menus configuration from initFile
    $menus = $initFileContent.menus
    Write-Verbose "[$scriptName] Loaded $($($menus.Count)) menus from $InitFile"
    Write-Log -logFile $LogFile -module $scriptName -Message "Loaded $($($menus.Count)) menus from $InitFile" -logLevel "Information"
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
    Write-Host "Configuration file $initFile not found. Using default values." -ForegroundColor Yellow
    
    $settingsCreated = Test-SettingsJsonExists -SettingsFile $initFile -Silent -AuthType $authConfig.AuthType -IsDelegated $authConfig.IsDelegated -DomainName $domain
    if (-not $settingsCreated)
    {
            
    }
        

    # Set auth as a script variable so it can be accessed by functions
    $script:Auth = $auth
}
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

$global:assignments = GetGroupDirectAssignments -accessToken $accessToken -GroupName 'autopilot' -IncludeBeta


exit 0 
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
