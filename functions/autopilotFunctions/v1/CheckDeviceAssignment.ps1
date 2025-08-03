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
                Write-Verbose "[$functionName] Device details: $($assignment | ConvertTo-Json -Depth 100)"
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

