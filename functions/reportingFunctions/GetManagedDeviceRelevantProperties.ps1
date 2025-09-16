function GetManagedDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
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

    if ($OrphanDevice -eq $false -and $CorrectRam -and -not ($HasUser -and $ValidUser))
    {
        $readyForNextUser = $true
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is ready for the next user" -LogLevel "Information"
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
    return $managedDeviceProperties
}

