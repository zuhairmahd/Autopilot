function normalizeADUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
    $functionName = $MyInvocation.MyCommand.Name
    $processedUser = [ordered] @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "[$functionName] Converting user display name: $UserDisplayName"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Verbose "[$functionName] Returning original display name."
        $currentUser = $UserDisplayName
    }
    #Add what we got the the processedUser hashtable
    $processedUser.Add('FullName', $currentUser)
    $processedUser.Add('FirstName', $firstName)
    $processedUser.Add('LastName', $lastName)
    $processedUser.Add('MiddleInitial', $middleInitial)
    $processedUser.Add('Nickname', $nickname)
    return $processedUser
}

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


function MergeSettings
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $settings,
        [Parameter(Mandatory = $true)]
        $globalSettings
    )
    $merged = @{}

    # Add all keys from $settings
    foreach ($property in $settings.PSObject.Properties)
    {
        $merged[$property.Name] = $property.Value
    }

    # Add/merge all keys from $globalSettings
    foreach ($property in $globalSettings.PSObject.Properties)
    {
        if ($merged.ContainsKey($property.Name))
        {
            # If both are arrays, merge arrays
            if ($merged[$property.Name] -is [System.Collections.IEnumerable] -and
                $property.Value -is [System.Collections.IEnumerable] -and
                ($merged[$property.Name] -isnot [string]) -and
                ($property.Value -isnot [string]))
            {
                $merged[$property.Name] = @($merged[$property.Name] + $property.Value)
            }
            else
            {
                # Otherwise, overwrite
                $merged[$property.Name] = $property.Value
            }
        }
        else
        {
            $merged[$property.Name] = $property.Value
        }
    }
    return $merged
}
