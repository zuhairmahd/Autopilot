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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "MaxSerialNumberLength: $MaxSerialNumberLength" -LogLevel "Information"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "MinSerialNumberLength: $MinSerialNumberLength" -LogLevel "Information"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    $returnValue = @{}
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trimmed input: '$UserInput'" -LogLevel "Information"
    Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking serial number length: $($UserInput.Length)" -LogLevel "Verbose"
    if ($UserInput.Length -gt $MaxSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial number exceeds maximum length of $MaxSerialNumberLength characters" -LogLevel "Information"
        Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
    }
    elseif ($UserInput.Length -lt $MinSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial number is shorter than minimum length of $MinSerialNumberLength characters" -LogLevel "Information"
        Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
    }
    elseif ($UserInput -match '^[a-zA-Z0-9]+$') 
    {
        Write-Verbose "[$functionName] Serial number validation passed"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial number validation passed" -LogLevel "Information"
        $returnValue.valid = $true
        $returnValue.value = $UserInput
    }
    else
    {
        Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning validation result: $($returnValue.valid)" -LogLevel "Information"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning validation value: $($returnValue.value)" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Message: $Message" -LogLevel "Information"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Prompt: $Prompt" -LogLevel "Information"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 
    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Item entered: '$inputItem'" # Added quotes for clarity" -LogLevel "Information"
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $($returnValues.backoutText)."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User pressed Enter. Returning $($returnValues.backoutText)." -LogLevel "Information"
            return $null # Return null to signal going back
        }
        # Validate the input if it's not empty
        $validationResult = validateInput -UserInput $inputItem
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value
        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Valid $inputType entered: $inputResultValid" -LogLevel "Information"
            Write-Verbose "[$functionName] Input result: $inputResult"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Input result: $inputResult" -LogLevel "Information"
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

function PrepareImportDevice()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $accessToken,
        [switch]$CustomImport
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Preparing to import device with serial number: $($deviceObject.serialNumber)."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing to import device with serial number: $($deviceObject.serialNumber)." -LogLevel "Information"
    Write-Verbose "[$functionName] Getting the serial number for this device..."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting the serial number for this device..." -LogLevel "Information"
    Write-Verbose "[$functionName] Checking whether the script has sufficient permissions to run."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking whether the script has sufficient permissions to run." -LogLevel "Verbose"
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$functionName] The script is running with sufficient permissions."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The script is running with sufficient permissions." -LogLevel "Information"
        Write-Verbose "[$functionName] Getting device object."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting device object." -LogLevel "Information"
        $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please run the script as an administrator.' -ForegroundColor Red
        return $null
    }
    if ($deviceObject)
    {
        if ($customImport) 
        {
            Write-Verbose "[$functionName] Custom import is enabled."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Custom import is enabled." -LogLevel "Information"
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import' -CustomImport
            if ($result -eq $returnValues.backoutText)
            {
                Write-Verbose "[$functionName] Custom import aborted. Returning $($returnValues.backoutText)."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Custom import aborted. Returning $($returnValues.backoutText)." -LogLevel "Information"
                return $returnValues.backoutText
            }
        }
        else 
        {
            Write-Verbose "[$functionName] The device with serial number $($deviceObject.serialNumber) is ready for import."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device with serial number $($deviceObject.serialNumber) is ready for import." -LogLevel "Information"
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import'
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
    }
}

function DisplayDeviceAssignmentStatus()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $deviceAssignment
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)" -LogLevel "Information"
    if ($deviceAssignment.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
    {
        Write-Host 'The device is already in Intune and is assigned to a profile.' -ForegroundColor Green
        Write-Verbose "[$functionName] The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)." -LogLevel "Information"
        $profileAssignmentDate = ($deviceAssignment.deploymentProfileAssignedDateTime | FormatDateWithTimeZone) 
        Write-Host "The device was assigned to the deployment profile $($deviceAssignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
        Write-Host "The device enrollment state is $($deviceAssignment.enrollmentState)." -ForegroundColor Green
        return $true
    }
    elseif ($deviceAssignment.deploymentProfileAssignmentStatus -eq 'unassigned')
    {
        Write-Host 'The device is not assigned to a deployment profile.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        return $false
    }
    elseif ($deviceAssignment.deploymentProfileAssignmentStatus -eq 'pending')
    {
        Write-Host 'The device is pending assignment to a deployment profile.' -ForegroundColor Yellow
        Write-Host 'Please check again after a little while.' -ForegroundColor Yellow
        return $false
    }
    else 
    {
        Write-Host "The device is in Intune but there is an issue with its profile assignment: $($deviceAssignment.deploymentProfileAssignmentStatus)" -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        return $false
    }
}

function HandleDeviceEnrollmentState()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $deviceAssignment,
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $returnValues,
        [Parameter(Mandatory = $false)]
        [string]$domain
    )

    $functionName = $MyInvocation.MyCommand.Name
    $enrollmentState = $deviceAssignment.enrollmentState
    Write-Verbose "[$functionName] Processing enrollment state: $enrollmentState"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing enrollment state: $enrollmentState" -LogLevel "Verbose"
    
    switch ($enrollmentState)
    {
        'notContacted'
        {
            Write-Host 'The device has not contacted the enrollment service.' -ForegroundColor Green
            Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
            Write-Verbose "[$functionName] Returning the message $($returnValues.notContactedMessage)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning the message $($returnValues.notContactedMessage)" -LogLevel "Information"
            return $returnValues.notContactedMessage
        }
        'enrolled'
        {
            Write-Host 'The device appears to have been enrolled.' -ForegroundColor Red
            Write-Host "Looking up user information..."
            $deviceManagementUri = "deviceManagement/managedDevices"
            $managedDeviceFilter = "serialNumber eq '$serialNumber'"
            $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -Filter $managedDeviceFilter).value
            Write-Verbose "[$functionName] Managed device user principal name: $($managedDevice.userPrincipalName)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device user principal name: $($managedDevice.userPrincipalName)" -LogLevel "Information"
            Write-Verbose "[$functionName] Managed device user display name: $($managedDevice.userDisplayName)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device user display name: $($managedDevice.userDisplayName)" -LogLevel "Information"
            Write-Verbose "[$functionName] Managed device last logon date: $($managedDevice.usersLoggedOn.lastLogOnDateTime)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device last logon date: $($managedDevice.usersLoggedOn.lastLogOnDateTime)" -LogLevel "Information"

            $hasUser = $false
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
            
            Write-Host "The device needs to be cleaned before giving to another user." -ForegroundColor Red
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
            Write-Host 'This may cause issues when the user logs on for the first time.' -ForegroundColor Red
            Write-Host "This means someone has already unsuccessfully tried to enroll the device." -ForegroundColor Red
            Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Red
            Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
            return $returnValues.EnrollmentFailedMessage
        }
        default
        {
            Write-Host "The device enrollment state is $enrollmentState." -ForegroundColor Red
            Write-Host 'Please check the Intune portal or contact an Intune administrator before you give the device to a user.' -ForegroundColor Red
            return $null
        }
    }
}

function HandleCustomImportSettings()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        [ref]$maxWaitTimeRef,
        [Parameter(Mandatory = $true)]
        [ref]$timeInSecondsRef,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    Write-Verbose "[$functionName] Handling custom import settings"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Handling custom import settings" -LogLevel "Information"
    $maxWaitTime = $maxWaitTimeRef.Value
    $timeInSeconds = $timeInSecondsRef.Value
    
    Write-Host "Enter how many times you would like to check for a profile assignment."
    Write-Host "Press enter to keep the default value of $maxWaitTime."
    Write-Host "Press 0 to skip the wait."
    $customMaxWaitTime = Read-Host 'Enter the number of retries or press enter to skip'
    
    if ($customMaxWaitTime -eq '0')
    {
        Write-Host "Skipping the wait for profile assignment."
        return $returnValues.deviceImportSuccessMessage
    }
    elseif ($customMaxWaitTime -as [int] -and [int]$customMaxWaitTime -ge 0 -and [int]$customMaxWaitTime -le 60)
    {
        $maxWaitTimeRef.Value = [int]$customMaxWaitTime
        Write-Host "Will check $($maxWaitTimeRef.Value) times for proper profile assignment."
    }
    else
    {
        do
        {
            Write-Host "Invalid input. Please enter a number between 0 and 60." -ForegroundColor Yellow
            $customMaxWaitTime = Read-Host 'Enter the number of retries or press enter to skip'
        } while (($customMaxWaitTime -as [int]) -and ([int]$customMaxWaitTime -lt 0 -or [int]$customMaxWaitTime -gt 60))
    }
    
    Write-Host "Enter how many seconds to wait between each check."
    Write-Host "Press enter to keep the default value of $timeInSeconds."
    Write-Host "Press 0 to skip the wait."
    $customTimeInSeconds = Read-Host 'Enter the number of seconds or press enter to skip'
    
    if ($customTimeInSeconds -eq '0')
    {
        Write-Host "Skipping the wait for profile assignment."
        return $returnValues.deviceImportSuccessMessage
    }
    elseif ($customTimeInSeconds -as [int] -and [int]$customTimeInSeconds -ge 0 -and [int]$customTimeInSeconds -le 60)
    {
        $timeInSecondsRef.Value = [int]$customTimeInSeconds
        Write-Host "Will check every $($timeInSecondsRef.Value) seconds for proper profile assignment."
    }
    else
    {
        do
        {
            Write-Host "Invalid input. Please enter a number between 0 and 60." -ForegroundColor Yellow
            $customTimeInSeconds = Read-Host 'Enter the number of seconds or press enter to skip'
        } while (($customTimeInSeconds -as [int]) -and ([int]$customTimeInSeconds -lt 0 -or [int]$customTimeInSeconds -gt 60))
    }
    
    Write-Host "The device will be checked $($maxWaitTimeRef.Value) times with a wait of $($timeInSecondsRef.Value) seconds between each check."
    return $null
}

function ProcessImportResult()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $device,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    Write-Verbose "[$functionName] Processing import result with status: $($device.state.deviceImportStatus)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing import result with status: $($device.state.deviceImportStatus)" -LogLevel "Verbose"
    if ($device.state.deviceImportStatus -eq 'complete')
    {
        $serialNumber = $device.SerialNumber
        Write-Host "The import of device with serial number $serialNumber completed successfully." -ForegroundColor Green
        return $returnValues.deviceImportSuccessMessage
    }
    elseif ($device.state.deviceImportStatus -eq 'error')
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
        return $returnValues.deviceImportFailedMessage
    }
    else
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceImportStatus)" -ForegroundColor Red
        return $returnValues.deviceImportFailedMessage
    }
}

function ProcessAssignmentResult()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $assignment,
        [Parameter(Mandatory = $true)]
        [datetime]$importStart,
        [Parameter(Mandatory = $true)]
        $returnValues
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing assignment result"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing assignment result" -LogLevel "Verbose"
    Write-Verbose "[$functionName] The assignment details are: $($assignment | ConvertTo-Json)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The assignment details are: $($assignment | ConvertTo-Json)" -LogLevel "Information"
    
    if (-not $assignment)
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
        return $returnValues.notInIntuneMessage
    }
    
    Write-Verbose "[$functionName] The assignment status is $($assignment.deploymentProfileAssignmentStatus)"    
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The assignment status is $($assignment.deploymentProfileAssignmentStatus)"    " -LogLevel "Information"
    if (($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or 
            $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync') -and 
        $null -ne $assignment.deploymentProfile.displayName)
    {
        $profileAssignmentDate = if ($assignment.deploymentProfileAssignedDateTime)
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
            return $returnValues.deviceImportSuccessMessage
        }
    }
    else
    {
        Write-Host 'The device could not be assigned to a deployment profile.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        Write-Host "The device current assignment status is $($assignment.deploymentProfileAssignmentStatus)."
        Write-Host "The device assignment profile name is $($assignment.deploymentProfile.displayName)."
        Write-Host "The device profile assignment date is $($assignment.deploymentProfileAssignmentDateTime)."
        return $returnValues.deviceImportFailedMessage
    }
}

function ImportAutopilotDevice() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [object]$DeviceObject,
        [Parameter(Mandatory = $false)]
        [string]$GroupTag = '',
        [Parameter(Mandatory = $false)]
        [string]$AssignedUser = '',
        [Parameter(Mandatory = $false)]
        [int]$maxWaitTime = 30,
        [Parameter(Mandatory = $false)]
        [int]$timeInSeconds = 60,
        [bool]$CustomImport = $false
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region print verbose log of the parameters and define variables
    if ($accessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken provided." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken not provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken not provided." -LogLevel "Information"
        return $false
    }
    Write-Verbose "[$functionName] DeviceObject: $DeviceObject"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "DeviceObject: $DeviceObject" -LogLevel "Information"
    Write-Verbose "[$functionName] GroupTag: $GroupTag"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "GroupTag: $GroupTag" -LogLevel "Information"
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "AssignedUser: $AssignedUser" -LogLevel "Information"
    Write-Verbose "[$functionName] MaxWaitTime: $maxWaitTime"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "MaxWaitTime: $maxWaitTime" -LogLevel "Information"
    Write-Verbose "[$functionName] TimeInSeconds: $timeInSeconds"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "TimeInSeconds: $timeInSeconds" -LogLevel "Information"
    Write-Verbose "[$functionName] CustomImport: $CustomImport"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "CustomImport: $CustomImport" -LogLevel "Information"
    $uri = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $serialNumber = $DeviceObject.serialNumber
    Write-Verbose "[$functionName] Serial Number: $serialNumber"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial Number: $serialNumber" -LogLevel "Information"
    $make = $DeviceObject.manufacturer
    Write-Verbose "[$functionName] Make: $make"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Make: $make" -LogLevel "Information"
    $model = $DeviceObject.model
    Write-Verbose "[$functionName] Model: $model"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Model: $model" -LogLevel "Information"
    $hash = $DeviceObject.hardwareHash
    #endregion  
    #region prepare import object.
    if ($CustomImport -eq $true)
    {
        do
        {
            Write-Verbose "[$functionName] CustomImport is set to true."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "CustomImport is set to true." -LogLevel "Information"
            Write-Host "Enter the desired Group Tag for the device:"
            Write-Host "Press enter to keep the default value of $GroupTag."
            Write-Host "Enter 'None' to enter a blank Group Tag"
            $customGroupTag = Read-Host "Enter Group Tag"
            if ($customGroupTag -eq 'None')
            {
                $groupTag = ''
            }
            elseif ($customGroupTag -ne '')
            {
                $groupTag = $customGroupTag
            }
            Write-Host "Enter the desired Assigned User for the device:"
            Write-Host "Press enter to keep the default value of $AssignedUser."
            Write-Host "Enter 'None' to enter a blank Assigned User"
            $customAssignedUser = Read-Host "Enter Assigned User"
            if ($customAssignedUser -eq 'None')
            {
                $AssignedUser = ''
            }
            elseif ($customAssignedUser -ne '')
            {
                $AssignedUser = $customAssignedUser
            }
            Write-Host "How many times do you want to check for import completion and assignment?"
            $customMaxWaitTime = Read-Host "Press enter to keep the default value of $maxWaitTime."
            if ($customMaxWaitTime -ne '')
            {
                while ($maxWaitTime -notmatch '^\d+$')
                {
                    Write-Host "Please enter a valid number."
                    [console]::beep(1000, 500)
                    $customMaxWaitTime = Read-Host "Enter Max Wait Time in minutes"
                    if ($customMaxWaitTime -ne '')
                    {
                        $maxWaitTime = $customMaxWaitTime
                    }
                }
            }
            Write-Host "How long do you want to wait between checks?"
            $customTimeInSeconds = Read-Host "Press enter to keep the default value of $timeInSeconds seconds."
            if ($customTimeInSeconds -ne '')
            {
                while ($timeInSeconds -notmatch '^\d+$')
                {
                    Write-Host "Please enter a valid number."
                    [console]::beep(1000, 500)
                    $customTimeInSeconds = Read-Host "Enter Time In Seconds"
                    if ($customTimeInSeconds -ne '')
                    {
                        $timeInSeconds = $customTimeInSeconds
                    }
                }
            }
            Write-Host "The device will be imported with the following parameters:"
            Write-Host "Group Tag: $groupTag"
            Write-Host "Assigned User: $AssignedUser"
            Write-Host "Max Wait Time: $maxWaitTime minutes"
            Write-Host "Time In Seconds: $timeInSeconds seconds"
            Write-Host "Is this correct?"
            Write-Host "Enter C to continue, R to reenter or press enter to return to the previous menu."
            $ImportChoice = Read-Host "Enter C, R or press enter"
            if ($ImportChoice -eq 'C')
            {
                $ProceedWithImport = $true
                Write-Host "Continuing with the import."
            }
            elseif ($ImportChoice -eq 'R')
            {
                $ProceedWithImport = $false
                Write-Host "Reentering the parameters."
            }
            else
            {
                $ProceedWithImport = $false
                Write-Host "Exiting..."
                return $returnValues.backoutText
            }
        } while ($ProceedWithImport -eq $false)
    }
    else
    {
        Write-Verbose "[$functionName] CustomImport is set to false."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "CustomImport is set to false." -LogLevel "Information"
    }
    $json = @"
{
  "@odata.type": "#microsoft.graph.importedWindowsAutopilotDeviceIdentity",
  "groupTag": "$groupTag",
  "serialNumber": "$serialNumber",
  "productKey": "",
  "importId": "",
  "hardwareIdentifier": "$hash",
  "state": {
    "@odata.type": "microsoft.graph.importedWindowsAutopilotDeviceIdentityState",
    "deviceImportStatus": "pending",
    "deviceRegistrationId": "",
    "deviceErrorCode": 15,
    "deviceErrorName": ""
  },
  "assignedUserPrincipalName": "$AssignedUser",
}    
"@
  
    $imported = callGraphApi -AccessToken $AccessToken -ResourcePath $uri -Method POST -Body $json
    if ($null -eq $imported)
    {
        Write-Host "The device import failed."
        Write-Host "Please check the Intune portal or contact an Intune administrator."
        return $null
    }
    Write-Host "The device import was successfully started."
    Write-Host "The imported device ID is $($imported.id)."
    #wait for the device to be imported
    Write-Host "Waiting for the import for device with device ID $($imported.id) to be completed."
    $device = callGraphApi -AccessToken $AccessToken -ResourcePath "$uri/$($imported.id)" -Method GET
    $index = 0
    while ($index -lt $maxWaitTime)
    {
        Write-Verbose "[$functionName] The device import status is $($device.state.deviceImportStatus)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device import status is $($device.state.deviceImportStatus)" -LogLevel "Information"
        if (($device.state.deviceImportStatus -ne 'unknown') -or ($index -gt $maxWaitTime))
        {
            break
        }
        Write-Host "The import status is $($device.state.deviceImportStatus)."
        Write-Host "Will check again in $timeInSeconds seconds."
        $index++
        Write-Host "Pass $index of $maxWaitTime"
        Start-Sleep -Seconds $timeInSeconds
        $device = callGraphApi -AccessToken $AccessToken -ResourcePath "$uri/$($imported.id)" -Method GET
    }
    Write-Host "The device import status is $($device.state.deviceImportStatus)"
    Write-Verbose "[$functionName] The index count is $index."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The index count is $index." -LogLevel "Information"
    if (($device.state.deviceImportStatus -eq 'unknown') -and ($index -gt $maxWaitTime))
    {
        Write-Host "The import is taking too long (over $maxWaitTime minutes)." 
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        return $null
    }
    else
    {
        Write-Verbose "[$functionName] The device import state is $($device.state.deviceImportStatus)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device import state is $($device.state.deviceImportStatus)" -LogLevel "Information"
        return $device
    }
}

function CheckDeviceAssignment()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [switch]$WaitForAssignment,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$waitTimeInSeconds = $waitTimeInSeconds,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$maxWaitTime = $maxWaitTime
    )
    
    #region variables and logs
    #get the function name.
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Received parameters: serialNumber=$serialNumber."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received parameters: serialNumber=$serialNumber." -LogLevel "Information"
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token provided." -LogLevel "Information"
    }
    Write-Verbose "[$functionName] WaitForAssignment switch: $WaitForAssignment."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "WaitForAssignment switch: $WaitForAssignment." -LogLevel "Information"
    if ($WaitForAssignment)
    {
        Write-Verbose "[$functionName] Wait time in seconds: $waitTimeInSeconds."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Wait time in seconds: $waitTimeInSeconds." -LogLevel "Information"
        Write-Verbose "[$functionName] Max wait time: $maxWaitTime."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Max wait time: $maxWaitTime." -LogLevel "Information"
    }
    $autoPilotDeviceURI = 'deviceManagement/windowsAutopilotDeviceIdentities'
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    $assignment = $null
    #endregion
    
    Write-Verbose "[$functionName] Checking whether the device with serial number $serialNumber is already in Intune."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking whether the device with serial number $serialNumber is already in Intune." -LogLevel "Verbose"
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "[$functionName] VMware device detected."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "VMware device detected." -LogLevel "Verbose"
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "[$functionName] Received $($autoPilotVMDevice.count) devices from Autopilot."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received $($autoPilotVMDevice.count) devices from Autopilot." -LogLevel "Information"
        if ($autoPilotVMDevice -ne '' -and $null -ne $autoPilotVMDevice)
        {
            Write-Verbose "[$functionName] Got an Autopilot Device with device id $($autoPilotVMDevice)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Got an Autopilot Device with device id $($autoPilotVMDevice)" -LogLevel "Information"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUriWithId
        }
        else
        {
            Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No match for device with serial number $serialNumber found in Autopilot." -LogLevel "Information"
            return $returnValues.notInIntuneMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] Not a VMWare device. Continuing"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Not a VMWare device. Continuing" -LogLevel "Information"
        $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUri -filter $autopilotDeviceFilter).value
    }
    Write-Verbose "[$functionName] Found $($assignment.count) Autopilot devices."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($assignment.count) Autopilot devices." -LogLevel "Information"
    if ($null -ne $assignment -and $assignment -ne '')
    {
        Write-Verbose "[$functionName] Found the device matching serial number $serialNumber."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found the device matching serial number $serialNumber." -LogLevel "Information"
        Write-Verbose "[$functionName] The device is registered in Autopilot."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is registered in Autopilot." -LogLevel "Information"
        Write-Verbose "[$functionName] Checking profile assignment"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking profile assignment" -LogLevel "Verbose"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($assignment.id)"
        $extraProfileParameters = "expand=deploymentProfile"
        $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -extraparameters $extraProfileParameters
        Write-Host "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
        if ($WaitForAssignment -and ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync')))
        {
            Write-Host "Checking up to $maxWaitTime times for the device to be assigned to a deployment profile."
            $index = 0
            while ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -lt $maxWaitTime)
            {
                Write-Host "Waiting for $waitTimeInSeconds  more seconds before checking again..." -ForegroundColor Yellow
                Start-Sleep -Seconds $waitTimeInSeconds
                $index++
                Write-Host "Checking again..."
                Write-Host "Pass $index of $maxWaitTime"
                $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -extraparameters $extraProfileParameters
                Write-Host "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
            }
            Write-Verbose "[$functionName] Gop final device assignment status: $($assignment.deploymentProfileAssignmentStatus)."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Gop final device assignment status: $($assignment.deploymentProfileAssignmentStatus)." -LogLevel "Information"
            if ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -gt $maxWaitTime)
            {
                Write-Host "Finished checking $maxWaitTime times."
                Write-Host "The device assignment is taking too long."
                Write-Host 'Please check the Intune portal or contact an Intune administrator.'
            }
            elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Congratulations!!! " 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Congratulations!!! " " -LogLevel "Information"
                Write-Verbose "[$functionName] The device is successfully assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime)."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is successfully assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime)." -LogLevel "Information"
            }
        }
        else
        {
            if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Device details: $($assignment | ConvertTo-Json -Depth 10)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device details: $($assignment | ConvertTo-Json -Depth 10)" -LogLevel "Information"
                Write-Verbose "[$functionName] The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)." -LogLevel "Information"
                Write-Verbose "[$functionName] The device is ready for enrollment."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is ready for enrollment." -LogLevel "Information"
                Write-Verbose "[$functionName] Returning $($returnValues.deviceAssignedMessage)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning $($returnValues.deviceAssignedMessage)" -LogLevel "Information"
            }
            else
            {
                Write-Host "The device is not assigned to a deployment profile."
                Write-Host "Please check the Intune portal or contact an Intune administrator."
                Write-Verbose "[$functionName] The device is not ready for enrollment."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is not ready for enrollment." -LogLevel "Information"
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device is not found in Intune."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is not found in Intune." -LogLevel "Information"
        return $returnValues.deviceNotInIntuneMessage
    }
    return $assignment
}

function GetDeviceHash()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $true)]
        $device
    )
    $success = $false

    Write-Verbose 'Creating DeviceHash with the following parameters:'
    Write-Verbose "OutputFile=$outputFile"
    Write-Verbose "SerialNumber=$($device.SerialNumber)"
    $csvObject = [PSCustomObject]@{
        'Device Serial Number' = $device.serialNumber
        'Windows Product ID'   = $device.product
        'Hardware Hash'        = $device.hardwareHash
        'Group Tag'            = $device.GroupTag
        'Assigned User'        = $device.AssignedUser
    }
    $csvObject | Select-Object 'Device Serial Number', 'Windows Product ID', 'Hardware Hash', 'Group Tag' | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | Out-File $OutputFile
    if ($outputFile)
    {
        Write-Host "Device hash saved to $outputFile" -ForegroundColor Green
        Write-Host 'In case of problems, you can manually upload the file to Intune or contact an Intune admin.'
        $success = $true
    }
    else
    {
        Write-Host 'Failed to save the device hash' -ForegroundColor Red
    }
    return $success 
}

function GetDeviceInfo()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string]$GroupTag,
        [Parameter(Mandatory = $false)]
        [string]$AssignedUser = '',
        [string]$Name,
        [switch]$NoHash
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #Print verbose logs of the received parameters.
    Write-Verbose "[$functionName] GroupTag: $GroupTag"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "GroupTag: $GroupTag" -LogLevel "Information"
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "AssignedUser: $AssignedUser" -LogLevel "Information"
    Write-Verbose "[$functionName] NoHash: $NoHash"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "NoHash: $NoHash" -LogLevel "Information"

    $device = @{}
    $session = New-CimSession
    $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
    #Add the serial number to the hash table.
    $device.Add('SerialNumber', $serial)
    Write-Verbose "[$functionName] The serial number is $serial."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The serial number is $serial." -LogLevel "Information"
    $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
    $make = $cs.Manufacturer.Trim()
    $device.Add('Manufacturer', $make)
    Write-Verbose "[$functionName] The manufacturer is $make."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The manufacturer is $make." -LogLevel "Information"
    $model = $cs.Model.Trim()
    $device.Add('Model', $model)
    Write-Verbose "[$functionName] The model is $model."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The model is $model." -LogLevel "Information"
    $product = ''
    $device.add('Product', $product)
    Write-Verbose "[$functionName] The group tag is $GroupTag"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The group tag is $GroupTag" -LogLevel "Information"
    $device.add('GroupTag', $GroupTag)
    Write-Verbose "[$functionName] The assigned user is $AssignedUser"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The assigned user is $AssignedUser" -LogLevel "Information"
    $device.add('AssignedUser', $AssignedUser)
    if (-not $NoHash)
    {
        Write-Verbose "[$functionName] Checking for hardware hash."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking for hardware hash." -LogLevel "Verbose"
        $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
        Write-Verbose "[$functionName] The device details are: $($devDetail | ConvertTo-Json -Depth 5)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device details are: $($devDetail | ConvertTo-Json -Depth 5)" -LogLevel "Information"
        if ($devDetail)
        {
            $hash = $devDetail.DeviceHardwareData
            $device.Add('HardwareHash', $hash)
            Write-Verbose "[$functionName] The hardware hash is $hash."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "The hardware hash is $hash." -LogLevel "Information"
        }
        else
        {
            Write-Error 'No hardware hash was found.'
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] No hardware hash was requested."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No hardware hash was requested." -LogLevel "Information"
    }
    Remove-CimSession $session
    return $device
}

function DeleteAutopilotDevice()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$DeviceIdentifyer,
        [ValidateSet('SerialNumber', 'DeviceId')]
        [string]$IdentifyerType = 'SerialNumber',
        [string]$accessToken = $accessToken,
        [int]$MaxRetries = 10,
        [int]$RetryDelaySeconds = 20
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region variables and logs.
    Write-Verbose "[$functionName] Received parameters:" 
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received parameters:" " -LogLevel "Information"
    if ($accessToken)
    {
        Write-Verbose "[$functionName]     AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken provided." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName]     No AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No AccessToken provided." -LogLevel "Information"
        return $null
    }
    Write-Verbose "[$functionName] Device identifier: $DeviceIdentifyer."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device identifier: $DeviceIdentifyer." -LogLevel "Information"
    Write-Verbose "[$functionName] Identifyer type: $IdentifyerType."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Identifyer type: $IdentifyerType." -LogLevel "Information"
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    #endregion

    switch ($IdentifyerType)
    {
        'SerialNumber'
        {
            $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
            Write-Verbose "[$functionName] Identifyer Type is $IdentifyerType."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Identifyer Type is $IdentifyerType." -LogLevel "Information"
            if ($DeviceIdentifyer -match 'vmware')
            {
                Write-Verbose "[$functionName] VMware device detected."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "VMware device detected." -LogLevel "Verbose"
                $autoPilotDeviceId = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $DeviceIdentifyer
                Write-Verbose "[$functionName] Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId" -LogLevel "Information"
                if ($autoPilotDeviceId)
                {
                    Write-Verbose "[$functionName] Device with Id $autoPilotDeviceId found in Autopilot."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device with Id $autoPilotDeviceId found in Autopilot." -LogLevel "Information"
                    Write-Verbose "[$functionName] Returning device id: $autoPilotDeviceId"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning device id: $autoPilotDeviceId" -LogLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "No match for device with serial number $serialNumber found in Autopilot." -LogLevel "Information"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Not a VMWare device. Continuing"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Not a VMWare device. Continuing" -LogLevel "Information"
                $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                Write-Verbose "[$functionName] Found $($autopilotDevice.count) Autopilot devices."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($autopilotDevice.count) Autopilot devices." -LogLevel "Information"
                Write-Verbose "[$functionName] Autopilot Device serial number: $($autopilotDevice.serialNumber)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot Device serial number: $($autopilotDevice.serialNumber)" -LogLevel "Information"
                $autoPilotDeviceId = $autopilotDevice.id
                Write-Verbose "[$functionName] Autopilot Device Id: $($autoPilotDeviceId)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot Device Id: $($autoPilotDeviceId)" -LogLevel "Information"
            }
        }
        'DeviceId'
        {
            Write-Verbose "[$functionName] Parameter type is DeviceId."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Parameter type is DeviceId." -LogLevel "Information"
            Write-Verbose "[$functionName] $IdentifyerType is $deviceIdentifyer."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "$IdentifyerType is $deviceIdentifyer." -LogLevel "Information"
            $autoPilotDeviceId = $deviceIdentifyer
        }
    }
    if ($autoPilotDeviceId)
    {
        Write-Verbose "[$functionName] Found device with id $autoPilotDeviceId in Autopilot."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found device with id $autoPilotDeviceId in Autopilot." -LogLevel "Information"
        Write-Verbose "[$functionName] Defining variables:"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Defining variables:" -LogLevel "Information"
        $deleteUri = "$autopilotDeviceURI/$autoPilotDeviceId"
        Write-Verbose "[$functionName] Delete URI: $deleteUri"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Delete URI: $deleteUri" -LogLevel "Information"
        Write-Host "Deleting autopilot device..."
        Write-Verbose "[$functionName] Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)" -LogLevel "Information"
        Write-Verbose "[$functionName] Passing the uri $deleteUri"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Passing the uri $deleteUri" -LogLevel "Information"
        $deleteResponse = CallGraphAPI -AccessToken $accessToken -ResourcePath $deleteUri -Method DELETE
        Write-Verbose "[$functionName] Delete response: $($deleteResponse | Out-String)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Delete response: $($deleteResponse | Out-String)" -LogLevel "Information"
        if ($null -eq $deleteResponse -or $deleteResponse -eq '')
        {
            Write-Verbose "[$functionName] Delete request initiated successfully. Beginning monitoring of device deletion..."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Delete request initiated successfully. Beginning monitoring of device deletion..." -LogLevel "Information"
            
            #region Monitor the deletion process
            $retryCount = 0
            $isDeleted = $false
            $deviceInfo = $null
            
            while (-not $isDeleted -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Verifying device deletion, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking if device is still present after delete request (Attempt $retryCount of $MaxRetries)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking if device is still present after delete request (Attempt $retryCount of $MaxRetries)" -LogLevel "Verbose"
                
                # Sleep before checking
                Start-Sleep -Seconds $RetryDelaySeconds
                
                # Check if the device still exists
                if ($IdentifyerType -eq 'SerialNumber')
                {
                    $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
                    $deviceInfo = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                }
                else # DeviceId
                {
                    $checkUri = "$autoPilotDeviceURI/$autoPilotDeviceId"
                    try
                    {
                        $deviceInfo = CallGraphAPI -AccessToken $accessToken -ResourcePath $checkUri -Method GET
                        Write-Verbose "[$functionName] Device check response: $($deviceInfo | Out-String)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device check response: $($deviceInfo | Out-String)" -LogLevel "Information"
                    } 
                    catch
                    {
                        # If the call fails with 404 (not found), the device is deleted
                        Write-Verbose "[$functionName] Error checking device: $_"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error checking device: $_" -LogLevel "Error"
                        if ($_.Exception.Response.StatusCode -eq 404)
                        {
                            $deviceInfo = $null
                        }
                    }
                }
                
                if ($null -eq $deviceInfo -or ($deviceInfo.Count -eq 0) -or ($deviceInfo -eq ''))
                {
                    $isDeleted = $true
                    Write-Host "Device deletion confirmed!" -ForegroundColor Green
                    Write-Verbose "[$functionName] Device deletion confirmed at attempt $retryCount."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device deletion confirmed at attempt $retryCount." -LogLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] Device still exists after attempt $retryCount. Waiting for $RetryDelaySeconds seconds before next check."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device still exists after attempt $retryCount. Waiting for $RetryDelaySeconds seconds before next check." -LogLevel "Information"
                }
            }
            
            if ($isDeleted)
            {
                Write-Verbose "[$functionName] Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully." -LogLevel "Information"
                $success = $true
            }
            else
            {
                Write-Host "Device deletion verification timed out after $MaxRetries attempts." -ForegroundColor Red
                Write-Verbose "[$functionName] Delete operation may have been queued but not completed within the monitoring period."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Delete operation may have been queued but not completed within the monitoring period." -LogLevel "Information"
                Write-Warning "Device may still be in the process of being deleted. Please check again later."
                $success = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)." -LogLevel "Error"
        }
    }
    else
    {
        Write-Host "No autopilot device found with $IdentifyerType $DeviceIdentifyer."
    }
    return $success
}

function RestartDevice()
{
    [CmdletBinding()]
    param (
        [string]$question = 'Do you want to reboot the device now? (Y/N)',
        [string]$bootMessage = 'Rebooting the device...',
        [string]$reminderMessage = 'Remember to reboot the device to start the device enrollment.'
    )
    $functionName = $MyInvocation.MyCommand.Name
    $reboot = Read-Host -Prompt $question
    while ($reboot -notin ('Y', 'N'))
    {
        $reboot = Read-Host -Prompt $question
        Write-Verbose "[$functionName] User input: $reboot"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User input: $reboot" -LogLevel "Information"
        if ($reboot -notin ('Y', 'N'))
        {
            Write-Host "Invalid input. Please enter 'Y' for Yes or 'N' for No." -ForegroundColor Red
            [console]::beep(1000, 500)
        }
    }
    if ($reboot -eq 'Y')
    {
        Write-Verbose "[$functionName] User chose to reboot the device."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User chose to reboot the device." -LogLevel "Information"
        Write-Host $bootMessage -ForegroundColor Green
        Restart-Computer -Force
    }
    else
    {
        Write-Verbose "[$functionName] User chose not to reboot the device."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User chose not to reboot the device." -LogLevel "Information"
        Write-Host $reminderMessage -ForegroundColor Red
        return $false
    }
}
