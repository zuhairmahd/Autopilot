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
#region Helper Functions 
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
      $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
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
      $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
      $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import'
    }
  }
  else
  {
    Write-Host "Could not obtain the serial number." -ForegroundColor Red
  }
}

function DisplayDeviceAssignmentStatus
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

function HandleDeviceEnrollmentState
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

function HandleCustomImportSettings
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

function ProcessImportResult
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

function ProcessAssignmentResult
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
            
      # Handle CustomImport settings if needed
      if ($CustomImport)
      {
        $maxWaitTimeRef = [ref]$maxWaitTime
        $timeInSecondsRef = [ref]$timeInSeconds
        $customResult = HandleCustomImportSettings -functionName $functionName -maxWaitTimeRef $maxWaitTimeRef -timeInSecondsRef $timeInSecondsRef -returnValues $returnValues
        if ($customResult)
        {
          return $customResult
        }
        $maxWaitTime = $maxWaitTimeRef.Value
        $timeInSeconds = $timeInSecondsRef.Value
      }
            
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
#endregion Helper Functions 

