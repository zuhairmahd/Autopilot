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
    [switch]$NoAdminCheck,
    [Parameter(ParameterSetName = 'intune')] [switch]$NoIntuneCheck,
    [Parameter(ParameterSetName = 'intune')] [switch]$check,
    [Parameter(ParameterSetName = 'intune')] [string]$SerialNumber = '',
    [switch]$NoSignatureVerify,
    [switch]$NoHashVerify,
    [switch]$GetDeviceHash,
    [switch]$Reconfigure,
    [switch]$ReInitialize,
    [Parameter(Mandatory = $False, ParameterSetName = 'NoUpdateCheckSet')] [switch]$NoUpdateCheck,
    [Parameter(Mandatory = $False, ParameterSetName = 'UpdateOnlySet')] [switch]$UpdateOnly,
    [Parameter(ParameterSetName = 'UpdateOnlySet')][ValidateSet('github', 'gitlab')][string]$Repo = 'github',
    [Parameter(ParameterSetName = 'UpdateOnlySet')]
    [Parameter(Mandatory = $False, ParameterSetName = 'github')]
    [Parameter(ParameterSetName = 'gitlab')]
    [string]$Release = 'main'
)

#region Load parameters from the configuration file if it exists
if (Test-Path -Path $Configuration)
{
    Write-Host " Loading configuration values from $Configuration."
    $configData = Get-Content -Path $Configuration -Raw | ConvertFrom-Json
    Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $configData.PSObject.Properties.Name)
    {
        Write-Verbose "Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $configData.$key)
        {
            Write-Verbose "Read parameter $key from the configuration file as $($configData.$key)"
            Write-Verbose "Setting $key to $($configData.$key)"
            if ($configData.$key -in ('true', 'false'))
            {
                Write-Verbose "Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($configData.$key)
                Write-Verbose "Setting the value of $key to the boolean value ($keybooleanValue)."
                Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "Setting the value of $key to the string value ($($configData.$key))."
                Set-Variable -Name $key -Value $configData.$key
            }
        }
        else
        {
            Write-Verbose "Read parameter $key from the commandline as $($PSBoundParameters[$key])"
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
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "Importing function $function"
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
$application = ($MyInvocation.MyCommand.Name) -replace '.ps1', ''
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
$Name = @('localhost')
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
$manifestFile = "$PSScriptRoot\manifest.json"
$manifest = (Get-Content -Path $ManifestFile | ConvertFrom-Json).$Application
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/manifest.json"
$ExclusionsFile = "$PSScriptRoot\exclusions.json"
$exclusions = (Get-Content -Path $ExclusionsFile | ConvertFrom-Json).$Application.exclusions
$scopes = "offline_access Device.ReadWrite.All DeviceManagementApps.Read.All DeviceManagementConfiguration.ReadWrite.All DeviceManagementManagedDevices.PrivilegedOperations.All DeviceManagementManagedDevices.ReadWrite.All DeviceManagementServiceConfig.ReadWrite.All"
#endregion Define static and dynamic variables

#region logging
Write-Verbose "Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Verbose "The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Verbose "Configuration file: $configFile"
Write-Verbose "Initial values file: $initialValues"
Write-Verbose "Computer name: $Name"
Write-Verbose "Group tag: $GroupTag"
Write-Verbose "Assigned user: $AssignedUser"
Write-Verbose "Check: $check"
Write-Verbose "No update check: $NoUpdateCheck"
Write-Verbose "Update only: $UpdateOnly"
Write-Verbose "No admin check: $NoAdminCheck"
Write-Verbose "No signature verify: $NoSignatureVerify"
Write-Verbose "No hash verify: $NoHashVerify"
Write-Verbose "Get device hash: $GetDeviceHash"
Write-Verbose "Reconfigure: $Reconfigure"
Write-Verbose "Repository: $Repo"
Write-Verbose "Release: $Release"
Write-Verbose "Domain: $domain"
Write-Verbose "Application name: $application"
Write-Verbose "Functions folder: $functionsFolder"
Write-Verbose "Base source URL: $baseSourceURL"
Write-Verbose "Exclusions file: $ExclusionsFile"
Write-Verbose "Exclusions: $($exclusions.count)"
Write-Verbose "Local manifest: $Manifest"
Write-Verbose "Remote manifest: $remoteManifest"
#endregion logging

#region Perform checks
if ($domain -eq 'arabictutor.com')
{
    Write-Verbose "Changing groupTag to 'entra'."
    $GroupTag = 'entra'
}

if ($Reconfigure)
{
    Write-Host 'Reconfiguring the script...'
    if (CreateFullConfiguration -DestinationFolder $PSScriptRoot -RootFolder $PSScriptRoot)
    {
        Write-Host 'The script has been reconfigured.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to reconfigure the script.' -ForegroundColor Red
        exit 1
    }
    exit 0
}   

if ($ReInitialize)
{
    Write-Host 'Reinitializing the script...'
    if (InitializeConfiguration -RootFolder $PSScriptRoot -overWrite)
    {
        Write-Host 'The script has been reinitialized.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to reinitialize the script.' -ForegroundColor Red
        exit 1
    }
    exit 0
}

if (-not($NoSignatureVerify))
{
    Write-Host 'Verifying code signature.'
    $codeAuthenticity = GetSignatureStatus -scriptFolders @("$PSScriptRoot", "$functionsFolder") -exclusions $exclusions
    if ($codeAuthenticity.count -gt 0)
    {
        Write-Host "$($codeAuthenticity.count) scripts failed the signature check." -ForegroundColor Red
        foreach ($Script in $codeAuthenticity.keys)
        {
            Write-Host "The script $script is $($codeAuthenticity[$script].status)."
            Write-Verbose "The reason is $($codeAuthenticity[$script].reason)."
        }
        Write-Host 'You may not run this script because the code signature verification failed.' -ForegroundColor Red
        Write-Host 'Exiting script.' -ForegroundColor Red
        exit 1
    }
    else
    {
        Write-Host 'All scripts are signed.' -ForegroundColor Green
    }
}
else
{
    Write-Host 'Skipping signature verification check.'
}

if (-not($NoHashVerify))
{
    Write-Host 'Verifying file integrity.'
    $fileIntegrity = GetScriptIntegrity -scriptFolders @("$PSScriptRoot", "$functionsFolder") -RootFolder $PSScriptRoot -exclusions $exclusions
    Write-Verbose "The file integrity check returned $($fileIntegrity.count) scripts."
    if (-not $fileIntegrity)
    {
        Write-Host 'You may not run this script because the integrity check failed.' -ForegroundColor Red
        Write-Host 'Exiting script.' -ForegroundColor Red
        exit 1
    }
    else
    {
        Write-Host 'All scripts passed integrity verification.' -ForegroundColor Green
    }
}
else
{
    Write-Host 'Skipping integrity verification check.'
}

if (-not($NoUpdateCheck))
{
    Write-Host 'Checking for script updates.'
    $remoteManifest = CheckForScriptUpdates -RemoteManifestPath $remoteVersionURL -LocalManifestContent $Manifest
    if ($remoteManifest.functions.count -gt 0 -or $remoteManifest.scripts.count -gt 0 -or $remoteManifest.cmds.count -gt 0)
    {
        Write-Host "$($remoteManifest.functions.count) functions, $($remoteManifest.scripts.count) scripts, and $($remoteManifest.cmds.count) cmds have an update available."
        Write-Host 'Would you like to download the latest version of the scripts? (Y/N)' -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq 'Y')
        {
            Write-Host 'Downloading the latest version of the script.'
            if (DownloadScriptUpdates -scriptsToUpdate $remoteManifest -scriptURI $updateURL -ScriptRoot $PSScriptRoot)
            {
                Write-Host 'All scripts have been updated.' -ForegroundColor Green
            }
            else
            {
                Write-Host 'Failed to update scripts.' -ForegroundColor Red
            }
        }
        else
        {
            Write-Host 'Updates will not be downloaded.' -ForegroundColor Red
        }
    }
    else
    {
        Write-Host 'All scripts are up to date.' -ForegroundColor Green
    }
}
else
{
    Write-Host 'Skipping script update check.'
}

if ($UpdateOnly)
{
    Write-Host 'Update check complete.'
    exit 0
}

if (-not($NoAdminCheck -or $UpdateOnly -or $Reconfigure -or $check -or $serialNumber -ne ''))
{
    Write-Host 'Checking whether the script has sufficient permissions to run.'
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Warning 'You do not have sufficient permissions to run this script. Please run this script as an administrator.'
        exit 1
    }
    else
    {
        Write-Host 'The script has sufficient permissions. Continuing.'
    }
}
else
{
    Write-Host 'Skipping administrator check.'
}
#endregion Perform checks

#region Gather device information.
if ($serialNumber -eq '')
{
    Write-Host 'Using the local device serial number.'
    if ($check)
    {
        Write-Verbose "Retrieving device info without hash"
        $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser -nohash
    }
    else
    {
        Write-Verbose "Retrieving device info with hash"
        $deviceObject = GetDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    }
    $serialNumber = $deviceObject.serialNumber
    Write-Verbose "The serial number is $serialNumber."
    $hash = $deviceObject.hardwareHas
    Write-Verbose "The hardware hash is $hash"
    $make = $deviceObject.manufacturer
    Write-Verbose "The manufacturer is $make"
    $model = $deviceObject.model
    Write-Verbose "The model is $model"
    $parentDir = (Get-Item -Path $PWD).Parent.FullName
    Write-Verbose "The parent directory is $parentDir"
    $outputFile = "$parentDir\device_$serial.csv"
    Write-Verbose "The output file is $outputFile"
    Write-Host "Processing device with serial number $serialNumber, manufacturer $make, and model $model."
    if ($GetDeviceHash)
    {
        GetDeviceHash -Device $deviceObject -OutputFile $outputFile
        exit 0
    }
}
else
{
    Write-Host "Using the provided serial number $serialNumber."
}
#endregion Gather device information.

$accessToken = GetGraphAccessToken -configFile $configFile
if ($null -eq $accessToken)
{
    Write-Host 'Failed to retrieve access token.' -ForegroundColor Red
    Write-Host 'Functions that require direct access to the API will not work.' -ForegroundColor Red
}

#region Check if the device is already in Intune
if (-not $NoIntuneCheck)
{
    $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
    Write-Verbose "The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)"
    if ($deviceAssignment)
    {
        if ($deviceAssignment.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
        {
            Write-Host 'The device is already in Intune and is assigned to a profile.' -ForegroundColor Green
            Write-Verbose "The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)."
            $profileAssignmentDate = ($deviceAssignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
            Write-Host "The device was assigned to the deployment profile $($deviceAssignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
            Write-Host "The device enrollment state is $($deviceAssignment.enrollmentState)." -ForegroundColor Green
            switch ($deviceAssignment.enrollmentState)
            {
                'notContacted'
                {
                    Write-Host 'The device has not contacted the enrollment service.' -ForegroundColor Green
                    Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
                }
                'enrolled'
                {
                    Write-Host 'The device appears to have been enrolled.' -ForegroundColor Red
                    Write-Host "Looking up user information..."
                    $deviceManagementUri = "deviceManagement/managedDevices"
                    $managedDeviceFilter = "serialNumber eq '$serialNumber'"
                    # $extraparameters = "select=userPrincipalName,userDisplayName,lastLogOnDateTime&orderby=userDisplayName"
                    $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -Filter $managedDeviceFilter).value
                    Write-Host "The device is registered to the user $($managedDevice.userDisplayName) with the email address $($managedDevice.userPrincipalName)." -ForegroundColor Red
                    $LastLogonDate = ($managedDevice.usersLoggedOn.lastLogOnDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
                    Write-Host "The last logon date was $LastLogonDate." -ForegroundColor Red
                    Write-Host "The device needs to be cleaned before giving to another user.." -ForegroundColor Red
                    $choices = @('Clean the device', 'Wipe the device')
                    $choice = DisplayNumericMenu -Choices $choices 
                    switch ($choice)
                    {
                        $choices[0]
                        {
                            Write-Host "Cleaning the device is a distructive action and cannot be undone" -ForegroundColor Red
                            Write-Host "Are you sure you want to clean the device?" -ForegroundColor Red
                            $subchoices = @('Yes', 'No')
                            $subchoice = DisplayNumericMenu -Choices $subchoices
                            switch ($subchoice)
                            {
                                'yes'
                                {
                                    Write-Host "Cleaning device..."
                                    $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes -ForceNewToken
                                    SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'clean'
                                }
                                'no'
                                {
                                    Write-Host "Exitting... Come back when you are sure."
                                }
                            }
                        }
                        $choices[1]
                        {
                            Write-Host "Wiping device..."
                            Write-Host "This will remove all data from the device." -ForegroundColor Red
                            Write-Host "Are you sure you want to wipe the device?" -ForegroundColor Red
                            Write-Host "This is a destructive action and cannot be undone." -ForegroundColor Red
                            $subchoices = @('Yes', 'No')
                            $subchoice = DisplayNumericMenu -Choices $subchoices
                            switch ($subchoice)
                            {
                                'yes'
                                {
                                    Write-Host "Wiping device..."
                                    $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes
                                    SendDeviceCommand -ManagedDeviceId $deviceAssignment.managedDeviceId -AccessToken $accessToken -Command 'wipe'
                                }
                                'no'
                                {
                                    Write-Host "Exitting... Come back when you are sure."
                                }
                            }
                        }
                    }
                }
                'pendingReset'
                {
                    Write-Host 'The device is pending a reset.' -ForegroundColor Yellow
                    Write-Host "The device needs to be allowed to finish the reset." -ForegroundColor Yellow
                    Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Yellow
                    Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Yellow
                    exit 1
                }
                'enrollmentFailed'
                {
                    Write-Host 'The device enrollment failed.' -ForegroundColor Red
                    Write-Host 'This may cause issues when the user loggs on for the first time.' -ForegroundColor Red
                    Write-Host "This means someone has already unsuccessfully tried to enroll the device." -ForegroundColor Red
                    Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Red
                    Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
                    exit 1
                }
                default
                {
                    Write-Host "The device enrollment state is $($deviceAssignment.enrollmentState)." -ForegroundColor Red
                    Write-Host 'Please check the Intune portal or contact an Intune administrator before you give the device to a user.' -ForegroundColor Red
                    exit 1
                }
            }
            if ($deviceAssignment.enrollmentState -ne 'enrolled')
            {
                switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                {
                    'unassigned'
                    {
                        Write-Host 'The device is not assigned to a deployment profile.' -ForegroundColor Red
                        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
                        exit 1
                    }
                    'pending'
                    {
                        Write-Host 'The device is pending assignment to a deployment profile.' -ForegroundColor Yellow
                        Write-Host 'Please check again after a little while.' -ForegroundColor Yellow
                        Write-Host 'If you continue to get this messgage, please check the Intune portal or contact an Intune administrator.' -ForegroundColor Yellow
                        exit 1
                    }
                    default
                    {
                        Write-Host "The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)."
                    }
                }
            }
        }
    }
    else
    {
        Write-Host 'The device is not in Intune.'
        if (-not $check)
        {
            Write-Host "Would yu like to continue to import the device to Intune?" -ForegroundColor Yellow
            $choices = @('Import the device')
            $choice = DisplayNumericMenu -Choices $choices
            if ($choice[0])
            {
                Write-Host 'Continuing to import the device.'
            }
            else
            {
                Write-Host 'Exitting script.' -ForegroundColor Red
                exit 1
            }
        }
    }
}
else
{
    Write-Host 'Skipping Intune check.'
}
if (-not $check)
{
    $choices = @('Restart the device', 'Continue to wait for profile assignment', 'Delete from Autopilot')
    $choice = DisplayNumericMenu -Choices $choices 
    switch ($choice)
    {
        $choices[0]
        {
            Write-Host 'Restarting the device...'
            RestartDevice
        }
        $choices[1]
        {
            Write-Host 'Continuing to wait for profile assignment...'
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -waitforAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
        }
        $choices[2]
        {
            Write-Host 'Deleting the device from Autopilot...'
            if (DeleteAutopilotDevice -DeviceIdentifyer $deviceAssignment.id -IdentifyerType 'DeviceId')
            {
                Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
            }
            else
            {
                Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                exit 1
            }
        }
    }
    Write-Verbose "Exitting script as requested."
    exit 0
}
else
{
    Write-Host 'Continuing to import the device.'
}
#endregion Check if the device is already in Intune

$importStart = Get-Date
$device = ImportAutopilotDevice -DeviceObject $deviceObject -AccessToken $accessToken -GroupTag $GroupTag -AssignedUser $AssignedUser -TimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
if ($device.state.deviceImportStatus -eq 'complete')
{
    $serialNumber = $device.SerialNumber
    Write-Host "The import of device with serial number $serialNumber completed successfully." -ForegroundColor Green
    Write-Host 'Checking device assignment.'
    $assignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -WaitForAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
    Write-Verbose "The assignment details are: $($assignment | ConvertTo-Json)"
    if ($assignment)
    {
        Write-Verbose "The assignment status is $($assignment.deploymentProfileAssignmentStatus)"    
        if (($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync') -and $null -ne $assignment.deploymentProfile.displayName )
        {
            $assignment.deploymentProfileAssignedDateTime
            $profileAssignmentDate = if ($enrollmentState.managedDevice.device.enrolledDateTime)
            {
                $assignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K" 
            }
            Write-Host 'Congratulations!!! ' -ForegroundColor Magenta
            Write-Host "The device is successfully assigned to the deployment profile $($assignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
            Write-Host "The device enrollment state is $($assignment.enrollmentState). " -ForegroundColor Green -NoNewline
            if ($assignment.enrollmentState -eq 'notContacted')
            {
                Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
            }
            $importDuration = (Get-Date) - $importStart
            $importMinutes = [int]$importDuration.TotalMinutes
            $importSeconds = $importDuration.Seconds
            Write-Host "Elapsed time to complete: $importMinutes minutes, $importSeconds seconds"
            $importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
            Write-Host "Elapsed time to complete: $importSeconds seconds"
            if (-not (RestartDevice))
            {
                exit 0
            }
        }
        else
        {
            Write-Host 'The device could not be assigned to a deployment profile.' -ForegroundColor Red
            Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
            Write-Host "The device current assignment status is $($assignment.deploymentProfileAssignmentStatus)."
            Write-Host "The device assignment profile name is $($assignment.deploymentProfile.displayName)."
            Write-Host "The device profile assignment date is $($assignment.deploymentProfileAssignmentDateTime)."
        }
    }
    else
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
        GetDeviceHash -Device $deviceObject -OutputFile $outputFile
        exit 1
    }
}
elseif ($device.state.deviceImportStatus -eq 'error')
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
    GetDeviceHash -Device $deviceObject -OutputFile $outputFile
    exit 1
}
else
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host "$($device.state.deviceImportStatus)" -ForegroundColor Red
    $createHash = GetDeviceHash -Device $deviceObject -OutputFile $outputFile
    if ($createHash)
    {
        Write-Verbose 'Device hash created successfully.'
        exit 0
    }
    else
    {
        Write-Verbose 'Failed to create device hash.'
        exit 1
    }
}
#endregion Add the device to Intune.

# SIG # Begin signature block
# MII95AYJKoZIhvcNAQcCoII91TCCPdECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC7BlfBASo/GlY6
# rfszP/rgBh30clL0uNM0wh9CzKaw9KCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAKui2AU
# rM0VqBZ/AAAAAq6LMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwNTAxMDQwNjUxWhcNMjUwNTA0
# MDQwNjUxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# jyaICLI9BqDMk/l9QxgoJCRj/CBTla7ZHRfYlZOu9EMU7znqu/DtlhUwIhD2R24t
# gn6YJe4gMdJ+U/oAgXq07EHJvRWqtorzi3vv1G9p6Nv6uwPeZH/lJ9LjDThCp6VJ
# 5c+MnVrNGKSbsFVZWKnhn9S5JHh5hoWtVeTO0YfyBQb4wWQbHXrKm6a+cMMV4LjQ
# Y6+Orxojeuer6sqSpilOMZLJwRo3dAWU7ntmqW/XBI4Z44PDctw8uAV7/1TRP/6I
# TIdZpJbaM4EHAK1/N4BFu911CBgfuEiNbXYVFULxdciEG0RVbrGCMMD17DqZYrXx
# fNjg9/dwaS6WKv1E1DlLMr2B8I6it+kjWo2Ki0DCc3RcvifOztctF+JSvCWK7fPV
# 4vmH981lq7tclIyn8w/RVPVUJ2OQutqVUusmOWKZEq4wI8qpzZJYjsLALkhFvOoa
# MEWadOCLhttrHcq4RDNpc1q01FGRK3uMCSad/UcI+GydyyTacOOXe+qqrHCzX3zF
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFGh2SUupHiUlJGlCyXw5l1YS+MJ1MB8GA1UdIwQY
# MBaAFGWfUc6FaH8vikWIqt2nMbseDQBeMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAHTHgapcBsF07MeD
# z2VBsQ8CkdrDo1A47+jAO9bpp/L2vcamTzHyOlVv+i9Sv4p8rPDjfLpRPRM5/2zd
# tHjD8ZWFFNOPMcmK9V2RLUWgkpXI8t12QlBVYEZZR5vbwLTrVC3HQcBrJNb0lN9B
# j492zCI7vklcCbkeLMIHKleDfoewWnzib3UDNoYy8l+6uk0ytB0idKmzjzMN8GIs
# pcuNgJU9ZtgYa36/dGatLUlaa1RQQBUQGlHCsoB7jh45B3qnHdrAhav6u1H62ut7
# YzGkBESe0qM1YMblb6zhe1gfor3e1nRVqaa4mo4J7f9LiEyLEvkw41IMWXUbRxUE
# JIeLOxgeUwXY6tiose3Az5grExQfP7Ny1f72AAbYLT9HpVWAV0JytdksTAZaBjAX
# cQb060G6z4vNlb7nG3y/trDI49jd+Z6d6j2XTVGGZBRhlgDRfWDG1tk7wj/nlz+L
# 05pUTGp+HrxXIpmB6ewIlh1di6Rb5T0JyksoZDXeZ00DQv1e+glujOSuodjv/m1e
# eQWC4eY+jtv8CDT9pI/vezJWEm7g07hqMz0rCBm3L725xfq+D1OEcUWzP9tCCv61
# kboZbqaLVXinzws19yBm1s3lSIxf0nIzqfQqHfJPUnbtlDxOlTVX2GQfjLs6B3jc
# YQEo+cDYX0lzrVMtYd05DcE0xvPNMIIG5zCCBM+gAwIBAgITMwACrotgFKzNFagW
# fwAAAAKuizANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDUwMTA0MDY1MVoXDTI1MDUwNDA0MDY1
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAI8miAiy
# PQagzJP5fUMYKCQkY/wgU5Wu2R0X2JWTrvRDFO856rvw7ZYVMCIQ9kduLYJ+mCXu
# IDHSflP6AIF6tOxByb0VqraK84t779Rvaejb+rsD3mR/5SfS4w04QqelSeXPjJ1a
# zRikm7BVWVip4Z/UuSR4eYaFrVXkztGH8gUG+MFkGx16ypumvnDDFeC40GOvjq8a
# I3rnq+rKkqYpTjGSycEaN3QFlO57Zqlv1wSOGeODw3LcPLgFe/9U0T/+iEyHWaSW
# 2jOBBwCtfzeARbvddQgYH7hIjW12FRVC8XXIhBtEVW6xgjDA9ew6mWK18XzY4Pf3
# cGkulir9RNQ5SzK9gfCOorfpI1qNiotAwnN0XL4nzs7XLRfiUrwliu3z1eL5h/fN
# Zau7XJSMp/MP0VT1VCdjkLralVLrJjlimRKuMCPKqc2SWI7CwC5IRbzqGjBFmnTg
# i4bbax3KuEQzaXNatNRRkSt7jAkmnf1HCPhsncsk2nDjl3vqqqxws198xQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRodklLqR4lJSRpQsl8OZdWEvjCdTAfBgNVHSMEGDAWgBRl
# n1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQB0x4GqXAbBdOzHg89lQbEP
# ApHaw6NQOO/owDvW6afy9r3Gpk8x8jpVb/ovUr+KfKzw43y6UT0TOf9s3bR4w/GV
# hRTTjzHJivVdkS1FoJKVyPLddkJQVWBGWUeb28C061Qtx0HAayTW9JTfQY+Pdswi
# O75JXAm5HizCBypXg36HsFp84m91AzaGMvJfurpNMrQdInSps48zDfBiLKXLjYCV
# PWbYGGt+v3RmrS1JWmtUUEAVEBpRwrKAe44eOQd6px3awIWr+rtR+trre2MxpARE
# ntKjNWDG5W+s4XtYH6K93tZ0VammuJqOCe3/S4hMixL5MONSDFl1G0cVBCSHizsY
# HlMF2OrYqLHtwM+YKxMUHz+zctX+9gAG2C0/R6VVgFdCcrXZLEwGWgYwF3EG9OtB
# us+LzZW+5xt8v7awyOPY3fmeneo9l01RhmQUYZYA0X1gxtbZO8I/55c/i9OaVExq
# fh68VyKZgensCJYdXYukW+U9CcpLKGQ13mdNA0L9XvoJbozkrqHY7/5tXnkFguHm
# Po7b/Ag0/aSP73syVhJu4NO4ajM9KwgZty+9ucX6vg9ThHFFsz/bQgr+tZG6GW6m
# i1V4p88LNfcgZtbN5UiMX9JyM6n0Kh3yT1J27ZQ8TpU1V9hkH4y7Ogd43GEBKPnA
# 2F9Jc61TLWHdOQ3BNMbzzTCCB1owggVCoAMCAQICEzMAAAAF+3pcMhNh310AAAAA
# AAUwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTNaFw0yNjA0MTMx
# NzMxNTNaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDSGpl8PzKQpMDoINta
# +yGYGkOgF/su/XfZFW5KpXBA7doAsuS5GedMihGYwajR8gxCu3BHpQcHTrF2o6QB
# +oHp7G5tdMe7jj524dQJ0TieCMQsFDKW4y5I6cdoR294hu3fU6EwRf/idCSmHj4C
# HR5HgfaxNGtUqYquU6hCWGJrvdCDZ0eiK1xfW5PW9bcqem30y3voftkdss2ykxku
# RYFpsoyXoF1pZldik8Z1L6pjzSANo0K8WrR3XRQy7vEd6wipelMNPdDcB47FLKVJ
# Nz/vg/eiD2Pc656YQVq4XMvnm3Uy+lp0SFCYPy4UzEW/+Jk6PC9x1jXOFqdUsvKm
# XPXf83NKhTdCOE92oAaFEjCH9gPOjeMJ1UmBZBGtbzc/epYUWTE2IwTaI7gi5iCP
# tHCx4bC/sj1zE7JoeKEox1P016hKOlI3NWcooZxgy050y0oWqhXsKKbabzgaYhhl
# MGitH8+j2LCVqxNgoWkZmp1YrJick7YVXygyZaQgrWJqAsuAS3plpHSuT/WNRiyz
# JOJGpavzhCzdcv9XkpQES1QRB9D/hG2cjT24UVQgYllX2YP/E5SSxah0asJBJ6bo
# fLbrXEwkAepOoy4MqDCLzGT+Z+WvvKFc8vvdI5Qua7UCq7gjsal7pDA1bZO1AHEz
# e+1JOZ09bqsrnLSAQPnVGOzIrQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRln1HOhWh/L4pFiKrdpzG7Hg0A
# XjBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAEVJ
# YNR3TxfiDkfO9V+sHVKJXymTpc8dP2M+QKa9T+68HOZlECNiTaAphHelehK1Elon
# +WGMLkOr/ZHs/VhFkcINjIrTO9JEx0TphC2AaOax2HMPScJLqFVVyB+Y1Cxw8nVY
# fFu8bkRCBhDRkQPUU3Qw49DNZ7XNsflVrR1LG2eh0FVGOfINgSbuw0Ry8kdMbd5f
# MDJ3TQTkoMKwSXjPk7Sa9erBofY9LTbTQTo/haovCCz82ZS7n4BrwvD/YSfZWQhb
# s+SKvhSfWMbr62P96G6qAXJQ88KHqRue+TjxuKyL/M+MBWSPuoSuvt9JggILMniz
# hhQ1VUeB2gWfbFtbtl8FPdAD3N+Gr27gTFdutUPmvFdJMURSDaDNCr0kfGx0fIx9
# wIosVA5c4NLNxh4ukJ36voZygMFOjI90pxyMLqYCrr7+GIwOem8pQgenJgTNZR5q
# 23Ipe0x/5Csl5D6fLmMEv7Gp0448TPd2Duqfz+imtStRsYsG/19abXx9Zd0C/U8K
# 0sv9pwwu0ejJ5JUwpBioMdvdCbS5D41DRgTiRTFJBr5b9wLNgAjfa43Sdv0zgyvW
# mPhslmJ02QzgnJip7OiEgvFiSAdtuglAhKtBaublFh3KEoGmm0n0kmfRnrcuN2fO
# U5TGOWwBtCKvZabP84kTvTcFseZBlHDM/HW+7tLnMIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
# nTiOL60cPqfny+Fq8UiuZzGCGpQwghqQAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwACrotgFKzNFagWfwAAAAKuizAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDANsy0j7hvjRhCbGTCJB7lccjt
# 56ALbUxY2yRTX9lqADANBgkqhkiG9w0BAQEFAASCAYBOXS2LERVaUJWVdRTs1cpv
# bptyz+sd/26ozZxlkLK4avXZnTp1zeULBYLIO8SqrfGROTOAJCm5HFfkC4qFUssn
# QziNu6tFKhHStneEcFIMJqgQybIq7kBbbU3H3qLvEoPrLaMKJjeVmD87qvx0Ku1u
# uweuStQcakcId4T50AvV/U2xT6APxEUIKBelxcrQo2xLyh+Cx4KHAsyyFth7v9D2
# /0Q/Pk+7SvnSbelmuEU1XBpGTUKtVCQHN1YDz57t5m7mtpP+cMfJCHAomRUa76va
# TwFOoId20R+FBC+tKInj+e59zvr6QO75bWCfqvA15SEJbO/F+eBdpE8uhkH0GYUA
# wqfPBBozYYts9+uuW3a0i2zRLQp7zaYNu6OdMnZXsXqRc/NhaOo8e0N9Ruuibr7H
# AJH0vG9yJESyscfbjHa23A+44UqJKuBK8Kk31Z0L4QRf67tvfu+dxu2zKPGws5Yw
# STJ0vFSai0jCtGIrphHlkSLzk/pYUgFFLLxEugHNLc6hghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQg5gjBcywDCSshxAcibhR34jTeoALgf3Y9xllnvN03
# a74CBmgSusgRchgTMjAyNTA1MDExNzU0MzIuMjY0WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOkE1MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
# QSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAA
# BeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29m
# dCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eX
# M9ETBb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3T
# OYtgoBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/S
# sah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i
# 5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx6
# 9uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3G
# gZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2
# HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT
# 4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnG
# nsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914Aq
# HOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3E
# Q79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3Nv
# ZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYI
# KwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAX4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVj
# JviceW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGE
# ndSpZ5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1Cesuf
# U211rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3a
# d4Xtm7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P
# 8tHYIFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAo
# dDW8HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb
# +H7DRon9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D
# +mTm8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN
# 41LGXHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgH
# APUvIdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgEC
# AhMzAAAASFV3ch50krf3AAAAAABIMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1MloXDTI1MTExOTE4NDg1MlowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpBNTAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDLfoD3Z++SVTIY
# JFnFnPrVlMvaJYlPTronDHe0VuiHANnCKTIq8qJk4weZ+cf1+vIJ7cdl+/gw3AaR
# gAQT/iDU6vLN6QfFg1YAO6cR7voo2y4QDJPguGjKpGtONxGj9fOavAkDTH4gaTJn
# uK9mhvIzUqI7TEDV7JoK6Sy0kYsVcWbp2mF4RJ4FliqEm70YNSwLjnKn5qYIZJoQ
# YKg9ZWYzYabgr9clHsjlZtFepsTYn2hrim8vaeO9dymfk7pmXrQX2O85UQl8k6AK
# 2B8KKQVuNNnBa37EAWfxxqlO97WOvkzboNZYWHWFOlS3aklvSa+742PSVIyEgraC
# gkqIMZkVuzF+5QnuyVekXaZ/hz+3ujmyrxsnXUXbXYmQi6enT7comWGpTfRo2WZt
# +tEzvhl46YmQ9IGREfn+ZRBWr8CHA+x2q1uqg9GTfNUvkQ4HxLSeu4eqDFKj9ViI
# hQu+Yn/IGitWjufmfBKp2nigC4FFabRe4vShrA7xJtrbOFmJ3jAIRtvu2dufiI7V
# uGQCPN2bXRjiafbBXevEuhA3998ECz4uwnGfSFF1u+LS7yDZLb8NzxXnuiN4bP/X
# w3AjKBCGr/lnmSJiCwoMERhXCyLb8KUhAOzXF06EZN0xnwud2A94OTQ7o66oXbii
# 21Z6KxjnSGV1XizJNCa+P1yFEBqVKQIDAQABo4IByzCCAccwHQYDVR0OBBYEFKa9
# d/S6631KGfe8umYaOzc8HPdHMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEATa2L4B40TANMMYgCNXTy+cuK
# TjDzNZ3dAJ+S4PbAKf78FBwQ79hYihqZ/qIg6GWt/jQ5GAsBSpBYKNZOMtUMArNQ
# fIlZ42y2tylAP/xBGQ6wwmu0uBmXzg6W3TomTZ56bh90li7ZO4BbiiCg2CAkpvtT
# vrgYu7FbvvTqTIv/LvXQaCJx+sxvJPsbIAyWUSfIYTdAWlVo63sJ8AkH5pzpifvk
# LyXmLxq2jTywaeD/pKazEJwXAby8+u04oCGVCZDbD+sDOJ753hbl6XyWOXmCpXVv
# j2wPoXJdI+T6DPtc9GWtMxSDUKZtVJV2UVgACazx8gODidj6h3aGwOr8Ut/FsO/X
# 853Q1CYpfHWfW3JEkLc3FslKf2Kl2zH14EBoLeUpTykhn8NZUeXhHsuuKjPx8mUA
# LW/LglUjZXyJ3yBQ1PiOevpxTot8afXc6rlq9FJ2kgtM6ij2uW7f9at5yIcdwFM9
# VUm0aCgiXvjvRkQeSUIIAm40LX2qve2kdPgNe/Zt8yb5zDcsJjHhZPtXiW3TnBUY
# LqCsLnD6fVh6X5QvFbtjLlBIMt3XlvAQnuVEzhoyt3isww9w8t+oGCg4aNh94IdK
# vUNS1ffxC+Q+XrsT3wDlSlqNSLfooxhsCu5gXKtzpfhx8+4l9rVHJxgZE9nwGKiA
# bwNXxKFB3bVgmwodJbUxggdGMIIHQgIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASFV3ch50krf3AAAA
# AABIMA0GCWCGSAFlAwQCAQUAoIIEnzARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA1MDExNzU0
# MzJaMC8GCSqGSIb3DQEJBDEiBCCD+zmJhDK+UXJuNiCD6RUedNrcOMrWcCjPf+J6
# Kt3NpjCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIOoqAVebTwjWn0P0gLwZ
# 03YfjX3QvDtHZEl38m8i8x1BMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASFV3ch50krf3AAAAAABI
# MIIDYQYLKoZIhvcNAQkQAhIxggNQMIIDTKGCA0gwggNEMIICLAIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjpBNTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# AOYSfUGUVzjpxDh59/qJiDRZaMMnoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 673iDDAiGA8yMDI1MDUwMTEyMDUzMloYDzIwMjUwNTAyMTIwNTMyWjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDrveIMAgEAMAoCAQACAjT+AgH/MAcCAQACAhJ0MAoC
# BQDrvzOMAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAH+JFgCxVvralMnK
# Oh5rsfswu/w5+sunju2tsj14NojuK4qaTgfAta6a2eqTDYAYFLEPB3cyxuls9g+x
# uo1/FnuJL53hU9dir7ZAiLDqUbW/YdhzcXll5NXjBYhDooGH3lu99eUwhLuT8kOQ
# c4P9aBRNp1bucycnIw/hc/D7WVgEzk8xmkxPLstfiVkMOC6lXn+eC4nbAnvzi9Yj
# lMjMm4qVw+zPtgz1Vu4wPoqJHJTfecU0iZUTp0+0VYSAzZtVfBA/cOlRDv/tB2+D
# KCk9x1bqQeLCoVn6IDu7aZJIXEF2XkxhetEY3igY3B66SIB8axYDDtZrvk2imWqq
# 9ls1BFIwDQYJKoZIhvcNAQEBBQAEggIAygJ1yKMw75mz1noyCP3ZF8sBSoiewUNd
# vduNk/Sgeta2pWDcwUCL2kH+7QX7Y8VjBi1dPSj1qQi0dv0w4PAVbcF9p9MiTr+2
# RK/ipTNBDty2FfCDZt17Dxdejtjw1h2qwRB9bm60/M0ikYUtYE3UMiiGS4GFOT2Q
# 6Xy97MsDB15h4KzykyOiNT3oT22RdFpqUfixOkcy9jIGkhvEmaEV5ZxxYvM0O2lQ
# DeNA8kjux+5mNksOTpHvyVpF3KDbMCGK7xD1SL+4LLgfS+ry8QAL60Y1JdYZMw+F
# TyVvAZ36uh9RjRbn60eckTU2YORuKSIp/OAEIGYqTmVJ6GfcLxw9MQTrAMYd0jAV
# zFrzwYzSmGdhtsX2u/3ZBisWciO/8YtVo+/8RLSBIS/FDxOxWfBboDIgtNQwYBL0
# 3kiUElY5HciAjtdaNnfjZP5icHVZEZZOXm0tIsErw3GXK829edsMX6k7++wgWb7V
# 2/f3wiSvMvVOQS92FmNpuPVEKEQG3tckk9cKJDFv/5178deiABGR/O39K+bVSky3
# mG9LH7vJ5oVhX40oxfjfVlLnjv2uZ93PkVAy43xW4dk0Gxt1cS7DQcgePkgU5mQJ
# IXAdJKtfUEI2IHcorTspNalKhv2hSPVWc4BdR5NwlKgDF6JqcQmvbo2vXHaJuOVU
# tJegwXE1zfQ=
# SIG # End signature block
