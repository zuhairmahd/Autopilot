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
    
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting CheckDeviceAssignment for serial number $serialNumber (WaitForAssignment=$WaitForAssignment, waitTimeInSeconds=$waitTimeInSeconds, maxWaitTime=$maxWaitTime)." -LogLevel "Information"
    Write-Verbose "[$functionName] Checking whether the device with serial number $serialNumber is already in Intune."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking Autopilot for serial number $serialNumber" -LogLevel "Verbose"
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "[$functionName] VMware device detected."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "VMware device detected for serial $serialNumber" -LogLevel "Information"
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "[$functionName] Received $($autoPilotVMDevice.count) devices from Autopilot."
        if ($autoPilotVMDevice -ne '' -and $null -ne $autoPilotVMDevice)
        {
            Write-Verbose "[$functionName] Got an Autopilot Device with device id $($autoPilotVMDevice)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found VMware Autopilot device id $autoPilotVMDevice" -LogLevel "Information"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUriWithId
        }
        else
        {
            Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial $serialNumber not found in Autopilot (VMware path)" -LogLevel "Information"
            return $returnValues.notInIntuneMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] Not a VMWare device. Continuing"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial $serialNumber is not VMware - querying standard Autopilot endpoint" -LogLevel "Verbose"
        $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUri -filter $autopilotDeviceFilter).value
    }
    Write-Verbose "[$functionName] Found $($assignment.count) Autopilot devices."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot query returned count=$($assignment.count) for serial $serialNumber" -LogLevel "Information"
    if ($null -ne $assignment -and $assignment -ne '')
    {
        Write-Verbose "[$functionName] Found the device matching serial number $serialNumber."
        Write-Verbose "[$functionName] The device is registered in Autopilot."
        Write-Verbose "[$functionName] Checking profile assignment"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device $serialNumber found. Expanding for profile assignment." -LogLevel "Information"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($assignment.id)"
        $extraProfileParameters = "expand=deploymentProfile"
        $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -extraparameters $extraProfileParameters
        Write-Host "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
        if ($WaitForAssignment -and ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync')))
        {
            Write-Host "Checking up to $maxWaitTime times for the device to be assigned to a deployment profile."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Waiting for profile assignment (max $maxWaitTime iterations, sleep $waitTimeInSeconds s) for serial $serialNumber" -LogLevel "Information"
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
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Iteration $index/$maxWaitTime status=$($assignment.deploymentProfileAssignmentStatus)" -LogLevel "Verbose"
            }
            Write-Verbose "[$functionName] Gop final device assignment status: $($assignment.deploymentProfileAssignmentStatus)."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Final assignment status after wait: $($assignment.deploymentProfileAssignmentStatus)" -LogLevel "Information"
            if ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -gt $maxWaitTime)
            {
                Write-Host "Finished checking $maxWaitTime times."
                Write-Host "The device assignment is taking too long."
                Write-Host 'Please check the Intune portal or contact an Intune administrator.'
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Timeout waiting for assignment for serial $serialNumber" -LogLevel "Warning"
            }
            elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Congratulations!!! " 
                Write-Verbose "[$functionName] The device is successfully assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime)."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device $serialNumber assigned to profile $($assignment.deploymentProfile.displayName)" -LogLevel "Information"
            }
        }
        else
        {
            if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Device details: $($assignment | ConvertTo-Json -Depth $maxJSONDepth)"
                Write-Verbose "[$functionName] The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)."
                Write-Verbose "[$functionName] The device is ready for enrollment."
                Write-Verbose "[$functionName] Returning $($returnValues.deviceAssignedMessage)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device $serialNumber already assigned (status $($assignment.deploymentProfileAssignmentStatus))" -LogLevel "Information"
            }
            else
            {
                Write-Host "The device is not assigned to a deployment profile."
                Write-Host "Please check the Intune portal or contact an Intune administrator."
                Write-Verbose "[$functionName] The device is not ready for enrollment."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device $serialNumber not yet assigned (status $($assignment.deploymentProfileAssignmentStatus))" -LogLevel "Information"
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device is not found in Intune."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device $serialNumber not found in Intune" -LogLevel "Information"
        return $returnValues.deviceNotInIntuneMessage
    }
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning assignment object for serial $serialNumber" -LogLevel "Verbose"
    return $assignment
}

