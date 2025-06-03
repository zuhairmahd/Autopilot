function GetVMAutopilotDeviceIdBySerialNumber() 
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write a verbose log  of receved parameters
    Write-Verbose "[$functionName] Received serial number: $serialNumber"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    $autopilotDevices = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI).value
    Write-Verbose "[$functionName] Received $($autopilotDevices.Count) devices from Autopilot."
    for ($i = 0; $i -lt $autopilotDevices.Count; $i++)
    {
        $device = $autopilotDevices[$i]
        Write-Verbose "[$functionName] Processing device with serial number $($device.serialNumber)"
        $filteredDeviceSerialNumber = $device.serialNumber -replace '\s', ''
        Write-Verbose "[$functionName] Filtered device serial number: $filteredDeviceSerialNumber"
        if ($serialNumber -match '\s')
        {
            Write-Verbose "[$functionName] Also filtering input serial number $serialNumber since it contains spaces."
            $serialNumber = $serialNumber -replace '\s', ''
            Write-Verbose "[$functionName] Filtered input serial number: $serialNumber"
        }
        if ($filteredDeviceSerialNumber -eq $serialNumber)
        {
            Write-Verbose "[$functionName] Found a match for serial number $serialNumber in Autopilot."
            return $device.id
        }
        else
        {
            Write-Verbose "[$functionName] No match for serial number $serialNumber in Autopilot."
        }
    }
    Write-Verbose "[$functionName] Filtered device serial number: $filteredDeviceSerialNumber"
    return $null
}

function SendDeviceCommand ()
{
    [CmdletBinding()]
    param (
        [string]$ManagedDeviceId,
        [string]$accessToken,
        [ValidateSet("clean", "wipe", "sync", "restart")]
        [string]$Command = "clean",
        [int]$MaxRetries = 20,
        [int]$RetryDelaySeconds = 15,
        [switch]$MonitorAction,
        [switch]$NoConfirmation
    )
  
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Device ID:     $ManagedDeviceId"
    Write-Verbose "[$functionName] Command: $Command"
    Write-Verbose "[$functionName] MaxRetries: $MaxRetries"
    Write-Verbose "[$functionName] RetryDelaySeconds: $RetryDelaySeconds"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        return $false
    }
    #endregion

    # Confirmation for destructive operations only
    if (-not $NoConfirmation -and ($Command -eq "clean" -or $Command -eq "wipe" -or $Command -eq "restart"))
    {
        Write-Host "Are you sure you want to $Command the device?" -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'yes' to confirm, or 'no' to cancel"
        if ($confirmation -ne 'yes')
        {
            Write-Host "Operation cancelled." -ForegroundColor Gray
            return $false
        }
    }

    Write-Host "Sending $Command command to device with identifier $ManagedDeviceId" -ForegroundColor Cyan
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $success = $false
    $actionType = ""
    $response = ""
  
    switch ($Command)
    {
        "clean"
        {
            Write-Host 'Cleaning the device...' -ForegroundColor Yellow
            $cleanURI = "$deviceManagementUri/cleanWindowsDevice"
            $body = @{ 'keepUserData' = $false } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body -apiVersion 'v1.0' 
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "cleanWindows"
        }
        "wipe"
        {
            Write-Host 'Wiping the device...' -ForegroundColor Yellow
            $wipeURI = "$deviceManagementUri/wipe"
            $body = @{
                'keepEnrollmentData'   = $false
                'keepUserData'         = $false
                'obliterationBehavior' = "doNotObliterate"
            } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $wipeURI -body $body -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "wipe"
        }
        "sync"
        {
            Write-Host 'Syncing the device...' -ForegroundColor Yellow
            $syncUri = "$deviceManagementUri/syncDevice"
            $response = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "syncDevice"
        }
        "restart"
        {
            Write-Host 'Restarting the device...' -ForegroundColor Yellow
            $restartUri = "$deviceManagementUri/rebootNow"
            $response = callGraphApi -AccessToken $accessToken -Method 'POST' -ResourcePath $restartUri -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "rebootNow"
        }
        default
        {
            Write-Host "Invalid command. Please use 'clean', 'wipe', 'sync', or 'restart'." -ForegroundColor Red
            return $false
        }
    }  
    # Monitor action status for all operations
    if ($MonitorAction)
    {
        if ($response -eq '')
        {
            Write-Host "Command sent successfully. Performing automatic device sync..." -ForegroundColor Green
        
            # Only send additional sync for non-sync operations to avoid redundancy
            if ($Command -ne "sync")
            {
                $syncUri = "$deviceManagementUri/syncDevice"
                $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
                Write-Verbose "[$functionName] Sync Response: $syncResponse"
            }

            # Begin monitoring the action status
            Write-Host "Starting to monitor $Command action status..." -ForegroundColor Yellow
            $retryCount = 0
            $actionCompleted = $false
            $actionFailed = $false
            $actionState = "unknown"

            # Loop until action completes, fails, or max retries reached
            while (-not $actionCompleted -and -not $actionFailed -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Checking $Command status, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking action results (Attempt $retryCount of $MaxRetries)"
  
                # Wait before checking
                Start-Sleep -Seconds $RetryDelaySeconds
  
                # Check action results
                $deviceDetails = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0' -ExtraParameters "select=deviceActionResults"
                Write-Verbose "[$functionName] Device action results: $($deviceDetails | ConvertTo-Json -Depth 5)"
                Write-Host "Action results: $($deviceDetails.deviceActionResults)"
  
                if ($deviceDetails -and $deviceDetails.deviceActionResults)
                {
                    # Find the relevant action result based on action type
                    $actionResult = $null
                    foreach ($result in $deviceDetails.deviceActionResults)
                    {
                        if ($result.actionName -eq $actionType)
                        {
                            $actionResult = $result
                            break
                        }
                    }
                    if ($actionResult)
                    {
                        $actionState = $actionResult.status
                        Write-Host "Current $Command status: $actionState" -ForegroundColor Cyan
                        Write-Verbose "[$functionName] Action start time: $($actionResult.startDateTime)"
                        Write-Verbose "[$functionName] Action last updated: $($actionResult.lastUpdatedDateTime)"
                        # Check if action completed or failed
                        switch ($actionState)
                        {
                            "succeeded"
                            {
                                Write-Host "$Command action completed successfully!" -ForegroundColor Green
                                $actionCompleted = $true
                                $success = $true
                            }
                            "failed"
                            {
                                Write-Host "$Command action failed with error: $($actionResult.errorCode)" -ForegroundColor Red
                                if ($actionResult.errorDescription)
                                {
                                    Write-Host "Error description: $($actionResult.errorDescription)" -ForegroundColor Red
                                }
                                $actionFailed = $true
                                $success = $false
                            }
                            "timeout"
                            {
                                Write-Host "$Command action timed out." -ForegroundColor Red
                                $actionFailed = $true
                                $success = $false
                            }
                            "canceled"
                            {
                                Write-Host "$Command action was canceled." -ForegroundColor Red
                                $actionFailed = $true
                                $success = $false
                            }
                            "notFound"
                            {
                                Write-Verbose "[$functionName] Action not found yet or device may no longer be available."
                                if ($retryCount -gt 3)
                                {
                                    Write-Verbose "[$functionName] Action not found after multiple attempts, assuming device is no longer available."
                                    $actionFailed = $false
                                    $success = $true
                                }
                            }
                            default
                            {
                                Write-Verbose "[$functionName] Action status is '$actionState', continuing to monitor."
                                # Continue monitoring for non-terminal states
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] No action of type '$actionType' found yet."
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] No device action results available or device might be offline/no longer accessible."
                    # If we can no longer get device details, check if device still exists
                    $deviceCheck = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0'
                    if (-not $deviceCheck)
                    {
                        Write-Host "Device is no longer accessible. This could be expected for wipe operations." -ForegroundColor Yellow
                        # For wipe operations, this might be expected behavior as device is reset
                        if ($Command -eq 'wipe')
                        {
                            Write-Host "Wipe command appears to have succeeded as device is no longer accessible." -ForegroundColor Green
                            $actionCompleted = $true
                            $success = $true
                        }
                    }
                }
            }

            # Final status report
            if ($actionCompleted)
            {
                Write-Host "$Command action has completed successfully." -ForegroundColor Green
            }
            elseif ($actionFailed)
            {
                Write-Host "$Command action has failed with status: $actionState" -ForegroundColor Red
            }
            else
            {
                Write-Host "$Command action monitoring timed out after $MaxRetries attempts." -ForegroundColor Yellow
                Write-Host "Last known status: $actionState" -ForegroundColor Yellow
                Write-Warning "The action may still be in progress. You can check the device status in the Intune portal."
            }
        }
        else
        {
            Write-Host "Failed to send $Command command to device." -ForegroundColor Red
            Write-Verbose "[$functionName] Failed to send command. Response: $response"
        }
    }
    return $success
}

function GetDeviceIdFromSerial()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    #region Variables and verbose logs    
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceUri = "deviceManagement/managedDevices"
    $filter = "serialNumber eq '$SerialNumber'"
    $extraParameters = "select=Id"
    $device = $null
    Write-Verbose "[$functionName] Serial Number: $SerialNumber"
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        return $false
    }
    #endregion    # Query the device enrollment status using Microsoft Graph API
    # Fetch the device details using the serial number
    $response = CallGraphApi -AccessToken $AccessToken -ResourcePath $managedDeviceUri -filter $filter -ExtraParameters $extraParameters -Method GET
    if ($response)
    {
        $device = $response.value.Id
        Write-Verbose "[$functionName] Device found with ID: $($device)"
    }
    else
    {
        Write-Verbose "[$functionName] Device with serial number $SerialNumber not found."
    }
    return $device
}

#region Autopilot functions
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
            if ($result -eq $backoutText)
            {
                Write-Verbose "[$functionName] Custom import aborted. Returning $backoutText."
                return $backoutText
            }
        }
        else 
        {
            Write-Host "This will import the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) to Intune."
            Write-Verbose "[$functionName] Importing device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
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
        $deviceAssignment,
        [Parameter(Mandatory = $true)]
        [string]$functionName
    )

    Write-Verbose "[$functionName] The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)"
    
    if ($deviceAssignment.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
    {
        Write-Host 'The device is already in Intune and is assigned to a profile.' -ForegroundColor Green
        Write-Verbose "[$functionName] The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)."
        $profileAssignmentDate = ($deviceAssignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
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
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        $returnValues,
        [Parameter(Mandatory = $false)]
        [string]$domain
    )

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
        return $returnValues.ImportSuccessMessage
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
        return $returnValues.ImportSuccessMessage
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
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    Write-Verbose "[$functionName] Processing import result with status: $($device.state.deviceImportStatus)"
    if ($device.state.deviceImportStatus -eq 'complete')
    {
        $serialNumber = $device.SerialNumber
        Write-Host "The import of device with serial number $serialNumber completed successfully." -ForegroundColor Green
        return $true
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
}

function ProcessAssignmentResult()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $assignment,
        [Parameter(Mandatory = $true)]
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        [datetime]$importStart,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
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
            return $returnValues.ImportSuccessMessage
        }
    }
    else
    {
        Write-Host 'The device could not be assigned to a deployment profile.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        Write-Host "The device current assignment status is $($assignment.deploymentProfileAssignmentStatus)."
        Write-Host "The device assignment profile name is $($assignment.deploymentProfile.displayName)."
        Write-Host "The device profile assignment date is $($assignment.deploymentProfileAssignmentDateTime)."
        return $returnValues.ImportFailedMessage
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
        [string]$action,
        [switch]$CustomImport
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
    Write-Verbose "[$functionName] Custom import: $CustomImport"
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
            if ($deviceAssignment)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment -functionName $functionName
                if (-not $isAssigned)
                {
                    return $returnValues.UnassignedMessage
                }
            }
            else
            {
                Write-Host "The device is not in Intune." 
            }
            #region Add the device to Intune
            $importStart = Get-Date
            $device = ImportAutopilotDevice -DeviceObject $deviceObject -AccessToken $accessToken -GroupTag $GroupTag -AssignedUser $AssignedUser -TimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime -CustomImport $CustomImport
            if ($device -eq $backoutText)
            {
                Write-Verbose "[$functionName] The import function returned $device."
                return $backoutText
            }
            $importResult = ProcessImportResult -device $device -functionName $functionName -returnValues $returnValues
            if ($importResult -ne $true)
            {
                return $importResult
            }
            
            #region Handle CustomImport settings if needed
            # if ($CustomImport)
            # {
            #   $maxWaitTimeRef = [ref]$maxWaitTime
            #   $timeInSecondsRef = [ref]$timeInSeconds
            #   $customResult = HandleCustomImportSettings -functionName $functionName -maxWaitTimeRef $maxWaitTimeRef -timeInSecondsRef $timeInSecondsRef -returnValues $returnValues
            #   if ($customResult)
            #   {
            #     return $customResult
            #   }
            #   $maxWaitTime = $maxWaitTimeRef.Value
            #   $timeInSeconds = $timeInSecondsRef.Value
            # }
            #endregion Handle CustomImport settings if needed
            
            Write-Host "Waiting for $timeInSeconds seconds to allow for profile assignment."
            Start-Sleep -Seconds $timeInSeconds
            
            $assignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -WaitForAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
            return ProcessAssignmentResult -assignment $assignment -functionName $functionName -importStart $importStart -returnValues $returnValues
            #endregion Add the device to Intune.
        }
        'check'
        {
            Write-Host "Checking device with serial number $serialNumber..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            
            if ($deviceAssignment)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment -functionName $functionName
                
                if ($isAssigned)
                {
                    # Handle enrollment state for assigned devices
                    return HandleDeviceEnrollmentState -deviceAssignment $deviceAssignment -serialNumber $serialNumber -accessToken $accessToken -functionName $functionName -returnValues $returnValues -domain $domain
                }
                else
                {
                    # Handle unassigned devices
                    switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                    {
                        'unassigned'
                        {
                            return $returnValues.UnassignedMessage
                        }
                        'pending'
                        {
                            return $returnValues.PendingMessage
                        }
                    }
                    
                    # Show options for problem devices
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
                Write-Verbose "[$functionName] Returning to the previous menu."
                return $backoutText
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
            return $null
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
                Write-Verbose "[$functionName] The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($autopilotDevice.deploymentProfileAssignedDateTime)."
                Write-Verbose "[$functionName] The device is ready for enrollment."
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
    }
    Write-Verbose "[$functionName] Returning $assignment."
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
#endregion 
