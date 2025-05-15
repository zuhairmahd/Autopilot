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

$scriptName = $MyInvocation.MyCommand.Name
#region Load parameters from the configuration file if it exists
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
$application = 'Register'
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
$localVersion = (Get-Content -Path version.txt -Raw -Force -ErrorAction SilentlyContinue).trim()
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/version.txt"
$backoutText = 'Returning to previous menu'
# $scopes = "offline_access Device.ReadWrite.All DeviceManagementApps.Read.All DeviceManagementConfiguration.ReadWrite.All DeviceManagementManagedDevices.PrivilegedOperations.All DeviceManagementManagedDevices.ReadWrite.All DeviceManagementServiceConfig.ReadWrite.All"
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

#region Helper Functions (Consolidated and Corrected)
function validateInput()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput
    )

    #Get the function name
    $functionName = $MyInvocation.MyCommand.Name
    $MaxSerialNumberLength = '11'
    $MinSerialNumberLength = '7'
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    $returnValue = @{}
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
    if ($UserInput.Length -gt $MaxSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
        Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
    }
    elseif ($UserInput.Length -lt $MinSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
        Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
    }
    elseif ($UserInput -match '^[a-zA-Z0-9]+$') 
    {
        Write-Verbose "[$functionName] Serial number validation passed"
        $returnValue.valid = $true
        $returnValue.value = $UserInput
    }
    else
    {
        Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    return $returnValue
}

function GetUserInput()
{
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt
    )
    #Get the function name
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 
    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $BackoutText."
            return $null # Return null to signal going back
        }
        # Validate the input if it's not empty
        $validationResult = validateInput -UserInput $inputItem
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value
        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Verbose "[$functionName] Input result: $inputResult"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red 
            # The loop will continue, prompting the user again
        }
    }
}

function ProcessDevice()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $DeviceObject,
        $returnValues = $returnValues,
        [Parameter(Mandatory = $true)]
        [ValidateSet('import', 'check', 'delete')]
        [string]$action
    )
    
    #region check and initialize variables
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking access token..."
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    else
    {
        Write-Verbose "[$functionName] Access token not provided. Returning Null."
        return $null
    }
    Write-Verbose "[$functionName] Processing serial number: $($deviceObject.SerialNumber)."
    Write-Verbose "[$functionName] Action: $action"
    $serialNumber = $deviceObject.serialNumber
    Write-Verbose "[$functionName] The serial number is $serialNumber."
    $make = $deviceObject.manufacturer
    Write-Verbose "[$functionName] The manufacturer is $make"
    $model = $deviceObject.model
    Write-Verbose "[$functionName] The model is $model"
    #endregion check and initialize variables

    switch ($action)
    {
        'import'
        {
            Write-Host "Checking to make sure the device hash is not already in Intune..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            Write-Verbose "[$functionName] The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)"
            if ($deviceAssignment)
            {
                if ($deviceAssignment.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
                {
                    Write-Host 'The device is already in Intune and is assigned to a profile.' -ForegroundColor Green
                    Write-Verbose "[$functionName] The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)."
                    $profileAssignmentDate = ($deviceAssignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
                    Write-Host "The device was assigned to the deployment profile $($deviceAssignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
                    Write-Host "The device enrollment state is $($deviceAssignment.enrollmentState)." -ForegroundColor Green
                }
                elseif ($deviceAssignment.deploymentProfileAssignmentStatus -eq 'unassigned')
                {
                    Write-Host 'The device is not assigned to a deployment profile.' -ForegroundColor Red
                    Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
                    return $returnValues.UnassignedMessage
                }
                else 
                {
                    Write-Host "The device is Intune but there is an issue with its profile assignment."
                    Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
                    return $returnValues.UnassignedMessage
                }
            }
            #region Add the device to Intune
            $importStart = Get-Date
            $device = ImportAutopilotDevice -DeviceObject $deviceObject -AccessToken $accessToken -GroupTag $GroupTag -AssignedUser $AssignedUser -TimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
            if ($device.state.deviceImportStatus -eq 'complete')
            {
                $serialNumber = $device.SerialNumber
                Write-Host "The import of device with serial number $serialNumber completed successfully." -ForegroundColor Green
                Write-Host 'Checking device assignment.'
                $assignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -WaitForAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
                Write-Verbose "[$functionName] The assignment details are: $($assignment | ConvertTo-Json)"
                if ($assignment)
                {
                    Write-Verbose "[$functionName] The assignment status is $($assignment.deploymentProfileAssignmentStatus)"    
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
                        if (-not (RestartDevice))
                        {
                            return $importValues.ImportSuccessMessage
                        }
                    }
                    else
                    {
                        Write-Host 'The device could not be assigned to a deployment profile.' -ForegroundColor Red
                        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
                        Write-Host "The device current assignment status is $($assignment.deploymentProfileAssignmentStatus)."
                        Write-Host "The device assignment profile name is $($assignment.deploymentProfile.displayName)."
                        Write-Host "The device profile assignment date is $($assignment.deploymentProfileAssignmentDateTime)."
                        return $importValues.ImportFailedMessage
                    }
                }
                else
                {
                    Write-Host 'The device cannot be found in Intune.'
                    Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
                    return $returnValues.notInIntuneMessage
                }
            }
            elseif ($device.state.deviceImportStatus -eq 'error')
            {
                Write-Host 'The device import failed with the following error:' -ForegroundColor Red
                Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
                return $returnValues.ImportFailedMessage
            }
            else
            {
                Write-Host 'The device import failed with the following error:' -ForegroundColor Red
                Write-Host "$($device.state.deviceImportStatus)" -ForegroundColor Red
                return $returnValues.ImportFailedMessage
            }
            #endregion Add the device to Intune.
        }
        'check'
        {
            Write-Host "Checking device with serial number $SerialNumber..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            Write-Verbose "[$functionName] The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)"
            if ($deviceAssignment)
            {
                if ($deviceAssignment.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
                {
                    Write-Host 'The device is already in Intune and is assigned to a profile.' -ForegroundColor Green
                    Write-Verbose "[$functionName] The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)."
                    $profileAssignmentDate = ($deviceAssignment.deploymentProfileAssignedDateTime | FormatDateWithTimeZone) 
                    Write-Host "The device was assigned to the deployment profile $($deviceAssignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
                    Write-Host "The device enrollment state is $($deviceAssignment.enrollmentState)." -ForegroundColor Green
                    switch ($deviceAssignment.enrollmentState)
                    {
                        'notContacted'
                        {
                            Write-Host 'The device has not contacted the enrollment service.' -ForegroundColor Green
                            Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
                            Write-Verbose "[$functionName] Returning the message $($returnValues.notContactedMessage)"
                            return $returnValues.notContactedMessage
                        }
                        'enrolled'
                        {
                            Write-Host 'The device appears to have been enrolled.' -ForegroundColor Red
                            Write-Host "Looking up user information..."
                            $deviceManagementUri = "deviceManagement/managedDevices"
                            $managedDeviceFilter = "serialNumber eq '$serialNumber'"
                            # $extraparameters = "select=userPrincipalName,userDisplayName,lastLogOnDateTime&orderby=userDisplayName"
                            $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -Filter $managedDeviceFilter).value
                            Write-Verbose "[$functionName] Managed device user principal name: $($managedDevice.userPrincipalName)"
                            Write-Verbose "[$functionName] Managed device user display name: $($managedDevice.userDisplayName)"
                            Write-Verbose "[$functionName] Managed device last logon date: $($managedDevice.usersLoggedOn.lastLogOnDateTime)"
                            if ($managedDevice.userPrincipalName -match $domain)
                            {
                                $normalizedUser = NormalizeADUserDisplayName -UserDisplayName $managedDevice.userDisplayName
                                Write-Host "The device is registered to the user $($normalizedUser.Fullname) with the email address $($managedDevice.userPrincipalName)." -ForegroundColor Red
                                $hasUser = $true
                            }
                            else 
                            {
                                Write-Host "Cannot determine logged on user."
                            }
                            if ($null -ne $managedDevice.usersLoggedOn.lastLogOnDateTime)
                            {
                                $LastLogonDate = ($managedDevice.usersLoggedOn.lastLogOnDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
                                if ($hasUser)
                                {
                                    Write-Host "The last logon date for $($normalizedUser.FirstName) was $LastLogonDate." -ForegroundColor Red
                                }
                                else
                                {
                                    Write-Host "The last logon date was $LastLogonDate." -ForegroundColor Red
                                }
                            }
                            else 
                            {
                                Write-Host "The last logon date is not available." -ForegroundColor Red
                            }
                            Write-Host "The device needs to be cleaned before giving to another user.." -ForegroundColor Red
                            return $returnValues.EnrolledMessage
                        }
                        'pendingReset'
                        {
                            Write-Host 'The device is pending a reset.' -ForegroundColor Yellow
                            Write-Host "The device needs to be allowed to finish the reset." -ForegroundColor Yellow
                            Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Yellow
                            Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Yellow
                            return $returnValues.PendingResetMessage
                        }
                        'enrollmentFailed'
                        {
                            Write-Host 'The device enrollment failed.' -ForegroundColor Red
                            Write-Host 'This may cause issues when the user loggs on for the first time.' -ForegroundColor Red
                            Write-Host "This means someone has already unsuccessfully tried to enroll the device." -ForegroundColor Red
                            Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Red
                            Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
                            return $returnValues.EnrollmentFailedMessage
                        }
                        default
                        {
                            Write-Host "The device enrollment state is $($deviceAssignment.enrollmentState)." -ForegroundColor Red
                            Write-Host 'Please check the Intune portal or contact an Intune administrator before you give the device to a user.' -ForegroundColor Red
                            return $null
                        }
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
                            return $returnValues.UnassignedMessage
                        }
                        'pending'
                        {
                            Write-Host 'The device is pending assignment to a deployment profile.' -ForegroundColor Yellow
                            Write-Host 'Please check again after a little while.' -ForegroundColor Yellow
                            return $returnValues.PendingMessage
                        }
                        default
                        {
                            Write-Host "The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)."
                            return $false
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
                                return $null
                            }
                        }
                    }
                    return $true
                }
            }
            else
            {
                Write-Host 'The device is not in Intune.'
            }
        }
        'delete'
        {
            Write-Host "Deleting device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) from Autopilot."
            if (DeleteAutopilotDevice -DeviceIdentifyer $serialNumber -IdentifyerType 'serialNumber')
            {
                Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                Write-Host "It may take a few minutes for the device to be removed from Intune." -ForegroundColor Green
                return $returnValues.DeleteSuccessMessage
            }
            else
            {
                Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                return $returnValues.DeleteFailedMessage
            }
        }
        default
        {
            Write-Verbose "[$functionName] Invalid action: $action"
            return $false
        }
    }
}
#endregion Helper Functions

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune device registration menu.  What would you like to do?"
$serialNumberMenu = newMenu -Title "Check device registration" -Description "How would you like to enter the serial number?."
$deviceMenu = NewMenu -Title "Device Menu" -Description "What would you like to do with the device?"
$settingsMenu = NewMenu -title "Settings menu" -Description "Make changes to the application settings"

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

$deviceMenu = AddMenuItem -menu $deviceMenu -name "Delete device from Autopilot" -action {
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
    $accessToken = GetGraphAccessToken -configFile $configFile -Deligated -Scope $scopes -ForceNewToken
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

$mainMenu = AddMenuItem -menu $mainMenu -Name "Import device into Autopilot." -Action {
    Write-Verbose "[$scriptName] Getting the serial number for this device..."
    Write-Verbose "[$scriptName] Checking whether the script has sufficient permissions to run."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Getting device object."
        $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please run the script as an administrator.' -ForegroundColor Red
        exit 1
    }
    Write-Host "This will import the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) to Intune."
    if ($deviceObject)
    {
        Write-Verbose "[$scriptName] Importing device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
        $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
        while ($choice -notin @('yes', 'no'))
        {
            Write-Host "Invalid choice. Please enter 'yes' or 'no'."
            #beep
            [console]::beep(1000, 500)
            $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
        }
        if ($choice -eq 'no')
        {
            Write-Host "Exiting..."
            return $backoutText
        }
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import'
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
    }
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Check device Autopilot status" -Submenu $serialNumberMenu
$mainMenu = AddMenuItem -menu $mainMenu -name "Get device hash for manual upload to Autopilot" -action {
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
$mainMenu = AddMenuItem -menu $mainMenu -Name "Change application settings" -Submenu $settingsMenu
if ($showAdvancedOptions)
{
    $mainMenu = AddMenuItem -menu $mainMenu -Name "Advanced options" -Submenu $deviceMenu
}
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
