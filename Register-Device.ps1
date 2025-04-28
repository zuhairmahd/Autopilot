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
                    Write-Host "You may proceed with the enrollment process." -ForegroundColor Green
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
                                    $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes -ForceNewToken
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
                if (-not (RestartDevice))
                {
                    exit 0
                }
            }
            else
            {
                exit 0
            }
        }
        else
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
                    Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
                    exit 1
                }
            }
        }
    }
    else
    {
        Write-Host 'The device is not in Intune.'
    }
}
else
{
    Write-Host 'Skipping Intune check.'
}
if ($check)
{
    Write-Host "Exitting script as requested."
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
    if ($assignment)
    {
        Write-Verbose "The assignment details are: $($assignment | ConvertTo-Json)"
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
# MII94wYJKoZIhvcNAQcCoII91DCCPdACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBHsWHyWISw2KJP
# rTxVZR7RXsNHxlNFumbM4YJKx+nNzKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAOBkSbr
# 6+lwVlNvAAAAA4GRMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDI4MDQxOTQxWhcNMjUwNTAx
# MDQxOTQxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# mf7+tbRuD3PX1o3SA5VcMyu24VWwwXFUAKuJ2oHdop3XXh7bGz5l0hJFpYa4AV53
# drxAPr+yqkrMkM7TGBUpHoh5GR72SDwxqL8vct8vk/RvPzGh00mADuoe6nZEmlhM
# b3hd1jSBshAAOp6YriYs5Ya4vczHUzGC2J0/v3grIM1Szrb1W192P9H/wrnvonL1
# 8RpqWqMBSTkmm+poFuQg8L4IOGFjNIwZbFtCoohbaAb8Le87voODb3PTZhSr6pY9
# PHE2z78757rwj9dBuCPDlJJ4p9IF8GcH9x+vtmESbzPr/oi38GOKlYH3d/oL86oJ
# 8otscnjWUswDBjFa3gzS3TsEDZZTVk3X065Nd4Z8ztaN1c21L1D1pgSH7DZpjK37
# WohRZ3EqLj7tdqBDXIBfXft3hKP9hqdTpQJscHlY3nroJO972+76ZUmx6gdFHPG9
# 8d6FXU0iP+VddIxaS80/lJLPp8/N07dvTXUD8CnJGkx7VpDDN0j5KH94qGcfWqxT
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFH/Gq1LSAubj5J7trvB4xaAA4rAxMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAGpzME+ppSK7DG6k
# npXQw635cDKMdzVSx3mUysY/F872vnb5WTj+DoM/hUdH1oKsH6j6Vor3dshcU6IR
# GPGL0Mp8HPoqHbDoq1LR75T1IJA5SYB+yZH6TYkcjxDT4yhJ01rf74/x6JWtUi4Q
# Jjg22WFWxcD/UT5NmivRgQSMhQsLUKI9XaGBgYJuNSIJWkwYWaPBwoKpQz75IZDI
# sdl6311rU5IwkbUeXLvu7oInIBhv3hthwAzqho3u90KewmUZyP9Tma3pS8bXJXXg
# zeBLTk7vRYJzeDa+Wy0YD3gsAJqwnrTZ0VArs7eyFcK7G1go01B7ACd+YYi/FBt3
# EN59yRmn3vvJLLeFnfH8+7KOKr2JDiCnKnc4TdmiZOaZq1HV8s6ILDgfaWhrH7ve
# nKieancFYDNXomvmT7J1sOvZjMG/nBuhBfGTV8CoNXVOpNuW5et8biQuDu7ypPT8
# NDgcKpaz2Oj0AtOGgZYxY7jZF5diDx6vwF/aBwOKWTOunRnWo78z0vSsmUKPPkwm
# 1EhbhvpVWY7aSLqtQBAN8W5mle3fcw9mZt8Jk2BLlVIRJuDM2cUEuAUYXDr2Gl1Z
# lexNQUhLHDjcWCV8QidoXa6iq3pNnuphkbzUj2/t3i0vmKMnbMUniqjO0Gwl/rIf
# NJ7T5tGwLTVNY4jq1uPPD+ZqAhLYMIIG5zCCBM+gAwIBAgITMwADgZEm6+vpcFZT
# bwAAAAOBkTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyODA0MTk0MVoXDTI1MDUwMTA0MTk0
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJn+/rW0
# bg9z19aN0gOVXDMrtuFVsMFxVACridqB3aKd114e2xs+ZdISRaWGuAFed3a8QD6/
# sqpKzJDO0xgVKR6IeRke9kg8Mai/L3LfL5P0bz8xodNJgA7qHup2RJpYTG94XdY0
# gbIQADqemK4mLOWGuL3Mx1MxgtidP794KyDNUs629Vtfdj/R/8K576Jy9fEaalqj
# AUk5JpvqaBbkIPC+CDhhYzSMGWxbQqKIW2gG/C3vO76Dg29z02YUq+qWPTxxNs+/
# O+e68I/XQbgjw5SSeKfSBfBnB/cfr7ZhEm8z6/6It/BjipWB93f6C/OqCfKLbHJ4
# 1lLMAwYxWt4M0t07BA2WU1ZN19OuTXeGfM7WjdXNtS9Q9aYEh+w2aYyt+1qIUWdx
# Ki4+7XagQ1yAX137d4Sj/YanU6UCbHB5WN566CTve9vu+mVJseoHRRzxvfHehV1N
# Ij/lXXSMWkvNP5SSz6fPzdO3b011A/ApyRpMe1aQwzdI+Sh/eKhnH1qsUwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBR/xqtS0gLm4+Se7a7weMWgAOKwMTAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBqczBPqaUiuwxupJ6V0MOt
# +XAyjHc1Usd5lMrGPxfO9r52+Vk4/g6DP4VHR9aCrB+o+laK93bIXFOiERjxi9DK
# fBz6Kh2w6KtS0e+U9SCQOUmAfsmR+k2JHI8Q0+MoSdNa3++P8eiVrVIuECY4Ntlh
# VsXA/1E+TZor0YEEjIULC1CiPV2hgYGCbjUiCVpMGFmjwcKCqUM++SGQyLHZet9d
# a1OSMJG1Hly77u6CJyAYb94bYcAM6oaN7vdCnsJlGcj/U5mt6UvG1yV14M3gS05O
# 70WCc3g2vlstGA94LACasJ602dFQK7O3shXCuxtYKNNQewAnfmGIvxQbdxDefckZ
# p977ySy3hZ3x/Puyjiq9iQ4gpyp3OE3ZomTmmatR1fLOiCw4H2loax+73pyonmp3
# BWAzV6Jr5k+ydbDr2YzBv5wboQXxk1fAqDV1TqTbluXrfG4kLg7u8qT0/DQ4HCqW
# s9jo9ALThoGWMWO42ReXYg8er8Bf2gcDilkzrp0Z1qO/M9L0rJlCjz5MJtRIW4b6
# VVmO2ki6rUAQDfFuZpXt33MPZmbfCZNgS5VSESbgzNnFBLgFGFw69hpdWZXsTUFI
# Sxw43FglfEInaF2uoqt6TZ7qYZG81I9v7d4tL5ijJ2zFJ4qoztBsJf6yHzSe0+bR
# sC01TWOI6tbjzw/magIS2DCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
# AAQwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTJaFw0yNjA0MTMx
# NzMxNTJaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDhzqDoM6JjpsA7AI9s
# GVAXa2OjdyRRm5pvlmisydGnis6bBkOJNsinMWRn+TyTiK8ElXXDn9v+jKQj55cC
# pprEx3IA7Qyh2cRbsid9D6tOTKQTMfFFsI2DooOxOdhz9h0vsgiImWLyTnW6locs
# vsJib1g1zRIVi+VoWPY7QeM73L81GZxY2NqZk6VGPFbZxaBSxR1rNIeBEJ6TztXZ
# sz/Xtv6jxZdRb3UimCBFqyaJnrlYQUdcpvKGbYtuEErplaZCgV4T4ZaspYIYr+r/
# hGJNow2Edda9a/7/8jnxS07FWLcNorV9DpgvIggYfMPgKa1ysaK/G6mr9yuse6cY
# 0Hv/9Ca6XZk/0dw6Zj9qm2BSfBP7bSD8DfuIN+65XDrJLYujT+Sn+Nv4ny8TgUyo
# iLDEYHIvjzY8xUELep381sVBrwyaPp6exT4cSq/1qv4BtwrC6ZtmokkqZCsZpI11
# Z+TY2h2BxY6aruPKFvHBk6OcuPT9vCexQ1w0B7T2/6qKjPJBB6zwDdRc9xFBvwb5
# zTJo7YgKJ9ZMrvJK7JQnzyTWa03bYI1+1uOK2IB5p+hn1WaGflF9v5L8rlqtW9Nw
# u6S3k91MNDGXnnsQgToD7pcUGl2yM7OQvN0SHsQuTw9U8yNB88KAq0nzhzXt93YL
# 36nEXWURBQVdj9i0Iv42az1xZQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQkRZmhd5AqfMPKg7BuZBaEKvgs
# ZzBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGct
# OF2Vsw0iiR0q3NJryKj6kQ73kJzdU7Jj+FCwghx0zKTaEk7Mu38zVZd9DISUOT9C
# 3IvNfrdN05vkn6c7y3SnPPCLtli8yI2oq8BA7nSww4mfdPeEI+mnE02GgYVXHPZT
# KJDhva86tywsr1M4QVdZtQwk5tH08zTBmwAEiG7iTpVUvEQN7QZJ5Bf9kTs8d9OD
# jgu5+3ggqpiae/UK6iyneCUVixV6AucxZlRnxS070XxAKICi4liEvk6UKSyANv29
# 78dCEsWd6V+Dp1C5sgWyoH0iUKidgoln8doxm9i0DvL0Q5ErhzGW9N60JcAdrKJJ
# cfS54T9P3bBUbRyy/lV1TKPrJWubba+UpgCRcg0q8M4Hz6ziH5OBKGVRrYAK7YVa
# fsnOVNJumTQgTxES5iaS7IT8FOST3dYMzHs/Auefgn7l+S9uONDTw57B+kyGHxK4
# 91AqqZnjQjhbZTIkowxNt63XokWKZKoMKGCcIHqXCWl7SB9uj3tTumult8EqnoHa
# TZ/tj5ONatBg3451w87JAB3EYY8HAlJokbeiF2SULGAAnlqcLF5iXtKNDkS5rpq2
# Mh5WE3Qp88sU+ljPkJBT4kLYfv3Hh387pg4VH1ph7nj8Ia6nt1FQh8tK/X+PQM9z
# oSV/djJbGWhaPzJ5jeQetkVoCVEzCEBfI9DesRf3MIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpMwghqPAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADgZEm6+vpcFZTbwAAAAOBkTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBNMHEru50IYBOn+1azLrpPPa5+
# TFgSFA/8OMq104cN/zANBgkqhkiG9w0BAQEFAASCAYA3vDFrF6FxE/IsOwaYZDPz
# 4ytCwRp7MUr0ddBUuIH71u0RhrnqRWLZWesgceyF/+kUVRriFdcGrp+2oUF0jHJA
# De8+1yYLFpkjXJUU6jJtq57P73tVeHAl0mBSE/bu17yfwLNyBrzOBzGtjLTMQ/xb
# kaNFl4rrXWM4ukkffDZ8fDXLnR+aJBUJMj3rDq5GLfEjGWHvKErHtbwQikuudG8I
# 5cRR0bKMBKuTvZc1Y+ND+sAMUTqAqM3OGQNHtuz4fFrw5V8TpC46PP+u3lmE5Qt6
# SwplGejrLvQumpVuFxwWuaqEsGHkiiJgA5w4E68GoV6oAPDe8DPSYuOFn0PAaORl
# ul++/7Wx7Gyaq3eyq+BUdF/o4XwiV/CM6WuPIgl6rz6avoVeH3/hU/wTARk8ZX6G
# B1/twi5tjmhGTdmj9HJeFKY/IA6fyUdfxou+FrrU6xx4faBAEH92bx1gpeHvVOR4
# 9r9LJG/wGOKDX1n2br64EAgxFB1Ep2TQ9LmfLtP+k6ehghgTMIIYDwYKKwYBBAGC
# NwMDATGCF/8wghf7BgkqhkiG9w0BBwKgghfsMIIX6AIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgXHR28hQVgqRJ//qCoBuIhD52xzGTNX+VNNEwKR5s
# gQwCBmgLvv0zwRgSMjAyNTA0MjgxMDAzNDkuNzFaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046QTUwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPITCCB4IwggVqoAMCAQICEzMAAAAF
# 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0
# IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz
# 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5
# i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx
# qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk
# X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2
# 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB
# nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd
# Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg
# juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae
# wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc
# 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD
# v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3
# oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl
# JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr
# BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC
# AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm
# +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd
# 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T
# bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3
# he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y
# 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0
# Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4
# fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6
# ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j
# UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5cwggV/oAMCAQIC
# EzMAAABIVXdyHnSSt/cAAAAAAEgwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODUyWhcNMjUxMTE5MTg0ODUyWjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkE1MDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMt+gPdn75JVMhgk
# WcWc+tWUy9oliU9OuicMd7RW6IcA2cIpMiryomTjB5n5x/X68gntx2X7+DDcBpGA
# BBP+INTq8s3pB8WDVgA7pxHu+ijbLhAMk+C4aMqka043EaP185q8CQNMfiBpMme4
# r2aG8jNSojtMQNXsmgrpLLSRixVxZunaYXhEngWWKoSbvRg1LAuOcqfmpghkmhBg
# qD1lZjNhpuCv1yUeyOVm0V6mxNifaGuKby9p4713KZ+TumZetBfY7zlRCXyToArY
# HwopBW402cFrfsQBZ/HGqU73tY6+TNug1lhYdYU6VLdqSW9Jr7vjY9JUjISCtoKC
# SogxmRW7MX7lCe7JV6Rdpn+HP7e6ObKvGyddRdtdiZCLp6dPtyiZYalN9GjZZm36
# 0TO+GXjpiZD0gZER+f5lEFavwIcD7HarW6qD0ZN81S+RDgfEtJ67h6oMUqP1WIiF
# C75if8gaK1aO5+Z8EqnaeKALgUVptF7i9KGsDvEm2ts4WYneMAhG2+7Z25+IjtW4
# ZAI83ZtdGOJp9sFd68S6EDf33wQLPi7CcZ9IUXW74tLvINktvw3PFee6I3hs/9fD
# cCMoEIav+WeZImILCgwRGFcLItvwpSEA7NcXToRk3TGfC53YD3g5NDujrqhduKLb
# VnorGOdIZXVeLMk0Jr4/XIUQGpUpAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQUpr13
# 9LrrfUoZ97y6Zho7Nzwc90cwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQBNrYvgHjRMA0wxiAI1dPL5y4pO
# MPM1nd0An5Lg9sAp/vwUHBDv2FiKGpn+oiDoZa3+NDkYCwFKkFgo1k4y1QwCs1B8
# iVnjbLa3KUA//EEZDrDCa7S4GZfODpbdOiZNnnpuH3SWLtk7gFuKIKDYICSm+1O+
# uBi7sVu+9OpMi/8u9dBoInH6zG8k+xsgDJZRJ8hhN0BaVWjrewnwCQfmnOmJ++Qv
# JeYvGraNPLBp4P+kprMQnBcBvLz67TigIZUJkNsP6wM4nvneFuXpfJY5eYKldW+P
# bA+hcl0j5PoM+1z0Za0zFINQpm1UlXZRWAAJrPHyA4OJ2PqHdobA6vxS38Ww79fz
# ndDUJil8dZ9bckSQtzcWyUp/YqXbMfXgQGgt5SlPKSGfw1lR5eEey64qM/HyZQAt
# b8uCVSNlfInfIFDU+I56+nFOi3xp9dzquWr0UnaSC0zqKPa5bt/1q3nIhx3AUz1V
# SbRoKCJe+O9GRB5JQggCbjQtfaq97aR0+A179m3zJvnMNywmMeFk+1eJbdOcFRgu
# oKwucPp9WHpflC8Vu2MuUEgy3deW8BCe5UTOGjK3eKzDD3Dy36gYKDho2H3gh0q9
# Q1LV9/EL5D5euxPfAOVKWo1It+ijGGwK7mBcq3Ol+HHz7iX2tUcnGBkT2fAYqIBv
# A1fEoUHdtWCbCh0ltTGCB0YwggdCAgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABIVXdyHnSSt/cAAAAA
# AEgwDQYJYIZIAWUDBAIBBQCgggSfMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDQyODEwMDM0
# OVowLwYJKoZIhvcNAQkEMSIEILoByrC7sGQmbbdrJB8O9KFCVHgTkEwKyXj72OPK
# DUbRMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQg6ioBV5tPCNafQ/SAvBnT
# dh+NfdC8O0dkSXfybyLzHUEwfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABIVXdyHnSSt/cAAAAAAEgw
# ggNhBgsqhkiG9w0BCRACEjGCA1AwggNMoYIDSDCCA0QwggIsAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOkE1MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# 5hJ9QZRXOOnEOHn3+omINFlowyegZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDr
# uYk6MCIYDzIwMjUwNDI4MDQ1NzMwWhgPMjAyNTA0MjkwNDU3MzBaMHcwPQYKKwYB
# BAGEWQoEATEvMC0wCgIFAOu5iToCAQAwCgIBAAICJNgCAf8wBwIBAAICE1owCgIF
# AOu62roCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQAC
# AwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAgpdQ5844KwKgRL9w
# ntLkrRuEkAGA2IahPE+qgsYos/zg5wnhcHphkcBxji019uSbqckd45yFxdbVprQc
# Kb0lVCKU78guU0cZFIM3QZR9xtMyKaXVP9F6/dx9A/7Kps+npPcr4/0ieqOeQyzC
# nnPMduGJ0tyb+7+0qSMaQXDF0y4KrFYr70Jv9ioKJCghrrYSQxmguXxTndcEaP8E
# ykpnjja6GfwB70jOBwYJA7xqHb+FxlHDEUD3Cck3lZEI/3fiF7j6hSQLpRLZlJ83
# 8vBPvPTmWyPHGAaqF5txpOu1CmOBiyFfeV2lUO7xUvS0WrF7qqRUHwjzect3nol/
# SwG/cTANBgkqhkiG9w0BAQEFAASCAgCTiOY4Ol7+arymkusO9GJcsRRu1Q6njvBU
# 0Q1Nui5xS2m+L6iPE2lm0kH4/YzUDUV+4U0yG/BlwaqAmAFApt3JFg9VfCAtu88k
# MCWXp4uslXFHwkldZHPAlwZniqO/jYsHH2giHHiTYR3KMVa2cGRlKzmUdoxz9Tlp
# BLRSLrnKCHni71eBWGQfWpcUa3xLijI1ZspquiGEvf/oRMQSMCajlCOQc2BRl4V+
# Zjcwc6kUkzTEdsssoQEguR3hAzz3gcYuQg9molzjxNIBH35WrBa8/yB5mXlnzPoI
# WkzWKJ3Ne3YiH4ym3MNvJOZpLJb3oPAWlfIFJbT1kGjuoUy/kWNNJfvUyi7sHelX
# wXZK5GRlxAeD3u7LJirMYvU5SU5/YgNmu5MCCD18nvdWz/2xhgOi5OKZBBBu3Atm
# 0PdNe0GLQDDub+UAbUDDlSG1/vbHPM5CrXk70d+6ULMOThMgvQJkX4ONLVX6CA8Y
# 5wrVug2Ls2SakVXUgDY8KW8iIi3+eaceyendYQBaN83KYtlqxuBr62gG+q3rauY0
# ShnFDKDhsZY6jrMRHOFPBHbpvLGMEho+VuPN2emKiY3/X3/wv2YsHUrttuQEOhuO
# DMjc6TcncS+4s02/76X2Svq/oFfQMjQMBrgacNd7+p7oSHEUF5iuSlWFeIbN7fJ1
# wC1JI55wfg==
# SIG # End signature block
