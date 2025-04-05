function GetAutopilotProfileAssignment()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber
    )
    #write a verbose log of the parameters passed to the function
    Write-Verbose "ProfileName: $ProfileName"
    # Get the Autopilot profile assignment
    $autopilotProfiles = Get-AutopilotProfile 
    Write-Verbose "Autopilot Profiles: $($autopilotProfiles | Out-String)"
    if ($autopilotProfiles)
    {
        Write-Verbose "Found $($autopilotProfiles.Count) autopilot profiles."
        foreach ($autopilotProfile in $autopilotProfiles)
        {
            Write-Verbose "Profile: $($autopilotProfile.DisplayName)"
            $profileId = $autopilotProfile.Id
            Write-Verbose "ProfileId: $profileId"
            $assignment = Get-MgBetaDeviceManagementWindowsAutopilotDeploymentProfileAssignedDevice -Filter "contains(serialNumber,'$serialNumber')" -WindowsAutopilotDeploymentProfileId $profileId
            if ($assignment)
            {
                $deviceAssignment = $autopilotProfile.DisplayName
            }
            else
            {
                Write-Verbose "No assignments returned for profile $($profile.DisplayName)"
                $deviceAssignment = $null
            }
        }
    }
    else
    {
        Write-Verbose "The device with serial number $SerialNumber is not assigned to any autopilot profile."
        $deviceAssignment = $null
    }
    return $deviceAssignment
}