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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting ImportAutopilotDevice for serial=$($DeviceObject.serialNumber) CustomImport=$CustomImport GroupTag='$GroupTag' AssignedUser='$AssignedUser' maxWaitTime=$maxWaitTime timeInSeconds=$timeInSeconds" -LogLevel "Information"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Access token provided" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken not provided."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Access token missing - aborting import" -LogLevel "Error"
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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Prepared import object for serial=$serialNumber make='$make' model='$model' groupTag='$GroupTag' assignedUser='$AssignedUser'" -LogLevel "Information"
    #endregion  
    #region prepare import object.
    if ($CustomImport -eq $true)
    {
        do
        {
            Write-Verbose "[$functionName] CustomImport is set to true."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting user for custom import parameters" -LogLevel "Information"
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
                Write-Log -LogFile $LogFile -Module $functionName -Message "User confirmed import with parameters GroupTag='$groupTag' AssignedUser='$AssignedUser'" -LogLevel "Information"
            }
            elseif ($ImportChoice -eq 'R')
            {
                $ProceedWithImport = $false
                Write-Host "Reentering the parameters."
                Write-Log -LogFile $LogFile -Module $functionName -Message "User chose to reenter parameters" -LogLevel "Information"
            }
            else
            {
                $ProceedWithImport = $false
                Write-Host "Exiting..."
                Write-Log -LogFile $LogFile -Module $functionName -Message "User aborted custom import (backout)" -LogLevel "Information"
                return $returnValues.backoutText
            }
        } while ($ProceedWithImport -eq $false)
    }
    else
    {
        Write-Verbose "[$functionName] CustomImport is set to false."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using default import parameters" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module $functionName -Message "POST import request submitted for serial=$serialNumber" -LogLevel "Information"
    
    if ($null -eq $imported)
    {
        Write-Host "The device import failed."
        Write-Host "Please check the Intune portal or contact an Intune administrator."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Import POST returned null - failure" -LogLevel "Error"
        return $null
    }
    Write-Host "The device import was successfully started."
    Write-Host "The imported device ID is $($imported.id)."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Import started id=$($imported.id)" -LogLevel "Information"
    #wait for the device to be imported
    Write-Host "Waiting for the import for device with device ID $($imported.id) to be completed."
    Start-Sleep -Seconds 10
    $device = callGraphApi -AccessToken $AccessToken -ResourcePath "$uri/$($imported.id)" -Method GET
    $index = 0
    Write-Log -LogFile $LogFile -Module $functionName -Message "Beginning wait loop for import completion with maxWaitTime=$maxWaitTime timeInSeconds=$timeInSeconds" -LogLevel "Information"
    while ($index -lt $maxWaitTime)
    {
        Write-Verbose "[$functionName] The device import status is $($device.state.deviceImportStatus)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Poll $index/$maxWaitTime status=$($device.state.deviceImportStatus)" -LogLevel "Information"
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
        Write-Log -LogFile $LogFile -Module $functionName -Message "Timeout waiting for import completion (status still unknown)" -LogLevel "Warning"
        return $null
    }
    else
    {
        Write-Verbose "[$functionName] The device import state is $($device.state.deviceImportStatus)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Import completed with status $($device.state.deviceImportStatus)" -LogLevel "Information"
        return $device
    }
}

