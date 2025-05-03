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
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/manifest.json"
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
Write-Verbose "Get device hash: $GetDeviceHash"
Write-Verbose "Reconfigure: $Reconfigure"
Write-Verbose "Repository: $Repo"
Write-Verbose "Release: $Release"
Write-Verbose "Domain: $domain"
Write-Verbose "Application name: $application"
Write-Verbose "Functions folder: $functionsFolder"
Write-Verbose "Base source URL: $baseSourceURL"
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
    if (CreateFullConfiguration -DestinationFolder $pwd -RootFolder $pwd)
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
    if (InitializeConfiguration -RootFolder $pwd -overWrite)
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

if (-not($NoUpdateCheck))
{
    Write-Host "Checking for script updates at $remoteVersionURL"
    Write-Host "Downloading script updates from $updateURL"
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
                    $choices = @('Restart the device', 'Delete from Autopilot')
                    switch ($choice)
                    {
                        'Restart the device'
                        {
                            Write-Host 'Restarting the device...'
                            RestartDevice
                        }
                        'Delete from Autopilot'
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
            if ($deviceAssignment.enrollmentState -ne 'enrolled' -and $deviceAssignment.deploymentProfileAssignmentStatus -notin @('assignedInSync', 'assignedUnkownSyncState'))
            {
                switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                {
                    'unassigned'
                    {
                        Write-Host 'The device is not assigned to a deployment profile.' -ForegroundColor Red
                        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
                        Write-Host "You can also choose to start a check every minute for the next $maxWaitTime minutes." -ForegroundColor Red
                    }
                    'pending'
                    {
                        Write-Host 'The device is pending assignment to a deployment profile.' -ForegroundColor Yellow
                        Write-Host 'Please check again after a little while.' -ForegroundColor Yellow
                        Write-Host "You can also choose to start a check every minute for the next $maxWaitTime minutes." -ForegroundColor Red
                    }
                    default
                    {
                        Write-Host "The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)."
                        Write-Host "You can also choose to start a check every minute for the next $maxWaitTime minutes." -ForegroundColor Red
                    }
                }
                Write-Host "What would you like to do?"
                $choices = @('Restart the device', 'Continue to wait for profile assignment', 'Delete from Autopilot')
                $choice = DisplayNumericMenu -Choices $choices 
                switch ($choice)
                {
                    'Restart the device'
                    {
                        Write-Host 'Restarting the device...'
                        RestartDevice
                    }
                    'Continue to wait for profile assignment'
                    {
                        Write-Host 'Continuing to wait for profile assignment...'
                        $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -waitforAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
                    }
                    'Delete from Autopilot'
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
                exit 0
            }
        }
    }
    else
    {
        Write-Host 'The device is not in Intune.'
        Write-Verbose "Checking if the user wants to enroll the device."
        if (-not $check)
        {
            Write-Host "Would you like to continue to import the device to Intune?" -ForegroundColor Yellow
            $choices = @('Import the device')
            $choice = DisplayNumericMenu -Choices $choices
            Write-Verbose "Got choice $choice"
            if ($choice -eq $choices[0])
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

if ($check)
{
    if ($deviceAssignment)
    {
        if ($deviceAssignment.deploymentProfileAssignmentStatus -notin @('assignedInSync', 'assignedUnkownSyncState'))
        {
            $choices = @('Restart the device', 'Continue to wait for profile assignment', 'Delete from Autopilot')
        }
        else
        {
            $choices = @('Restart the device', 'Delete from Autopilot')
        }
        $choice = DisplayNumericMenu -Choices $choices 
        switch ($choice)
        {
            'Restart the device'
            {
                Write-Host 'Restarting the device...'
                RestartDevice
            }
            'Continue to wait for profile assignment'
            {
                Write-Host 'Continuing to wait for profile assignment...'
                $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -waitforAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
            }
            'Delete from Autopilot'
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
    }
    exit 0
}
#endregion Check if the device is already in Intune

#region Add the device to Intune
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
