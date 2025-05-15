function GetAutopilotProfileAssignment()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write a verbose log of the parameters passed to the function
    Write-Verbose "[$functionName] ProfileName: $ProfileName"
    # Get the Autopilot profile assignment
    $autopilotProfiles = Get-AutopilotProfile 
    Write-Verbose "[$functionName] Autopilot Profiles: $($autopilotProfiles | Out-String)"
    if ($autopilotProfiles)
    {
        Write-Verbose "[$functionName] Found $($autopilotProfiles.Count) autopilot profiles."
        foreach ($autopilotProfile in $autopilotProfiles)
        {
            Write-Verbose "[$functionName] Profile: $($autopilotProfile.DisplayName)"
            $profileId = $autopilotProfile.Id
            Write-Verbose "[$functionName] ProfileId: $profileId"
            $assignment = Get-MgBetaDeviceManagementWindowsAutopilotDeploymentProfileAssignedDevice -Filter "contains(serialNumber,'$serialNumber')" -WindowsAutopilotDeploymentProfileId $profileId
            if ($assignment)
            {
                $deviceAssignment = $autopilotProfile.DisplayName
            }
            else
            {
                Write-Verbose "[$functionName] No assignments returned for profile $($profile.DisplayName)"
                $deviceAssignment = $null
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device with serial number $SerialNumber is not assigned to any autopilot profile."
        $deviceAssignment = $null
    }
    return $deviceAssignment
}
