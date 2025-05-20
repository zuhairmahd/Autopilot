#region help
<#PSScriptInfo
.VERSION 2.2.2
.GUID c5b2b9ce-7269-4fe5-a126-3c84a5053d37
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Intune device deployment script
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES, Microsoft.Graph.Authentication, Microsoft.Graph.Groups', Microsoft.Graph.Identity.DirectoryManagement, WindowsAutoPilotIntune
.SYNOPSIS
Registers one or more devices into Intune and checks for profiles and module requirements.  
.DESCRIPTION
    Registers one or more devices into Intune.  The script will check for the required modules, permissions, and import the device into Intune.  The script will check if the device is already in Intune and if it is assigned to a deployment profile.  If the device is not in Intune, the script will import the device and wait until it is recognized.  If the device is in Intune but not assigned to a deployment profile, the script will prompt the user to check the Intune portal.  If the device is assigned to a deployment profile, the script will prompt the user to restart the device.
.PARAMETER configFile
    The path to the configuration file.  The default value is '.\.secrets\config.json'.
.PARAMETER Name
    The name of the device to register.  The default value is 'localhost'.
.PARAMETER GroupTag
    The group tag for the device.  The default value is 'MSB01'.
.PARAMETER AssignedUser
    The assigned user for the device.  The default value is null.
.PARAMETER check
    A switch to only check the device assignment status.  If used, no devices will be imported. The default value is false.
.PARAMETER NoModuleCheck
    A switch to skip the required module check.  The default value is false.
.PARAMETER NoUpdateCheck
.PARAMETER UpdateOnly
    A switch to only update the scripts.  The default value is false.  Cannot be used with NoUpdateCheck
    A switch to skip the script update check.  The default value is false.
.PARAMETER NoAdminCheck
    A switch to skip the administrator check.  The default value is false.
.PARAMETER NoSignatureVerify
    A switch to skip the code signature verification.  The default value is false.
    .PARAMETER NoHashVerify
    A switch to skip the hash verification.  The default value is false.
    

.PARAMETER GetDeviceHash
    A switch to get the device hash.  The default value is false.
.PARAMETER Redeploy
    A switch to redeploy the device.  The default value is false.
.PARAMETER SerialNumber
    The serial number of the device to verify deployment or prepare for redeployment.  If no serial number is provided, the script will use the serial number of the local device.
.PARAMETER Repo
    The repository to use for script updates.  The default value is 'github'.  The options are 'github' or 'gitlab'.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01'
    Registers the device with the name 'localhost' into Intune.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD'
    Registers the device with the name 'localhost' into Intune and assigns the user 'JohnD'.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -check
    Checks the device assignment status for the device with the name 'localhost'.  The device will not be imported.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoModuleCheck
    Registers the device with the name 'localhost' into Intune and skips the required module check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoUpdateCheck
    Registers the device with the name 'localhost' into Intune and skips the script update check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoAdminCheck
    Registers the device with the name 'localhost' into Intune and skips the administrator check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoSignatureVerify
    Registers the device with the name 'localhost' into Intune and skips the code signature verification.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoHashVerify
    Registers the device with the name 'localhost' into Intune and skips the hash verification.
.NOTES
  1. Optionally update scripts if newer versions are available.  
  2. Check whether the script is running with admin rights.  
  3. Verify required modules are installed.  
  4. Connect to Microsoft Graph.  
  5. Gather device info (serial, hardware hash, manufacturer, etc.).  
  6. Check if the device is already in Intune.  
  7. If needed, import the device into Intune and wait until it’s recognized.  
  8. Check deployment profile assignment and display status.  
  9. If the device is assigned, prompt for restart. Otherwise, advise the user to check the Intune portal.
#>
#endregion help

[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    [int]$maxWaitTime = 60,
    [int]$timeInSeconds = 30,
    [string]$configFile = '.\.secrets\config.json',
    [string]$Configuration = 'vars.json',
    [String] $GroupTag = 'MSB01',
    [String] $AssignedUser = '',
    [switch]$Reconfigure,
    [switch]$ReInitialize,
    [switch]$showAdvancedOptions,
    [Parameter(Mandatory = $False, ParameterSetName = 'UpdateSet')] [switch]$Update,
    [Parameter(ParameterSetName = 'UpdateSet')][ValidateSet('github', 'gitlab')][string]$Repo = 'github',
    [Parameter(Mandatory = $False, ParameterSetName = 'github')]
    [Parameter(ParameterSetName = 'gitlab')]
    [string]$Release = 'main'
)


#region Load parameters from the configuration file if it exists
$scriptName = $MyInvocation.MyCommand.Name
if (Test-Path -Path $Configuration)
{
    Write-Host " Loading configuration values from $Configuration."
    $configData = Get-Content -Path $Configuration -Raw | ConvertFrom-Json
    Write-Verbose "[$scriptName] Found $($configData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $configData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $configData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($configData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($configData.$key)"
            if ($configData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($configData.$key)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
                Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($configData.$key))."
                Set-Variable -Name $key -Value $configData.$key
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Read parameter $key from the commandline as $($PSBoundParameters[$key])"
        }
    }
}
else
{
    Write-Host "Configuration file $Configuration not found. Using default values."
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

#region Define static and dynamic variables
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
# $scopes = "offline_access Device.ReadWrite.All DeviceManagementApps.Read.All DeviceManagementConfiguration.ReadWrite.All DeviceManagementManagedDevices.PrivilegedOperations.All DeviceManagementManagedDevices.ReadWrite.All DeviceManagementServiceConfig.ReadWrite.All"
$application = 'Register'
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
$version = '3.0.0'
$versionFile = 'version.txt'
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/version.txt"
$backoutText = 'Returning to previous menu'
$returnValues = [ordered] @{}
$returnValues.add('EnrolledMessage', 'The device is enrolled.')
$returnValues.add('notContactedMessage', 'The device has not contacted the enrollment service.')
$returnValues.add('PendingResetMessage', 'The device is pending a reset.')
$returnValues.add('EnrollmentFailedMessage', 'The device enrollment failed.')
$returnValues.add('UnassignedMessage', 'The device is not assigned to a deployment profile.')
$returnValues.add('PendingMessage', 'The device is pending assignment to a deployment profile.')
$returnValues.add('notInIntuneMessage', 'The device is not in Intune.')
$returnValues.add('ImportSuccessMessage', 'The device was imported successfully.')
$returnValues.add('ImportFailedMessage', 'The device import failed.')
$returnValues.add('DeleteSuccessMessage', 'The device was deleted successfully.')
$returnValues.add('DeleteFailedMessage', 'The device deletion failed.')
$returnValues.add('UpdateFailedMessage', 'Could not download update.')
$returnValues.add('UpdateSuccessMessage', 'The script was updated successfully.')
$returnValues.add('UpdateNotNeededMessage', 'The script is already up to date.')
if ($domain -eq 'arabictutor.com')
{
    Write-Verbose "[$scriptName] Changing groupTag to 'entra'."
    $GroupTag = 'entra'
}
if (Test-Path -Path $versionFile)
{
    Write-Verbose "[$scriptName] Version file $versionFile found. Reading version."
    $localVersion = Get-Content -Path $versionFile -Raw -ErrorAction Stop
    Write-Verbose "[$scriptName] Local version: $localVersion"
    $localVersionObject = [System.Version]::Parse($LocalVersion)
    Write-Verbose "[$scriptName] Local version object: $localVersionObject"
    $versionObject = [System.Version]::Parse($version)
    Write-Verbose "[$scriptName] Version object: $versionObject"
    if ($versionObject -le $localVersionObject)
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
#endregion Define static and dynamic variables

#region logging
Write-Verbose "[$scriptName] Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Verbose "[$scriptName] The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Verbose "[$scriptName] Configuration file: $configFile"
Write-Verbose "[$scriptName] Initial values file: $initialValues"
Write-Verbose "[$scriptName] Computer name: $Name"
Write-Verbose "[$scriptName] Group tag: $GroupTag"
Write-Verbose "[$scriptName] Assigned user: $AssignedUser"
Write-Verbose "[$scriptName] Reconfigure: $Reconfigure"
Write-Verbose "[$scriptName] Repository: $Repo"
Write-Verbose "[$scriptName] Release: $Release"
Write-Verbose "[$scriptName] Domain: $domain"
Write-Verbose "[$scriptName] Application name: $application"
Write-Verbose "[$scriptName] Functions folder: $functionsFolder"
Write-Verbose "[$scriptName] Base source URL: $baseSourceURL"
Write-Verbose "[$scriptName] Backout text: $backoutText"
#endregion logging

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune device registration menu. Please select from the following option. `r`n Be sure to press Enter after you make your selection."
$serialNumberMenu = newMenu -Title "Check device registration" -Description "How would you like to enter the serial number?."
$deviceMenu = NewMenu -Title "Device Menu" -Description "What would you like to do with the device?"
$settingsMenu = NewMenu -title "Settings menu" -Description "Make changes to the application settings"
$autopilotMenu = NewMenu -Title "Autopilot Menu" -Description "Import a device into Autopilot and perform related actions"

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

$deviceMenu = AddMenuItem -menu $deviceMenu -name "Clean device" -action {
    Write-Host 'Cleaning the device...'
    $choice = Read-Host "Are you sure you want to clean the device? (yes/no)"
    while ($choice -notin @('yes', 'no'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'."
        #beep
        [console]::beep(1000, 500)
        $choice = Read-Host "Are you sure you want to clean the device? (yes/no)"
    }
    if ($choice -eq 'no')
    {
        Write-Host "Exiting..."
        return $backoutText
    }
    $accessToken = GetGraphAccessToken -configFile $configFile
    SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'clean'
}   
$deviceMenu = AddMenuItem -menu $deviceMenu -name "Wipe device" -action {
    Write-Host 'Wiping the device...'
    $choice = Read-Host "Are you sure you want to wipe the device? (yes/no)"
    while ($choice -notin @('yes', 'no'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'."
        #beep
        [console]::beep(1000, 500)
        $choice = Read-Host "Are you sure you want to wipe the device? (yes/no)"
    }
    if ($choice -eq 'no')
    {
        Write-Host "Exiting..."
        return $backoutText
    }
    $accessToken = GetGraphAccessToken -configFile $configFile
    SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'wipe'
}

$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers and is no more than 10 digits long.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number'
    # Check if user entered 'back'
    if ($null -eq $serialNumber)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    } 
    else # Process only if a serial number was entered
    {
        Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
        Write-Host "Checking device with serial number $($SerialNumber)..."
        $deviceObject = @{SerialNumber = $serialNumber}
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        $result = ProcessDevice -accessToken $accessToken -deviceObject $deviceObject -action 'check'
    }
}
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number." -Action {
    Write-Verbose "[$scriptName] Getting the serial number for this device..."
    $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser -NoHash
    Write-Verbose "[$scriptName] Device object: $($deviceObject)"
    if ($deviceObject)
    {
        Write-Host "Checking device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'check'
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
    }
}

$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Quick Import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Quick import device into Autopilot."
    $result = PrepareImportDevice
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Custom import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Custom import device into Autopilot."
    $result = PrepareImportDevice -CustomImport
    if ($result -eq $backoutText)
    {
        Write-Verbose "[$scriptName] Custom import aborted. Returning $backoutText."
        return $backoutText
    }
}
$autopilotMenu = AddMenuItem -Menu $autopilotMenu -Name "Check device Autopilot status" -Submenu $serialNumberMenu
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
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'delete'
    }
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -name "Get device hash for manual upload to Autopilot" -action {
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

$mainMenu = AddMenuItem -menu $mainMenu -Name "Autopilot menu" -Submenu $autopilotMenu
if ($showAdvancedOptions)
{
    $mainMenu = AddMenuItem -menu $mainMenu -Name "Device options" -Submenu $deviceMenu
}
$mainMenu = AddMenuItem -menu $mainMenu -Name "Change application settings" -Submenu $settingsMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Check for script updates" -Action {
    Write-Host "Checking for script updates..."
    $updateResult = GetUpdates -RootFolder $pwd -LocalVersion $localVersion -remoteVersionURL $remoteVersionURL -updateURL $updateURL -returnValues $returnValues
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
            Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
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
    $choice = Read-Host "Are you sure you want to restart the device? (yes/no)"
    while ($choice -notin @('yes', 'no'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'."
        #beep
        [console]::beep(1000, 500)
        $choice = Read-Host "Are you sure you want to restart the device? (yes/no)"
    }
    if ($choice -eq 'no')
    {
        Write-Host 'Exiting...'
        return $backoutText
    }
    RestartDevice
}
ShowMenu -Menu $mainMenu
#endregion Menu Definitions
