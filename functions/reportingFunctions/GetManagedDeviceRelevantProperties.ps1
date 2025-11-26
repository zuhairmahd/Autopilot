function GetManagedDeviceRelevantProperties()
{
    <#
    .SYNOPSIS
    Extracts relevant properties from managed device object for reporting.

    .DESCRIPTION
    This function selects and formats key properties from an Intune managed device object including
    device name, OS, compliance state, management state, last sync time, and user information.
    Returns standardized property set for consistent reporting.

    .PARAMETER managedDevice
    Managed device object from Graph API. This parameter is mandatory.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns object with relevant device properties formatted for reporting.

    .EXAMPLE
    $properties = GetManagedDeviceRelevantProperties -managedDevice $device

    .NOTES
    Standardizes property names and formats.
    Includes compliance, management, and user details.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings,
        [string]$username
    )
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceProperties = [ordered] @{}
    if ($null -eq $settings.MinimumDevicePhysicalMemoryInGB -or $settings.MinimumDevicePhysicalMemoryInGB -eq 0)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No minimum device physical memory specified in settings." -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Setting default value to 16GB." -LogLevel "Information"
        $MinimumDevicePhysicalMemoryInGB = 16
    }
    else
    {
        $MinimumDevicePhysicalMemoryInGB = $settings.MinimumDevicePhysicalMemoryInGB
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Minimum device physical memory specified in settings: $MinimumDevicePhysicalMemoryInGB" -LogLevel "Information"
    }
    Write-Host "Checking managed device..."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device: $($enrollmentState.managed)" -LogLevel "Information"
    if ($enrollmentState.managed)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found a managed device." -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking whether this is an orphan device..." -LogLevel "Verbose"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot managed device id: $($enrollmentState.autopilot.device.managedDeviceId)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device id: $($enrollmentState.managedDevice.device.id)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking if they are the same..." -LogLevel "Verbose"
        if ($enrollmentState.managedDevice.device.id -eq $enrollmentState.autopilot.device.managedDeviceId)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device Id's match." -LogLevel "Information"
            Write-Host "The device is not an orphan device."
            $orphanDevice = $false
            Write-Host "Checking whether the device has enough RAM..."
            if ($enrollmentState.managedDevice.memory -ge $MinimumDevicePhysicalMemoryInGB)
            {
                Write-Host "The device has $($enrollmentState.managedDevice.memory)GB of ram, which meets the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                $correctRam = $true
            }
            else
            {
                Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                Write-Host "Contact Hardware and Logistics."
                $correctRam = $false
            }   
            Write-Host "Checking for a user association on the manage device..."
            if ($enrollmentState.managedDevice.device.userId -ne '' -and $null -ne $enrollmentState.managedDevice.device.userId)
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found a user..." -LogLevel "Verbose"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User display name: $($enrollmentState.managedDevice.users.userDisplayName)" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User id: $($enrollmentState.managedDevice.device.userId)" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User principal name: $($enrollmentState.managedDevice.users.userPrincipalName)" -LogLevel "Information"
                $hasUser = $true
                
                # Check if device is registered to the same user we're checking for
                $registeredToSameUser = $false
                if (-not [string]::IsNullOrWhiteSpace($username) -and $enrollmentState.managedDevice.users.userPrincipalName)
                {
                    $registeredToSameUser = $enrollmentState.managedDevice.users.userPrincipalName -eq $username
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device registered to same user ($username): $registeredToSameUser" -LogLevel "Information"
                }
                
                if ($enrollmentState.managedDevice.users.azureUser)
                {
                    $validUser = $true
                    $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.users.userDisplayName
                    Write-Host "This device is registered to $($normalizedUsername.FullName) ($($enrollmentState.managedDevice.users.userPrincipalName))"
                    if ($null -ne $enrollmentState.managedDevice.users.lastLogOnDateTime)
                    {
                        $lastLogonDate = $enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone
                        Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $lastLogonDate."
                    }
                    else
                    {
                        $lastLogonDate = $null
                        Write-Host "Cannot determine the last time $($normalizedUsername.FirstName) logged on..."
                    }
                }
                else 
                {
                    Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                    Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                    $validUser = $false
                }
            }
            else
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The managed device is not associated with a user." -LogLevel "Information"
                Write-Host "The device is not associated with a user."
                $hasUser = $false
            }
        }
        else
        {
            $orphanDevice = $true
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device Id's do not match." -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is an orphan device." -LogLevel "Information"
        }
    }

    if ($OrphanDevice -eq $false -and $CorrectRam -and -not $HasUser)
    {
        $readyForNextUser = $true
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is ready for the next user" -LogLevel "Information"
    }
    elseif ($OrphanDevice -eq $false -and $CorrectRam -and $HasUser -and -not $ValidUser)
    {
        # Device has an invalid user (SPN or deleted user) - not ready
        $readyForNextUser = $false
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has invalid user association, not ready for next user" -LogLevel "Information"
    }
    else
    {
        $readyForNextUser = $false
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is not ready for the next user" -LogLevel "Information"
    }
    $managedDeviceProperties.Add('OrphanDevice', $orphanDevice)
    $managedDeviceProperties.Add('CorrectRam', $correctRam)
    $managedDeviceProperties.Add('HasUser', $hasUser)
    $managedDeviceProperties.Add('ValidUser', $validUser)
    $managedDeviceProperties.Add('LastLogonDate', $lastLogonDate)
    $managedDeviceProperties.Add('ReadyForNextUser', $readyForNextUser)
    $managedDeviceProperties.Add('RegisteredToSameUser', $registeredToSameUser)
    return $managedDeviceProperties
}

