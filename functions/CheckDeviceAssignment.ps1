<#
.SYNOPSIS
Checks if a device with a given serial number is already in Intune and verifies its profile assignment status.

.DESCRIPTION
The CheckDeviceAssignment function takes a serial number as input and checks if the device is already imported into Intune. If the device is found, it further checks the deployment profile assignment status. If the device is assigned to a deployment profile, it outputs the profile name and indicates readiness for enrollment. Otherwise, it provides guidance for further action.

.PARAMETER serial
The serial number of the device to check.

.EXAMPLE
CheckDeviceAssignment -serial "123456789"
Checks if the device with serial number 123456789 is in Intune and verifies its profile assignment status.

.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
GUID: 3f2504e0-4f89-11d3-9a0c-0305e82c3301
Date: April 5, 2025
#>
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
        [int]$waitTimeInSeconds = 60,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$maxWaitTime = 30
    )
    
    #region variables and logs
    Write-Verbose "Received parameters: serialNumber=$serialNumber."
    if ($AccessToken)
    {
        Write-Verbose "Access token provided."
    }
    if ($WaitForAssignment)
    {
        Write-Verbose "WaitForAssignment switch: $WaitForAssignment."
        Write-Verbose "Wait time in seconds: $waitTimeInSeconds."
        Write-Verbose "Max wait time: $maxWaitTime."
    }
    $autoPilotDeviceURI = 'deviceManagement/windowsAutopilotDeviceIdentities'
    $returnValue = $null
    #endregion
    
    Write-Verbose "Calling Graph API at $autoPilotDeviceURI."
    Write-Verbose "Checking whether the device with serial number $serialNumber is already in Intune."
    $autopilotDevices = CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI
    Write-Verbose "Graph response: $($autopilotDevices)."
    if ($null -eq $autopilotDevices -and $autopilotDevices -notin 200..204)
    {
        Write-Verbose 'No devices found in Intune.'
        return $returnValue
    }
    Write-Verbose "Found $($autopilotDevices.value.count) Autopilot devices."
    $assignment = $autopilotDevices.value | Where-Object { $_.serialNumber -match $serialNumber }
    Write-Verbose "Found $($assignment.count) devices matching the serial number $serialNumber."
    Write-Verbose "Device assignment: $($assignment | ConvertTo-Json -Depth 10)"
    if ($assignment)
    {
        Write-Verbose 'The device is registered in Intune.'
        Write-Verbose 'Checking profile assignment'
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($assignment.id)?`$expand=deploymentProfile"
        Write-Verbose "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
        if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
        {
            $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI
            Write-Verbose "Graph response: $($assignment)."
            Write-Verbose "Device details: $($assignment | ConvertTo-Json -Depth 10)"
            Write-Verbose "The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($autopilotDevice.deploymentProfileAssignedDateTime)."
            Write-Verbose 'The device is ready for enrollment.'
            $returnValue = $assignment
        }
        elseif ($wwait)
        {
            Write-Host "Waiting for up to $maxWaitTime minutes for the device to be assigned to a deployment profile."
            $index = 0
            while (($assignment.deploymentProfileAssignmentStatus -ne 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -ne 'assignedInSync') -and $index -lt $maxWaitTime)
            {
                Write-Host "Waiting for $waitTimeInSeconds  seconds before checking again..." -ForegroundColor Yellow
                Start-Sleep -Seconds $waitTimeInSeconds
                $index++
                Write-Host "Checking again... ($index/$maxWaitTime)"
                $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI
                Write-Verbose "Graph response: $($autopilotDevices)."
            }
            if ((($assignment.deploymentProfileAssignmentStatus -ne 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -ne 'assignedInSync') -or -not ($assignment.deploymentProfileAssignedDateTime)) -and $index -gt $maxWaitTime)
            {
                Write-Host "The device assignment is taking too long (over $maxWaitTime minutes)."
                Write-Host 'Please check the Intune portal or contact an Intune administrator.'
            }
            elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose 'Congratulations!!! ' 
                Write-Verbose "The device is successfully assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime)."
                $returnValue = $assignment
            }
        }
        else
        {
            Write-Verbose 'The device is imported but not assigned to a deployment profile.'
            $returnValue = $assignment
            Write-Verbose "Returning $returnValue."
        }
    }
    else
    {
        Write-Verbose 'The device is not found in Intune.'
    }
    Write-Verbose "Returning $returnValue."
    return $returnValue
}
