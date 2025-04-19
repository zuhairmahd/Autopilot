#region help
<#PSScriptInfo
.VERSION 2.2.0
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
    [Parameter(Mandatory = $False)] [String] $GroupTag = 'MSB01',
    [Parameter(Mandatory = $False)] [String] $AssignedUser = '',
    [Parameter(Mandatory = $False)] [switch]$NoAdminCheck,
    [Parameter(Mandatory = $False, ParameterSetName = 'intune')] [switch]$NoIntuneCheck,
    [Parameter(Mandatory = $False, ParameterSetName = 'intune')] [switch]$check,
    [Parameter(Mandatory = $False)] [switch]$NoSignatureVerify,
    [Parameter(Mandatory = $False)] [switch]$NoHashVerify,
    [Parameter(Mandatory = $False)] [switch]$GetDeviceHash,
    [Parameter(Mandatory = $False)] [switch]$Reconfigure,
    [Parameter(Mandatory = $False)] [switch]$ReInitialize,
    [Parameter(Mandatory = $False, ParameterSetName = 'NoUpdateCheckSet')] [switch]$NoUpdateCheck,
    [Parameter(Mandatory = $False, ParameterSetName = 'UpdateOnlySet')] [switch]$UpdateOnly,
    [Parameter(ParameterSetName = 'UpdateOnlySet')][ValidateSet('github', 'gitlab')][string]$Repo = 'github',
    [Parameter(ParameterSetName = 'UpdateOnlySet')]
    [Parameter(Mandatory = $False, ParameterSetName = 'github')]
    [Parameter(Mandatory = $False, ParameterSetName = 'gitlab')]
    [ValidateSet('auto', 'main')][string]$Release = 'main'
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
$Name = @('localhost')
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
$localManifest = Get-Content -Path "$PSScriptRoot\manifest.json" -Raw | ConvertFrom-Json
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/manifest.json"
$exclusions = GetExclusions -ExclusionsFile "$PSScriptRoot\exclusions.json"
#endregion Define static and dynamic variables

#region logging
#print a verbose log of all received variables
Write-Verbose "Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Verbose "The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Verbose "Configuration file: $configFile"
Write-Verbose "Initial values file: $initialValues"
Write-Verbose "Computer name: $Name"
Write-Verbose "Group tag: $GroupTag"
Write-Verbose "Assigned user: $AssignedUser"
Write-Verbose "Check: $check"
Write-Verbose "No module check: $NoModuleCheck"
Write-Verbose "No update check: $NoUpdateCheck"
Write-Verbose "Update only: $UpdateOnly"
Write-Verbose "No admin check: $NoAdminCheck"
Write-Verbose "No signature verify: $NoSignatureVerify"
Write-Verbose "No hash verify: $NoHashVerify"
Write-Verbose "Get device hash: $GetDeviceHash"
Write-Verbose "Redeploy: $Redeploy"
Write-Verbose "Reconfigure: $Reconfigure"
Write-Verbose "Serial number: $SerialNumber"
Write-Verbose "Repository: $Repo"
Write-Verbose "Release: $Release"
Write-Verbose "Domain: $domain"
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
    $remoteManifest = CheckForScriptUpdates -RemoteManifestPath $remoteVersionURL -LocalManifestContent $localManifest
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

if (-not($NoAdminCheck -or $UpdateOnly -or $Redeploy -or $Reconfigure))
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
$deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
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
    $global:a = $deviceAssignment
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
                    Write-Host "This may cause issues when the user loggs on for the first timme." -ForegroundColor Red
                    Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
                    exit 1
                }
                'enrollmentPending'
                {
                    Write-Host 'The device is pending enrollment.' -ForegroundColor Yellow
                    Write-Host "This means someone has already started the enrollment process." -ForegroundColor Yellow
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
            if (-not (RestartDevice))
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
