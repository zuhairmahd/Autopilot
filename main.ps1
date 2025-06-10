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
    [switch]$SecureString,
    [switch]$ForceNewToken,
    [parameter(parameterSetName = 'Deligated')]
    [switch]$Deligated,
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
    [string]$appMode
)

#region Load parameters from the configuration file if it exists
$scriptName = $MyInvocation.MyCommand.Name
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
Write-Verbose "[$scriptName] Domain: $domain"
if (Test-Path -Path $InitFile)
{
    Write-Host " Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
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
#Attempt to import module if found.
$moduleName = 'HelperModule'
$moduleFileName = 'HelperModule.psm1'
$moduleObject = Get-Item -Path $moduleFileName -Force -ErrorAction SilentlyContinue
if ($null -ne $moduleObject)
{
    $moduleName = $moduleObject.BaseName
}
if ($moduleObject -and $moduleObject.PSIsContainer -eq $false)
{
    Write-Verbose "[$scriptName] Importing module $moduleFileName"
    try
    {
        Import-Module -Name $moduleObject -Force -ErrorAction SilentlyContinue
        Write-Verbose "[$scriptName] Module $moduleFileName imported successfully."
    }
    catch
    {
        Write-Verbose "[$scriptName] Failed to import module $moduleFileName. Error: $_"
    }
}
else
{
    Write-Verbose "[$scriptName] Module $moduleFileName not found in the current directory. Skipping import."
}

if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue)
{
    Write-Verbose "[$scriptName] Module $moduleName is already imported."
}
else
{
    Write-Verbose "[$scriptName] Module $moduleName not found. Attempting to import functions."
    #beep
    [console]::beep(200, 100)
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
}
#endregion import functions.

#region Define variables
if ($repo -eq 'github')
{
    $baseSourceURL = 'https://raw.githubusercontent.com'
    $repoPath = 'zuhairmahd'
    $repoName = 'autopilot'
    if ($release -eq 'auto')
    {
        $latestRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
        if ($latestRelease)
        {
            Write-Host "The latest release is $latestRelease"
        }
        else
        {
            Write-Host 'Failed to retrieve the latest release information from GitHub.' -ForegroundColor Red
            Write-Host 'Defaulting to main branch.'
            $latestRelease = 'main'
        }
    }
    else
    {
        $latestRelease = $Release
    }
}
elseif ($repo -eq 'gitlab')
{
    $baseSourceURL = 'https://git.gao.gov'
    $repoPath = 'mahmoudz'
    $repoName = 'autopilot-deployment'
    $repoId = '1031'
    $latestRelease = GetLatestGitlabRelease -RepositoryId $repoId
}
else
{
    Write-Host 'Invalid repository specified.'
    Write-Host 'Defaulting to the main branch from GitHub.'
    $latestRelease = 'main'
}
$settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
$groupsToInclude = $settings.groupsToInclude
Write-Verbose "[$scriptName] Groups to include: $($groupsToInclude | Out-String)"
$groupsToExclude = $settings.groupsToExclude
Write-Verbose "[$scriptName] Groups to exclude: $($groupsToExclude | Out-String)"
Write-Verbose "[$scriptName] Settings are as follows:"
foreach ($key in $settings.Keys)
{
    Write-Verbose "[$scriptName] $($key): $($settings[$key])"
}
$auth = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty auth
Write-Verbose "[$scriptName] Auth configuration loaded from $configFile"
foreach ($key in $auth.Keys)
{
    Write-Verbose "[$scriptName] Auth key: $($key) = $($auth[$key])"
}   
$getTokenParams = BuildAuthSplatTable -auth $auth
$backoutText = 'Returning to previous menu'
Write-Verbose "[$scriptName] Backout Text: $backoutText"
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
Write-Verbose "[$scriptName] Update URL: $updateURL"
$version = '3.0.0'
Write-Verbose "[$scriptName] Version: $version"
$versionFile = 'version.txt'
Write-Verbose "[$scriptName] Version file: $versionFile"
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/version.txt"
Write-Verbose "[$scriptName] Remote version URL: $remoteVersionURL"
$returnValues = [ordered] @{
    noRestartMessage              = 'Device not restarted.'
    EnrolledMessage               = 'The device is enrolled.'
    notContactedMessage           = 'The device has not contacted the enrollment service.'
    PendingResetMessage           = 'The device is pending a reset.'
    EnrollmentFailedMessage       = 'The device enrollment failed.'
    UnassignedMessage             = 'The device is not assigned to a deployment profile.'
    PendingMessage                = 'The device is pending assignment to a deployment profile.'
    notInIntuneMessage            = 'The device is not in Intune.'
    noUserDeviceFoundMessage      = 'No user or device found.'
    noUserFoundInDirectoryMessage = 'This user does not exist'
    ImportSuccessMessage          = 'The device was imported successfully.'
    ImportFailedMessage           = 'The device import failed.'
    DeleteSuccessMessage          = 'The device was deleted successfully.'
    DeleteFailedMessage           = 'The device deletion failed.'
    UpdateFailedMessage           = 'Could not download update.'
    noAccessTokenMessage          = 'Could not obtain an access token. Please check your credentials.'
    UpdateSuccessMessage          = 'The script was updated successfully.'
    UpdateNotNeededMessage        = 'The script is already up to date.'
    999                           = 'No updates were found'
    1000                          = 'All updates were installed'
    1001                          = 'Some updates were installed'
    10002                         = 'Some updates were installed'
    1003                          = 'Updates failed to install'
}
$deviceStates = [ordered] @{
    Ready    = 'The device is ready for the next user'
    NotReady = 'The device is not ready for the next user'
}
$deviceActions = [ordered] @{
    none            = 'No action'
    contactAdmin    = 'Contact an Intune administrator'
    contactHelpdesk = 'Contact the helpdesk'
    WipeOrClean     = 'Wipe or clean the device'
}
if (Test-Path -Path $versionFile)
{
    Write-Verbose "[$scriptName] Version file $versionFile found. Reading version."
    $localVersion = Get-Content -Path $versionFile -Raw -ErrorAction Stop
    Write-Verbose "[$scriptName] Local version: $localVersion"
    $localVersionObject = [System.Version]::Parse($LocalVersion)
    Write-Verbose "[$scriptName] Local version object: $localVersionObject"
    $versionVariableObject = [System.Version]::Parse($version)
    Write-Verbose "[$scriptName] Version object: $versionVariableObject"
    if ($versionVariableObject -le $localVersionObject)
    {
        Write-Verbose "[$scriptName] Version file $versionFile is up to date."
    }
    else
    {
        Write-Verbose "[$scriptName] Version file $versionFile is not up to date. Updating version file."
        Set-Content -Path $versionFile -Value $version -Force
        $localVersion = $version
    }
}
else
{
    Write-Verbose "[$scriptName] Version file $versionFile not found. Creating version file."
    Set-Content -Path $versionFile -Value $version -Force
    $localVersion = $version
}
# Initialize navigation context variables
$Global:History = [System.Collections.ArrayList]::new() 
$Global:MenuHistory = [System.Collections.ArrayList]::new() 
$global:previousMenu = New-Object System.Collections.Hashtable
# Device enrollment state cache content
$script:DeviceEnrollmentCache = @{}
#endregion Define variables

#region logging
Write-Verbose "[$scriptName] Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Verbose "[$scriptName] The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Verbose "[$scriptName] Configuration file: $configFile"
Write-Verbose "[$scriptName] Computer name: $Name"
Write-Verbose "[$scriptName] Group tag: $GroupTag"
Write-Verbose "[$scriptName] Assigned user: $AssignedUser"
Write-Verbose "[$scriptName] Reconfigure: $Reconfigure"
Write-Verbose "[$scriptName] Repository: $Repo"
Write-Verbose "[$scriptName] Release: $Release"
Write-Verbose "[$scriptName] Domain: $domain"
Write-Verbose "[$scriptName] Functions folder: $functionsFolder"
Write-Verbose "[$scriptName] Base source URL: $baseSourceURL"
Write-Verbose "[$scriptName] Backout text: $backoutText"
#endregion logging

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune Helpdesk menu.  What would you like to do?"
$CheckMenu = NewMenu -Title "Check Device Status" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$deviceExportMenu = newMenu -Title "Export Devices" -Description "Choose which devices you want to export."
$settingsMenu = NewMenu -title "Settings menu" -Description "Make changes to the application settings"
$autopilotMenu = NewMenu -Title "Autopilot Menu" -Description "Import a device into Autopilot and perform related actions"
$autopilotSerialNumberMenu = newMenu -Title "Check device registration" -Description "How would you like to enter the serial number?."

#region export menu
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Autopilot Devices" -Action {
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'autopilot'
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
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'imported'
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
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'managed'
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
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'unmanaged'
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
    $accessToken = GetGraphAccessToken @getTokenParams
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
    if ($null -eq $serialNumber)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    }
    else
    {
        Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
        $accessToken = GetGraphAccessToken @getTokenParams
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
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
        $accessToken = GetGraphAccessToken @getTokenParams
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        Write-Verbose "Result returned: $result"
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
        elseif ($result -eq $true)
        {
            Write-Host "Device information for device with serial number: $serialNumber was retrieved successfully." -ForegroundColor Green
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
$autopilotSerialNumberMenu = AddMenuItem -Menu $autopilotSerialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers and is no more than 10 digits long.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber'
    # Check if user entered 'back'
    if ($null -eq $serialNumber)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $backoutText."
        GoBack
    } 
    else # Process only if a serial number was entered
    {
        Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
        Write-Host "Checking device with serial number $($SerialNumber)..."
        $deviceObject = @{SerialNumber = $serialNumber}
        $accessToken = GetGraphAccessToken @getTokenParams
        $result = ProcessDevice -accessToken $accessToken -deviceObject $deviceObject -action 'check'
        Write-Verbose "[$scriptName] Result returned: $result"
        # Handle navigation responses  
        if ($result -eq "Back" -or $result -eq "back")
        {
            Write-Verbose "[$scriptName] Received Back from ProcessDevice function, returning to previous menu"
            return $backoutText
        }
        elseif ($result -eq "Main Menu" -or $result -eq "main menu")
        {
            Write-Verbose "[$scriptName] Received MainMenu from ProcessDevice function, returning to main menu"
            GoToMainMenu
        }
        elseif ([string]::IsNullOrWhiteSpace($result) -or $null -eq $result)
        {
            Write-Verbose "[$scriptName] User requested application exit."
            return "EXIT_APPLICATION"
        }
        elseif ($result -eq $true -or $result -in $returnValues.Values)
        {
            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            GoBack
        }
        else
        {
            Write-Host "Failed to fetch information for device with serial number: $($deviceObject.serialNumber)" -ForegroundColor Red  
        }
    }
} -returnsValue
$autopilotSerialNumberMenu = AddMenuItem -Menu $autopilotSerialNumberMenu -Name "Use this device's serial number." -Action {
    Write-Verbose "[$scriptName] Getting the serial number for this device..."
    
    $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser -NoHash
    Write-Verbose "[$scriptName] Device object: $($deviceObject)"
    if ($deviceObject)
    {
        Write-Host "Checking device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
        $accessToken = GetGraphAccessToken @getTokenParams
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'check'
        Write-Host "[$scriptName] Result returned: $result"
        # Handle navigation responses  
        if ($result -eq "Back" -or $result -eq "back")
        {
            Write-Verbose "[$scriptName] Received Back from ProcessDevice function, returning to previous menu"
            return $backoutText
        }
        elseif ($result -eq "Main Menu" -or $result -eq "main menu")
        {
            Write-Verbose "[$scriptName] Received MainMenu from ProcessDevice function, returning to main menu"
            GoToMainMenu
        }
        elseif ([string]::IsNullOrWhiteSpace($result) -or $null -eq $result)
        {
            Write-Verbose "[$scriptName] User requested application exit."
            return "EXIT_APPLICATION"
        }
        elseif ($result -eq $true -or $result -in $returnValues.Values)
        {
            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            GoBack
        }
        else
        {
            Write-Host "Failed to fetch information for device with serial number: $($deviceObject.serialNumber)" -ForegroundColor Red  
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
    }
} -returnsValue
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Quick Import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Quick import device into Autopilot."
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
    $accessToken = GetGraphAccessToken @getTokenParams
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
    $accessToken = GetGraphAccessToken @getTokenParams
    $result = PrepareImportDevice -accessToken $accessToken -CustomImport
    if ($result -eq $backoutText)
    {
        Write-Verbose "[$scriptName] Custom import aborted. Returning $backoutText."
        return $backoutText
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
$autopilotMenu = AddMenuItem -Menu $autopilotMenu -Name "Check device Autopilot status" -Submenu $autopilotSerialNumberMenu
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
            return $backoutText
        }
        $accessToken = GetGraphAccessToken @getTokenParams
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'delete'
        Write-Verbose "[$scriptName] Device deletion result: $result"
    }
}

#endregion Autopilot menu

$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change application settings" -Action {
    Write-Host 'Reconfiguring the script...'
    if (CreateFullConfiguration -DestinationFolder $pwd -RootFolder $pwd)
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
    $encryptedConfigObject = EncryptObject -decryptedObject $configObject -excludeFields @('name', 'domain')
    $json = $encryptedConfigObject | ConvertTo-Json -Depth 10
    Write-Host "Saving configuration to $configFile"
    Set-Content -Path $configFile -Value $json -Force
    Write-Host 'The application credentials have been changed.' -ForegroundColor Green
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Restore defaults" -Action {
    Write-Host 'Restoring the script to its default settings...'
    if (InitializeConfiguration -RootFolder $pwd -overWrite)
    {
        Write-Host 'The script defaults have been restored.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to restore script defaults..' -ForegroundColor Red
    }
}
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by Serial Number" -Submenu $serialNumberMenu
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by User" -Action {
    $userName = GetUserInput -Message "Enter the username (email address) of the user whose device you want to look up." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    if ($null -eq $userName)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    }
    else
    {
        Write-Verbose "[$scriptName] Got user name: $userName"
        $accessToken = GetGraphAccessToken @getTokenParams
        #Check if the user exists first.

        $userInfo = GetEntraUser -UserName $userName -AccessToken $accessToken
        if ($userInfo -eq $returnValues.noUserFoundInDirectoryMessage)  
        {
            Write-Verbose "[$scriptName] User $userName not found in directory."
            return $userInfo
        }
        else
        {
            Write-Host "Found user: $($userInfo.displayName) ($($userInfo.userPrincipalName))"
        }
        #Print the current navigation context prior too calling GetDeviceByUser
        Write-Verbose "[$scriptName] Current navigation context:"
        Write-Verbose "[$scriptName] Action History: $($actionHistory -join ' > ')"
        Write-Verbose "[$scriptName] Menu History: $($actionMenuHistory -join ' > ')"
        # Call GetDeviceByUser to find devices for the specified user
        Write-Verbose "[$scriptName] Calling GetDeviceByUser for user: $userName"
        $serialNumber = GetDeviceByUser -UserName $userName -OperatingSystem 'Windows' -AccessToken $accessToken
        Write-Verbose "[$scriptName] GetDeviceByUser returned: $serialNumber"
        
        # Handle navigation responses from GetDeviceByUser
        if ($serialNumber -eq "Back" -or $serialNumber -eq "back")
        {
            Write-Verbose "[$scriptName] User selected Back from device selection, returning to previous menu"
            return $backoutText
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
        elseif ($serialNumber -ne '0' -and $null -ne $serialNumber -and $serialNumber -ne "Back" -and $serialNumber -ne "Main Menu" -and $serialNumber -ne $returnValues.noUserDeviceFoundMessage)
        {
            Write-Host "Found device for user $userName with serial number: $serialNumber"
            $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
            
            Write-Verbose "[$scriptName] ProcessSerialNumber returned: $result"
            if ($null -eq $result)
            {
                Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
                return "EXIT_APPLICATION"
            }
            elseif ($result -eq $true)
            {
                Write-Host "Device information for device with serial number: $serialNumber was retrieved successfully." -ForegroundColor Green
            }
            else
            {
                Write-Host "Failed to fetch information for device with serial number: $serialNumber" -ForegroundColor Red
            }
        }
        elseif ($serialNumber -eq '0')
        {
            Write-Verbose "[$scriptName] User selected Exit option (0). Returning $BackoutText."
            return $backoutText
        }
        else
        {
            Write-Host $returnValues.noUserDeviceFoundMessage -ForegroundColor Red
        }
    }
}

$mainMenu = AddMenuItem -Menu $mainMenu -Name "Give a device to a user" -Action {
    $username = GetUserInput -Message "Enter the username (email address) of the user receiving the device." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    # Check if user entered 'back'
    if ($null -eq $username)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText # Return to the previous menu
    } 
    else # Continue only if a username was entered
    {
        $hasCorrectGroups = $false
        $hasCorrectNumberOfDevices = $false
        Write-Host "Checking group membership for user $userName."
        Write-Verbose "[$scriptName] Getting access token..."
        $accessToken = GetGraphAccessToken @getTokenParams
        $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
        if ($groups.success -eq $true)
        {
            Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
            Write-Host "The user is a member of all $($groupsToInclude.Count) required groups and is not a member of any of the $($groupsToExclude.Count) forbidden groups."
            $hasCorrectGroups = $true
        }
        else
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
                Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
                return $backoutText # Return to the previous menu
            }
            else # Process only if a serial number was entered
            {
                # Pass navigation context to ProcessSerialNumber
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
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
$mainMenu = AddMenuItem -menu $mainMenu -Name "Change application settings" -Submenu $settingsMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Check for script updates" -Action {
    Write-Host "Checking for script updates..."
    $updateResult = GetUpdates -RootFolder $pwd -LocalVersion $localVersion -remoteVersionURL $remoteVersionURL -updateURL $updateURL -returnValues $returnValues
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
            Write-Host 'An unknown error occurred while checking for updates.' -ForegroundColor Red
        }
    }
}
$mainMenu = AddMenuItem -menu $mainMenu -name "Restart the device" -action {
    Write-Host 'Restarting the device...'
    if (-not (RestartDevice))
    {
        Write-Verbose "[$scriptName] RestartDevice function failed."
        return $backoutText
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
    $script:MainMenuHistory += "Main Menu"
    $script:MainMenuHistory_Menu += $mainMenu
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
