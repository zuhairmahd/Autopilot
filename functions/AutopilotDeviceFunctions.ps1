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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting serial number validation" -LogLevel "Debug"
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    $returnValue = @{}
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Validating serial number length: $($UserInput.Length)" -LogLevel "Debug"
    
    if ($UserInput.Length -gt $MaxSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
        Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation failed: exceeds maximum length of $MaxSerialNumberLength characters" -LogLevel "Warning"
    }
    elseif ($UserInput.Length -lt $MinSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
        Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation failed: shorter than minimum length of $MinSerialNumberLength characters" -LogLevel "Warning"
    }
    elseif ($UserInput -match '^[a-zA-Z0-9]+$') 
    {
        Write-Verbose "[$functionName] Serial number validation passed"
        $returnValue.valid = $true
        $returnValue.value = $UserInput
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation passed" -LogLevel "Debug"
    }
    else
    {
        Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Serial number validation failed: invalid format (non-alphanumeric characters)" -LogLevel "Warning"
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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting user input collection" -LogLevel "Debug"
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 
    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        Write-Log -LogFile $LogFile -Module $functionName -Message "User input received" -LogLevel "Debug"
        
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $($returnValues.backoutText)."
            Write-Log -LogFile $LogFile -Module $functionName -Message "User pressed Enter to return to previous menu" -LogLevel "Debug"
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
            Write-Log -LogFile $LogFile -Module $functionName -Message "Valid input received and validated" -LogLevel "Debug"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red 
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid input provided - prompting user to try again" -LogLevel "Warning"
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
    Write-Verbose "[$functionName] Getting the serial number for this device..."
    Write-Verbose "[$functionName] Checking whether the script has sufficient permissions to run."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$functionName] The script is running with sufficient permissions."
        Write-Verbose "[$functionName] Getting device object."
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
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import' -CustomImport
            if ($result -eq $returnValues.backoutText)
            {
                Write-Verbose "[$functionName] Custom import aborted. Returning $($returnValues.backoutText)."
                return $returnValues.backoutText
            }
        }
        else 
        {
            Write-Verbose "[$functionName] The device with serial number $($deviceObject.serialNumber) is ready for import."
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
    if ($deviceAssignment.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
    {
        Write-Host 'The device is already in Intune and is assigned to a profile.' -ForegroundColor Green
        Write-Verbose "[$functionName] The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)."
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
    
    switch ($enrollmentState)
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
            $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -Filter $managedDeviceFilter).value
            Write-Verbose "[$functionName] Managed device user principal name: $($managedDevice.userPrincipalName)"
            Write-Verbose "[$functionName] Managed device user display name: $($managedDevice.userDisplayName)"
            Write-Verbose "[$functionName] Managed device last logon date: $($managedDevice.usersLoggedOn.lastLogOnDateTime)"

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
    Write-Verbose "[$functionName] The assignment details are: $($assignment | ConvertTo-Json)"
    
    if (-not $assignment)
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
        return $returnValues.notInIntuneMessage
    }
    
    Write-Verbose "[$functionName] The assignment status is $($assignment.deploymentProfileAssignmentStatus)"    
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
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken not provided."
        return $false
    }
    Write-Verbose "[$functionName] DeviceObject: $DeviceObject"
    Write-Verbose "[$functionName] GroupTag: $GroupTag"
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Verbose "[$functionName] MaxWaitTime: $maxWaitTime"
    Write-Verbose "[$functionName] TimeInSeconds: $timeInSeconds"
    Write-Verbose "[$functionName] CustomImport: $CustomImport"
    $uri = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $serialNumber = $DeviceObject.serialNumber
    Write-Verbose "[$functionName] Serial Number: $serialNumber"
    $make = $DeviceObject.manufacturer
    Write-Verbose "[$functionName] Make: $make"
    $model = $DeviceObject.model
    Write-Verbose "[$functionName] Model: $model"
    $hash = $DeviceObject.hardwareHash
    #endregion  
    #region prepare import object.
    if ($CustomImport -eq $true)
    {
        do
        {
            Write-Verbose "[$functionName] CustomImport is set to true."
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
    if (($device.state.deviceImportStatus -eq 'unknown') -and ($index -gt $maxWaitTime))
    {
        Write-Host "The import is taking too long (over $maxWaitTime minutes)." 
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        return $null
    }
    else
    {
        Write-Verbose "[$functionName] The device import state is $($device.state.deviceImportStatus)"
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
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    Write-Verbose "[$functionName] WaitForAssignment switch: $WaitForAssignment."
    if ($WaitForAssignment)
    {
        Write-Verbose "[$functionName] Wait time in seconds: $waitTimeInSeconds."
        Write-Verbose "[$functionName] Max wait time: $maxWaitTime."
    }
    $autoPilotDeviceURI = 'deviceManagement/windowsAutopilotDeviceIdentities'
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    $assignment = $null
    #endregion
    
    Write-Verbose "[$functionName] Checking whether the device with serial number $serialNumber is already in Intune."
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "[$functionName] VMware device detected."
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "[$functionName] Received $($autoPilotVMDevice.count) devices from Autopilot."
        if ($autoPilotVMDevice -ne '' -and $null -ne $autoPilotVMDevice)
        {
            Write-Verbose "[$functionName] Got an Autopilot Device with device id $($autoPilotVMDevice)"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUriWithId
        }
        else
        {
            Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
            return $returnValues.notInIntuneMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] Not a VMWare device. Continuing"
        $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUri -filter $autopilotDeviceFilter).value
    }
    Write-Verbose "[$functionName] Found $($assignment.count) Autopilot devices."
    if ($null -ne $assignment -and $assignment -ne '')
    {
        Write-Verbose "[$functionName] Found the device matching serial number $serialNumber."
        Write-Verbose "[$functionName] The device is registered in Autopilot."
        Write-Verbose "[$functionName] Checking profile assignment"
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
            if ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -gt $maxWaitTime)
            {
                Write-Host "Finished checking $maxWaitTime times."
                Write-Host "The device assignment is taking too long."
                Write-Host 'Please check the Intune portal or contact an Intune administrator.'
            }
            elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Congratulations!!! " 
                Write-Verbose "[$functionName] The device is successfully assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime)."
            }
        }
        else
        {
            if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Device details: $($assignment | ConvertTo-Json -Depth 10)"
                Write-Verbose "[$functionName] The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)."
                Write-Verbose "[$functionName] The device is ready for enrollment."
                Write-Verbose "[$functionName] Returning $($returnValues.deviceAssignedMessage)"
            }
            else
            {
                Write-Host "The device is not assigned to a deployment profile."
                Write-Host "Please check the Intune portal or contact an Intune administrator."
                Write-Verbose "[$functionName] The device is not ready for enrollment."
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device is not found in Intune."
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
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Verbose "[$functionName] NoHash: $NoHash"

    $device = @{}
    $session = New-CimSession
    $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
    #Add the serial number to the hash table.
    $device.Add('SerialNumber', $serial)
    Write-Verbose "[$functionName] The serial number is $serial."
    $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
    $make = $cs.Manufacturer.Trim()
    $device.Add('Manufacturer', $make)
    Write-Verbose "[$functionName] The manufacturer is $make."
    $model = $cs.Model.Trim()
    $device.Add('Model', $model)
    Write-Verbose "[$functionName] The model is $model."
    $product = ''
    $device.add('Product', $product)
    Write-Verbose "[$functionName] The group tag is $GroupTag"
    $device.add('GroupTag', $GroupTag)
    Write-Verbose "[$functionName] The assigned user is $AssignedUser"
    $device.add('AssignedUser', $AssignedUser)
    if (-not $NoHash)
    {
        Write-Verbose "[$functionName] Checking for hardware hash."
        $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
        Write-Verbose "[$functionName] The device details are: $($devDetail | ConvertTo-Json -Depth 5)"
        if ($devDetail)
        {
            $hash = $devDetail.DeviceHardwareData
            $device.Add('HardwareHash', $hash)
            Write-Verbose "[$functionName] The hardware hash is $hash."
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
    if ($accessToken)
    {
        Write-Verbose "[$functionName]     AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName]     No AccessToken provided."
        return $null
    }
    Write-Verbose "[$functionName] Device identifier: $DeviceIdentifyer."
    Write-Verbose "[$functionName] Identifyer type: $IdentifyerType."
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    #endregion

    switch ($IdentifyerType)
    {
        'SerialNumber'
        {
            $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
            Write-Verbose "[$functionName] Identifyer Type is $IdentifyerType."
            if ($DeviceIdentifyer -match 'vmware')
            {
                Write-Verbose "[$functionName] VMware device detected."
                $autoPilotDeviceId = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $DeviceIdentifyer
                Write-Verbose "[$functionName] Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId"
                if ($autoPilotDeviceId)
                {
                    Write-Verbose "[$functionName] Device with Id $autoPilotDeviceId found in Autopilot."
                    Write-Verbose "[$functionName] Returning device id: $autoPilotDeviceId"
                }
                else
                {
                    Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
                }
            }
            else
            {
                Write-Verbose "[$functionName] Not a VMWare device. Continuing"
                $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                Write-Verbose "[$functionName] Found $($autopilotDevice.count) Autopilot devices."
                Write-Verbose "[$functionName] Autopilot Device serial number: $($autopilotDevice.serialNumber)"
                $autoPilotDeviceId = $autopilotDevice.id
                Write-Verbose "[$functionName] Autopilot Device Id: $($autoPilotDeviceId)"
            }
        }
        'DeviceId'
        {
            Write-Verbose "[$functionName] Parameter type is DeviceId."
            Write-Verbose "[$functionName] $IdentifyerType is $deviceIdentifyer."
            $autoPilotDeviceId = $deviceIdentifyer
        }
    }
    if ($autoPilotDeviceId)
    {
        Write-Verbose "[$functionName] Found device with id $autoPilotDeviceId in Autopilot."
        Write-Verbose "[$functionName] Defining variables:"
        $deleteUri = "$autopilotDeviceURI/$autoPilotDeviceId"
        Write-Verbose "[$functionName] Delete URI: $deleteUri"
        Write-Host "Deleting autopilot device..."
        Write-Verbose "[$functionName] Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "[$functionName] Passing the uri $deleteUri"
        $deleteResponse = CallGraphAPI -AccessToken $accessToken -ResourcePath $deleteUri -Method DELETE
        Write-Verbose "[$functionName] Delete response: $($deleteResponse | Out-String)"
        if ($null -eq $deleteResponse -or $deleteResponse -eq '')
        {
            Write-Verbose "[$functionName] Delete request initiated successfully. Beginning monitoring of device deletion..."
            
            #region Monitor the deletion process
            $retryCount = 0
            $isDeleted = $false
            $deviceInfo = $null
            
            while (-not $isDeleted -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Verifying device deletion, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking if device is still present after delete request (Attempt $retryCount of $MaxRetries)"
                
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
                    } 
                    catch
                    {
                        # If the call fails with 404 (not found), the device is deleted
                        Write-Verbose "[$functionName] Error checking device: $_"
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
                }
                else
                {
                    Write-Verbose "[$functionName] Device still exists after attempt $retryCount. Waiting for $RetryDelaySeconds seconds before next check."
                }
            }
            
            if ($isDeleted)
            {
                Write-Verbose "[$functionName] Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully."
                $success = $true
            }
            else
            {
                Write-Host "Device deletion verification timed out after $MaxRetries attempts." -ForegroundColor Red
                Write-Verbose "[$functionName] Delete operation may have been queued but not completed within the monitoring period."
                Write-Warning "Device may still be in the process of being deleted. Please check again later."
                $success = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)."
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
        if ($reboot -notin ('Y', 'N'))
        {
            Write-Host "Invalid input. Please enter 'Y' for Yes or 'N' for No." -ForegroundColor Red
            [console]::beep(1000, 500)
        }
    }
    if ($reboot -eq 'Y')
    {
        Write-Verbose "[$functionName] User chose to reboot the device."
        Write-Host $bootMessage -ForegroundColor Green
        Restart-Computer -Force
    }
    else
    {
        Write-Verbose "[$functionName] User chose not to reboot the device."
        Write-Host $reminderMessage -ForegroundColor Red
        return $false
    }
}

function GetCorpDeviceIdentifier()
{
    [CmdletBinding()]
    param (
        [string]$OutputPath = "$pwd\corp_device_info.csv"
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Entered function. OutputPath: $OutputPath"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting GetCorpDeviceIdentifier. OutputPath: $OutputPath" -LogLevel "Information"

    # Get computer system information
    try
    {
        Write-Verbose "[$functionName] Attempting to retrieve computer system information via Win32_ComputerSystem."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving Win32_ComputerSystem info..." -LogLevel "Debug"
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem 
        Write-Verbose "[$functionName] Computer system information retrieved: $($computerSystem | ConvertTo-Json -Depth 5)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Win32_ComputerSystem info: $($computerSystem | ConvertTo-Json -Depth 5)" -LogLevel "Debug"

        Write-Verbose "[$functionName] Attempting to retrieve BIOS information via Win32_BIOS."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving Win32_BIOS info..." -LogLevel "Debug"
        $bios = Get-CimInstance -ClassName Win32_BIOS
        Write-Verbose "[$functionName] BIOS information retrieved: $($bios | ConvertTo-Json -Depth 5)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Win32_BIOS info: $($bios | ConvertTo-Json -Depth 5)" -LogLevel "Debug"
    }
    catch
    {
        Write-Error "Failed to retrieve computer system information: $_"
        Write-Verbose "[$functionName] Exception occurred: $($_.Exception | Format-List * | Out-String)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error retrieving system info: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }

    # Extract the desired properties
    Write-Verbose "[$functionName] Extracting Manufacturer, Model, and SerialNumber."
    $make = $computerSystem.Manufacturer
    $model = $computerSystem.Model
    $serialNumber = $bios.SerialNumber
    Write-Verbose "[$functionName] Extracted values: Manufacturer='$make', Model='$model', SerialNumber='$serialNumber'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Extracted device info: Manufacturer='$make', Model='$model', SerialNumber='$serialNumber'" -LogLevel "Information"

    # Output the information
    Write-Host "Device Manufacturer: $make"
    Write-Host "Device Model: $model"
    Write-Host "Device Serial Number: $serialNumber"
    Write-Verbose "[$functionName] Outputting device info to host."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Outputting device info to host." -LogLevel "Debug"

    $deviceInfo = [PSCustomObject]@{
        Manufacturer = $make
        Model        = $model
        SerialNumber = $serialNumber
    }
    Write-Verbose "[$functionName] Returning device info object."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Returning device info object: $($deviceInfo | ConvertTo-Json -Depth 3)" -LogLevel "Debug"
    return $deviceInfo
}

function AddCorporateDeviceIdentifier()
{
    <#
    .SYNOPSIS
    Adds a device identifier to Windows Corporate Device Identifiers in Intune.
    
    .DESCRIPTION
    This function adds a device identifier to the corporate device identifiers list in Microsoft Intune. 
    This helps identify corporate-owned devices for enrollment and management purposes.
    
    Supports three types of identifiers:
    - SerialNumber: Just the device serial number
    - IMEI: Device IMEI number (for mobile devices)
    - manufacturerModelSerial: Comma-separated string "Manufacturer,Model,SerialNumber" (Windows-specific)
    
    .PARAMETER AccessToken
    Valid Microsoft Graph API access token with deviceManagement permissions.
    
    .PARAMETER DeviceIdentifier
    The device identifier to add. Format depends on IdentifierType:
    - For SerialNumber: Just the serial number (e.g., "ABC123456789")
    - For IMEI: Just the IMEI number (e.g., "123456789012345")
    - For manufacturerModelSerial: "Manufacturer,Model,SerialNumber" (e.g., "Microsoft Corporation,Virtual Machine,ABC123456789")
    
    .PARAMETER IdentifierType
    Type of identifier being provided. Valid values are:
    - 'SerialNumber': Device serial number only
    - 'IMEI': Device IMEI number only  
    - 'manufacturerModelSerial': Windows-specific format with manufacturer, model, and serial
    Default is 'manufacturerModelSerial'.
    
    .PARAMETER OverwriteImportedDeviceIdentities
    Switch to enable overwriting existing device identities if they already exist.
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "123456789012345" -IdentifierType "IMEI"
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "Microsoft Corporation,Virtual Machine,ABC123456789" -IdentifierType "manufacturerModelSerial"
    
    .EXAMPLE
    AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "Dell Inc.,OptiPlex 7090,DEL123456" -IdentifierType "manufacturerModelSerial" -OverwriteImportedDeviceIdentities
    
    .NOTES
    This function was created to resolve Autopilot V2 device import issues where devices
    need to be marked as corporate-owned before enrollment.
    
    Requires Microsoft Graph API permissions:
    - DeviceManagementManagedDevices.ReadWrite.All
    - DeviceManagementConfiguration.ReadWrite.All
    
    API Endpoint: https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/importDeviceIdentityList
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$DeviceIdentifier,
        [Parameter(Mandatory = $false)]
        [ValidateSet('SerialNumber', 'IMEI', 'manufacturerModelSerial')]
        [string]$IdentifierType = 'manufacturerModelSerial',
        [switch]$OverwriteImportedDeviceIdentities
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Entered function. Parameters: AccessToken='$(if ($AccessToken) {'***'} else {'<null>'})', DeviceIdentifier='$DeviceIdentifier', IdentifierType='$IdentifierType', OverwriteImportedDeviceIdentities='$OverwriteImportedDeviceIdentities'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting AddCorporateDeviceIdentifier. DeviceIdentifier='$DeviceIdentifier', IdentifierType='$IdentifierType', OverwriteImportedDeviceIdentities='$OverwriteImportedDeviceIdentities'" -LogLevel "Information"

    if ($AccessToken -eq '' -or $null -eq $AccessToken)
    {
        Write-Verbose "[$functionName] No AccessToken provided. Aborting."
        Write-Log -LogFile $LogFile -Module $functionName -Message "No AccessToken provided. Aborting." -LogLevel "Error"
        return $false
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken provided."
        Write-Log -LogFile $LogFile -Module $functionName -Message "AccessToken provided." -LogLevel "Debug"
    }

    if ($OverwriteImportedDeviceIdentities)
    {
        $deviceOverwrite = $true
        Write-Verbose "[$functionName] OverwriteImportedDeviceIdentities switch is set. Will overwrite existing device identities."
        Write-Log -LogFile $LogFile -Module $functionName -Message "OverwriteImportedDeviceIdentities is set to true." -LogLevel "Debug"
    }
    else
    {
        $deviceOverwrite = $false
        Write-Verbose "[$functionName] OverwriteImportedDeviceIdentities switch is NOT set. Will NOT overwrite existing device identities."
        Write-Log -LogFile $LogFile -Module $functionName -Message "OverwriteImportedDeviceIdentities is set to false." -LogLevel "Debug"
    }

    # Microsoft Graph API endpoint for Windows Corporate Device Identifiers
    $uri = "deviceManagement/importedDeviceIdentities/importDeviceIdentityList"
    Write-Verbose "[$functionName] Using Graph API endpoint: $uri"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Using Graph API endpoint: $uri" -LogLevel "Debug"

    # Handle different identifier types with proper formatting
    $formattedIdentifier = $DeviceIdentifier
    $formattedType = $IdentifierType.ToLower()
    Write-Verbose "[$functionName] Initial formattedIdentifier: $formattedIdentifier, formattedType: $formattedType"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Initial formattedIdentifier: $formattedIdentifier, formattedType: $formattedType" -LogLevel "Debug"

    # For manufacturerModelSerial, ensure proper comma-separated format
    if ($IdentifierType -eq 'manufacturerModelSerial')
    {
        Write-Verbose "[$functionName] IdentifierType is manufacturerModelSerial. Validating format."
        $parts = $DeviceIdentifier -split ','
        if ($parts.Count -eq 3)
        {
            $manufacturer = $parts[0].Trim()
            $model = $parts[1].Trim()
            $serial = $parts[2].Trim()
            $formattedIdentifier = "$manufacturer,$model,$serial"
            $formattedType = "manufacturerModelSerial"
            Write-Verbose "[$functionName] manufacturerModelSerial parsed: Manufacturer='$manufacturer', Model='$model', Serial='$serial'"
            Write-Log -LogFile $LogFile -Module $functionName -Message "manufacturerModelSerial parsed: Manufacturer='$manufacturer', Model='$model', Serial='$serial'" -LogLevel "Debug"
        }
        else
        {
            Write-Verbose "[$functionName] Invalid manufacturerModelSerial format. Throwing error."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid manufacturerModelSerial format: $DeviceIdentifier" -LogLevel "Error"
            throw "Invalid manufacturerModelSerial format. Expected 'Manufacturer,Model,SerialNumber' but got: $DeviceIdentifier"
        }
    }
    elseif ($IdentifierType -eq 'SerialNumber')
    {
        $formattedType = "serialNumber"
        Write-Verbose "[$functionName] IdentifierType is SerialNumber. formattedType set to 'serialNumber'."
        Write-Log -LogFile $LogFile -Module $functionName -Message "IdentifierType is SerialNumber. formattedType set to 'serialNumber'." -LogLevel "Debug"
    }
    elseif ($IdentifierType -eq 'IMEI')
    {
        $formattedType = "imei"
        Write-Verbose "[$functionName] IdentifierType is IMEI. formattedType set to 'imei'."
        Write-Log -LogFile $LogFile -Module $functionName -Message "IdentifierType is IMEI. formattedType set to 'imei'." -LogLevel "Debug"
    }

    $body = @{
        overwriteImportedDeviceIdentities = $deviceOverwrite 
        importedDeviceIdentities          = @(
            @{ 
                "@odata.type"              = "#microsoft.graph.importedDeviceIdentity"
                importedDeviceIdentifier   = $formattedIdentifier
                importedDeviceIdentityType = $formattedType
                description                = "Added via PowerShell Autopilot Tool"
            }
        )
    } | ConvertTo-Json -Depth 10
    Write-Verbose "[$functionName] Request body: $body"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Request body prepared for API call: $body" -LogLevel "Debug"

    try
    {
        Write-Host "Adding device identifier to corporate identifiers..." -ForegroundColor Yellow
        Write-Verbose "[$functionName] Calling CallGraphAPI with POST to $uri."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Calling CallGraphAPI with POST to $uri." -LogLevel "Information"
        $result = (CallGraphAPI -AccessToken $AccessToken -ResourcePath $uri -Method POST -Body $body).value
        Write-Verbose "[$functionName] CallGraphAPI returned: $($result | ConvertTo-Json -Depth 5)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "CallGraphAPI returned: $($result | ConvertTo-Json -Depth 5)" -LogLevel "Debug"
        Start-Sleep -Seconds 5 # Allow time for the API to process
        if ($result -and $result.importedDeviceIdentities -is [array] -and $result.importedDeviceIdentities.Count -gt 0)
        {
            Write-Host "Successfully added device identifier to corporate identifiers." -ForegroundColor Green
            Write-Host "Number of imported device identities: $($result.importedDeviceIdentities.Count)" -ForegroundColor Green
            Write-Verbose "[$functionName] Successfully added corporate device identifiers. Response: $($result | ConvertTo-Json -Depth 5)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully added corporate device identifiers. Response: $($result | ConvertTo-Json -Depth 5)" -LogLevel "Information"
            return $result
        }
        else
        {
            Write-Host "Failed to add device identifier to corporate identifiers." -ForegroundColor Red
            Write-Verbose "[$functionName] API call returned unexpected result: $($result | ConvertTo-Json -Depth 3)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to add corporate device identifier - unexpected API response: $($result | ConvertTo-Json -Depth 5)" -LogLevel "Error"
            return $null
        }
    }
    catch
    {
        Write-Host "Error adding device identifier to corporate identifiers: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error details: $($_.Exception | Format-List * | Out-String)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error adding corporate device identifier: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Exception details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        return $null
    }
}
