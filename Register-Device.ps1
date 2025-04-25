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

if (-not($NoAdminCheck -or $UpdateOnly -or $Reconfigure -or $check ))
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
if ($serialNumber -eq '' -and $check)
{
    Write-Host 'Using the local device serial number.'
    $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser -nohash
    $serialNumber = $deviceObject.serialNumber
    Write-Verbose "The serial number is $serialNumber."
    $hash = $deviceObject.hardwareHash
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
# MII9YAYJKoZIhvcNAQcCoII9UTCCPU0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD834aBAvgNDlGm
# GmpC+WmAs+gCNJJbnt2Ww1IZrTUlxKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAKZLXLd
# C8+fUGcaAAAAApktMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwNDI0MDQ0MDMyWhcNMjUwNDI3
# MDQ0MDMyWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# 5hkQco7D48Z2PmxPIwWxayf0baRANPffCssfn1K0fRYGRfQbTSSEdqgWsJswpFNj
# 1AhRtJ3a42Hz9B6r+zZaJuKpm5rsDblGRQhmjATshSnnCGQetusKd7HLVunqUPWM
# 50kxoXlUJfl4EeJCYYa5zp99jWYWf5hwONhbNv0vMTGBNeN8h8PyPDOQR0Bq9Aid
# muLfT2yCS+mvhg9Lmgw38catxujNMwaHzSYha9iWhhb2Uwimqr/F3OFegP4fd2rl
# 3nEJoCAer3hDUenQtaY+C4ODEy/8juIGIuB5jdZ2/jdZkBp4ZEa0gNeab3083D5o
# B16F+51GOGcAH5C4jbSq07+ykka2LqqS8hgFUlLxzU3f7gDpdAaPwt5a8vAUEQQq
# BCKCnmMprl2eaM+tEO1qCwofTX4bMX84wKWbpruxp3MIWjpEcl1Oe3H7sG3vvQqE
# +OXai+qWU+0ucXikaAj0bzkUqAwVUgFY/4i3SM5xOjRlreDt8L2myBxT+T88Y/G/
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFGrNWdlJNXtPUqNgkdmIo9w5ZecMMB8GA1UdIwQY
# MBaAFGWfUc6FaH8vikWIqt2nMbseDQBeMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAD2jFaZbIETRFWPj
# uJJ6Vr0oezUUjG4JOblltnDzJ1LjP0XUQW0DsTBasaSMfMRpn3Bs40IlntLj7LAi
# 6UaVn/7d7X+AFhcj6qUJNmSssPPZCGWuMyBSI+96f8LTwbHV3BxB1iIGYhZQNYeI
# f4Zka+IJZVxaPNc+ak3b9DjI0yuNDNYDfVbqeewbUKQ8OtTDr36MeDv5UZbzcKju
# j6JAUpBBYPo95k/51baf14zA/fn+baAkBKHt6mYgFrOOYK12fVw4gxzjlORgW/eT
# PRfg1UM1HJXlx/GGmpqHHxyzlAnqzwnz7854r4TjrLoMCNmDFBZgbYzjwGFQw8r3
# Uis7U0nolsat8Tn/6H/HJzfDz9u3TNFGWYfTnO3bgsaxnGuKVkpjf1HSiTB0qaqi
# 2KNxOA8HSPLUSEGn5uvcuD0zwyrc2HYGgOkUm7kAfjdy9KKn4Ob0wXW1dLDN9bZM
# w2FnIMS/vBi/D+oOMJAka1Fy39y7aakaVLQ0jWKDLphJAGUZiM+ldGam7ajOlhOL
# HiYebbQ1KC+TbmnTDyfmgndyBu7MAbetJirxuMW9x/a6cUAdpP40gGMvlo3OTEM3
# R0wImciO4zUV6S1fBhOkh6DZMA0FVf7cgIX23nr7qbkhWWXowwp9bFyyTMmHq0Nl
# sYlqJoovd2Bfk05PfM9AtoiQ/cPGMIIG5zCCBM+gAwIBAgITMwACmS1y3QvPn1Bn
# GgAAAAKZLTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDQyNDA0NDAzMloXDTI1MDQyNzA0NDAz
# MlowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAOYZEHKO
# w+PGdj5sTyMFsWsn9G2kQDT33wrLH59StH0WBkX0G00khHaoFrCbMKRTY9QIUbSd
# 2uNh8/Qeq/s2WibiqZua7A25RkUIZowE7IUp5whkHrbrCnexy1bp6lD1jOdJMaF5
# VCX5eBHiQmGGuc6ffY1mFn+YcDjYWzb9LzExgTXjfIfD8jwzkEdAavQInZri309s
# gkvpr4YPS5oMN/HGrcbozTMGh80mIWvYloYW9lMIpqq/xdzhXoD+H3dq5d5xCaAg
# Hq94Q1Hp0LWmPguDgxMv/I7iBiLgeY3Wdv43WZAaeGRGtIDXmm99PNw+aAdehfud
# RjhnAB+QuI20qtO/spJGti6qkvIYBVJS8c1N3+4A6XQGj8LeWvLwFBEEKgQigp5j
# Ka5dnmjPrRDtagsKH01+GzF/OMClm6a7sadzCFo6RHJdTntx+7Bt770KhPjl2ovq
# llPtLnF4pGgI9G85FKgMFVIBWP+It0jOcTo0Za3g7fC9psgcU/k/PGPxvwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRqzVnZSTV7T1KjYJHZiKPcOWXnDDAfBgNVHSMEGDAWgBRl
# n1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQA9oxWmWyBE0RVj47iSela9
# KHs1FIxuCTm5ZbZw8ydS4z9F1EFtA7EwWrGkjHzEaZ9wbONCJZ7S4+ywIulGlZ/+
# 3e1/gBYXI+qlCTZkrLDz2QhlrjMgUiPven/C08Gx1dwcQdYiBmIWUDWHiH+GZGvi
# CWVcWjzXPmpN2/Q4yNMrjQzWA31W6nnsG1CkPDrUw69+jHg7+VGW83Co7o+iQFKQ
# QWD6PeZP+dW2n9eMwP35/m2gJASh7epmIBazjmCtdn1cOIMc45TkYFv3kz0X4NVD
# NRyV5cfxhpqahx8cs5QJ6s8J8+/OeK+E46y6DAjZgxQWYG2M48BhUMPK91IrO1NJ
# 6JbGrfE5/+h/xyc3w8/bt0zRRlmH05zt24LGsZxrilZKY39R0okwdKmqotijcTgP
# B0jy1EhBp+br3Lg9M8Mq3Nh2BoDpFJu5AH43cvSip+Dm9MF1tXSwzfW2TMNhZyDE
# v7wYvw/qDjCQJGtRct/cu2mpGlS0NI1igy6YSQBlGYjPpXRmpu2ozpYTix4mHm20
# NSgvk25p0w8n5oJ3cgbuzAG3rSYq8bjFvcf2unFAHaT+NIBjL5aNzkxDN0dMCJnI
# juM1FektXwYTpIeg2TANBVX+3ICF9t56+6m5IVll6MMKfWxcskzJh6tDZbGJaiaK
# L3dgX5NOT3zPQLaIkP3DxjCCB1owggVCoAMCAQICEzMAAAAF+3pcMhNh310AAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGhAwghoMAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwACmS1y3QvPn1BnGgAAAAKZLTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDH8Au1T7tbAP4HBp7CmvauvRJl
# qIPxWjr0fmOI1uvqezANBgkqhkiG9w0BAQEFAASCAYDO8frh/sPRR1qAdrpiyYzQ
# V9NIxGsdb4Tx8fCqLve55+M2pI+5H5OGXCtD25g3HVIwcdmb2XxebZkruax9rNkD
# zZfaXCYfvAxUvNFrKILBz55JUOnEoom0AsNVi3UKk/DmfSRAcABT3mGrPxZXBuxX
# Yp0tluIc3wLgCIfbmgXZI5wiK2PEfR9NzlbHd6iCiCZY/csIsOhTJqss6bpDTYux
# qQpCPEylNaSjh9te477xKa8/L3M3/U0z3x/5CWRx3T2VsBOnT0+r3J/YVoZBldNq
# PWza0VdiYyXHfzOcX2UUCFflflhN48nflVd92lJMr/hXaiswAYVCQPtsCDfpEEeV
# rpErlb5MwOYnlDAMkPq0zoIQxU4zrxljVPIzisaO8NnE99eGPgDKw9VDahv2RWWi
# 1hoQzmVFtYHBbajUFoC6M830U/h9dSaMiQC80ZxE/Wo+7GIjo5xxicNEOSMamI0L
# HlCPgD65sqz6HOv1hDKWssaBBb3p93LKO5P/LdpbljOhgheQMIIXjAYKKwYBBAGC
# NwMDATGCF3wwghd4BgkqhkiG9w0BBwKgghdpMIIXZQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgBhJVbGBfrrRlno0XDaxh3aMXfZIUxt6AGt31Qepu
# ITwCBmf89yehMRgTMjAyNTA0MjUwMjE1NTMuOTM2WjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046NDVENi05NkM1LTVFNjMxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF
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
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQIC
# EzMAAABJcL2GqhZ4TDEAAAAAAEkwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODU0WhcNMjUxMTE5MTg0ODU0WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046NDVENi05NkM1LTVFNjMxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA+pnMBEJ5wYi/nr7N
# 9J+y+uRiVD3AMm7/Q/hyzkTwT7NbQgYHobrt4NzYffDmTKX7EhoDOE0ivbiIlvSC
# p3AggM2AUVGQ3DpZRWYsTQJrPgEIK7JJ0WADhp8HOLAm3RDEfTkTyi2VZg4jJtYS
# MaQpgGPlp32JoQlHfWnYLNTwHoxhLEhuM2nv8tYkS0G30+SF+0jO4E61Zqr/oSHs
# xHE008r+dVyI5o6M9dCPczDaqAv/+aDc6QJ50tj/2Ug5uK8w3+otsQEh4R6n8JBD
# vXigwdJz8jgHdIzS5qTptOEHqzw0WiaSfA0xaF7AyeRYqe3KbD40UokOnXfiMJRb
# IXNz+wxi1tu1sKJIwPWP7PJFV4xnESb9uXsao5CCkWhCNqOZkbX2VKSkvjLVy3CC
# hpxTKZHgTsYERHg5goOr5svVmlI+zxZaPf7SzoLhk1eFiE2I8LUQ7hEs8oKfGtFk
# EwedPAjv7bpS1jKd5b6zjnTPGaNpI50Ulj3m4oqoQ1s0snP/tOOal3mVhsj9YbTK
# oY142uqgkiZhxrYMgIxkCAowm2OQDAWVhzITxjer/KGHzwnL4VX/1BSfJRs8LnI0
# GKDFhrMT3N1EufYiHEwvY+cw9wuvZVuSToLZzXDAWhqBbOClXL3e9z3dUlYolWRC
# LPgGWE9xCf6qrugNB2NZOrADiOMCAwEAAaOCAcswggHHMB0GA1UdDgQWBBRVjnhP
# XjrArN1QumQu7fwTWwJKCzAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBAGF+OSZ1G/RYme6il24h6LDoni1m
# wawibMfur2XjEPdVwGjz91D3c7wavAVE1rnX1EKWyVJ1+QNCsN2EewZ9h3/Fhl1t
# YrjBz+6T4jgOzsgFEXiFhmuIieWMY2+eFMFSw4RcNUdP1fOJz1cNNPk12XL2W69y
# mUXhJLZjD1xVE98Y+Nt2NG0WPzXBHkzQW+rhepIsL1hQmgTWXs1cP/R/K7AT4VB8
# /D7X+u3U2HILtYJad72zlBYfQQZH5tsPsVjlBtRWYcMeAsdJzSNjsxOyWgyA6jqZ
# ivOm7wLuv1xS7yiaIfyTotDGNHJ1VGPwITrbTv0PQiirFLumFLIUEywIXqC1sudZ
# NxXI8z48QmuHH/KMPGkiFyq1E2XUB3PDjgjv5bCHV170f/Lgh+msMFqO/V3YoOfA
# jsRUdgJX7TlE4Dnp9NhPqLTcH8evZldegxHs6YzEflUovsJpBK6wCBuqt9TAqx1r
# H0REYeBmTVIVUh68i6yVmPFYsJazv8WXVDLbmSDuCrQ8kbv4MHdoYJy7dF/qmURf
# 9xkBuajORGaT+uRmDRLboMZHLIufi/pglNDt0Bb16+HvkJ654b+sTZ45SWNLmUb9
# QXKSt5iMMdCfzsM8LDsovzgeRG+Oal7YeLSi6GSOGxPLlcSvtXN2csLGzRPVNMJt
# FeaToNBfSPI9KyaIMYIGxDCCBsACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAElwvYaqFnhMMQAAAAAA
# STANBglghkgBZQMEAgEFAKCCBB0wEQYLKoZIhvcNAQkQAg8xAgUAMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUwNDI1MDIxNTUz
# WjAvBgkqhkiG9w0BCQQxIgQg5DU6MPDVafalbeOKcuEKE6Zy8MROC62oY46CMYQs
# SZQwgbkGCyqGSIb3DQEJEAIvMYGpMIGmMIGjMIGgBCBZKDgGu8T+xwIzm2AmYzwg
# NDM/08rlNoMjGGIJ5AbVIjB8MGWkYzBhMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVibGlj
# IFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAElwvYaqFnhMMQAAAAAASTCC
# At8GCyqGSIb3DQEJEAISMYICzjCCAsqhggLGMIICwjCCAisCAQEwggEIoYHgpIHd
# MIHaMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjo0NUQ2LTk2QzUtNUU2MzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMVACAL
# jk8yViMVfCNap6QGEogntH7UoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBBQUAAgUA67VN
# MjAiGA8yMDI1MDQyNDIzNTIxOFoYDzIwMjUwNDI1MjM1MjE4WjB3MD0GCisGAQQB
# hFkKBAExLzAtMAoCBQDrtU0yAgEAMAoCAQACAhDRAgH/MAcCAQACAhEzMAoCBQDr
# tp6yAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAPkY/TOCS/d7Z3lXYyKtk
# TKuRlGC4sTuAuKV2UR+LzpmhuwCBdMt0rv0gSJ3SAlK8gpr+bL0oGt2BLWbfrLpU
# G37Ty5jG7ET5gANIKLHDe4hEj+mlLXLB05TG1THdOd7sV4o+fLL9joQiaKbcKQqa
# IavOkQv8cDrluAx+Iu0veJEwDQYJKoZIhvcNAQEBBQAEggIAIxNNq7KUTasUxxS4
# 3bHFPKbo3PSflqiHSvIZcXhTIIXO4EXsvzI8qU23AnfYOvKIpCRF9wmoKddJvYJC
# cAZhO0cz/DOokQSBY1rcnU/gXVuLKoxETg6nOOpTcMbthLwjCpADRre48uTXyAnw
# sSnur8OitLaIamtibF8X0oOhXtMlq4Eib612P3mXWlWV81LDYpOwiPtsg2yUye38
# h35jCqR4OnyEy/A03VEcHT2pAJveHsgxMayYhAN6EhLpM9SVkNDYHyHqiY8opGyj
# rhB9HdVYgiGpw1z9yH4lJ7KrBu5fExR2UBBAkjie8vXILEy6AW9E7ijvGIj8vypN
# jemNkesbFliX6YjxIYbLWN4vJx4/7AcnaJEg+Q5oe/FGPRr44UUxBmXfUgstHP1X
# Y+JhYYItOX6oHY4pzvGhvkEak9FRmkMyOQpvoglW9o5+bW0RqBqxjE1/pPGf2uEO
# u8dH0gStciXWyqMHK0HO9zMG4hiTFjKhTczrrItKRXr9MII0kZaaoCZoAcwL18v6
# XANlau57950XuvdPGBCiuZKEpKBGwu1mD8OTuwpF0Yv0qXdW2aFH4gqZeCw40PG0
# lJ80R8sXShhXZ3tNougLnpWM37C4pSWmYFAMTH/74BH/7y+EXXpOA6UKopdDvmDV
# ZPH6N0sjUy1G3uD7OQ7JpdX88hc=
# SIG # End signature block
